function runPredictabilitySweep(figHandle)
%RUNPREDICTABILITYSWEEP   Correlate word-level predictability with freezing.
%   If real wordOnsets are available, use them. Otherwise split the
%   utterance into equal-duration windows.

    %% 1) Guard
    if nargin<1 || isempty(figHandle) || ...
       ~isfield(figHandle.UserData,'simulationResults') || ...
       isempty(fieldnames(figHandle.UserData.simulationResults))
        errordlg('Please load audio and run a simulation before Predictability Sweep.','Sweep Error');
        return;
    end

    %% 2) Unpack inputs
    ud    = figHandle.UserData;
    audio = ud.audioData;
    Fs    = ud.Fs;
    C0    = ud.constants;
    cfg0  = ud.config;
    mp0   = ud.modelParams;

    % Pull predictabilities
    P_raw = ud.annotations;
    if iscell(P_raw)
        P = cell2mat(P_raw(:,4));
    else
        P = P_raw;
    end
    P = P(:);
    nWords = numel(P);

    %% 3) Run simulation once
    params.constants   = C0;
    params.config      = cfg0;
    params.modelParams = mp0;
    [~,~,~,~, tspan, ~, freezeMask] = runStutterSimulation(audio, Fs, params, P);

    %% 4) Determine windows
    sim = ud.simulationResults;
    if isfield(sim,'wordOnsets') && numel(sim.wordOnsets)==nWords && ~isempty(sim.wordOnsets)
        edges = [sim.wordOnsets(:); tspan(end)];  % real onsets + final end
    else
        % fallback: equal-duration slices
        edges = linspace(tspan(1), tspan(end), nWords+1)';
    end

    %% 5) Compute per-word freeze%
    freezeAtWord = nan(nWords,1);
    for w = 1:nWords
        t0  = edges(w);
        t1  = edges(w+1);
        idx = tspan>=t0 & tspan<t1;
        if any(idx)
            fm = freezeMask(idx);
            fm(isnan(fm)) = false;
            freezeAtWord(w) = mean(fm)*100;
        end
    end

    %% 6) Scatter + regression plot
    valid = ~isnan(freezeAtWord);
    if ~any(valid)
        errordlg('No valid freeze data – all NaN','Sweep Error');
        return;
    end
    xData = P(valid);
    yData = freezeAtWord(valid);

    % Fit & corr
    pCorr = corr(xData, yData, 'Rows','complete');
    pFit  = polyfit(xData, yData, 1);
    xFit  = linspace(min(P), max(P), 200);

    f = figure('Color','w','Units','normalized','Position',[.2 .2 .7 .5]);
    tl = tiledlayout(1,2,'TileSpacing','compact','Padding','compact');

    % (a) Scatter + fit line
    ax1 = nexttile(tl,1);
    scatter(ax1, xData, yData, 60, 'MarkerFaceColor',[0.2 0.6 0.8],'MarkerEdgeColor','k');
    hold(ax1,'on');
      plot(ax1, xFit, polyval(pFit,xFit), '--r', 'LineWidth',1.5);
    hold(ax1,'off');
    grid(ax1,'on'); box(ax1,'on');
    xlabel(ax1,'Word Predictability','FontWeight','bold');
    ylabel(ax1,'% Time Frozen','FontWeight','bold');
    title(ax1,sprintf('Freeze %% vs Predictability (n=%d, r=%.2f)', numel(xData), pCorr),'FontSize',14);

    % (b) Binned bar plot
    ax2 = nexttile(tl,2);
    nBins = min(10, nWords);
    [counts,edgesB,binIdx] = histcounts(P, nBins);
    centers = edgesB(1:end-1) + diff(edgesB)/2;
    meanFz  = accumarray(binIdx, freezeAtWord, [nBins,1], @nanmean, NaN);

    bar(ax2, centers, meanFz, 'FaceColor',[0.4 0.8 0.4],'EdgeColor','k');
    hold(ax2,'on');
      for b = 1:nBins
        text(ax2, centers(b), meanFz(b)+2, sprintf('%.1f%%', meanFz(b)), ...
             'HorizontalAlignment','center','FontSize',9,'FontWeight','bold');
        text(ax2, centers(b), -5, sprintf('n=%d',counts(b)), ...
             'HorizontalAlignment','center','FontSize',9,'Color',[.2 .2 .2]);
      end
    hold(ax2,'off');
    grid(ax2,'on'); box(ax2,'on');
    xlabel(ax2,'Predictability Bin','FontWeight','bold');
    ylabel(ax2,'Avg % Time Frozen','FontWeight','bold');
    title(ax2,'Binned Avg Freeze','FontSize',14);

    %% 7) Append summary
    % Ensure summaryTableData exists
    if ~isfield(ud,'summaryTableData') || isempty(ud.summaryTableData)
        ud.summaryTableData = cell(0,8);
    end

    testName   = 'Predictability Sweep';
    hypothesis = 'Higher predictability → more freezing';
    M1 = freezeAtWord(1);
    M2 = freezeAtWord(ceil(nWords/2));
    M3 = freezeAtWord(end);
    M4 = sum(P>median(P));
    M5 = nanmean(freezeAtWord);
    resultText = ternary(pCorr>0, 'Confirmed', 'Not Confirmed');

    % Update summary
    data = ud.summaryTableData;
    data(end+1,:) = {testName, hypothesis, M1, M2, M3, M4, M5, resultText};
    T = findobj(figHandle,'Tag','summaryTable');
    set(T,'Data',data);
    figHandle.UserData.summaryTableData = data;
end

%% Helpers

function out = ternary(cond, a, b)
    if cond
        out = a;
    else
        out = b;
    end
end
