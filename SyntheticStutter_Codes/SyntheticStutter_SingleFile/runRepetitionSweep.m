function runRepetitionSweep(figHandle)
%RUNREPETITIONSWEEP   Repeat utterance simulation to test adaptation.
%   Uses observed Free Energy reductions to adapt sensory variances,
%   plots trajectories, adaptation metrics, and segment-level FE adaptation.

    %% 1) Guard
    if nargin<1 || isempty(figHandle) || ...
       ~isfield(figHandle.UserData,'simulationResults') || ...
       isempty(fieldnames(figHandle.UserData.simulationResults))
        errordlg('Please run a baseline simulation first.','Sweep Error');
        return;
    end

    %% 2) Unpack baseline & transcript info
    sim   = figHandle.UserData.simulationResults;
    audio = figHandle.UserData.audioData;
    Fs    = figHandle.UserData.Fs;
    C0    = figHandle.UserData.constants;
    cfg0  = figHandle.UserData.config;
    mp0   = figHandle.UserData.modelParams;
    P_raw = figHandle.UserData.annotations;
    if iscell(P_raw)
        P = cell2mat(P_raw(:,4));
    else
        P = P_raw;
    end

    %% 3) Preallocate
    nReps     = 10;
    freezePct = nan(1,nReps);
    meanFE    = nan(1,nReps);
    FE_traces = cell(nReps,1);
    tspan_tr  = cell(nReps,1);

    %% 4) Sweep with adaptation
    learningRate = 0.05;
    mpAdapt      = mp0;
    hWB = waitbar(0,'Running Repetition Sweep...','Name','Sweep Progress');
    for r = 1:nReps
        waitbar(r/nReps,hWB, sprintf('Rep %d/%d',r,nReps));
        params.constants   = C0;
        params.config      = cfg0;
        params.modelParams = mpAdapt;
        try
            [~,~,~,~, tspan, FE_hist, freezeMask] = ...
                runStutterSimulation(audio, Fs, params, P);
        catch ME
            warning('Simulation failed at rep %d: %s', r, ME.message);
            continue;
        end

        % Compute metrics
        freezeMask(isnan(freezeMask)) = false;
        freezePct(r)    = mean(freezeMask)*100;
        meanFE(r)       = mean(FE_hist,'omitnan');
        FE_traces{r}    = FE_hist;
        tspan_tr{r}     = tspan;

        % Adapt sensory variances
        if r>1
            deltaFE = meanFE(r-1) - meanFE(r);
            if isfield(mpAdapt,'sigmaA')
                mpAdapt.sigmaA = max(mpAdapt.sigmaA - learningRate*deltaFE, 0.01);
            end
            if isfield(mpAdapt,'sigmaS')
                mpAdapt.sigmaS = max(mpAdapt.sigmaS - learningRate*deltaFE, 0.01);
            end
        end
    end
    close(hWB);

    %% 5) Segment-level FE data
    if isfield(sim,'wordOnsets') && isfield(sim,'wordLabels')
        edges   = sim.wordOnsets;
        labels  = sim.wordLabels;
        nSeg    = numel(edges)-1;
    else
        nSeg   = 10;
        edges  = linspace(tspan_tr{1}(1), tspan_tr{1}(end), nSeg+1);
        labels = arrayfun(@(b)sprintf('B%d',b),1:nSeg,'uni',0);
    end

    FE_blocks = nan(nReps, nSeg);
    for r = 1:nReps
        tr = FE_traces{r}; ts = tspan_tr{r};
        if numel(tr)==numel(ts)
            for b = 1:nSeg
                idx = ts>=edges(b) & ts<edges(b+1);
                if any(idx)
                    FE_blocks(r,b) = mean(tr(idx),'omitnan');
                end
            end
        end
    end

    %% 6) Plotting
    figure('Color','w','Units','normalized','Position',[.1 .1 .8 .7]);
    tl = tiledlayout(3,1,'TileSpacing','compact','Padding','compact');

    % (a) FE trajectories
    ax1 = nexttile(tl,1); hold(ax1,'on');
      cmap = parula(nReps);
      for r = 1:nReps
        plot(ax1, tspan_tr{r}, FE_traces{r}, 'Color',[cmap(r,:) 0.6],'LineWidth',1.2);
      end
    hold(ax1,'off');
    grid(ax1,'on'); box(ax1,'on');
    xlabel(ax1,'Time (s)','FontWeight','bold');
    ylabel(ax1,'Free Energy','FontWeight','bold');
    title(ax1,'FE Trajectories Across Repetitions','FontSize',14);

    % (b) % Freeze & mean FE vs repetition
    ax2 = nexttile(tl,2); hold(ax2,'on');
      reps = 1:nReps;
      p1 = plot(ax2, reps, freezePct, '-o','LineWidth',1.5,'MarkerSize',8);
      yyaxis(ax2,'right');
      p2 = plot(ax2, reps, meanFE, '--s','LineWidth',1.5,'MarkerSize',8);
    hold(ax2,'off');
    grid(ax2,'on'); box(ax2,'on');
    xlabel(ax2,'Repetition','FontWeight','bold');
    yyaxis(ax2,'left');  ylabel(ax2,'% Time Frozen','FontWeight','bold');
    yyaxis(ax2,'right'); ylabel(ax2,'Mean FE','FontWeight','bold');
    legend(ax2, [p1 p2], {'% Freeze','Mean FE'}, 'Location','best');
    title(ax2,'Adaptation Metrics','FontSize',14);
    slopeF = polyfit(reps, freezePct,1);
    slopeE = polyfit(reps, meanFE,1);
    text(ax2,0.02,0.85,sprintf('Slope(%%)=%.2f/rep',slopeF(1)),...
         'Units','normalized','Color',p1.Color,'FontSize',10);
    text(ax2,0.02,0.75,sprintf('Slope(FE)=%.2f/rep',slopeE(1)),...
         'Units','normalized','Color',p2.Color,'FontSize',10);

    % (c) Segment-level FE: individual reps + mean ± SD
    ax3 = nexttile(tl,3); hold(ax3,'on');
      % 1) plot each rep as a faint gray line
      for r = 1:nReps
        plot(ax3, 1:nSeg, FE_blocks(r,:), '-', ...
             'Color',[0.8 0.8 0.8],'LineWidth',0.8);
      end

      % 2) compute mean and std
      meanBlk = mean(FE_blocks,1,'omitnan');
      stdBlk  = std( FE_blocks,0,1,'omitnan');

      % 3) plot bold mean + errorbars
      errorbar(ax3, 1:nSeg, meanBlk, stdBlk, '-o', ...
               'LineWidth',1.5,'MarkerSize',6,'CapSize',8, ...
               'Color',[0 0.4470 0.7410]);
    hold(ax3,'off');
    grid(ax3,'on'); box(ax3,'on');
    xlabel(ax3,'Segment','FontWeight','bold');
    ylabel(ax3,'Free Energy','FontWeight','bold');
    title(ax3,'Segment-level FE Adaptation','FontSize',14);

    % rotate & subsample ticklabels if needed
    xticks(ax3,1:nSeg);
    xticklabels(ax3,labels);
    xtickangle(ax3,45);

    % zoom in on the narrow FE range
    yMin = min(meanBlk - stdBlk);
    yMax = max(meanBlk + stdBlk);
    ylim(ax3,[yMin*0.995, yMax*1.005]);

    %% 7) Stats & summary row
    [~,pVal]   = corr(reps', freezePct','Type','Pearson','Rows','complete');
    adaptation = (slopeF(1)<0) && (slopeE(1)<0) && (pVal<0.05);
    resultText = ternary(adaptation,'Confirmed','Not Confirmed');
    appendTestSummary(figHandle, { ...
      'Repetition Sweep', 'Rep→↓FE & Freeze%', ...
      freezePct(1), freezePct(end), ...
      meanFE(1),   meanFE(end), ...
      mean(diff(freezePct),'omitnan'), ...
      resultText ...
    });
end

%% Helper functions

function appendTestSummary(figHandle, row)
    hT   = findobj(figHandle,'Tag','summaryTable');
    data = get(hT,'Data');
    if isempty(data), data = {}; end
    data(end+1,:) = row;
    set(hT,'Data',data);
    figHandle.UserData.summaryTableData = data;
end

function out = ternary(cond, a, b)
    if cond, out = a; else, out = b; end
end
