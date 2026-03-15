%% baseline_comparison.m - 基准对比实验
clear; clc;
mdlPath = 'C:\Users\27443\Desktop\VSG\Three_Phase_VSG_Double_Loop_Control.mdl\Three_Phase_VSG_Double_Loop_Control.mdl';
mdlName = 'Three_Phase_VSG_Double_Loop_Control';
load_system(mdlPath);
set_param(mdlName,'SolverType','Variable-step','Solver','ode45','StopTime','1.5');
set_param([mdlName '/Step'],'Commented','on');

J_list   = [0.1,  0.5,  1.0,  2.0,  5.0];
J_labels = {'J=0.1', 'J=0.5(default)', 'J=1.0', 'J=2.0', 'J=5.0'};
colors   = {'b','k','g','m','r'};
N = length(J_list);
f_all = cell(N,1); t_all = cell(N,1); V_all = cell(N,1);
RES_J=zeros(1,N); RES_fdrop=zeros(1,N); RES_rocof=zeros(1,N);
RES_Vmin=zeros(1,N); RES_ts=zeros(1,N);

fprintf('Start baseline test (%d groups)...\n', N);
fprintf('%-18s %-12s %-14s %-10s %-12s\n','J','df(Hz)','RoCoF(Hz/s)','Vmin(V)','t_settle(s)');
fprintf('%s\n',repmat('-',70,1));

for k = 1:N
    J_val = J_list(k);
    set_param([mdlName '/VSG/Rotor Function/1//J'],'Gain',sprintf('1/%.4f',J_val));
    simOut = sim(mdlName,'StopTime','1.5','ReturnWorkspaceOutputs','on');
    t   = simOut.f.Time;  fv  = simOut.f.Data;
    Vdv = simOut.Vd.Data; Vqv = simOut.Vq.Data;
    Vamp= sqrt(Vdv.^2 + Vqv.^2);
    f_all{k}=fv; t_all{k}=t; V_all{k}=Vamp;
    idx_f  = t>=0.35 & t<0.90;
    f_drop = 50 - min(fv(idx_f));
    df_dt  = abs(diff(fv)./diff(t));
    t_mid  = t(1:end-1);
    idx_rc = t_mid>=0.395 & t_mid<0.45;
    rocof  = max(df_dt(idx_rc));
    Vmin   = min(Vamp(idx_f));
    t_aft  = t(t>=0.4); f_aft=fv(t>=0.4);
    idx_s  = find(abs(f_aft-50)<0.005,1,'first');
    t_settle=99; if ~isempty(idx_s), t_settle=t_aft(idx_s)-0.4; end
    RES_J(k)=J_val; RES_fdrop(k)=f_drop; RES_rocof(k)=rocof;
    RES_Vmin(k)=Vmin; RES_ts(k)=t_settle;
    fprintf('%-18s %-12.6f %-14.6f %-10.4f %-12.4f\n',J_labels{k},f_drop,rocof,Vmin,t_settle);
end

%% Figure 1: Frequency response
figure('Name','Frequency Response','Position',[100 100 800 450]);
hold on;
for k=1:N
    plot(t_all{k},f_all{k},colors{k},'LineWidth',1.5,'DisplayName',J_labels{k});
end
xline(0.4,'--k','LineWidth',1); xline(0.8,'--k','LineWidth',1);
xlabel('Time (s)'); ylabel('Frequency (Hz)');
title('VSG Frequency Response under Different Inertia J');
legend('Location','best'); grid on; ylim([49.9985 50.001]);
saveas(gcf,'C:\Users\27443\Desktop\VSG\fig1_freq.png');

%% Figure 2: Metrics bar chart
figure('Name','Performance Metrics','Position',[100 600 1000 380]);
subplot(1,3,1); bar(RES_J, RES_fdrop*1e5,'FaceColor',[0.3 0.6 0.9]);
xlabel('J'); ylabel('df x1e-5 Hz'); title('Freq Drop'); grid on;
subplot(1,3,2); bar(RES_J, RES_rocof*1e4,'FaceColor',[0.9 0.4 0.3]);
xlabel('J'); ylabel('RoCoF x1e-4 Hz/s'); title('RoCoF'); grid on;
subplot(1,3,3); bar(RES_J, RES_ts,'FaceColor',[0.4 0.8 0.4]);
xlabel('J'); ylabel('seconds'); title('Settle Time'); grid on;
saveas(gcf,'C:\Users\27443\Desktop\VSG\fig2_metrics.png');

fprintf('\nDone! fig1_freq.png and fig2_metrics.png saved.\n');
fprintf('These are your paper baseline results (Table & Fig).\n');
save('C:\Users\27443\Desktop\VSG\baseline_results.mat','RES_J','RES_fdrop','RES_rocof','RES_Vmin','RES_ts','J_labels');
fprintf('Raw data saved: baseline_results.mat\n');
