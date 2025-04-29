function runPrecisionRateSweep(figHandle)
%RUNPRECISIONRATESWEEP   Sweep sensory precision × speech rate & update Test Summary.

    %% 1) Guard: require prior simulation
    if nargin<1 || isempty(figHandle) || ...
       ~isfield(figHandle.UserData,'simulationResults') || ...
       isempty(figHandle.UserData.simulationResults)
        errordlg( ...
          'Please load audio and run a baseline simulation first.', ...
          'Sweep Error' ...
        );
        return;
    end

    %% 2) Unpack baseline state
    sim   = figHandle.UserData.simulationResults;
    audio = sim.originalAudio;
    Fs    = sim.Fs;
    C0    = sim.constants;
    cfg0  = sim.config;
    mp0   = sim.modelParams;
    P     = sim.P;

    %% 3) Define sweep grid
    precFactors = linspace(0.5, 2.0, 6);    % noise multipliers
    rates       = linspace(0.5, 2.5, 10);   % speech rate multipliers
    nP = numel(precFactors); 
    nR = numel(rates);

    %% 4) Preallocate results
    freezePct2D   = nan(nP,nR);
    freezeCount2D = nan(nP,nR);
    meanDur2D     = nan(nP,nR);

    %% 5) Run all sims with waitbar
    total = nP*nR; idx = 0;
    hWB   = waitbar(0,'Running Precision×Rate Sweep...','Name','Sweep Progress');
    for iP = 1:nP
      for iR = 1:nR
        idx = idx + 1;
        waitbar(idx/total, hWB, sprintf('P %d/%d, R %d/%d', iP,nP, iR,nR));
        try
          % Update constants
          C = C0;
          C.noise.amp = C0.noise.amp * precFactors(iP);
          C.dtBase    = C0.dtBase / rates(iR);

          % Simulate
          params.constants   = C;
          params.config      = cfg0;
          params.modelParams = mp0;
          [~,~,~,~,tspan,~,freezeMask] = ...
            runStutterSimulation(audio, Fs, params, P);

          % Compute metrics
          dt = mean(diff(tspan));
          fm = logical(freezeMask);
          freezePct2D(iP,iR)   = mean(fm)*100;
          CC                   = bwconncomp(fm);
          freezeCount2D(iP,iR) = CC.NumObjects;
          if CC.NumObjects>0
            stats = regionprops(CC,'Area');
            meanDur2D(iP,iR) = mean([stats.Area]) * dt;
          else
            meanDur2D(iP,iR) = 0;
          end
        catch ME
          warning('Sweep failed at P=%d,R=%d: %s', iP,iR, ME.message);
        end
      end
    end
    close(hWB);

    %% 6) Plot as line‐plots with fits & stats
    figure('Color','w','Units','normalized','Position',[.1 .1 .8 .6]);
    fs = 12; lw = 1.5;
    cmap = lines(nP);

    % (a) Freeze % vs Rate
    ax1 = subplot(3,1,1); hold(ax1,'on');
    for iP = 1:nP
      y = freezePct2D(iP,:);
      plot(ax1, rates, y, '-o','Color',cmap(iP,:),'LineWidth',lw,'MarkerSize',6);
      p = polyfit(rates,y,1);
      plot(ax1, rates, polyval(p,rates), '--','Color',cmap(iP,:),'LineWidth',1);
      [rCoef,pVal] = corr(rates.', y.','Rows','complete');
      legends1{iP} = sprintf('Noise×%.2g (r=%.2f,p=%.2f)', precFactors(iP), rCoef, pVal);
    end
    hold(ax1,'off');
    grid(ax1,'on'); box(ax1,'on');
    xlabel(ax1,'Speech Rate ×','FontSize',fs,'FontWeight','bold');
    ylabel(ax1,'% Time Frozen','FontSize',fs,'FontWeight','bold');
    title(ax1,'Freeze \% vs. Speech Rate','FontSize',fs+2,'FontWeight','bold');
    legend(ax1, legends1, 'Location','best','FontSize',fs-2);
    ax1.FontSize  = fs; ax1.LineWidth = 1;

    % (b) Freeze count vs Rate
    ax2 = subplot(3,1,2); hold(ax2,'on');
    for iP = 1:nP
      y = freezeCount2D(iP,:);
      plot(ax2, rates, y, '-s','Color',cmap(iP,:),'LineWidth',lw,'MarkerSize',6);
      p = polyfit(rates,y,1);
      plot(ax2, rates, polyval(p,rates), '--','Color',cmap(iP,:),'LineWidth',1);
      [rCoef,pVal] = corr(rates.', y.','Rows','complete');
      legends2{iP} = sprintf('Noise×%.2g (r=%.2f,p=%.2f)', precFactors(iP), rCoef, pVal);
    end
    hold(ax2,'off');
    grid(ax2,'on'); box(ax2,'on');
    xlabel(ax2,'Speech Rate ×','FontSize',fs,'FontWeight','bold');
    ylabel(ax2,'# Freeze Episodes','FontSize',fs,'FontWeight','bold');
    title(ax2,'Freeze Count vs. Speech Rate','FontSize',fs+2,'FontWeight','bold');
    legend(ax2, legends2, 'Location','best','FontSize',fs-2);
    ax2.FontSize  = fs; ax2.LineWidth = 1;

    % (c) Mean freeze duration vs Rate
    ax3 = subplot(3,1,3); hold(ax3,'on');
    for iP = 1:nP
      y = meanDur2D(iP,:);
      plot(ax3, rates, y, '-d','Color',cmap(iP,:),'LineWidth',lw,'MarkerSize',6);
      p = polyfit(rates,y,1);
      plot(ax3, rates, polyval(p,rates), '--','Color',cmap(iP,:),'LineWidth',1);
      [rCoef,pVal] = corr(rates.', y.','Rows','complete');
      legends3{iP} = sprintf('Noise×%.2g (r=%.2f,p=%.2f)', precFactors(iP), rCoef, pVal);
    end
    hold(ax3,'off');
    grid(ax3,'on'); box(ax3,'on');
    xlabel(ax3,'Speech Rate ×','FontSize',fs,'FontWeight','bold');
    ylabel(ax3,'Mean Freeze Duration (s)','FontSize',fs,'FontWeight','bold');
    title(ax3,'Avg Freeze Duration vs. Speech Rate','FontSize',fs+2,'FontWeight','bold');
    legend(ax3, legends3, 'Location','best','FontSize',fs-2);
    ax3.FontSize  = fs; ax3.LineWidth = 1;

    linkaxes([ax1 ax2 ax3],'x');

    %% 7) Hypothesis test at mid‐rate & append summary
    midR    = ceil(nR/2);
    M_lowP  = freezePct2D(1,       midR);
    M_midP  = freezePct2D(ceil(nP/2),midR);
    M_highP = freezePct2D(end,     midR);
    if M_highP < M_lowP
        resultText = 'Confirmed';
    else
        resultText = 'Not Confirmed';
    end

    testName   = 'Precision×Rate Sweep';
    hypothesis = 'At fixed rate: ↑ noise (↓ precision) → ↓ freeze %';
    M1 = M_lowP; M2 = M_midP; M3 = M_highP;
    M4 = mean(freezeCount2D(:),'omitnan');
    M5 = mean(meanDur2D(:),'omitnan');

    appendTestSummary(figHandle, {testName, hypothesis, M1, M2, M3, M4, M5, resultText});
end

% --- Helper: append one row to the GUI's Test Summary -------------
function appendTestSummary(figHandle, row)
    hTable = findobj(figHandle,'Tag','summaryTable');
    data   = get(hTable,'Data');
    if isempty(data), data = {}; end
    data(end+1,:) = row;
    set(hTable,'Data', data);
    figHandle.UserData.summaryTableData = data;
end
