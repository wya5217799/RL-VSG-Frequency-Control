%% RESUME_TD3.m - 从上次崩溃断点继续TD3训练
%% 自动加载最新保存的Agent，无需从头训练
clear; clc;
vsgDir  = 'C:\Users\27443\Desktop\VSG';
mdlPath = [vsgDir '\Three_Phase_VSG_Double_Loop_Control.mdl\Three_Phase_VSG_Double_Loop_Control.mdl'];
mdlName = 'Three_Phase_VSG_Double_Loop_Control';
addpath(vsgDir);

fprintf('[1/4] 加载模型...\n');
load_system(mdlPath);
set_param(mdlName,'SolverType','Variable-step','Solver','ode45','StopTime','1.5');
set_param([mdlName '/Step'],'Commented','on');
set_param(mdlName,'SimulationMode','normal');
set_param(mdlName,'FastRestart','off');
set_param([mdlName '/VSG/Rotor Function/1//J'],'Gain','1/0.5');
set_param([mdlName '/VSG/Rotor Function/D'],'Gain','20');
fprintf('    完成\n');

fprintf('[2/4] 初始化变量...\n');
J_min=0.05; J_max=5.0; D_min=5.0; D_max=100.0;
assignin('base','mdlName',mdlName);
assignin('base','J_min',J_min); assignin('base','J_max',J_max);
assignin('base','D_min',D_min); assignin('base','D_max',D_max);
fprintf('    完成\n');

fprintf('[3/4] 加载最新保存的TD3 Agent...\n');
saveDir = fullfile(vsgDir,'saved_agents_td3');
d = dir(fullfile(saveDir,'Agent*.mat'));
[~,idx] = max([d.datenum]);
latestFile = fullfile(saveDir, d(idx).name);
fprintf('    加载: %s\n', d(idx).name);
data = load(latestFile);
agent = data.saved_agent;
fprintf('    Agent类型: %s\n', class(agent));

%% 重建环境（必须，因为env不保存在agent里）
obsInfo=rlNumericSpec([8 1],...
    'LowerLimit',[-1;-1;-1;-0.5;0;0;0;0],...
    'UpperLimit',[ 1; 1; 1; 0.5;1;1;1;1]);
obsInfo.Name='VSG_8d_Psi';
actInfo=rlNumericSpec([2 1],'LowerLimit',[0;0],'UpperLimit',[1;1]);
actInfo.Name='JD_norm';
env=rlFunctionEnv(obsInfo,actInfo,'vsg_step_td3','vsg_reset_td3');
fprintf('    环境重建完成\n');

fprintf('[4/4] 配置续训选项...\n');
trainOpts=rlTrainingOptions(...
    'MaxEpisodes',500,...
    'MaxStepsPerEpisode',1,...
    'ScoreAveragingWindowLength',20,...
    'StopTrainingCriteria','AverageReward',...
    'StopTrainingValue',-10.0,...
    'Verbose',true,...
    'Plots','training-progress',...
    'SaveAgentCriteria','EpisodeReward',...
    'SaveAgentValue',-11.0,...
    'SaveAgentDirectory',saveDir);
fprintf('    完成\n');

fprintf('\n========================================\n');
fprintf('✓ 从 %s 恢复训练\n', d(idx).name);
fprintf('  注意：Episode编号从1重新开始，但网络权重已恢复\n');
fprintf('\n运行: trainingStats = train(agent, env, trainOpts);\n');
fprintf('========================================\n');
