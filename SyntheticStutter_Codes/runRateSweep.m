function runRateSweep(figHandle)
%RUNRATESWEEP   Sweep speech rate & report metrics in the Test Summary.

    %% 1) Guard: must have run a simulation first
    if nargin<1 || isempty(figHandle) || ...
       ~isfield(figHandle.UserData,'simulationResults') || ...
       isempty(figHandle.UserData.simulationResults)
        errordlg( ...
          'Please load audio and run the simulation before using Rate Sweep.', ...
          'Sweep Error' ...
        );
        return;
    end

    %% 2) Unpack baseline simulation state
    sim   = figHandle.UserData.simulationResults;
    audio = sim.originalAudio;
    Fs    = sim.Fs;
    C0    = sim.constants;
    cfg0  = sim.config;
    mp0   = sim.modelParams;
    P     = sim.P;

    %% 3) Define sweep grid
    rates        = linspace(0.5, 2.5, 10);   % 0.5× … 2.5× normal rate
    n            = numel(rates);
    freezePct    = zeros(1,n);
    freezeCount  = zeros(1,n);
    meanDuration = zeros(1,n);

    %% 4) Run all simulations
    h = waitbar(0,'Running Rate Sweep...','Name','Sweep Progress');
    for i = 1:n
        % adjust integration time-step for this rate
        C = C0;
        C.dtBase = C0.dtBase / rates(i);

        % pack params and simulate
        params.constants   = C;
        params.config      = cfg0;
        params.modelParams = mp0;
        [~,~,~,~,tspan,~,freezeMask] = runStutterSimulation(audio, Fs, params, P);

        % compute dt and metrics
        dt = mean(diff(tspan));
        freezePct(i)   = mean(freezeMask) * 100;
        CC             = bwconncomp(freezeMask);
        freezeCount(i) = CC.NumObjects;
        if CC.NumObjects>0
            stats          = regionprops(CC,'Area');
            areas          = [stats.Area];
            meanDuration(i)= mean(areas) * dt;
        else
            meanDuration(i)= 0;
        end

        waitbar(i/n, h);
    end
    close(h);

    %% 5) Plot Results with fits & correlations
    figure('Color','w','Units','normalized','Position',[.2 .2 .6 .6]);

    % (a) % Time Frozen vs Rate
    ax1 = subplot(3,1,1);
    plot(rates, freezePct, '-o', ...
         'LineWidth',1.5, 'MarkerSize',8, ...
         'MarkerFaceColor',[0.2 0.6 0.8]);
    hold(ax1,'on');
      p1 = polyfit(rates, freezePct, 1);
      plot(rates, polyval(p1, rates), '--r','LineWidth',1.5);
      [r1, p1val] = corr(rates.', freezePct.','Rows','complete');
      text(0.05, 0.85, sprintf('r=%.2f, p=%.3f', r1, p1val), ...
           'Units','normalized','FontSize',11,'FontWeight','bold');
    hold(ax1,'off');
    grid(ax1,'on'); box(ax1,'on');
    xlabel(ax1,'Speech Rate Multiplier','FontSize',12,'FontWeight','bold');
    ylabel(ax1,'% Time Frozen','FontSize',12,'FontWeight','bold');
    title(ax1,'Freeze Percentage vs. Speech Rate','FontSize',14);

    % (b) # Freeze Episodes vs Rate
    ax2 = subplot(3,1,2);
    plot(rates, freezeCount, '-s', ...
         'LineWidth',1.5,'MarkerSize',8, ...
         'MarkerFaceColor',[0.8 0.4 0.4]);
    hold(ax2,'on');
      p2 = polyfit(rates, freezeCount, 1);
      plot(rates, polyval(p2, rates), '--r','LineWidth',1.5);
      [r2, p2val] = corr(rates.', freezeCount.','Rows','complete');
      text(0.05, 0.85, sprintf('r=%.2f, p=%.3f', r2, p2val), ...
           'Units','normalized','FontSize',11,'FontWeight','bold');
    hold(ax2,'off');
    grid(ax2,'on'); box(ax2,'on');
    xlabel(ax2,'Speech Rate Multiplier','FontSize',12,'FontWeight','bold');
    ylabel(ax2,'# Freeze Episodes','FontSize',12,'FontWeight','bold');
    title(ax2,'Number of Freeze Episodes','FontSize',14);

    % (c) Mean Freeze Duration vs Rate
    ax3 = subplot(3,1,3);
    plot(rates, meanDuration, '-d', ...
         'LineWidth',1.5,'MarkerSize',8, ...
         'MarkerFaceColor',[0.4 0.8 0.4]);
    hold(ax3,'on');
      p3 = polyfit(rates, meanDuration, 1);
      plot(rates, polyval(p3, rates), '--r','LineWidth',1.5);
      [r3, p3val] = corr(rates.', meanDuration.','Rows','complete');
      text(0.05, 0.85, sprintf('r=%.2f, p=%.3f', r3, p3val), ...
           'Units','normalized','FontSize',11,'FontWeight','bold');
    hold(ax3,'off');
    grid(ax3,'on'); box(ax3,'on');
    xlabel(ax3,'Speech Rate Multiplier','FontSize',12,'FontWeight','bold');
    ylabel(ax3,'Mean Freeze Duration (s)','FontSize',12,'FontWeight','bold');
    title(ax3,'Average Freeze Duration','FontSize',14);

    % Tidy all axes
    ax = findobj(gcf,'Type','axes');
    for k = 1:numel(ax)
        ax(k).FontSize  = 11;
        ax(k).LineWidth = 1;
    end

    %% 6) Hypothesis Test: monotonic rise in freezePct
    if all(diff(freezePct) > 0)
        resultText = 'Confirmed';
    else
        resultText = 'Not Confirmed';
    end

    %% 7) Build and append summary row
    testName   = 'Rate Sweep';
    hypothesis = 'Freeze % ↑ as speech rate ↑';
    M1 = freezePct(1);
    M2 = freezePct(ceil(n/2));
    M3 = freezePct(end);
    M4 = mean(freezeCount);
    M5 = mean(meanDuration);
    newRow = { testName, hypothesis, M1, M2, M3, M4, M5, resultText };
    appendTestSummary(figHandle, newRow);
end

function appendTestSummary(figHandle, row)
%APPENDTESTSUMMARY   Adds one row to the GUI's summary table.
    hTable = findobj(figHandle,'Tag','summaryTable');
    data   = get(hTable,'Data');
    if isempty(data), data = {}; end
    updated = [data; row];
    set(hTable,'Data', updated);
    figHandle.UserData.summaryTableData = updated;
end
