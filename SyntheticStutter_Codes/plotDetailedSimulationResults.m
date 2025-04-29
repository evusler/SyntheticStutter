function [figOverview, figStats] = plotDetailedSimulationResults( ...
    audData, Fs, ...
    xHist, U_hist, sigmaA_hist, FE_hist, ...
    stutteredAudio, tspan, ...
    ~, wordLabels, ...          % ignored input: onsets
    config, modelParams, freezeMask )
% PLOTDETAILEDSIMULATIONRESULTS  Overview + stats with provided freezeMask
%
% [figOverview, figStats] = plotDetailedSimulationResults( ...
%     audData, Fs, ...
%     xHist, U_hist, sigmaA_hist, FE_hist, ...
%     stutteredAudio, tspan, ~, wordLabels, ...
%     config, modelParams, freezeMask )
%
% The last input, freezeMask, must be a logical vector same length as tspan.

    %% —— Settings & smoothing —————————————————————————
    fs      = 12;                 
    lw      = 1.5;                
    W       = config.smoothingWindow;
    Ws      = max(1, min(W,10));
    dt      = mean(diff(tspan));

    Usm      = movmean(U_hist,      W);
    sigmaAsm = movmean(sigmaA_hist, W);
    FEs      = movmean(FE_hist,     W);
    x1sm     = movmean(xHist(:,1),  Ws);
    x2sm     = movmean(xHist(:,2),  Ws);

    %% —— Use provided freezeMask —————————————————————————
    CC = bwconncomp(freezeMask);

    %% === FIGURE 1: SIMULATION OVERVIEW ===
    figOverview = figure('Color','w','Position',[100 100 1200 800]);
    tl = tiledlayout(7,1,'TileSpacing','compact','Padding','loose');
    
    % Add a blank line to lift the title above the first axes
    titleStr = { sprintf('Figure 1: Simulation Overview (%d freezes)', CC.NumObjects) ; ' ' };
    sgtitle(tl, titleStr, 'FontSize',fs+4, 'FontWeight','bold');

    % 1) Raw audio + LaTeX word labels shifted by 150 ms
    ax1 = nexttile;
    tAudio = (0:numel(audData)-1)/Fs;
    plot(ax1, tAudio, audData, 'k', 'LineWidth', lw);
    xlabel(ax1, 'Time (s)',   'FontSize', fs);
    ylabel(ax1, 'Amplitude',  'FontSize', fs);
    xlim(ax1, [0 tspan(end)]);
    grid(ax1, 'on');
    hold(ax1, 'on');
    ax1.Clipping = 'off';

    nLab = numel(wordLabels);
    if nLab > 0
        shift = 0.150;  % 150 ms offset
        xPos  = linspace(0, tspan(end)-shift, nLab) + shift;
        yL    = ylim(ax1);
        textY = yL(2) + 0.12*(yL(2)-yL(1));
        for i = 1:nLab
            xline(ax1, xPos(i), '--', 'LineWidth', 0.8, 'Color', [0.8,0,0]);
            lab = wordLabels{i};
            str = ['$\mathrm{' lab '}$'];
            text(ax1, xPos(i), textY, str, ...
                'Interpreter','latex', ...
                'HorizontalAlignment','center', ...
                'Rotation',75, ...
                'FontSize', fs-2);
        end
        ylim(ax1, [yL(1), textY + 0.02*(yL(2)-yL(1))]);
    end
    hold(ax1, 'off');

    % 2) Uncertainty
    ax2 = nexttile;
    plot(ax2, tspan, Usm, 'LineWidth', lw);
    ylabel(ax2, 'Uncertainty', 'FontSize', fs);
    xlim(ax2, [0 tspan(end)]);
    grid(ax2, 'on');

    % 3) Precision
    ax3 = nexttile;
    plot(ax3, tspan, sigmaAsm, 'LineWidth', lw);
    ylabel(ax3, 'Precision', 'FontSize', fs);
    xlim(ax3, [0 tspan(end)]);
    grid(ax3, 'on');

    % 4) Free Energy
    ax4 = nexttile;
    plot(ax4, tspan, FEs, 'LineWidth', lw);
    ylabel(ax4, 'Free Energy', 'FontSize', fs);
    xlim(ax4, [0 tspan(end)]);
    grid(ax4, 'on');

    % 5) x₁
    ax5 = nexttile;
    plot(ax5, tspan, x1sm, 'LineWidth', lw);
    ylabel(ax5, '$x_1$', 'Interpreter','latex', 'FontSize', fs);
    xlim(ax5, [0 tspan(end)]);
    grid(ax5, 'on');

    % 6) x₂ + shaded freeze intervals
    ax6 = nexttile;
    hold(ax6, 'on');
    y2 = prctile(x2sm, [1,99]);
    for c = 1:CC.NumObjects
        idx = CC.PixelIdxList{c};
        patch(ax6, ...
            [tspan(idx(1)), tspan(idx(end)), tspan(idx(end)), tspan(idx(1))], ...
            [y2(1), y2(1), y2(2), y2(2)], [1,0.6,0.6], ...
            'FaceAlpha', 0.3, 'EdgeColor', 'none');
    end
    plot(ax6, tspan, x2sm, 'LineWidth', lw);
    hold(ax6, 'off');
    ylabel(ax6, '$x_2$', 'Interpreter','latex', 'FontSize', fs);
    xlim(ax6, [0 tspan(end)]);
    grid(ax6, 'on');

    % 7) Stuttered audio + shaded freezes
    ax7 = nexttile;
    hold(ax7, 'on');
    tS = linspace(0, tspan(end), numel(stutteredAudio));
    yS = prctile(stutteredAudio, [1,99]);
    for c = 1:CC.NumObjects
        idx = CC.PixelIdxList{c};
        patch(ax7, ...
            [tspan(idx(1)), tspan(idx(end)), tspan(idx(end)), tspan(idx(1))], ...
            [yS(1), yS(1), yS(2), yS(2)], [1,0.6,0.6], ...
            'FaceAlpha', 0.3, 'EdgeColor', 'none');
    end
    plot(ax7, tS, stutteredAudio, 'LineWidth', lw);
    hold(ax7, 'off');
    ylabel(ax7, 'Amplitude', 'FontSize', fs);
    xlabel(ax7, 'Time (s)', 'FontSize', fs);
    xlim(ax7, [0 tspan(end)]);
    grid(ax7, 'on');

    linkaxes([ax1 ax2 ax3 ax4 ax5 ax6 ax7], 'x');
    set([ax2 ax3 ax4 ax5 ax6], 'XTickLabel', []);

    %% === FIGURE 2: FREEZE EVENT STATISTICS ===
    figStats = figure('Color','w','Position',[300 300 900 350]);
    t2 = tiledlayout(1,3,'TileSpacing','compact','Padding','compact');
    sgtitle(t2, 'Figure 2: Freeze Event Statistics', ...
        'FontSize', fs+4, 'FontWeight','bold');

    % compute durations
    durs    = cellfun(@numel, CC.PixelIdxList) * dt;
    N       = numel(durs);
    totDur  = sum(durs);
    meanDur = mean(durs);
    medDur  = median(durs);

    % Panel 1: dual‐axis Count vs Total Duration
    axA = nexttile(t2, 1);
    yyaxis(axA,'left');
      bar(axA, 1, N, 'FaceAlpha', 0.7);
      ylabel(axA, 'Freeze Count','FontSize',fs);
    yyaxis(axA,'right');
      bar(axA, 2, totDur, 'FaceAlpha', 0.7);
      ylabel(axA, 'Total Duration (s)','FontSize',fs);
    set(axA, 'XTick',[1 2], 'XTickLabel',{'Count','Total Dur'}, 'FontSize',fs);
    grid(axA,'on');

    % Panel 2: Mean & Median
    axB = nexttile(t2, 2);
    bar(axB, [meanDur, medDur], 'FaceAlpha', 0.7);
    set(axB, 'XTickLabel',{'Mean','Median'}, 'FontSize',fs);
    ylabel(axB, 'Duration (s)','FontSize',fs);
    grid(axB,'on');

    % Panel 3: Distribution
    axC = nexttile(t2, 3);
    if isempty(durs)
        text(0.5,0.5,'No freezes','HorizontalAlignment','center','FontSize',fs);
        axis(axC,'off');
    else
        histogram(axC, durs, 10, 'FaceAlpha', 0.6);
        xlabel(axC,'Duration (s)','FontSize',fs);
        ylabel(axC,'Count','FontSize',fs);
        grid(axC,'on');
    end
    title(axC,'Distribution','FontSize',fs);

end
