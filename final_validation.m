%% final_validation.m
%% 最终对比验证：5种方案 × 3种场景 = 15组实验
%% 这就是论文Table和Figure的核心数据
clear; clc;
vsgDir  = 'C:\Users\27443\Desktop\VSG';
mdlPath = [vsgDir '\Three_Phase_VSG_Double_Loop_Control.mdl\Three_Phase_VSG_Double_Loop_Control.mdl'];
mdlName = 'Three_Phase_VSG_Double_Loop_Control';
addpath(vsgDir);
load_system(mdlPath);
set_param(mdlName,'SolverType','Variable-step','Solver','ode45','StopTime','1.5');
set_param([mdlName '/Step'],'Commented','on');
set_param(mdlName,'SimulationMode','normal');

%% 加载训练好的TD3+Ψ agent
J_min=0.05;J_max=5.0;D_min=5.0;D_max=100.0;
assignin('base','mdlName',mdlName);
assignin('base','J_min',J_min);assignin('base','J_max',J_max);
assignin('base','D_min',D_min);assignin('base','D_max',D_max);
td3_data = load(fullfile(vsgDir,'saved_agents_td3','FINAL_TD3_Psi.mat'));
td3_agent = td3_data.saved_agent;
fprintf('✓ TD3+Ψ agent加载完成\n');

%% 三种测试场景
scenarios = struct();
scenarios(1).name = 'Light Load';  scenarios(1).P = 4e3;
scenarios(2).name = 'Medium Load'; scenarios(2).P = 8e3;
scenarios(3).name = 'Heavy Load';  scenarios(3).P = 13e3;

%% 五种对比方案
methods = {'Fixed J=0.5(Default)', 'Fixed J=5.0(Best)', 'TD3+Ψ(Proposed)', 'Fixed D=20 J=0.5', 'Fixed D=100 J=5'};
lb = find_system(mdlName,'MaskType','Three-Phase Parallel RLC Branch');

%% 结果存储
nS=3; nM=5;
RES_fdev  = zeros(nS,nM);
RES_rocof = zeros(nS,nM);
RES_Vmin  = zeros(nS,nM);
f_waves = cell(nS,nM);
t_waves = cell(nS,nM);

fprintf('开始验证实验（共%d组，每组约45s）...\n',nS*nM);
fprintf('%-25s %-12s %-12s %-10s\n','方案','|Δf|(Hz)','RoCoF(Hz/s)','Vmin(V)');
fprintf('%s\n',repmat('-',60,1));

for si=1:nS
    P_load = scenarios(si).P;
    set_param(lb{1},'Resistance',sprintf('380^2/%.0f',P_load));
    fprintf('\n[场景%d] %s (P=%.0fW)\n',si,scenarios(si).name,P_load);

    for mi=1:nM
        % 设置参数
        switch mi
            case 1 % Fixed J=0.5
                set_param([mdlName '/VSG/Rotor Function/1//J'],'Gain','1/0.5');
                set_param([mdlName '/VSG/Rotor Function/D'],'Gain','20');
            case 2 % Fixed J=5.0
                set_param([mdlName '/VSG/Rotor Function/1//J'],'Gain','1/5.0');
                set_param([mdlName '/VSG/Rotor Function/D'],'Gain','20');
            case 3 % TD3+Ψ（用agent决策）
                % 构造观测
                obs = [0;0;0;P_load/20000-0.5;311/400;0.5;0.5;(si-1)/2];
                act = getAction(td3_agent,{obs});
                J_n=double(act{1}(1)); D_n=double(act{1}(2));
                J_v=J_min+J_n*(J_max-J_min);
                D_v=D_min+D_n*(D_max-D_min);
                set_param([mdlName '/VSG/Rotor Function/1//J'],'Gain',sprintf('1/%.4f',J_v));
                set_param([mdlName '/VSG/Rotor Function/D'],'Gain',sprintf('%.4f',D_v));
                fprintf('    TD3决策: J=%.2f D=%.1f\n',J_v,D_v);
            case 4 % Fixed D=20 J=0.5
                set_param([mdlName '/VSG/Rotor Function/1//J'],'Gain','1/0.5');
                set_param([mdlName '/VSG/Rotor Function/D'],'Gain','20');
            case 5 % Fixed D=100 J=5
                set_param([mdlName '/VSG/Rotor Function/1//J'],'Gain','1/5.0');
                set_param([mdlName '/VSG/Rotor Function/D'],'Gain','100');
        end

        simOut=sim(mdlName,'StopTime','1.5','ReturnWorkspaceOutputs','on');
        t=simOut.f.Time; fv=simOut.f.Data;
        Vdv=simOut.Vd.Data; Vqv=simOut.Vq.Data;
        Vamp=sqrt(Vdv.^2+Vqv.^2);

        idx_f=t>=0.35&t<0.90;
        f_dev=max(abs(fv(idx_f)-50));
        df_dt=abs(diff(fv)./diff(t));
        t_mid=t(1:end-1);
        idx_rc=t_mid>=0.395&t_mid<0.45;
        rocof=max(df_dt(idx_rc));
        Vmin=min(Vamp(idx_f));

        RES_fdev(si,mi)=f_dev;
        RES_rocof(si,mi)=rocof;
        RES_Vmin(si,mi)=Vmin;
        f_waves{si,mi}=fv; t_waves{si,mi}=t;

        fprintf('  %-23s %-12.6f %-12.6f %-10.4f\n',methods{mi},f_dev,rocof,Vmin);
    end
end

save(fullfile(vsgDir,'validation_results.mat'),'RES_fdev','RES_rocof','RES_Vmin','f_waves','t_waves','scenarios','methods');
fprintf('\n✓ 所有结果已保存到 validation_results.mat\n');

%% 打印最终汇总表
fprintf('\n==================== 论文核心结果表 ====================\n');
fprintf('%-25s','方案');
for si=1:3, fprintf(' %-20s',scenarios(si).name); end
fprintf('\n');
fprintf('%s\n',repmat('-',85,1));
fprintf('--- |Δf| (Hz) ---\n');
for mi=1:nM
    fprintf('%-25s',methods{mi});
    for si=1:3, fprintf(' %-20.6f',RES_fdev(si,mi)); end
    fprintf('\n');
end
fprintf('--- RoCoF (Hz/s) ---\n');
for mi=1:nM
    fprintf('%-25s',methods{mi});
    for si=1:3, fprintf(' %-20.6f',RES_rocof(si,mi)); end
    fprintf('\n');
end
