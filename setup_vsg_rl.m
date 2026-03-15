clear; clc;
mdlName = 'Three_Phase_VSG_Double_Loop_Control';
mdlPath  = 'C:\\Users\\27443\\Desktop\\VSG\\Three_Phase_VSG_Double_Loop_Control.mdl\\Three_Phase_VSG_Double_Loop_Control.mdl';
addpath('C:\\Users\\27443\\Desktop\\VSG');
fprintf('加载模型...\\n');
load_system(mdlPath);

% 求解器
set_param(mdlName, 'SolverType', 'Fixed-step');
set_param(mdlName, 'Solver',     'ode4');
set_param(mdlName, 'FixedStep',  '1e-4');
set_param(mdlName, 'StopTime',   '1.5');
fprintf('求解器: Fixed-step ode4, dt=1e-4\\n');

% J 参数范围
J_min = 0.05; J_max = 5.0; J_init = 0.5;
set_param([mdlName '/VSG/Rotor Function/1//J'], 'Gain', sprintf('1/%g', J_init));
fprintf('J 范围: [%.2f, %.2f]\\n', J_min, J_max);

% 工作区变量（step/reset 函数需要）
assignin('base', 'mdlName', mdlName);
assignin('base', 'J_min', J_min);
assignin('base', 'J_max', J_max);
assignin('base', 'J_current', J_init);

% 观测量
obsInfo = rlNumericSpec([4 1], 'LowerLimit', [45;0;0;0], 'UpperLimit', [55;20000;400;1]);
obsInfo.Name = 'VSG_observations';

% 动作量
actInfo = rlNumericSpec([1 1], 'LowerLimit', 0, 'UpperLimit', 1);
actInfo.Name = 'J_normalized';

% 环境
env = rlFunctionEnv(obsInfo, actInfo, 'vsg_step', 'vsg_reset');
fprintf('RL 环境创建成功\\n');

% Critic 网络
statePath = featureInputLayer(4, 'Normalization', 'none', 'Name', 'state');
actionPath = featureInputLayer(1, 'Normalization', 'none', 'Name', 'action');
criticNet1 = [statePath; fullyConnectedLayer(64,'Name','fc1_s'); reluLayer('Name','relu1_s')];
criticNet2 = [actionPath; fullyConnectedLayer(64,'Name','fc1_a'); reluLayer('Name','relu1_a')];
criticMerge = [additionLayer(2,'Name','add'); reluLayer('Name','relu_m'); fullyConnectedLayer(64,'Name','fc2'); reluLayer('Name','relu2'); fullyConnectedLayer(1,'Name','Qout')];
cDLN = layerGraph(criticNet1);
cDLN = addLayers(cDLN, criticNet2);
cDLN = addLayers(cDLN, criticMerge);
cDLN = connectLayers(cDLN,'relu1_s','add/in1');
cDLN = connectLayers(cDLN,'relu1_a','add/in2');
critic = rlQValueFunction(cDLN, obsInfo, actInfo, 'ObservationInputNames','state','ActionInputNames','action');

% Actor 网络
actorNet = [featureInputLayer(4,'Normalization','none','Name','state'); fullyConnectedLayer(64,'Name','fc1'); reluLayer('Name','relu1'); fullyConnectedLayer(64,'Name','fc2'); reluLayer('Name','relu2'); fullyConnectedLayer(1,'Name','fcout'); sigmoidLayer('Name','sigmoid')];
actor = rlContinuousDeterministicActor(actorNet, obsInfo, actInfo);

% DDPG Agent
agentOpts = rlDDPGAgentOptions('SampleTime',0.1,'DiscountFactor',0.99,'MiniBatchSize',64,'ExperienceBufferLength',1e5,'TargetSmoothFactor',1e-3,'ActorOptimizerOptions',rlOptimizerOptions('LearnRate',1e-4),'CriticOptimizerOptions',rlOptimizerOptions('LearnRate',1e-3));
agentOpts.NoiseOptions.StandardDeviation = 0.15;
agentOpts.NoiseOptions.StandardDeviationDecayRate = 1e-5;
agent = rlDDPGAgent(actor, critic, agentOpts);
fprintf('DDPG Agent 创建完成\\n');

% 训练选项
if ~exist('C:\\Users\\27443\\Desktop\\VSG\\saved_agents','dir'), mkdir('C:\\Users\\27443\\Desktop\\VSG\\saved_agents'); end
trainOpts = rlTrainingOptions('MaxEpisodes',500,'MaxStepsPerEpisode',1,'ScoreAveragingWindowLength',20,'StopTrainingCriteria','AverageReward','StopTrainingValue',-0.5,'Verbose',true,'Plots','training-progress','SaveAgentCriteria','EpisodeReward','SaveAgentValue',-1.0,'SaveAgentDirectory','C:\\Users\\27443\\Desktop\\VSG\\saved_agents');
fprintf('\\n所有配置完成！\\n运行: trainingStats = train(agent, env, trainOpts)\\n');
