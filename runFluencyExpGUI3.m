function runFluencyExpGUI3
% runFluencyExpGUI3  GUI for fluency analysis using computeActionFunctional.m
% Usage:
%   runFluencyExpGUI3
% Computes action & cost terms, including surprisal from transcripts.

    %% State & Parameters
    wavPaths        = {};
    transcriptPaths = {};
    params.freezeFactor = 2;
    params.minFreezeDur = 0.2;
    params.nInterp      = 400;

    %% Create UIFigure & Layout
    fig = uifigure('Name','Fluency Comparison','Position',[200 200 1600 900], ...
                   'Color',[0.97 0.97 0.97],'CloseRequestFcn',@onClose);
    mainGrid = uigridlayout(fig,[1 2], ...
        'Padding',[10 10 10 10],'RowSpacing',10,'ColumnSpacing',10, ...
        'ColumnWidth',{'1x','3x'});

    %% Left Panel: Controls
    ctrlPanel = uipanel(mainGrid,'Title','Parameters & Options', ...
                        'FontSize',14,'BackgroundColor','white');
    ctrlPanel.Layout.Row    = 1;
    ctrlPanel.Layout.Column = 1;
    ctrlGrid = uigridlayout(ctrlPanel,[26 2], ...
        'Padding',[12 12 12 12],'RowSpacing',8,'ColumnSpacing',8, ...
        'RowHeight',[repmat({30},1,22),{40},{40}], ...
        'ColumnWidth',{'1x','2x'});

    % π slider
    uilabel(ctrlGrid,'Text','Sensory Precision (\pi):','FontWeight','bold');
    hPi    = uislider(ctrlGrid,'Limits',[0.1 1],'Value',0.5,'ValueChangedFcn',@updatePi);
    hPiLabel = uilabel(ctrlGrid,'Text','0.50','HorizontalAlignment','center');
    % π modulation factor
    uilabel(ctrlGrid,'Text','\pi Modulation Factor:','FontWeight','bold');
    hPiDyn = uislider(ctrlGrid,'Limits',[0.5 2],'Value',1,'ValueChangedFcn',@updatePiDyn);
    hPiDynLabel = uilabel(ctrlGrid,'Text','1.00','HorizontalAlignment','center');
    % σ slider
    uilabel(ctrlGrid,'Text','Motor-noise (\sigma):','FontWeight','bold');
    hSigma = uislider(ctrlGrid,'Limits',[0.01 0.5],'Value',0.1,'ValueChangedFcn',@updateSigma);
    hSigmaLabel = uilabel(ctrlGrid,'Text','0.10','HorizontalAlignment','center');
    % Cost-term weights
    termNames = {'Effort (C1)','Deviation (C2)','Surprisal (C3)', ...
                 'Rhythm (C4)','GlobalSpec (C5)','Planning (C6)'};
    hW = gobjects(1,6); hWLabel = gobjects(1,6);
    for i=1:6
        uilabel(ctrlGrid,'Text',termNames{i},'FontWeight','bold');
        hW(i)      = uislider(ctrlGrid,'Limits',[0 2],'Value',1, ...
                              'MajorTicks',0:0.5:2, ...
                              'ValueChangedFcn',@(s,e)updateWeight(i));
        hWLabel(i) = uilabel(ctrlGrid,'Text','1.00','HorizontalAlignment','center');
    end
    % File loaders
    btnLoadWav     = uibutton(ctrlGrid,'Text','Load WAVs…','ButtonPushedFcn',@loadWav);
    btnRemoveWav   = uibutton(ctrlGrid,'Text','Remove WAV(s)','ButtonPushedFcn',@removeWav);
    hWavList       = uilistbox(ctrlGrid,'Items',{},'Multiselect','on');
    btnLoadTrans   = uibutton(ctrlGrid,'Text','Load Transcript(s)…','ButtonPushedFcn',@loadTranscript);
    btnRemoveTrans = uibutton(ctrlGrid,'Text','Remove Transcript(s)','ButtonPushedFcn',@removeTranscript);
    hTransList     = uilistbox(ctrlGrid,'Items',{},'Multiselect','on');
    hUseTranscript = uicheckbox(ctrlGrid,'Text','Use Transcript Data','Value',true, ...
                                'ValueChangedFcn',@toggleTranscriptControls);
    % Plot options & run
    hDisablePlot   = uicheckbox(ctrlGrid,'Text','Disable Plotting','Value',false);
    uilabel(ctrlGrid,'Text','Plot Type:','FontWeight','bold');
    hPlotType      = uidropdown(ctrlGrid,'Items',{'Action/sec vs Duration','Action/Word vs Words'});
    hRun           = uibutton(ctrlGrid,'Text','Run Comparison','Enable','off', ...
                    'BackgroundColor',[0.2 0.6 1],'FontColor','white', ...
                    'ButtonPushedFcn',@runAnalysis);
    % Clear & Close
    uibutton(ctrlGrid,'Text','Clear Analysis','BackgroundColor',[0.8 0.2 0.2], ...
             'FontColor','white','ButtonPushedFcn',@clearAnalysis);
    uibutton(ctrlGrid,'Text','Close GUI','BackgroundColor',[0.5 0.5 0.5], ...
             'FontColor','white','ButtonPushedFcn',@onClose);

    %% Right Panel: Tabs & Axes
    tg = uitabgroup(mainGrid,'TabLocation','top');
    tg.Layout.Row    = 1; tg.Layout.Column = 2;
    % Comparison Tab
    tab1 = uitab(tg,'Title','Comparison');
    compGrid = uigridlayout(tab1,[5 1],'Padding',[12 12 12 12],'RowSpacing',8, ...
                           'RowHeight',{'3x','fit','fit','fit','1x'});
    hAxCost      = uiaxes(compGrid); hAxCost.Layout.Row=1;
    stationLabel = uilabel(compGrid,'Text','StdCost:','FontSize',12,'FontWeight','bold'); stationLabel.Layout.Row=2;
    volLabel     = uilabel(compGrid,'Text','CostVol:','FontSize',12,'FontWeight','bold');     volLabel.Layout.Row=3;
    fluLabel     = uilabel(compGrid,'Text','Fluency:','FontSize',12,'FontWeight','bold');     fluLabel.Layout.Row=4;
    uitCmp       = uitable(compGrid,'RowName',{},'ColumnWidth','auto'); uitCmp.Layout.Row=5;
    % Advanced Plots Tab
    tab2 = uitab(tg,'Title','Advanced Plots');
    advGrid = uigridlayout(tab2,[2 4],'Padding',[12 12 12 12], ...
                'RowSpacing',8,'ColumnSpacing',8, ...
                'RowHeight',{'1x','1x'}, ...
                'ColumnWidth',{'1x','1x','1x','1x'});
    hAxStationHist = uiaxes(advGrid); hAxStationHist.Layout.Row=1; hAxStationHist.Layout.Column=1;
    hAxVolHist     = uiaxes(advGrid); hAxVolHist.Layout.Row=1;     hAxVolHist.Layout.Column=2;
    hAxFreezeHist  = uiaxes(advGrid); hAxFreezeHist.Layout.Row=1;  hAxFreezeHist.Layout.Column=3;
    hAxFreezeBar   = uiaxes(advGrid); hAxFreezeBar.Layout.Row=1;   hAxFreezeBar.Layout.Column=4;
    hAxGroupTraj   = uiaxes(advGrid); hAxGroupTraj.Layout.Row=2;   hAxGroupTraj.Layout.Column=1;
    hAxGroupAction = uiaxes(advGrid); hAxGroupAction.Layout.Row=2;  hAxGroupAction.Layout.Column=2;
    hAxGroupAAI    = uiaxes(advGrid); hAxGroupAAI.Layout.Row=2;     hAxGroupAAI.Layout.Column=3;
    hAxScatter     = uiaxes(advGrid); hAxScatter.Layout.Row=2;     hAxScatter.Layout.Column=4;
    hAxTermTraj    = hAxGroupAAI;

    %% Color Palette
    palette.blue   = [0 0.4470 0.7410];
    palette.freeze = [1 0.8 0.8];

    enableRunIfReady();

    %% -------------------
    %% Nested Utility Functions
    %% -------------------

    function enableRunIfReady()
        ready = ~isempty(hWavList.Items) && (~hUseTranscript.Value || ~isempty(hTransList.Items));
        hRun.Enable = ready;
    end

    function toggleTranscriptControls(~,~)
        hTransList.Enable = hUseTranscript.Value;
        enableRunIfReady();
    end

    function updatePi(~,~)
        hPiLabel.Text = sprintf('%.2f',hPi.Value);
    end

    function updatePiDyn(~,~)
        hPiDynLabel.Text = sprintf('%.2f',hPiDyn.Value);
    end

    function updateSigma(~,~)
        hSigmaLabel.Text = sprintf('%.2f',hSigma.Value);
    end

    function updateWeight(i)
        hWLabel(i).Text = sprintf('%.2f',hW(i).Value);
    end

    function loadWav(~,~)
        [f,p] = uigetfile('*.wav','Select WAVs','MultiSelect','on');
        if isequal(f,0), return; end
        if ischar(f), f={f}; end
        wavPaths = fullfile(p,f);
        hWavList.Items = f; hWavList.Value={};
        enableRunIfReady();
    end

    function removeWav(~,~)
        sel = hWavList.Value; if isempty(sel), return; end
        it = hWavList.Items; idx=ismember(it,sel);
        wavPaths(idx)=[]; it(idx)=[]; hWavList.Items=it; hWavList.Value={};
        enableRunIfReady();
    end

    function loadTranscript(~,~)
        [f,p] = uigetfile({'*.csv;*.xlsx'},'Select Transcripts','MultiSelect','on');
        if isequal(f,0), return; end
        if ischar(f), f={f}; end
        transcriptPaths = fullfile(p,f);
        hTransList.Items = f; hTransList.Value={};
        enableRunIfReady();
    end

    function removeTranscript(~,~)
        sel = hTransList.Value; if isempty(sel), return; end
        it = hTransList.Items; idx=ismember(it,sel);
        transcriptPaths(idx)=[]; it(idx)=[]; hTransList.Items=it; hTransList.Value={};
        enableRunIfReady();
    end

    function clearAnalysis(~,~)
        wavPaths={}; transcriptPaths={};
        cla(hAxCost); stationLabel.Text='StdCost:'; volLabel.Text='CostVol:'; fluLabel.Text='Fluency:';
        uitCmp.Data={};
        cla(hAxStationHist); cla(hAxVolHist); cla(hAxFreezeHist); cla(hAxFreezeBar);
        cla(hAxGroupTraj); cla(hAxGroupAction); cla(hAxScatter); cla(hAxTermTraj);
        enableRunIfReady();
    end

    %% -------------------
    %% runAnalysis
    %% -------------------
    function runAnalysis(~,~)
        hRun.Enable='off';
        btnLoadWav.Enable='off'; btnRemoveWav.Enable='off';
        btnLoadTrans.Enable='off'; btnRemoveTrans.Enable='off';

        n = numel(wavPaths);
        if hUseTranscript.Value && numel(transcriptPaths)==1
            transcriptPaths = repmat(transcriptPaths,1,n);
        end

        % Grouping dialog
        numG = str2double(inputdlg('Number of groups?','Groups',[1 35],{'2'}));
        if isnan(numG)||numG<1, uialert(fig,'Need \u22651 group.','Error'); return; end
        defaultNames = arrayfun(@(i)sprintf('G%d',i),1:numG,'UniformOutput',false);
        grpNames = inputdlg(repmat({'Group name:'},1,numG),'Groups',[1 50],defaultNames);
        if isempty(grpNames), uialert(fig,'Grouping canceled.','Canceled'); return; end
        groups = strings(n,1); rem=1:n;
        for gi=1:numG-1
            [sel,ok]=listdlg('ListString',wavPaths(rem),'PromptString',sprintf('Select %s',grpNames{gi}));
            if ~ok, uialert(fig,'Cancelled.','Canceled'); return; end
            groups(rem(sel))=grpNames{gi};
            rem(sel)=[]; 
        end
        groups(rem)=grpNames{end};

        % Init results
        results = table('Size',[n,15],...
            'VariableTypes',{'string','double','double','double','double', ...
                             'double','double','double','double','double', ...
                             'double','double','double','double','string'},...
            'VariableNames',{'File','Duration','TotalAction','ActPerSec','ActPerWord', ...
                             'StdCost','CostVol','AAI','PercentStut','Fluency', ...
                             'CostAtSD_Mean','CostAtSD_Med','CostAtTD_Mean','CostAtTD_Med','Group'});

        tCell=cell(n,1); costInstCell=cell(n,1); costTermsCell=cell(n,1);
        freezeDurs=cell(n,1); disT=cell(n,1); disTy=cell(n,1); fileNames=cell(n,1);

        pg = uiprogressdlg(fig,'Title','Analyzing','Message','Starting...','Cancelable','on');

        for k=1:n
            if pg.CancelRequested, break; end
            pg.Message=sprintf('File %d of %d',k,n); pg.Value=k/n;

            % Load audio
            [~,name,~]=fileparts(wavPaths{k}); fileNames{k}=name;
            try
                [y,Fs0]=audioread(wavPaths{k});
                if size(y,2)>1, y=mean(y,2); end
                if Fs0>4000, y=resample(y,4000,Fs0); Fs=4000; else Fs=Fs0; end
            catch ME
                warning('Audio read failed on %s: %s',wavPaths{k},ME.message); continue;
            end

            % Parse transcript for surprisal
             % ----------------------------------------------------------------
    % Inside runAnalysis, for each file k:
    % ----------------------------------------------------------------

    % 1) Read and parse transcript once
    if hUseTranscript.Value
        try
            T = readtable(transcriptPaths{k});
            % total words
            wordCnt = height(T);

            % locate columns
            tcol = find(strcmpi(T.Properties.VariableNames,'Timecode'),1);
            scol = find(strcmpi(T.Properties.VariableNames,'Surprisal'),1);
            dcol = find(strcmpi(T.Properties.VariableNames,'DisfluencyType')| ...
                        strcmpi(T.Properties.VariableNames,'DysfluencyType'),1);

            if isempty(tcol) || isempty(scol) || isempty(dcol)
                error('Transcript must have Timecode, Surprisal, and DisfluencyType columns');
            end

            rawT    = T.(T.Properties.VariableNames{tcol});
            rawSurp = T.(T.Properties.VariableNames{scol});
            rawType = lower(string(T.(T.Properties.VariableNames{dcol})));

            % valid (non\x2010NaN) rows
            valid = ~isnan(rawT) & ~isnan(rawSurp) & rawT>=0;
            timesAll    = rawT(valid);
            surprisalAll= rawSurp(valid);
            typesAll    = rawType(valid);

            % stutter\x2010disfluencies only
            isSD = ismember(typesAll,["repetition","block","prolongation"]);
            stutTimes   = timesAll(isSD);
            stutSurp    = surprisalAll(isSD);

            % compute percent\x2010words stuttered correctly
            numSD = sum(isSD);
            pctS  = 100 * numSD / max(wordCnt,1);

        catch ME
            warning('Transcript parse failed: %s',ME.message);
            % fallback to no events
            wordCnt     = NaN;
            pctS        = NaN;
            stutTimes   = [];
            stutSurp    = [];
        end
    else
        wordCnt   = NaN;
        pctS      = NaN;
        stutTimes = [];
        stutSurp  = [];
    end

    % 2) Audio \x2192 action functional WITH only stutter\x2010events
    [S, costInst, t, cTerms] = computeActionFunctional(y, Fs, stutTimes, stutSurp);

    % 3) Summary metrics (after CFA)
    dur  = t(end);
    stdC = std(costInst);
    volC = std(costInst);
    rate = S / dur;
    perW = S / wordCnt;            % wordCnt from above
    AAI  = computeAdaptiveActionIndex(costInst,t);
    flu  = rate;

    % 4) Fill results
    results.File(k)        = string(name);
    results.Duration(k)    = dur;
    results.TotalAction(k) = S;
    results.ActPerSec(k)   = rate;
    results.ActPerWord(k)  = perW;
    results.StdCost(k)     = stdC;
    results.CostVol(k)     = volC;
    results.AAI(k)         = AAI;
    results.PercentStut(k) = pctS;
    results.Fluency(k)     = flu;
    results.Group(k)       = groups(k);

            % Store for plots
            tCell{k}=t; costInstCell{k}=costInst; costTermsCell{k}=cTerms;
            freezeDurs{k}=detectFreezes(costInst,Fs,params);
            disT{k}=timesAll; disTy{k}=cell(size(timesAll));

            % Plot trace
            if ~hDisablePlot.Value
                plot(hAxCost,t,costInst,'Color',palette.blue); hold(hAxCost,'on');
            end
        end

        hold(hAxCost,'off'); delete(pg);
        populateAndExportTable(uitCmp,results);

        % Save data
        dataStruct=struct('results',results,'tCell',{tCell},...
            'costInstCell',{costInstCell},'costTermsCell',{costTermsCell},...
            'freezeDurs',{freezeDurs},'fileNames',{fileNames},...
            'disfluencyTimesCell',{disT},'disfluencyTypesCell',{disTy},...
            'transcriptPaths',{transcriptPaths});
        fig.UserData=dataStruct;

        % Refresh & extra figures
        refreshAdvancedPlots();
        plotSmallMultiples();
        plotGroupMeanCostTrajectories();
        plotMeanCostTermTrajectories();

        % Re-enable UI
        hRun.Enable='on'; btnLoadWav.Enable='on';
        btnRemoveWav.Enable='on'; btnLoadTrans.Enable='on';
        btnRemoveTrans.Enable='on';
    end

    %% -------------------
    %% Nested Plot & Helper Functions
    %% -------------------

    function populateAndExportTable(uitCmp,results)
        numCols=varfun(@isnumeric,results,'OutputFormat','uniform');
        for c=find(numCols)
            results.(results.Properties.VariableNames{c})=round(results.(results.Properties.VariableNames{c}),3);
        end
        uitCmp.ColumnName=results.Properties.VariableNames;
        uitCmp.Data=results;
        ts=datestr(now,'yyyyMMdd_HHmm');
        def=sprintf('fluency_%s.csv',ts);
        [fn,p]=uiputfile(def,'Save results as');
        if isequal(fn,0), uialert(fig,'Export canceled','Export'); return; end
        writetable(results,fullfile(p,fn));
        uialert(fig,sprintf('Saved to:\n%s',fullfile(p,fn)),'Export');
    end

    function refreshAdvancedPlots()
        D=fig.UserData; tbl=D.results;
        % StdCost hist
        cla(hAxStationHist);
        histogram(hAxStationHist,tbl.StdCost,20,'Normalization','pdf','FaceAlpha',0.6);
        hold(hAxStationHist,'on');
        pd=fitdist(tbl.StdCost,'Kernel','Bandwidth',0.005);
        x=linspace(min(tbl.StdCost),max(tbl.StdCost),200);
        plot(hAxStationHist,x,pdf(pd,x),'r-','LineWidth',1.2);
        hold(hAxStationHist,'off');
        title(hAxStationHist,'StdCost','FontWeight','bold'); xlabel(hAxStationHist,'StdCost'); ylabel(hAxStationHist,'PDF'); grid(hAxStationHist,'on');
        % CostVol hist
        cla(hAxVolHist);
        histogram(hAxVolHist,tbl.CostVol,20,'Normalization','pdf','FaceAlpha',0.6);
        title(hAxVolHist,'CostVol','FontWeight','bold'); xlabel(hAxVolHist,'CostVol'); ylabel(hAxVolHist,'PDF'); grid(hAxVolHist,'on');
        % Freeze hist
        cla(hAxFreezeHist);
        allD=vertcat(D.freezeDurs{:});
        if ~isempty(allD), histogram(hAxFreezeHist,allD,'Normalization','pdf'); set(hAxFreezeHist,'XScale','log'); end
        title(hAxFreezeHist,'Freeze Durations','FontWeight','bold'); xlabel(hAxFreezeHist,'s'); ylabel(hAxFreezeHist,'PDF'); grid(hAxFreezeHist,'on');
        % Mean freeze by group
        cla(hAxFreezeBar);
        G=unique(tbl.Group,'stable'); m=zeros(size(G));
        for i=1:numel(G), d=vertcat(D.freezeDurs{tbl.Group==G(i)}); m(i)=mean(d,'omitnan'); end
        bar(hAxFreezeBar,m,'FaceColor',palette.freeze); xticks(hAxFreezeBar,1:numel(G)); xticklabels(hAxFreezeBar,cellstr(G)); xtickangle(hAxFreezeBar,45);
        title(hAxFreezeBar,'Mean Freeze','FontWeight','bold'); ylabel(hAxFreezeBar,'s'); grid(hAxFreezeBar,'on');
        % Group errorbars & scatter & cost-terms
        plotGroupErrorbar(hAxGroupTraj,categorical(tbl.Group),tbl.TotalAction); title(hAxGroupTraj,'TotalAction','FontWeight','bold');
        plotGroupErrorbar(hAxGroupAction,categorical(tbl.Group),tbl.ActPerSec); title(hAxGroupAction,'Act/sec','FontWeight','bold');
        plotGroupErrorbar(hAxGroupAAI,categorical(tbl.Group),tbl.AAI,'s-'); title(hAxGroupAAI,'AAI','FontWeight','bold');
        cla(hAxScatter); hold(hAxScatter,'on'); grid(hAxScatter,'on');
        cmap=lines(numel(G));
        for i=1:numel(G), idx=tbl.Group==G(i); scatter(hAxScatter,tbl.ActPerSec(idx),tbl.ActPerWord(idx),36,cmap(i,:),'filled','DisplayName',G(i)); end
        title(hAxScatter,'Act/sec vs Act/Word','FontWeight','bold'); xlabel(hAxScatter,'Act/sec'); ylabel(hAxScatter,'Act/Word'); legend(hAxScatter,'Location','best','Box','off'); hold(hAxScatter,'off');
        cla(hAxTermTraj);
        plotCostTermTrajectoriesOnAxes(hAxTermTraj,D,tbl.Group);
        title(hAxTermTraj,'Cost-Terms','FontWeight','bold'); xlabel(hAxTermTraj,'Time'); ylabel(hAxTermTraj,'Cost'); grid(hAxTermTraj,'on');
    end

    function freezeDurs=detectFreezes(costInst,Fs,params)
        thresh=mean(costInst)*params.freezeFactor;
        mask=costInst>thresh;
        e=diff([0;mask;0]); s=find(e==1); f=find(e==-1)-1;
        durs=(f-s+1)/Fs;
        freezeDurs=durs(durs>=params.minFreezeDur);
    end

    function plotGroupErrorbar(ax,groups,vals,style)
        if nargin<4, style='o-'; end
        G=unique(groups,'stable'); nG=numel(G);
        m=arrayfun(@(g)mean(vals(groups==g),'omitnan'),G);
        sem=arrayfun(@(g)std(vals(groups==g),'omitnan')/sqrt(sum(groups==g)),G);
        cols=lines(nG); cla(ax); hold(ax,'on'); grid(ax,'on');
        for i=1:nG
            errorbar(ax,i,m(i),sem(i),'LineStyle','none','CapSize',12,'Color',cols(i,:)); plot(ax,i,m(i),style,'MarkerEdgeColor',cols(i,:),'MarkerFaceColor','w','LineWidth',1.5);
        end
        xlim(ax,[0.5 nG+0.5]); ax.XTick=1:nG; ax.XTickLabel=cellstr(G); xtickangle(ax,45);
        xlabel(ax,'Group'); ylabel(ax,ax.YLabel.String); hold(ax,'off');
    end

    function plotCostTermTrajectoriesOnAxes(ax,D,~)
        nF=numel(D.tCell); nPts=params.nInterp; tnorm=linspace(0,1,nPts);
        CTall=nan(nF,nPts,6);
        for k=1:nF
            Tn=D.tCell{k}/D.tCell{k}(end);
            for c=1:6
                raw=D.costTermsCell{k}.(['C',num2str(c)]);
                CTall(k,:,c)=interp1(Tn,raw,tnorm,'linear',0);
            end
        end
        cla(ax); hold(ax,'on'); grid(ax,'on');
        cols=lines(6);
        for c=1:6
            mu=mean(CTall(:,:,c),1);
            plot(ax,D.tCell{1}(end)*tnorm,mu,'Color',cols(c,:),'LineWidth',1.5,'DisplayName',sprintf('C%d',c));
        end
        legend(ax,'Location','best','Box','off'); hold(ax,'off');
    end

    function plotSmallMultiples()
        D=fig.UserData; tbl=D.results; if isempty(tbl), return; end
        nPts=params.nInterp; tnorm=linspace(0,1,nPts); tMax=min(cellfun(@(v)v(end),D.tCell)); tAx=tnorm*tMax;
        CTall=nan(height(tbl),nPts,6);
        for k=1:height(tbl)
            Tn=D.tCell{k}/D.tCell{k}(end);
            for c=1:6
                raw=D.costTermsCell{k}.(['C',num2str(c)]);
                CTall(k,:,c)=interp1(Tn,raw,tnorm,'linear',0);
            end
        end
        G=unique(tbl.Group,'stable'); nG=numel(G); mu=zeros(nG,nPts,6);
        for gi=1:nG
            idx=tbl.Group==G(gi); mu(gi,:,:)=squeeze(mean(CTall(idx,:,:),1));
        end
        figCT=figure('Name','Mean Cost-Term by Group','Color','w');
        tlo=tiledlayout(figCT,3,2,'TileSpacing','compact','Padding','compact');
        cmap=lines(nG);
        for c=1:6
            ax=nexttile; hold(ax,'on'); grid(ax,'on');
            for gi=1:nG
                plot(ax,tAx,mu(gi,:,c),'Color',cmap(gi,:),'LineWidth',1.5,'DisplayName',G(gi));
            end
            if c==1, legend(ax,'Location','best','Box','off'); end
            title(ax,sprintf('C%d',c)); if any(c==[5,6]), xlabel(ax,'Time (s)'); else ax.XTickLabel=[]; end
            if any(mod(c-1,2)==0), ylabel(ax,'Cost'); end; xlim(ax,[0 tMax]); hold(ax,'off');
        end
    end

    function plotGroupMeanCostTrajectories()
        D=fig.UserData; tbl=D.results; if isempty(tbl), return; end
        G=unique(tbl.Group,'stable'); nG=numel(G);
        nPts=params.nInterp; tnorm=linspace(0,1,nPts);
        CIall=nan(height(tbl),nPts);
        for k=1:height(tbl)
            Tn=D.tCell{k}/D.tCell{k}(end);
            CIall(k,:)=interp1(Tn,D.costInstCell{k},tnorm,'linear',NaN);
        end
        muG=nan(nG,nPts);
        for gi=1:nG
            muG(gi,:)=mean(CIall(tbl.Group==G(gi),:),1,'omitnan');
        end
        figGM=figure('Name','Group Mean Cost Trajectories','Color','w');
        ax=axes(figGM); hold(ax,'on'); grid(ax,'on');
        cmap=lines(nG);
        for gi=1:nG
            plot(ax,tnorm,muG(gi,:),'Color',cmap(gi,:),'LineWidth',1.8,'DisplayName',G(gi));
        end
        xlabel(ax,'Normalized Time'); ylabel(ax,'Mean Cost');
        title(ax,'Group\x2010Mean Cost Trajectories'); legend(ax,'Location','best','Box','off'); hold(ax,'off');
    end

    function plotMeanCostTermTrajectories()
        D=fig.UserData; tbl=D.results; if isempty(tbl), return; end
        nPts=params.nInterp; tnorm=linspace(0,1,nPts); tMax=min(cellfun(@(v)v(end),D.tCell)); tAx=tnorm*tMax;
        CTall=nan(height(tbl),nPts,6);
        for k=1:height(tbl)
            Tn=D.tCell{k}/D.tCell{k}(end);
            for c=1:6
                raw=D.costTermsCell{k}.(['C',num2str(c)]);
                CTall(k,:,c)=interp1(Tn,raw,tnorm,'linear',0);
            end
        end
        mu=squeeze(mean(CTall,1));
        figMCT=figure('Name','Mean Cost-Term Trajectories','Color','w');
        ax=axes(figMCT); hold(ax,'on'); grid(ax,'on');
        cmap=lines(6);
        for c=1:6
            plot(ax,tAx,mu(:,c),'Color',cmap(c,:),'LineWidth',1.8,'DisplayName',sprintf('C%d',c));
        end
        xlabel(ax,'Time (s)'); ylabel(ax,'Mean Cost'); title(ax,'Grand-Mean Cost-Terms'); legend(ax,'Location','best','Box','off'); hold(ax,'off');
    end

    function onClose(src,~)
        sel=uiconfirm(src,'Close the GUI?','Confirm','Options',{'Yes','No'},'DefaultOption',2);
        if strcmp(sel,'Yes'), delete(src); end
    end

end
