function runPlanningHorizonSweep(figHandle)
%RUNPLANNINGHORIZONSWEEP   Sweep planning horizon & update Test Summary.

    %% 1) Guard
    if nargin<1 || isempty(figHandle) || ...
       ~isfield(figHandle.UserData,'simulationResults') || ...
       isempty(figHandle.UserData.simulationResults)
        errordlg('Run a baseline simulation first.','Sweep Error');
        return;
    end

    %% 2) Unpack
    sim   = figHandle.UserData.simulationResults;
    audio = sim.originalAudio; 
    Fs    = sim.Fs;
    C0    = sim.constants;     
    cfg0  = sim.config;       
    mp0   = sim.modelParams;   
    P     = sim.P;

    %% 3) Sweep values
    horizons    = round(logspace(log10(10), log10(200), 10));
    nH          = numel(horizons);
    freezePct   = nan(1,nH);
    freezeCount = nan(1,nH);
    meanDur     = nan(1,nH);

    %% 4) Run sims
    hWB = waitbar(0,'Running Planning‐Horizon Sweep...','Name','Sweep Progress');
    for i = 1:nH
        ph = horizons(i);
        waitbar(i/nH, hWB, sprintf('Horizon %d/%d',i,nH));
        try
            cfg = cfg0;
            cfg.planningHorizon = ph;
            params.constants   = C0;
            params.config      = cfg;
            params.modelParams = mp0;

            [~,~,~,~,tspan,~,freezeMask] = runStutterSimulation(audio,Fs,params,P);
            fm = logical(freezeMask);
            dt = mean(diff(tspan));

            freezePct(i)   = mean(fm)*100;
            CC             = bwconncomp(fm);
            freezeCount(i) = CC.NumObjects;
            if CC.NumObjects>0
                stats       = regionprops(CC,'Area');
                meanDur(i)  = mean([stats.Area]) * dt;
            else
                meanDur(i)  = 0;
            end
        catch ME
            warning('Horizon %d failed: %s', ph, ME.message);
        end
    end
    close(hWB);

    %% 5) Plot with fits & stats
    fs = 12; lw = 1.5;
    xLog = log10(horizons);
    xf   = linspace(min(xLog),max(xLog),200);

    figure('Color','w','Units','normalized','Position',[.1 .1 .8 .6]);
    tl = tiledlayout(3,1,'Padding','compact','TileSpacing','compact');

    % (a) % Time Frozen vs Horizon
    ax1 = nexttile(tl,1);
    semilogx(ax1, horizons, freezePct, '-o', 'LineWidth',lw,'MarkerSize',8,'MarkerFaceColor',[0.2 0.6 0.8]);
    hold(ax1,'on');
      p1 = polyfit(xLog, freezePct, 1);
      semilogx(ax1, 10.^xf, polyval(p1, xf), '--r', 'LineWidth',lw);
      [r1,p1val] = corr(xLog.', freezePct.');
      text(0.05,0.85, sprintf('r=%.2f, p=%.3f',r1,p1val), ...
           'Units','normalized','FontSize',fs-2,'FontWeight','bold');
    hold(ax1,'off');
    grid(ax1,'on'); box(ax1,'on');
    xlabel(ax1,'Planning Horizon','FontSize',fs,'FontWeight','bold');
    ylabel(ax1,'% Time Frozen','FontSize',fs,'FontWeight','bold');
    title(ax1,'Freeze \% vs. Planning Horizon','FontSize',fs+2,'FontWeight','bold');
    ax1.FontSize = fs; ax1.LineWidth = 1;

    % (b) # Freeze Episodes vs Horizon
    ax2 = nexttile(tl,2);
    semilogx(ax2, horizons, freezeCount, '-s', 'LineWidth',lw,'MarkerSize',8,'MarkerFaceColor',[0.8 0.4 0.4]);
    hold(ax2,'on');
      p2 = polyfit(xLog, freezeCount, 1);
      semilogx(ax2, 10.^xf, polyval(p2, xf), '--r', 'LineWidth',lw);
      [r2,p2val] = corr(xLog.', freezeCount.');
      text(0.05,0.85, sprintf('r=%.2f, p=%.3f',r2,p2val), ...
           'Units','normalized','FontSize',fs-2,'FontWeight','bold');
    hold(ax2,'off');
    grid(ax2,'on'); box(ax2,'on');
    xlabel(ax2,'Planning Horizon','FontSize',fs,'FontWeight','bold');
    ylabel(ax2,'# Freeze Episodes','FontSize',fs,'FontWeight','bold');
    title(ax2,'Number of Freezes vs. Planning Horizon','FontSize',fs+2,'FontWeight','bold');
    ax2.FontSize = fs; ax2.LineWidth = 1;

    % (c) Mean Freeze Duration vs Horizon
    ax3 = nexttile(tl,3);
    semilogx(ax3, horizons, meanDur, '-d', 'LineWidth',lw,'MarkerSize',8,'MarkerFaceColor',[0.4 0.8 0.4]);
    hold(ax3,'on');
      p3 = polyfit(xLog, meanDur, 1);
      semilogx(ax3, 10.^xf, polyval(p3, xf), '--r', 'LineWidth',lw);
      [r3,p3val] = corr(xLog.', meanDur.');
      text(0.05,0.85, sprintf('r=%.2f, p=%.3f',r3,p3val), ...
           'Units','normalized','FontSize',fs-2,'FontWeight','bold');
    hold(ax3,'off');
    grid(ax3,'on'); box(ax3,'on');
    xlabel(ax3,'Planning Horizon','FontSize',fs,'FontWeight','bold');
    ylabel(ax3,'Mean Freeze Duration (s)','FontSize',fs,'FontWeight','bold');
    title(ax3,'Avg Freeze Duration vs. Planning Horizon','FontSize',fs+2,'FontWeight','bold');
    ax3.FontSize = fs; ax3.LineWidth = 1;

    linkaxes([ax1 ax2 ax3],'x');

    %% 6) Hypothesis: U‐shape (ends > middle)
    midIdx = ceil(nH/2);
    cond   = freezePct(1)>freezePct(midIdx) && freezePct(end)>freezePct(midIdx);
    if cond
        resultText = 'Confirmed';
    else
        resultText = 'Not Confirmed';
    end

    %% 7) Append summary row
    testName   = 'Planning-Horizon Sweep';
    hypothesis = 'Freeze % higher at short & long horizons (U-shape)';
    M1 = freezePct(1);
    M2 = freezePct(midIdx);
    M3 = freezePct(end);
    M4 = mean(freezeCount,'omitnan');
    M5 = mean(meanDur,'omitnan');

    appendTestSummary(figHandle, {testName, hypothesis, M1, M2, M3, M4, M5, resultText});
end

%% ── Helper to append one row to the GUI's Test Summary ------------
function appendTestSummary(figHandle, row)
    hT   = findobj(figHandle,'Tag','summaryTable');
    data = get(hT,'Data');
    if isempty(data), data = {}; end
    data(end+1,:) = row;
    set(hT,'Data', data);
    figHandle.UserData.summaryTableData = data;
end
