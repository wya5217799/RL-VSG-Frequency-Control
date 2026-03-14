%% START_TRAINING_TD3.m - 阶段2：TD3 + J+D + 8维观测（含Ψ）
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
set_param([mdlName '/VSG/Rotor Function/D'],'Gain','20');
fprintf('    完成\n');

fprintf('[2/4] 初始化变量...\n');
J_min=0.05; J_max=5.0;
D_min=5.0;  D_max=100.0;
assignin('base','mdlName',mdlName);
assignin('base','J_min',J_min); assignin('base','J_max',J_max);
assignin('base','D_min',D_min); assignin('base','D_max',D_max);
fprintf('    J∈[%.2f,%.2f]  D∈[%.1f,%.1f]\n',J_min,J_max,D_min,D_max);
fprintf('    完成\n');

fprintf('[3/4] 创建TD3环境和Agent...\n');
%% 8维观测: [Δf/5, dwdt/10, Ψ, Pe_norm, Vamp_norm, J_norm, D_norm, load_norm]
obsInfo=rlNumericSpec([8 1],...
    'LowerLimit',[-1;-1;-1;-0.5;0;0;0;0],...
    'UpperLimit',[ 1; 1; 1; 0.5;1;1;1;1]);
obsInfo.Name='VSG_8d_Psi';
%% 2维动作 [J_norm, D_norm]
actInfo=rlNumericSpec([2 1],'LowerLimit',[0;0],'UpperLimit',[1;1]);
actInfo.Name='JD_norm';
env=rlFunctionEnv(obsInfo,actInfo,'vsg_step_td3','vsg_reset_td3');

%% 两个Critic（TD3核心）
function crt=mkC(pfx,oInfo,aInfo)
    sp=featureInputLayer(8,'Normalization','none','Name','s');
    ap=featureInputLayer(2,'Normalization','none','Name','a');
    c1=[sp;fullyConnectedLayer(128,'Name',[pfx,'1']);reluLayer('Name',[pfx,'r1'])];
    c2=[ap;fullyConnectedLayer(128,'Name',[pfx,'2']);reluLayer('Name',[pfx,'r2'])];
    cm=[additionLayer(2,'Name',[pfx,'ad']);reluLayer('Name',[pfx,'rm']);
        fullyConnectedLayer(64,'Name',[pfx,'3']);reluLayer('Name',[pfx,'r3']);
        fullyConnectedLayer(1,'Name',[pfx,'Q'])];
    cg=layerGraph(c1);cg=addLayers(cg,c2);cg=addLayers(cg,cm);
    cg=connectLayers(cg,[pfx,'r1'],[pfx,'ad/in1']);
    cg=connectLayers(cg,[pfx,'r2'],[pfx,'ad/in2']);
    crt=rlQValueFunction(cg,oInfo,aInfo,...
        'ObservationInputNames','s','ActionInputNames','a');
end
critic1=mkC('ca',obsInfo,actInfo);
critic2=mkC('cb',obsInfo,actInfo);

%% Actor（8维输入，2维输出）
actorNet=[featureInputLayer(8,'Normalization','none','Name','s');
    fullyConnectedLayer(128,'Name','a1');reluLayer('Name','ra1');
    fullyConnectedLayer(64, 'Name','a2');reluLayer('Name','ra2');
    fullyConnectedLayer(2,  'Name','ao');
    tanhLayer('Name','th');
    scalingLayer('Name','sc','Scale',0.5,'Bias',0.5)];
actor=rlContinuousDeterministicActor(actorNet,obsInfo,actInfo);

%% TD3 Agent
agentOpts=rlTD3AgentOptions('SampleTime',1,'DiscountFactor',0.99,...
    'MiniBatchSize',64,'ExperienceBufferLength',2000,...
    'TargetSmoothFactor',5e-3,'PolicyUpdateFrequency',2,...
    'ActorOptimizerOptions', rlOptimizerOptions('LearnRate',1e-4),...
    'CriticOptimizerOptions',rlOptimizerOptions('LearnRate',2e-4));
agentOpts.ExplorationModel.StandardDeviation=0.2;
agentOpts.ExplorationModel.StandardDeviationDecayRate=2e-3;
agent=rlTD3Agent(actor,[critic1,critic2],agentOpts);
fprintf('    完成\n');

fprintf('[4/4] 配置训练...\n');
saveDir=fullfile(vsgDir,'saved_agents_td3');
if ~exist(saveDir,'dir'),mkdir(saveDir);end
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
fprintf('✓ TD3 + Ψ 阶段2就绪！\n');
fprintf('  状态: 8维 [Δf,dω/dt,Ψ,Pe,Vamp,J,D,load]\n');
fprintf('  动作: J∈[0.05,5.0]  D∈[5,100]\n');
fprintf('  Ψ=sign(Δf·dω/dt)：判断频率收敛方向\n');
fprintf('\n运行: trainingStats = train(agent, env, trainOpts);\n');
fprintf('========================================\n');
