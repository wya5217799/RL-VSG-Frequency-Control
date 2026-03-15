function [observation, loggedSignals] = vsg_reset_v2()
mdlName = evalin('base', 'mdlName');
J_min = evalin('base', 'J_min'); J_max = evalin('base', 'J_max');
D_min = evalin('base', 'D_min'); D_max = evalin('base', 'D_max');
J_init = J_min + (J_max - J_min) * rand();
D_init = D_min + (D_max - D_min) * rand();
J_norm = (J_init - J_min) / (J_max - J_min);
D_norm = (D_init - D_min) / (D_max - D_min);
set_param([mdlName '/VSG/Rotor Function/1//J'], 'Gain', sprintf('1/%.6f', J_init));
set_param([mdlName '/VSG/Rotor Function/D'],    'Gain', sprintf('%.6f',   D_init));
assignin('base', 'J_current', J_init);
assignin('base', 'D_current', D_init);
observation = [0.85; 0.99; 0.1; J_norm; D_norm];
loggedSignals.J_norm = J_norm; loggedSignals.D_norm = D_norm;
loggedSignals.J_val = J_init;  loggedSignals.D_val = D_init;
loggedSignals.stepCount = 0;
end
