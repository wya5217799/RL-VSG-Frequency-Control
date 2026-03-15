function [observation, reward, isdone, loggedSignals] = vsg_step(action, loggedSignals)
mdlName = evalin('base','mdlName');
J_min   = evalin('base','J_min');
J_max   = evalin('base','J_max');

J_norm = max(0, min(1, double(action(1))));
J_val  = J_min + J_norm*(J_max-J_min);
set_param([mdlName '/VSG/Rotor Function/1//J'],'Gain',sprintf('1/%.6f',J_val));

P_load     = loggedSignals.P_load;
load_level = loggedSignals.load_level;
load_norm  = (load_level-1)/2;

reward=-50; f_fin=50; Pe_fin=8500; Vamp_fin=311;

try
    simOut=sim(mdlName,'StopTime','1.5','ReturnWorkspaceOutputs','on');
    t   =simOut.f.Time;  fv  =simOut.f.Data;
    Vdv =simOut.Vd.Data; Vqv =simOut.Vq.Data;
    t_Pe=simOut.Pe.Time; Pev =simOut.Pe.Data;
    Vamp=sqrt(Vdv.^2+Vqv.^2);

    df_dt =abs(diff(fv)./diff(t));
    t_mid =t(1:end-1);
    idx_rc=t_mid>=0.395 & t_mid<0.45;
    rocof =max(df_dt(idx_rc))*any(idx_rc);
    if rocof==0, rocof=0.0005; end

    idx_f=t>=0.35 & t<0.90;
    f_dev=max(abs(fv(idx_f)-50.0));

    t_aft=t(t>=0.4); f_aft=fv(t>=0.4);
    idx_s=find(abs(f_aft-50)<f_dev*0.1,1,'first');
    t_settle=1.1;
    if ~isempty(idx_s), t_settle=t_aft(idx_s)-0.4; end

    reward=-(1000*rocof+3000*f_dev+0.5*t_settle)*10;

    idx_st=t>=0.1;
    if max(abs(fv(idx_st)-50))>2.0||min(Vamp(idx_st))<30
        reward=-100;
    end

    f_fin=fv(end); Pe_fin=Pev(end); Vamp_fin=Vamp(end);
catch ME
    warning('[vsg_step] %s',ME.message);
end

observation=[f_fin;Pe_fin;Vamp_fin;J_norm;load_norm];
isdone=true;
loggedSignals.stepCount=loggedSignals.stepCount+1;
loggedSignals.J_val =J_val;
loggedSignals.J_norm=J_norm;

fprintf('[Ep%3d] J=%5.2f P=%6.0fW L=%d reward=%7.3f\n',...
    loggedSignals.stepCount,J_val,P_load,load_level,reward);
end
