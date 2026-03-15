%% START_TRAINING.m - 阶段1：随机扰动 + 5维观测 + DDPG
clear; clc;
vsgDir  = 'C:\Users\27443\Desktop\VSG';
mdlPath = [vsgDir '\Three_Phase_VSG_Double_Loop_Control.mdl\Three_Phase_VSG_Double_Loop_Control.mdl'];
mdlName = 'Three_Phase_VSG_Double_Loop_Control';
addpath(vsgDir);

fprintf('[1/4] 加载模型...\n');
load_system(mdlPath);
set_param(mdlName,'SolverType','Variable-step','Solver','ode45','StopTime','1.5');
set_param([mdlName '/Step'],'Commented','on');
set_param([mdlName '/VSG/Rotor Function/1//J'],'Gain','1/0.5');
fprintf('    完成\n');

fprintf('[2/4] 初始化变量...\n');
J_min = 0.05; J_max = 5.0;
assignin('base','mdlName',  mdlName);
assignin('base','J_min',    J_min);
assignin('base','J_max',    J_max);
lb = find_system(mdlName,'MaskType','Three-Phase Parallel RLC Branch');
assignin('base','load_blk_path', lb{1});
fprintf('    负载块: %s\n', lb{1});
fprintf('    完成\n');

fprintf('[3/4] 创建环境和Agent...\n');
obsInfo = rlNumericSpec([5 1],'LowerLimit',[45;0;0;0;0],'UpperLimit',[55;20000;400;1;1]);
obsInfo.Name = 'VSG_obs';
actInfo = rlNumericSpec([1 1],'LowerLimit',0,'UpperLimit',1);
actInfo.Name = 'J_norm';
env = rlFunctionEnv(obsInfo,actInfo,'vsg_step','vsg_reset');

sp=featureInputLayer(5,'Normalization','none','Name','s');
ap=featureInputLayer(1,'Normalization','none','Name','a');
c1=[sp; fullyConnectedLayer(128,'Name','c1'); reluLayer('Name','rc1')];
c2=[ap; fullyConnectedLayer(128,'Name','c2'); reluLayer('Name','rc2')];
cm=[additionLayer(2,'Name','add'); reluLayer('Name','rm');
    fullyConnectedLayer(64,'Name','c3'); reluLayer('Name','rc3');
    fullyConnectedLayer(1,'Name','Q')];
cg=layerGraph(c1); cg=addLayers(cg,c2); cg=addLayers(cg,cm);
cg=connectLayers(cg,'rc1','add/in1'); cg=connectLayers(cg,'rc2','add/in2');
critic=rlQValueFunction(cg,obsInfo,actInfo,'ObservationInputNames','s','ActionInputNames','a');

actorNet=[featureInputLayer(5,'Normalization','none','Name','s');
    fullyConnectedLayer(128,'Name','a1'); reluLayer('Name','ra1');
    fullyConnectedLayer(64, 'Name','a2'); reluLayer('Name','ra2');
    fullyConnectedLayer(1,  'Name','ao');
    tanhLayer('Name','tanh1');
    scalingLayer('Name','scale1','Scale',0.5,'Bias',0.5)];
actor=rlContinuousDeterministicActor(actorNet,obsInfo,actInfo);

agentOpts=rlDDPGAgentOptions('SampleTime',1,'DiscountFactor',0.99,...
    'MiniBatchSize',64,'ExperienceBufferLength',2000,...
    'TargetSmoothFactor',5e-3,...
    'ActorOptimizerOptions', rlOptimizerOptions('LearnRate',1e-4),...
    'CriticOptimizerOptions',rlOptimizerOptions('LearnRate',2e-4));
agentOpts.NoiseOptions.StandardDeviation = 0.2;
agentOpts.NoiseOptions.StandardDeviationDecayRate = 2e-3;
agent = rlDDPGAgent(actor,critic,agentOpts);
fprintf('    完成\n');

fprintf('[4/4] 配置训练...\n');
saveDir = fullfile(vsgDir,'saved_agents');
if ~exist(saveDir,'dir'), mkdir(saveDir); end
trainOpts = rlTrainingOptions(...
    'MaxEpisodes',             500,...
    'MaxStepsPerEpisode',       1,...
    'ScoreAveragingWindowLength',20,...
    'StopTrainingCriteria',     'AverageReward',...
    'StopTrainingValue',        -11.5,...
    'Verbose',                  true,...
    'Plots',                    'training-progress',...
    'SaveAgentCriteria',        'EpisodeReward',...
    'SaveAgentValue',           -12.0,...
    'SaveAgentDirectory',       saveDir);
fprintf('    完成\n');

fprintf('\n========================================\n');
fprintf('✓ 阶段1就绪：随机扰动 + 5维观测\n');
fprintf('  观测: [f, Pe, Vamp, J_norm, load_norm]\n');
fprintf('  扰动: 轻载3~5kW / 中载5~10kW / 重载10~15kW\n');
fprintf('  目标: 不同负载下Agent输出不同J\n');
fprintf('\n运行: trainingStats = train(agent, env, trainOpts);\n');
fprintf('========================================\n');
