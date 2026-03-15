%% CONTINUE_TRAINING.m - 从BEST_sofar继续训练
clear; clc;
vsgDir  = 'C:\Users\27443\Desktop\VSG';
mdlPath = [vsgDir '\Three_Phase_VSG_Double_Loop_Control.mdl\Three_Phase_VSG_Double_Loop_Control.mdl'];
mdlName = 'Three_Phase_VSG_Double_Loop_Control';
addpath(vsgDir);

%% 1. 加载模型
load_system(mdlPath);
set_param(mdlName,'SolverType','Variable-step','Solver','ode45','StopTime','1.5');
set_param(mdlName,'SimulationMode','normal');
set_param([mdlName '/Step'],'Commented','on');

%% 2. 工作区变量
J_min=0.05;J_max=5.0;D_min=5.0;D_max=100.0;
assignin('base','mdlName',mdlName);
assignin('base','J_min',J_min);assignin('base','J_max',J_max);
assignin('base','D_min',D_min);assignin('base','D_max',D_max);

%% 3. 重建环境（必须，env不保存在agent里）
obsInfo=rlNumericSpec([8 1],'LowerLimit',[-1;-1;-1;-0.5;0;0;0;0],'UpperLimit',[1;1;1;0.5;1;1;1;1]);
obsInfo.Name='VSG_8d_Psi';
actInfo=rlNumericSpec([2 1],'LowerLimit',[0;0],'UpperLimit',[1;1]);
actInfo.Name='JD_norm';
env=rlFunctionEnv(obsInfo,actInfo,'vsg_step_td3','vsg_reset_td3');
fprintf('✓ 环境重建完成\n');

%% 4. 加载最佳agent
data=load(fullfile(vsgDir,'saved_agents_td3','BEST_sofar.mat'));
agent=data.agent;
fprintf('✓ Agent加载完成: %s\n',class(agent));

%% 5. 训练选项（不自动停止）
saveDir=fullfile(vsgDir,'saved_agents_td3');
trainOpts=rlTrainingOptions(...
    'MaxEpisodes',           500,...
    'MaxStepsPerEpisode',     1,...
    'ScoreAveragingWindowLength',20,...
    'StopTrainingCriteria',   'AverageReward',...
    'StopTrainingValue',      -1.0,...
    'Verbose',                true,...
    'Plots',                  'training-progress',...
    'SaveAgentCriteria',      'EpisodeReward',...
    'SaveAgentValue',         -6.0,...
    'SaveAgentDirectory',     saveDir);

fprintf('✓ 全部就绪，开始续训...\n');
fprintf('  目标：跑满500轮或手动停止\n');
fprintf('  当前最佳：Average=-6.90\n');
trainingStats = train(agent, env, trainOpts);
