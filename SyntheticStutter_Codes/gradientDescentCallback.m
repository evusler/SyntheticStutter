%% ─── Gradient Descent with Live Feedback ──────────────────────────────
function gradientDescentCallback(figHandle)
%GRADIENTDESCENTCALLBACK  GUI callback to run gradient descent on free energy.
    ud = figHandle.UserData;
    if ~isfield(ud,'simulationResults')
        errordlg('No simulation results to optimize.','Gradient Descent');
        return;
    end

    sim = ud.simulationResults;
    logMessage('INFO','Starting gradient descent on mean free energy…');

    % Create figure for live updates
    figGD = figure('Name','Gradient Descent Optimization','Color','w','Position',[300,300,900,400]);

    % Subplot 1: Free Energy over iterations
    ax1 = subplot(1,2,1);
    hold(ax1,'on'); grid(ax1,'on');
    title(ax1,'Free Energy vs. Iteration','FontWeight','bold');
    xlabel(ax1,'Iteration','FontWeight','bold');
    ylabel(ax1,'Mean Free Energy','FontWeight','bold');

    % Subplot 2: Parameter trajectories
    ax2 = subplot(1,2,2);
    hold(ax2,'on'); grid(ax2,'on');
    title(ax2,'Parameter Trajectories','FontWeight','bold');
    xlabel(ax2,'Iteration','FontWeight','bold');
    ylabel(ax2,'Value','FontWeight','bold');
    legend(ax2, {'Attention','Coupling k'}, 'Location','best');

    % Run descent with live plot updates
    [J_hist, Theta_hist] = runGradientDescentFE(sim, ax1, ax2);

    logMessage('INFO',sprintf('Gradient descent complete. Final FE = %.3g', J_hist(end)));
end

function [J_hist, Theta_hist] = runGradientDescentFE(sim, ax1, ax2)
%RUNGRADIENTDESCENTFE   Minimize mean free energy w.r.t. [attention; k]
%   This version builds fresh params each iteration to avoid struct-mutation errors.

    % Base settings
    C0   = sim.constants;
    CFG0 = sim.config;
    MP0  = sim.modelParams;
    P    = sim.wordPredict;
    audio = sim.originalAudio;
    Fs    = sim.Fs;

    % Initial theta = [attention; k]
    theta = [CFG0.defaultAttentionLevel; MP0.k];
    alpha = 0.01;      % step size
    Niter = 30;        % number of iterations

    % Preallocate
    J_hist     = zeros(Niter,1);
    Theta_hist = zeros(2,Niter);

    for it = 1:Niter
        % Build fresh params struct for this theta
        CFG = CFG0;  MP = MP0;
        CFG.defaultAttentionLevel = theta(1);
        MP.k                      = theta(2);

        params.constants   = C0;
        params.config      = CFG;
        params.modelParams = MP;

        % Run sim and compute cost
        [~,~,~,~,~,~,FE_hist] = runStutterSimulation(audio, Fs, params, P);
        J = mean(FE_hist);

        % Record
        J_hist(it)         = J;
        Theta_hist(:,it)   = theta;

        % Finite-difference gradient
        grad = zeros(2,1);
        epsv = 1e-4;
        for p = 1:2
            thp = theta; thp(p) = theta(p) + epsv;
            thm = theta; thm(p) = theta(p) - epsv;

            % compute cost at thp
            CFGp = CFG0; MPp = MP0;
            CFGp.defaultAttentionLevel = thp(1); MPp.k = thp(2);
            params_p.constants   = C0;
            params_p.config      = CFGp;
            params_p.modelParams = MPp;
            [~,~,~,~,~,~,FHp] = runStutterSimulation(audio, Fs, params_p, P);
            Jp = mean(FHp);

            % compute cost at thm
            CFGm = CFG0; MPm = MP0;
            CFGm.defaultAttentionLevel = thm(1); MPm.k = thm(2);
            params_m.constants   = C0;
            params_m.config      = CFGm;
            params_m.modelParams = MPm;
            [~,~,~,~,~,~,FHm] = runStutterSimulation(audio, Fs, params_m, P);
            Jm = mean(FHm);

            grad(p) = (Jp - Jm)/(2*epsv);
        end

        % Gradient descent update
        theta = theta - alpha * grad;

        % Live plot updates
        if nargin>1 && ishandle(ax1) && ishandle(ax2)
            cla(ax1); cla(ax2);
            plot(ax1, 1:it,            J_hist(1:it),       'b-o','LineWidth',1.5);
            plot(ax2, 1:it, Theta_hist(1,1:it), 'r--','LineWidth',1.5); % Attention
            plot(ax2, 1:it, Theta_hist(2,1:it), 'g-','LineWidth',1.5);  % k
            drawnow;
            pause(0.1);  % adjust or remove as desired
        end
    end
end

%% ─── Logging Utility ────────────────────────────────────────────────
function logMessage(level, message)
    % Append timestamped message to console and GUI log box
    ts    = datestr(now,'yyyy-mm-dd HH:MM:SS');
    entry = sprintf('%s [%s]: %s', ts, upper(level), message);
    fprintf('%s\n', entry);

    fig = gcbf;
    if isempty(fig), return; end
    hBox = findobj(fig,'Tag','debugLog');
    if isempty(hBox), return; end

    curr = hBox.String;
    if ischar(curr), curr = {curr}; end
    curr{end+1} = entry;
    hBox.String = curr;
    hBox.Value  = numel(curr);
end
