function [observation, reward, isdone, loggedSignals] = vsg_step_td3(action, loggedSignals)
mdlName=evalin('base','mdlName');
J_min=evalin('base','J_min'); J_max=evalin('base','J_max');
D_min=evalin('base','D_min'); D_max=evalin('base','D_max');

J_norm=max(0,min(1,double(action(1))));
D_norm=max(0,min(1,double(action(2))));
J_val=J_min+J_norm*(J_max-J_min);
D_val=D_min+D_norm*(D_max-D_min);
set_param([mdlName '/VSG/Rotor Function/1//J'],'Gain',sprintf('1/%.6f',J_val));
set_param([mdlName '/VSG/Rotor Function/D'],'Gain',sprintf('%.4f',D_val));

P_load=loggedSignals.P_load;
load_level=loggedSignals.load_level;
load_norm=(load_level-1)/2;
reward=-50; f_fin=50; Pe_fin=8500; Vamp_fin=311;
delta_f_fin=0; dwdt_fin=0; Psi_fin=0;

try
    simOut=sim(mdlName,'StopTime','1.5','ReturnWorkspaceOutputs','on');
    t=simOut.f.Time; fv=simOut.f.Data;
    Vdv=simOut.Vd.Data; Vqv=simOut.Vq.Data;
    Pev=simOut.Pe.Data;
    Vamp=sqrt(Vdv.^2+Vqv.^2);

    % RoCoF
    df_dt=diff(fv)./diff(t);  % 保留符号
    t_mid=t(1:end-1);
    idx_rc=t_mid>=0.395 & t_mid<0.45;
    rocof=max(abs(df_dt(idx_rc)))*any(idx_rc);
    if rocof==0, rocof=0.0005; end

    % 频率偏差
    idx_f=t>=0.35 & t<0.90;
    f_dev=max(abs(fv(idx_f)-50));

    % 积分项 ∫|Δf|dt（对应论文r_integ）
    f_integ=trapz(t(idx_f), abs(fv(idx_f)-50));

    % reward（对标论文三项惩罚）
    reward=-(3000*f_dev + 1000*rocof + 500*f_integ)*10;

    % 稳定性保护
    idx_st=t>=0.1;
    if max(abs(fv(idx_st)-50))>2||min(Vamp(idx_st))<30
        reward=-100;
    end

    % 末态观测量
    f_fin=fv(end);
    Pe_fin=Pev(end);
    Vamp_fin=Vamp(end);

    % Ψ变量：核心改进（来自论文3.2节）
    % Ψ = sign((f-fn) * df/dt)
    % +1: 频率正在偏离额定值（恶化）
    % -1: 频率正在向额定值收敛（改善）
    delta_f_fin = f_fin - 50;
    n=length(fv);
    dwdt_fin=(fv(n)-fv(max(1,n-100)))/(t(n)-t(max(1,n-100))+1e-9);
    Psi_fin=sign(delta_f_fin * dwdt_fin);
    if Psi_fin==0, Psi_fin=0; end  % 稳态时为0

catch ME
    warning('[vsg_step_td3] %s',ME.message);
end

% 8维观测：加入Ψ（对标论文改进版状态空间）
% [Δf, df/dt归一化, Ψ, Pe归一化, Vamp归一化, J_norm, D_norm, load_norm]
observation=[delta_f_fin/5; dwdt_fin/10; Psi_fin; Pe_fin/20000-0.5; Vamp_fin/400; J_norm; D_norm; load_norm];
isdone=true;
loggedSignals.stepCount=loggedSignals.stepCount+1;
loggedSignals.J_val=J_val; loggedSignals.J_norm=J_norm;
loggedSignals.D_val=D_val; loggedSignals.D_norm=D_norm;
fprintf('[Ep%3d] J=%4.2f D=%5.1f P=%6.0fW L=%d r=%7.2f\n',...
    loggedSignals.stepCount,J_val,D_val,P_load,load_level,reward);
end
