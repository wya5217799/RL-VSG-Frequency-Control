function [observation, loggedSignals] = vsg_reset()
mdlName = evalin('base','mdlName');
J_min   = evalin('base','J_min');
J_max   = evalin('base','J_max');

% 随机J
J_norm = rand();
J_val  = J_min + J_norm*(J_max-J_min);
set_param([mdlName '/VSG/Rotor Function/1//J'],'Gain',sprintf('1/%.6f',J_val));

% 直接查找负载块，不依赖工作区变量
lb = find_system(mdlName,'MaskType','Three-Phase Parallel RLC Branch');
load_blk = lb{1};

% 随机负载三档
load_level = randi(3);
switch load_level
    case 1, P_load = 3e3 + rand()*2e3;   % 轻载 3~5 kW
    case 2, P_load = 5e3 + rand()*5e3;   % 中载 5~10 kW
    case 3, P_load = 10e3 + rand()*5e3;  % 重载 10~15 kW
end
R_expr = sprintf('380^2/%.0f', P_load);
set_param(load_blk, 'Resistance', R_expr);

loggedSignals.stepCount  = 0;
loggedSignals.J_val      = J_val;
loggedSignals.J_norm     = J_norm;
loggedSignals.P_load     = P_load;
loggedSignals.load_level = load_level;

load_norm   = (load_level-1)/2;
observation = [50; 8500; 311; J_norm; load_norm];
end
