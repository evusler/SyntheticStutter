%% ─── Gradient Descent with Live Feedback ──────────────────────────────
function gradientDescentCallback(figHandle)
%GRADIENTDESCENTCALLBACK  GUI callback to run free-energy gradient descent optimization.
    ud = figHandle.UserData;
    if ~isfield(ud, 'simulationResults')
        errordlg('No simulation results to optimize.', 'Gradient Descent');
        return;
    end

    sim = ud.simulationResults;
    logMessage('INFO', 'Starting gradient descent on mean free energy…');

    % Create live feedback window
    figGD = figure('Name', 'Gradient Descent Optimization', ...
        'Color', 'w', 'Position', [300, 300, 1000, 450]);

    % Subplot: Free energy
    ax1 = subplot(1,2,1);
    hold on; grid on;
    title('$\mathcal{F}$ vs. Iteration', 'Interpreter', 'latex', 'FontWeight', 'bold');
    xlabel('Iteration'); ylabel('Mean Free Energy');

    % Subplot: Parameters
    ax2 = subplot(1,2,2);
    hold on; grid on;
    title('Parameter Trajectories', 'FontWeight', 'bold');
    xlabel('Iteration'); ylabel('Value');
    legend({'Attention $\Pi_a$', 'Coupling $k$'}, 'Interpreter', 'latex', 'Location', 'best');

    % Run optimizer
    [J_hist, Theta_hist] = runGradientDescentFE(sim, ax1, ax2);
    logMessage('INFO', sprintf('Gradient descent complete. Final FE = %.3f', J_hist(end)));
end

function [J_hist, Theta_hist] = runGradientDescentFE(sim, ax1, ax2)
%RUNGRADIENTDESCENTFE  Optimize [attention; k] using finite-difference gradient descent.

    % Extract inputs
    C0   = sim.constants;
    CFG0 = sim.config;
    MP0  = sim.modelParams;
    audio = sim.originalAudio;
    Fs    = sim.Fs;
    P     = sim.P;

    % Initial params: [attention; k]
    theta = [CFG0.defaultAttentionLevel; MP0.k];
    alpha = 0.01;
    Niter = 30;

    J_hist     = nan(Niter,1);
    Theta_hist = nan(2,Niter);

    for it = 1:Niter
        CFG = CFG0;  MP = MP0;
        CFG.defaultAttentionLevel = theta(1);
        MP.k                      = theta(2);

        params.constants   = C0;
        params.config      = CFG;
        params.modelParams = MP;

        % Run simulation
        try
            [~,~,~,~,~,~,FE_hist] = runStutterSimulation(audio, Fs, params, P);
            J = mean(FE_hist(~isnan(FE_hist)));
        catch ME
            logMessage('ERROR', ['Simulation failed at iter ', num2str(it), ': ', ME.message]);
            J = NaN;
        end

        J_hist(it)       = J;
        Theta_hist(:,it) = theta;

        % Log iteration
        logMessage('INFO', sprintf('Iter %2d | FE: %.4f | att: %.3f | k: %.3f', ...
            it, J, theta(1), theta(2)));

        % Estimate gradient
        grad = zeros(2,1); epsv = 1e-4;
        for p = 1:2
            offset = zeros(2,1); offset(p) = epsv;
            theta_plus  = theta + offset;
            theta_minus = theta - offset;

            CFGp = CFG0; MPp = MP0;
            CFGp.defaultAttentionLevel = theta_plus(1); MPp.k = theta_plus(2);
            CFGm = CFG0; MPm = MP0;
            CFGm.defaultAttentionLevel = theta_minus(1); MPm.k = theta_minus(2);

            % Cost at theta + eps
            params_p.constants = C0; params_p.config = CFGp; params_p.modelParams = MPp;
            FHp = runStutterSimulation(audio, Fs, params_p, P);
            Jp = mean(FHp(~isnan(FHp)));

            % Cost at theta - eps
            params_m.constants = C0; params_m.config = CFGm; params_m.modelParams = MPm;
            FHm = runStutterSimulation(audio, Fs, params_m, P);
            Jm = mean(FHm(~isnan(FHm)));

            grad(p) = (Jp - Jm) / (2 * epsv);
        end

        % Gradient descent step
        theta = theta - alpha * grad;

        % Live plotting
        if nargin > 1 && ishandle(ax1) && ishandle(ax2)
            cla(ax1); cla(ax2);
            plot(ax1, 1:it, J_hist(1:it), 'k-o', 'LineWidth', 1.4);
            plot(ax2, 1:it, Theta_hist(1,1:it), 'r--', 'LineWidth', 1.5);
            plot(ax2, 1:it, Theta_hist(2,1:it), 'b-', 'LineWidth', 1.5);
            drawnow;
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
