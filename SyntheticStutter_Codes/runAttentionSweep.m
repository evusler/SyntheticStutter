function runAttentionSweep(figHandle)
%RUNATTENTIONSWEEP   Sweep attention levels & report extended metrics.

    %% 1) Guard
    if nargin<1 || isempty(figHandle) || ...
       ~isfield(figHandle.UserData,'simulationResults') || ...
       isempty(figHandle.UserData.simulationResults)
        errordlg('Please load audio and run the simulation first.','Sweep Error');
        return;
    end

    %% 2) Unpack baseline
    sim   = figHandle.UserData.simulationResults;
    C0    = sim.constants;
    mp0   = sim.modelParams;
    cfg0  = sim.config;
    audio = sim.originalAudio;
    Fs    = sim.Fs;
    P     = sim.P;

    %% 3) Sweep grid
    attnVals    = linspace(0.5,10,10);
    n           = numel(attnVals);
    freezePct   = zeros(1,n);
    freezeCount = zeros(1,n);
    meanDur     = zeros(1,n);

    %% 4) Run sims
    h = waitbar(0,'Running Attention Sweep...','Name','Sweep Progress');
    for i = 1:n
        % update attention
        cfg = cfg0;
        cfg.defaultAttentionLevel = attnVals(i);

        % pack params
        params.constants   = C0;
        params.config      = cfg;
        params.modelParams = mp0;

        % run
        [~,~,~,~,tspan,~,rawMask] = runStutterSimulation(audio,Fs,params,P);
        dt = mean(diff(tspan));

        % merge micro‐gaps <50ms
        mask = movmedian(rawMask, round(0.05/dt) )>0;
        CC   = bwconncomp(mask);
        durs = cellfun(@numel, CC.PixelIdxList) * dt;

        % keep only ≥150ms
        durs = durs(durs>=0.150);

        % metrics
        freezePct(i)   = sum(durs) / (tspan(end)-tspan(1)) * 100;
        freezeCount(i) = numel(durs);
        meanDur(i)     = mean(durs);

        waitbar(i/n, h);
    end
    close(h);

    %% 5) Plot with fits & stats
    figure('Color','w','Units','normalized','Position',[.2 .2 .6 .6]);

    % % Time Frozen vs Attention
    ax1 = subplot(3,1,1);
    plot(attnVals,freezePct,'-o','LineWidth',1.5,'MarkerSize',8,'MarkerFaceColor',[0.2 0.6 0.8]);
    hold(ax1,'on');
      p1 = polyfit(attnVals,freezePct,1);
      plot(attnVals,polyval(p1,attnVals),'--r','LineWidth',1.5);
      [r1,p1val] = corr(attnVals.',freezePct.','Rows','complete');
      text(0.05,0.9,sprintf('r=%.2f, p=%.3f',r1,p1val),...
           'Units','normalized','FontSize',11,'FontWeight','bold');
    hold(ax1,'off');
    grid(ax1,'on'); box(ax1,'on');
    xlabel(ax1,'Attention Level','FontSize',12,'FontWeight','bold');
    ylabel(ax1,'% Time Frozen','FontSize',12,'FontWeight','bold');
    title(ax1,'Freeze \% vs. Attention Level','FontSize',14);

    % Freeze Count vs Attention
    ax2 = subplot(3,1,2);
    plot(attnVals,freezeCount,'-s','LineWidth',1.5,'MarkerSize',8,'MarkerFaceColor',[0.8 0.4 0.4]);
    hold(ax2,'on');
      p2 = polyfit(attnVals,freezeCount,1);
      plot(attnVals,polyval(p2,attnVals),'--r','LineWidth',1.5);
      [r2,p2val] = corr(attnVals.',freezeCount.','Rows','complete');
      text(0.05,0.9,sprintf('r=%.2f, p=%.3f',r2,p2val),...
           'Units','normalized','FontSize',11,'FontWeight','bold');
    hold(ax2,'off');
    grid(ax2,'on'); box(ax2,'on');
    xlabel(ax2,'Attention Level','FontSize',12,'FontWeight','bold');
    ylabel(ax2,'# Freeze Episodes','FontSize',12,'FontWeight','bold');
    title(ax2,'Number of Freezes','FontSize',14);

    % Mean Freeze Duration vs Attention
    ax3 = subplot(3,1,3);
    plot(attnVals,meanDur,'-d','LineWidth',1.5,'MarkerSize',8,'MarkerFaceColor',[0.4 0.8 0.4]);
    hold(ax3,'on');
      p3 = polyfit(attnVals,meanDur,1);
      plot(attnVals,polyval(p3,attnVals),'--r','LineWidth',1.5);
      [r3,p3val] = corr(attnVals.',meanDur.','Rows','complete');
      text(0.05,0.9,sprintf('r=%.2f, p=%.3f',r3,p3val),...
           'Units','normalized','FontSize',11,'FontWeight','bold');
    hold(ax3,'off');
    grid(ax3,'on'); box(ax3,'on');
    xlabel(ax3,'Attention Level','FontSize',12,'FontWeight','bold');
    ylabel(ax3,'Mean Freeze Duration (s)','FontSize',12,'FontWeight','bold');
    title(ax3,'Average Freeze Duration','FontSize',14);

    % tidy
    for ax = [ax1 ax2 ax3]
        ax.FontSize  = 11;
        ax.LineWidth = 1;
    end

    %% 6) Append summary
    testName   = 'Attention Sweep';
    hypothesis = 'Freeze % ↑ as attention ↑';
    M1 = freezePct(1);
    M2 = freezePct(ceil(n/2));
    M3 = freezePct(end);
    M4 = mean(freezeCount);
    M5 = mean(meanDur);
    if r1 > 0.8
        resultText = 'Confirmed';
    else
        resultText = 'Not Confirmed';
    end

    % Now call the local helper below
    appendTestSummary(figHandle, {testName, hypothesis, M1, M2, M3, M4, M5, resultText});
end

%% ── Local helper to append to the GUI table ─────────────────────────
function appendTestSummary(figHandle, row)
    hTable = findobj(figHandle,'Tag','summaryTable');
    data   = get(hTable,'Data');
    if isempty(data), data = {}; end
    data(end+1,:) = row;
    set(hTable,'Data',data);
    figHandle.UserData.summaryTableData = data;
end
