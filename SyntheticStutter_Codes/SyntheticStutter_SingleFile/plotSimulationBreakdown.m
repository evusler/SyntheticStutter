function plotSimulationBreakdown(figHandle)
%PLOTSIMULATIONBREAKDOWN  Diagnostic breakdown of x₁, x₂, FE, predictability, and freezing.

    %% 1. Validate input
    if nargin < 1 || ~isvalid(figHandle) || ...
       ~isfield(figHandle.UserData, 'simulationResults') || ...
       isempty(figHandle.UserData.simulationResults)
        errordlg('No simulation results available.', 'Simulation Breakdown');
        return;
    end

    sim = figHandle.UserData.simulationResults;
    requiredFields = {'xHist','FE_hist','freezeMask','tspan','P'};
    for f = requiredFields
        if ~isfield(sim, f{1})
            errordlg(['Missing field: ', f{1}], 'Simulation Incomplete');
            return;
        end
    end

    %% 2. Unpack data
    t  = sim.tspan;
    x1 = sim.xHist(:,1);
    x2 = sim.xHist(:,2);
    FE = sim.FE_hist;
    P  = sim.P;
    freezeMask = sim.freezeMask;
    dt = mean(diff(t));

    x1_smooth = smoothdata(x1, 'gaussian', 20);
    x2_smooth = smoothdata(x2, 'gaussian', 20);
    FE_smooth = smoothdata(FE, 'gaussian', 20);

    %% 3. Compute freeze statistics robustly
    freezeStarts = find(diff([0; freezeMask]) == 1);
    freezeEnds   = find(diff([freezeMask; 0]) == -1);
    nFreezes     = numel(freezeStarts);
    if nFreezes > 0
        durations = (freezeEnds - freezeStarts) * dt;
        meanFreezeDur = mean(durations);
        freezeTitle = sprintf('%d freezes (mean %.3f s)', nFreezes, meanFreezeDur);
    else
        freezeTitle = '0 freezes (mean NaN s)';
    end

    %% 4. Create figure
    figure('Name', 'Figure 1 – Simulation Overview', ...
           'Color', 'w', ...
           'Position', [100, 100, 1000, 1000]);

    sgtitle(['Figure 1: Simulation Overview — ' freezeTitle], 'FontWeight', 'bold');

    subplotRows = 7;

    %% 5. Plot waveform
    subplot(subplotRows,1,1);
    if isfield(sim, 'audio') && ~isempty(sim.audio)
        plot(t, sim.audio);
        title('Original Audio');
    else
        title('Audio waveform not available');
    end
    ylabel('Amplitude');

    %% 6. Uncertainty
    if isfield(sim, 'U_hist')
        subplot(subplotRows,1,2);
        plot(t, sim.U_hist, 'b');
        ylabel('Uncertainty'); grid on;
    end

    %% 7. Precision
    if isfield(sim, 'sigmaA_hist')
        subplot(subplotRows,1,3);
        plot(t, sim.sigmaA_hist, 'r');
        ylabel('Precision'); grid on;
    end

    %% 8. Free Energy
    subplot(subplotRows,1,4);
    plot(t, FE, ':k'); hold on;
    plot(t, FE_smooth, 'k', 'LineWidth', 1.5);
    ylabel('Free Energy'); title('Prediction Error Dynamics'); grid on;

    %% 9. x₁ and x₂
    subplot(subplotRows,1,5); hold on;
    plot(t, x1_smooth, 'b', 'DisplayName','x₁');
    plot(t, x2_smooth, 'r', 'DisplayName','x₂');
    legend; ylabel('State'); title('Cognitive (x₁) & Motor (x₂)'); grid on;

    %% 10. Freeze mask
    subplot(subplotRows,1,6);
    area(t, freezeMask, 'FaceColor', [0.8 0.2 0.2], 'FaceAlpha', 0.4, 'EdgeAlpha', 0);
    ylim([-0.1 1.1]);
    xlabel('Time (s)'); ylabel('Freezing');
    title('Detected Motor Freezing'); grid on;

    %% 11. Audio again
    subplot(subplotRows,1,7);
    if isfield(sim, 'audio')
        plot(t, sim.audio .* (1 - freezeMask)); % optionally mute where frozen
        ylabel('Amplitude');
        title('Stuttered Audio Output (if available)');
    end
end
