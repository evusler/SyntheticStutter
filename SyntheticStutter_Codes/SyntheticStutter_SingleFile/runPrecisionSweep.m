function runPrecisionSweep(figHandle)
%RUNPRECISIONSWEEP  Sweep sensory *variance* σ (and its inverse precision Π)
%                   and visualise how freezing metrics change.

    %% 1) Guard
    if nargin<1 || isempty(figHandle) || ...
       ~isfield(figHandle.UserData,'simulationResults') || ...
       isempty(figHandle.UserData.simulationResults)
        errordlg( ...
          ['Please load audio and run the simulation ', ...
           'before using Precision (Variance) Sweep.'], ...
          'Sweep Error' );
        return;
    end

    %% 2) Unpack baseline run
    sim   = figHandle.UserData.simulationResults;
    audio = sim.originalAudio;   Fs  = sim.Fs;
    C0    = sim.constants;       cfg0 = sim.config;
    mp0   = sim.modelParams;     P    = sim.P;

    %% 3) Sweep grid  — logarithmic σ, derived Π = 1/σ
    sigmas     = logspace(log10(0.05), log10(5), 10);   % σ : auditory / somato variance
    precisions = 1 ./ sigmas;                           % Π = 1/σ  (inverse variance)
    n          = numel(sigmas);

    freezePct   = nan(1,n);
    freezeCount = nan(1,n);
    meanDur     = nan(1,n);

    hWB = waitbar(0,'Running Variance Sweep...','Name','Sweep Progress');

    %% 4) Run simulations
    for i = 1:n
        waitbar(i/n, hWB, sprintf('Run %d of %d  (σ = %.2f)', i, n, sigmas(i)));
        mp          = mp0;
        mp.sigmaA   = sigmas(i);
        mp.sigmaS   = sigmas(i);

        params.constants   = C0;
        params.config      = cfg0;
        params.modelParams = mp;

        try
            [~,~,~,~,tspan,~,freezeMask] = runStutterSimulation(audio, Fs, params, P);
            fm          = logical(freezeMask);
            dt          = mean(diff(tspan));

            freezePct(i)   = mean(fm) * 100;
            CC             = bwconncomp(fm);
            freezeCount(i) = CC.NumObjects;
            if CC.NumObjects>0
                areas     = [regionprops(CC,'Area').Area];
                meanDur(i) = mean(areas) * dt;
            else
                meanDur(i) = 0;
            end
        catch ME
            warning('Variance sweep failed at σ = %.2f  (%s)', sigmas(i), ME.message);
        end
    end
    close(hWB);

    %% ----------------------------------------------------------------
    %% 5)  SEMILOG-X  —  Freezing vs Precision Π  ( = 1/σ )
    %% ----------------------------------------------------------------
    fs   = 12;   lw = 1.5;
    xLog = log10(precisions);
    xf   = linspace(min(xLog), max(xLog), 200);

    figure('Color','w','Units','normalized','Position',[.1 .1 .8 .6]);
    tl1 = tiledlayout(3,1,'Padding','compact','TileSpacing','compact');

    % (a) % time frozen
    ax1 = nexttile(tl1,1);
    semilogx(ax1, precisions, freezePct, '-o', 'LineWidth',lw, ...
             'MarkerSize',8,'MarkerFaceColor',[0.2 0.6 0.8]);
    hold(ax1,'on');
      p1 = polyfit(xLog, freezePct, 1);
      semilogx(ax1, 10.^xf, polyval(p1,xf), '--r', 'LineWidth',lw);
      [r1,p1val] = corr(xLog.', freezePct.');
      text(0.05,0.85, sprintf('r = %.2f, p = %.3f', r1, p1val), ...
           'Units','normalized','FontSize',fs-2,'FontWeight','bold');
    hold(ax1,'off');
    grid(ax1,'on'); box(ax1,'on');
    xlabel(ax1,'Sensory *Precision*   Π  (= 1 / σ)','FontSize',fs,'FontWeight','bold');
    ylabel(ax1,'% Time Frozen','FontSize',fs,'FontWeight','bold');
    title(ax1,'SEMILOG:  Freeze %  vs.  Precision Π','FontSize',fs+2,'FontWeight','bold');

    % (b) Freeze-episode count
    ax2 = nexttile(tl1,2);
    semilogx(ax2, precisions, freezeCount, '-s', 'LineWidth',lw, ...
             'MarkerSize',8,'MarkerFaceColor',[0.8 0.4 0.4]);
    hold(ax2,'on');
      p2 = polyfit(xLog, freezeCount, 1);
      semilogx(ax2, 10.^xf, polyval(p2,xf), '--r', 'LineWidth',lw);
      [r2,p2val] = corr(xLog.', freezeCount.');
      text(0.05,0.85, sprintf('r = %.2f, p = %.3f', r2, p2val), ...
           'Units','normalized','FontSize',fs-2,'FontWeight','bold');
    hold(ax2,'off');
    grid(ax2,'on'); box(ax2,'on');
    xlabel(ax2,'Sensory *Precision*   Π  (= 1 / σ)','FontSize',fs,'FontWeight','bold');
    ylabel(ax2,'# Freeze Episodes','FontSize',fs,'FontWeight','bold');
    title(ax2,'SEMILOG:  Episode Count  vs.  Precision Π','FontSize',fs+2,'FontWeight','bold');

    % (c) Mean duration
    ax3 = nexttile(tl1,3);
    semilogx(ax3, precisions, meanDur, '-d', 'LineWidth',lw, ...
             'MarkerSize',8,'MarkerFaceColor',[0.4 0.8 0.4]);
    hold(ax3,'on');
      p3 = polyfit(xLog, meanDur, 1);
      semilogx(ax3, 10.^xf, polyval(p3,xf), '--r', 'LineWidth',lw);
      [r3,p3val] = corr(xLog.', meanDur.');
      text(0.05,0.85, sprintf('r = %.2f, p = %.3f', r3, p3val), ...
           'Units','normalized','FontSize',fs-2,'FontWeight','bold');
    hold(ax3,'off');
    grid(ax3,'on'); box(ax3,'on');
    xlabel(ax3,'Sensory *Precision*   Π  (= 1 / σ)','FontSize',fs,'FontWeight','bold');
    ylabel(ax3,'Mean Freeze Duration (s)','FontSize',fs,'FontWeight','bold');
    title(ax3,'SEMILOG:  Avg Duration  vs.  Precision Π','FontSize',fs+2,'FontWeight','bold');

    linkaxes([ax1 ax2 ax3],'x');

    %% ----------------------------------------------------------------
    %% 6)  LINEAR-X  —  Freezing vs Variance σ
    %% ----------------------------------------------------------------
    figure('Color','w','Units','normalized','Position',[.1 .1 .8 .6]);
    tl2 = tiledlayout(3,1,'Padding','compact','TileSpacing','compact');

    % (a) % time frozen
    ax4 = nexttile(tl2,1);
    plot(ax4, sigmas, freezePct, '-o', 'LineWidth',lw, ...
         'MarkerSize',8,'MarkerFaceColor',[0.2 0.6 0.8]);
    hold(ax4,'on');
      p4 = polyfit(sigmas, freezePct, 1);
      plot(ax4, sigmas, polyval(p4,sigmas), '--r', 'LineWidth',lw);
      [r4,p4val] = corr(sigmas(:), freezePct(:));
      text(0.05,0.85, sprintf('r = %.2f, p = %.3f', r4, p4val), ...
           'Units','normalized','FontSize',fs-2,'FontWeight','bold');
    hold(ax4,'off');
    grid(ax4,'on'); box(ax4,'on');
    xlabel(ax4,'Sensory *Variance*   σ','FontSize',fs,'FontWeight','bold');
    ylabel(ax4,'% Time Frozen','FontSize',fs,'FontWeight','bold');
    title(ax4,'LINEAR:  Freeze %  vs.  Variance σ','FontSize',fs+2,'FontWeight','bold');

    % (b) Episode count
    ax5 = nexttile(tl2,2);
    plot(ax5, sigmas, freezeCount, '-s', 'LineWidth',lw, ...
         'MarkerSize',8,'MarkerFaceColor',[0.8 0.4 0.4]);
    hold(ax5,'on');
      p5 = polyfit(sigmas, freezeCount, 1);
      plot(ax5, sigmas, polyval(p5,sigmas), '--r', 'LineWidth',lw);
      [r5,p5val] = corr(sigmas(:), freezeCount(:));
      text(0.05,0.85, sprintf('r = %.2f, p = %.3f', r5, p5val), ...
           'Units','normalized','FontSize',fs-2,'FontWeight','bold');
    hold(ax5,'off');
    grid(ax5,'on'); box(ax5,'on');
    xlabel(ax5,'Sensory *Variance*   σ','FontSize',fs,'FontWeight','bold');
    ylabel(ax5,'# Freeze Episodes','FontSize',fs,'FontWeight','bold');
    title(ax5,'LINEAR:  Episode Count  vs.  Variance σ','FontSize',fs+2,'FontWeight','bold');

    % (c) Mean duration
    ax6 = nexttile(tl2,3);
    plot(ax6, sigmas, meanDur, '-d', 'LineWidth',lw, ...
         'MarkerSize',8,'MarkerFaceColor',[0.4 0.8 0.4]);
    hold(ax6,'on');
      p6 = polyfit(sigmas, meanDur, 1);
      plot(ax6, sigmas, polyval(p6,sigmas), '--r', 'LineWidth',lw);
      [r6,p6val] = corr(sigmas(:), meanDur(:));
      text(0.05,0.85, sprintf('r = %.2f, p = %.3f', r6, p6val), ...
           'Units','normalized','FontSize',fs-2,'FontWeight','bold');
    hold(ax6,'off');
    grid(ax6,'on'); box(ax6,'on');
    xlabel(ax6,'Sensory *Variance*   σ','FontSize',fs,'FontWeight','bold');
    ylabel(ax6,'Mean Freeze Duration (s)','FontSize',fs,'FontWeight','bold');
    title(ax6,'LINEAR:  Avg Duration  vs.  Variance σ','FontSize',fs+2,'FontWeight','bold');

    linkaxes([ax4 ax5 ax6],'x');

    %% ----------------------------------------------------------------
    %% 7)  Test Summary row
    %% ----------------------------------------------------------------
    %  Direction can go either way, so we simply report the correlation
    resultText = sprintf('r(Π,Freeze%%)=%.2f', r1);

    testName   = 'Variance/Precision Sweep';
    hypothesis = 'Freezing vs. Variance σ (⇔ Precision Π)';
    M1 = freezePct(1);                  % low σ / high Π
    M2 = freezePct(ceil(n/2));
    M3 = freezePct(end);                % high σ / low Π
    M4 = mean(freezeCount,'omitnan');
    M5 = mean(meanDur,'omitnan');

    appendTestSummary(figHandle, {testName, hypothesis, M1, M2, M3, M4, M5, resultText});
end
