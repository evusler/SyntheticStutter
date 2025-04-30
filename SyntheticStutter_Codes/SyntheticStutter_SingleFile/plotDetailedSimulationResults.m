function [figOverview, figStats] = plotDetailedSimulationResults( ...
    audData, Fs, ...
    xHist, U_hist, sigmaA_hist, FE_hist, ...
    stutteredAudio, tspan, ...
    ~, wordLabels, ...
    config, modelParams, freezeMask)

    %% Settings
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

    %% Compute freeze blocks
    CC = bwconncomp(freezeMask);
    durations = cellfun(@numel, CC.PixelIdxList) * dt;
    shortIdx  = durations < 0.150;
    longIdx   = durations >= 0.150;

    %% === FIGURE 1: SIMULATION OVERVIEW ===
    figOverview = figure('Color','w','Position',[100 100 1200 800]);
    tl = tiledlayout(7,1,'TileSpacing','compact','Padding','loose');
    titleStr = { sprintf('Figure 1: Simulation Overview — %d freezes (mean %.2f s)', ...
        CC.NumObjects, mean(durations)) ; ' ' };
    sgtitle(tl, titleStr, 'FontSize',fs+4, 'FontWeight','bold');

    % 1. Audio plot
    ax1 = nexttile;
    tAudio = (0:numel(audData)-1)/Fs;
    plot(ax1, tAudio, audData, 'k', 'LineWidth', lw);
    xlabel(ax1, 'Time (s)', 'FontSize', fs);
    ylabel(ax1, 'Amplitude', 'FontSize', fs);
    xlim(ax1, [0 tspan(end)]);
    grid(ax1, 'on'); hold(ax1, 'on');
    if ~isempty(wordLabels)
        xPos = linspace(0, tspan(end)-0.15, numel(wordLabels)) + 0.15;
        for i = 1:numel(xPos)
            xline(ax1, xPos(i), '--', 'LineWidth', 0.8, 'Color', [0.7,0,0]);
            text(ax1, xPos(i), max(audData)*1.1, ...
                ['$\mathrm{' wordLabels{i} '}$'], ...
                'Interpreter','latex','Rotation',75, ...
                'FontSize',fs-2,'HorizontalAlignment','center');
        end
    end

    % 2–6: Uncertainty, Precision, FE, x1, x2
    signals = {Usm, sigmaAsm, FEs, x1sm, x2sm};
    labels  = {'Uncertainty','Precision','Free Energy','$x_1$','$x_2$'};
    for i = 1:5
        ax = nexttile;
        plot(ax, tspan, signals{i}, 'LineWidth', lw);
        ylabel(ax, labels{i}, 'Interpreter','latex','FontSize', fs);
        xlim(ax, [0 tspan(end)]); grid(ax,'on');
        if i == 5  % x2 freeze shading
            hold(ax,'on');
            y2 = prctile(x2sm, [1,99]);
            for j = find(shortIdx)
                idx = CC.PixelIdxList{j};
                patch(ax, [tspan(idx([1 end end 1]))], [y2(1) y2(1) y2(2) y2(2)], ...
                      [1 0.7 0.7], 'EdgeColor','none', 'FaceAlpha', 0.5);
            end
            for j = find(longIdx)
                idx = CC.PixelIdxList{j};
                patch(ax, [tspan(idx([1 end end 1]))], [y2(1) y2(1) y2(2) y2(2)], ...
                      [0.9 0 0], 'EdgeColor','none', 'FaceAlpha', 0.4);
            end
        end
    end

    % 7. Stuttered Audio with shaded freezes
    ax7 = nexttile;
    tS = linspace(0, tspan(end), numel(stutteredAudio));
    plot(ax7, tS, stutteredAudio, 'LineWidth', lw);
    hold(ax7,'on');
    yS = prctile(stutteredAudio, [1 99]);
    for j = find(shortIdx)
        idx = CC.PixelIdxList{j};
        patch(ax7, [tspan(idx([1 end end 1]))], [yS(1) yS(1) yS(2) yS(2)], ...
              [1 0.7 0.7], 'EdgeColor','none', 'FaceAlpha', 0.4);
    end
    for j = find(longIdx)
        idx = CC.PixelIdxList{j};
        patch(ax7, [tspan(idx([1 end end 1]))], [yS(1) yS(1) yS(2) yS(2)], ...
              [0.9 0 0], 'EdgeColor','none', 'FaceAlpha', 0.4);
    end
    ylabel(ax7, 'Amplitude', 'FontSize', fs);
    xlabel(ax7, 'Time (s)', 'FontSize', fs);
    xlim(ax7, [0 tspan(end)]); grid(ax7, 'on');

    linkaxes(findall(tl,'Type','Axes'), 'x');
    set(findall(tl,'Type','Axes'),'FontSize',fs);

    %% === FIGURE 2: STATS ===
    figStats = figure('Color','w','Position',[400 300 900 350]);
    t2 = tiledlayout(1,3,'TileSpacing','compact','Padding','compact');
    sgtitle(t2, 'Figure 2: Freeze Statistics', 'FontSize', fs+4, 'FontWeight','bold');

    % Panel 1: Count & total duration
    axA = nexttile(t2, 1);
    yyaxis left;  bar(1, numel(durations)); ylabel('Freeze Count');
    yyaxis right; bar(2, sum(durations)); ylabel('Total Duration (s)');
    set(axA,'XTick',[1 2],'XTickLabel',{'Count','Total Dur'},'FontSize',fs); grid on;

    % Panel 2: Mean and Median
    axB = nexttile(t2, 2);
    bar([mean(durations), median(durations)]); grid on;
    set(axB, 'XTickLabel',{'Mean','Median'}, 'FontSize',fs);
    ylabel('Duration (s)','FontSize',fs);

    % Panel 3: Histogram
    axC = nexttile(t2, 3);
    if isempty(durations)
        text(0.5,0.5,'No freezes','HorizontalAlignment','center');
        axis off;
    else
        histogram(axC, durations, 12); xlabel('Duration (s)'); ylabel('Count'); grid on;
        title('Distribution');
    end
end
