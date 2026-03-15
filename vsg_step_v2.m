function [observation, reward, isdone, loggedSignals] = vsg_step_v2(action, loggedSignals)
mdlName=evalin('base','mdlName'); J_min=evalin('base','J_min'); J_max=evalin('base','J_max');
D_min=evalin('base','D_min'); D_max=evalin('base','D_max');
J_norm=max(0,min(1,double(action(1)))); D_norm=max(0,min(1,double(action(2))));
J_val=J_min+J_norm*(J_max-J_min); D_val=D_min+D_norm*(D_max-D_min);
set_param([mdlName '/VSG/Rotor Function/1//J'],'Gain',sprintf('1/%.6f',J_val));
set_param([mdlName '/VSG/Rotor Function/D'],   'Gain',sprintf('%.6f',  D_val));
reward=-5.0; obs_out=[0.85;0.99;0.5;J_norm;D_norm];
try
  so=sim(mdlName,'StopTime','1.5','ReturnWorkspaceOutputs','on');
  t=so.f.Time; Vamp=sqrt(so.Vd.Data.^2+so.Vq.Data.^2);
  t_Pe=so.Pe.Time; Pev=so.Pe.Data;
  idx_on_f =(t   >=0.4 & t   <0.8);
  idx_on_Pe=(t_Pe>=0.4 & t_Pe<0.8);
  idx_off_Pe=(t_Pe>=0.8 & t_Pe<1.2);
  Pe_std_on  = std(Pev(idx_on_Pe));
  Vamp_min   = min(Vamp(idx_on_f));
  Pe_settle  = mean(Pev(t_Pe>=1.3));
  Pe_osc_off = rms(Pev(idx_off_Pe)-Pe_settle);
  Pe_peak    = max(Pev(idx_on_Pe));
  Pe_overshoot = max(0, Pe_peak-8500-8000);
  r1 = -(Pe_std_on/1500)^2 * 3.0;
  r2 = -((311-Vamp_min)/311)^2 * 2.0;
  r3 = -(Pe_osc_off/1000)^2 * 2.0;
  r4 = -(Pe_overshoot/2000)^2 * 1.0;
  reward = r1+r2+r3+r4;
  if min(Vamp)>50 && max(abs(so.f.Data-50))<2.0, reward=reward+0.02; end
  obs_out=[Pev(end)/1e4; Vamp(end)/311; min(Pe_std_on/1e3,5); J_norm; D_norm];
  fprintf('[Step%3d] J=%5.2f D=%5.1f Std=%6.0f Vmin=%5.1f Osc=%5.0f r=%7.4f\n',
    loggedSignals.stepCount+1,J_val,D_val,Pe_std_on,Vamp_min,Pe_osc_off,reward);
catch ME
  warning('[step_v2] %s',ME.message); reward=-5.0;
end
observation=obs_out; isdone=true;
loggedSignals.stepCount=loggedSignals.stepCount+1;
loggedSignals.J_val=J_val; loggedSignals.D_val=D_val;
loggedSignals.J_norm=J_norm; loggedSignals.D_norm=D_norm;
end
