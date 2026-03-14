function [observation, loggedSignals] = vsg_reset_td3()
mdlName=evalin('base','mdlName');
J_min=evalin('base','J_min'); J_max=evalin('base','J_max');
D_min=evalin('base','D_min'); D_max=evalin('base','D_max');
J_norm=rand(); J_val=J_min+J_norm*(J_max-J_min);
D_norm=rand(); D_val=D_min+D_norm*(D_max-D_min);
set_param([mdlName '/VSG/Rotor Function/1//J'],'Gain',sprintf('1/%.6f',J_val));
set_param([mdlName '/VSG/Rotor Function/D'],'Gain',sprintf('%.4f',D_val));
lb=find_system(mdlName,'MaskType','Three-Phase Parallel RLC Branch');
load_level=randi(3);
switch load_level
    case 1, P_load=3e3+rand()*2e3;
    case 2, P_load=5e3+rand()*5e3;
    case 3, P_load=10e3+rand()*5e3;
end
set_param(lb{1},'Resistance',sprintf('380^2/%.0f',P_load));
loggedSignals.stepCount=0;
loggedSignals.J_val=J_val; loggedSignals.J_norm=J_norm;
loggedSignals.D_val=D_val; loggedSignals.D_norm=D_norm;
loggedSignals.P_load=P_load; loggedSignals.load_level=load_level;
load_norm=(load_level-1)/2;
Pe_norm  = 8500/20000 - 0.5;   % 先定义
Vamp_norm= 311/400;             % 先定义
observation=[0; 0; 0; Pe_norm; Vamp_norm; J_norm; D_norm; load_norm];
end
