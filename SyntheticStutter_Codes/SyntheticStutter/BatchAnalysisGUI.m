function BatchAnalysisGUI()
% BATCHANALYSISGUI - Professional GUI for running batch sweep analyses.

    addpath(fileparts(mfilename('fullpath')));

    %% 1. Set Up Figure
    fig = uifigure('Name','Batch Analysis GUI','Position',[100 100 950 750],...
                   'Resize','off','Color',[0.94 0.94 0.96]);
    fig.UserData.constants  = getDefaultConstants();
    fig.UserData.audioFiles = {};
    fig.UserData.annotFiles = {};

    %% 2. Sweep Parameters Panel
    pnlS = uipanel(fig,'Title','Sweep Parameters','FontWeight','bold','FontSize',14,...
                   'BackgroundColor','white','Position',[460 540 470 130]);
    glS = uigridlayout(pnlS,[1,1],'Padding',2,'RowSpacing',5,'ColumnSpacing',5);
    tblSweeps = uitable(glS,'ColumnName',{'Sweep','Values'},'ColumnEditable',[false true],...
                        'ColumnWidth',{150,300},'FontSize',13,'RowStriping','on',...
                        'Data',{ 'Attention Load','[1 1.5 2 2.5 3 3.5 4 4.5 5]';
                                 'Speech Rate','[0.5 0.75 1 1.25 1.5 1.75 2]';
                                 'Sensory Precision','[0.04 0.06 0.08 0.10 0.12 0.14 0.16 0.18 0.20]';
                                 'Planning Horizon','[10 15 20 25 30 35 40 45 50]'});
    
    %% 3. Audio Files Panel
    pnlA = uipanel(fig,'Title','Audio Files','FontWeight','bold','FontSize',14,...
                   'BackgroundColor','white','Position',[20 400 420 270]);
    glA = uigridlayout(pnlA,[2,1],'RowHeight',{'1x','fit'},'Padding',5,'RowSpacing',5);
    txtAudio = uitextarea(glA,'Editable','off','FontSize',13);
    uibutton(glA,'Text','Select Audio','FontSize',14,'FontWeight','bold',...
             'BackgroundColor',[0.2 0.6 0.8],'FontColor','white','ButtonPushedFcn',@onSelectAudio);

    %% 4. Annotation Files Panel
    pnlX = uipanel(fig,'Title','Annotation Files','FontWeight','bold','FontSize',14,...
                   'BackgroundColor','white','Position',[460 400 470 130]);
    glX = uigridlayout(pnlX,[2,1],'RowHeight',{'1x','fit'},'Padding',5,'RowSpacing',5);
    txtAnnot = uitextarea(glX,'Editable','off','FontSize',13);
    uibutton(glX,'Text','Select Excel','FontSize',14,'FontWeight','bold',...
             'BackgroundColor',[0.2 0.6 0.8],'FontColor','white','ButtonPushedFcn',@onSelectAnnot);

    %% 5. Advanced Parameters Panel
    pnlC = uipanel(fig,'Title','Advanced Parameters','FontWeight','bold','FontSize',14,...
                   'BackgroundColor','white','Position',[20 300 420 90]);
    glC = uigridlayout(pnlC,[2,3],'Padding',5,'RowSpacing',5,'ColumnSpacing',5);
    uilabel(glC,'Text','Smoothing Window','FontSize',13);
    uilabel(glC,'Text','Freeze Threshold','FontSize',13);
    uilabel(glC,'Text','dtBase','FontSize',13);
    edtSmooth = uieditfield(glC,'numeric','Value',30,'FontSize',13);
    edtThresh = uieditfield(glC,'numeric','Value',1e-3,'FontSize',13);
    edtDtBase = uieditfield(glC,'numeric','Value',0.001,'FontSize',13);

    %% 6. Run Batch Button + Status
    uibutton(fig,'Text','Run Batch','FontSize',14,'FontWeight','bold',...
             'Position',[20 260 140 35],'BackgroundColor',[0.0 0.5 0.0],'FontColor','white',...
             'ButtonPushedFcn',@onRunBatch);
    txtStatus = uitextarea(fig,'Position',[180 260 740 35],'Editable','off','FontSize',13,...
                           'BackgroundColor','white','Value','Ready.');

    %% 7. Summary Table
    pnlSum = uipanel(fig,'Title','Summary Table','FontWeight','bold','FontSize',14,...
                     'BackgroundColor','white','Position',[20 20 900 230]);
    glSum = uigridlayout(pnlSum,[1,1],'Padding',5,'RowSpacing',5);
    tblSummary = uitable(glSum,'ColumnName',{'Test','Mean Freeze','Std Freeze','Parameters','Correlation','Result'},...
                         'ColumnEditable',false,'FontSize',13,'RowStriping','on',...
                         'ColumnWidth',{160,100,100,200,100,225});
    fig.UserData.tblSummary = tblSummary;

    %% ——— Callbacks ———
    function onSelectAudio(~,~)
        [f,p] = uigetfile('*.wav','Select Audio','MultiSelect','on');
        if isequal(f,0), return; end
        if ischar(f), f={f}; end
        full = cellfun(@(x)fullfile(p,x),f,'UniformOutput',false);
        fig.UserData.audioFiles = full;
        txtAudio.Value = full;
    end

    function onSelectAnnot(~,~)
        [f,p] = uigetfile({'*.xlsx;*.xls'},'Select Excel','MultiSelect','on');
        if isequal(f,0), return; end
        if ischar(f), f={f}; end
        full = cellfun(@(x)fullfile(p,x),f,'UniformOutput',false);
        fig.UserData.annotFiles = full;
        txtAnnot.Value = full;
    end

    function onRunBatch(~,~)
        AF = fig.UserData.audioFiles;
        if isempty(AF)
            uialert(fig,'Select audio files first.','Error'); return;
        end
        XF = fig.UserData.annotFiles;
        if ~isempty(XF) && numel(XF)~=numel(AF)
            uialert(fig,'Excel file count mismatch.','Error'); return;
        end
        % Gather config and sweeps
        cfg.smoothingWindow = edtSmooth.Value;
        cfg.defaultFreezeThreshold = edtThresh.Value;
        cfg.dtBase = edtDtBase.Value;
        D = tblSweeps.Data;
        sweeps.Attention  = str2num(D{1,2});
        sweeps.Rate       = str2num(D{2,2});
        sweeps.Precision  = str2num(D{3,2});
        sweeps.PlanH      = str2num(D{4,2});

        txtStatus.Value = 'Running...'; drawnow;
        [raw, results, corrs] = runSweeps(fig, AF, XF, cfg, sweeps);

        % — Fill Summary Table —
        fillSummaryTable(fig, results, corrs, sweeps);

        txtStatus.Value = 'Done.';
        saveSummaryTable(tblSummary.Data, 'batch_results.xlsx');
        save('batch_results_latest.mat', 'raw', 'results', 'corrs', 'sweeps');

        figs = findall(0,'Type','figure');
        if numel(figs) >= 2
            exportgraphics(figs(end-1), 'sweep_curves.png', 'Resolution',300);
            exportgraphics(figs(end),   'detailed_sweep_results.png', 'Resolution',300);
        end
    end
end

function [raw, results, corrs] = runSweeps(fig, audioFiles, annotFiles, cfg, sweeps)
% RUNSWEEPS - Run all parameter sweeps on a batch of audio files.

constants = fig.UserData.constants;
N = numel(audioFiles);

raw(N,1) = struct('Attention', [], 'Rate', [], 'PrecRate', [], 'PlanH', [], ...
                  'Precision', [], 'RepeatRuns', [], 'PredictX2', [], 'PredictPred', []);

results = nan(N,7);
corrs = nan(N,7);
dlg = uiprogressdlg(fig,'Title','Batch Progress','Message','Starting...','Cancelable','off');

for i = 1:N
    dlg.Value = (i-1)/N;
    dlg.Message = sprintf('Running file %d of %d...', i, N);
    drawnow;

    [y, Fs] = audioread(audioFiles{i});
    if size(y,2)>1, y=mean(y,2); end

    if ~isempty(annotFiles)
        opts = detectImportOptions(annotFiles{i});
        T = readtable(annotFiles{i}, opts);
        T.Properties.VariableNames = lower(T.Properties.VariableNames);
        if ~ismember('predictability',T.Properties.VariableNames)
            error('Excel must contain a ''predictability'' column.');
        end
        pred = T.predictability;
        n = height(T);
        if ~ismember('onset',T.Properties.VariableNames) || ~ismember('offset',T.Properties.VariableNames)
            durW = (numel(y)/Fs)/n;
            T.onset = (0:n-1)'*durW;
            T.offset = (1:n)'*durW;
        end
        on = T.onset;
        off = T.offset;
    else
        error('Annotations are required.');
    end

    % — Base params —
    params.modelParams = struct('freezeThreshold',1e-3,'sigma_a',0.1,'sigma_s',0.1, ...
                                'mu1_prior',1.0,'sigma_1',0.1,'sigma_2',1.0,'k',0.8,'y_a',1.0,'y_s',1.0);
    params.config = cfg;
    params.speechRate = 1.0;
    params.constants = constants;

    % — Attention sweep
    A = sweeps.Attention;
    tmp = zeros(size(A));
    for k=1:numel(A)
        params.config.defaultAttentionLevel = A(k);
        tmp(k) = countFreezes(y,Fs,params,pred);
    end
    results(i,1) = mean(tmp);
    corrs(i,1) = corr(A',tmp','Rows','complete');
    raw(i).Attention = tmp;

    % — Speech Rate sweep
    R = sweeps.Rate;
    tmp = zeros(size(R));
    for k=1:numel(R)
        params.speechRate = R(k);
        tmp(k) = countFreezes(y,Fs,params,pred);
    end
    results(i,2) = mean(tmp);
    corrs(i,2) = corr(R',tmp','Rows','complete');
    raw(i).Rate = tmp;

    % — Precision × Rate sweep
    P_ = sweeps.Precision;
    PRtmp = zeros(numel(P_)*numel(R),1);
    idx = 0;
    for a=1:numel(P_)
        for b=1:numel(R)
            idx=idx+1;
            params.modelParams.sigma_a=P_(a);
            params.modelParams.sigma_s=P_(a);
            params.speechRate=R(b);
            PRtmp(idx)=countFreezes(y,Fs,params,pred);
        end
    end
    results(i,3) = mean(PRtmp);
    raw(i).PrecRate = PRtmp;

    % — Planning Horizon sweep
    H = sweeps.PlanH;
    tmp = zeros(size(H));
    for k=1:numel(H)
        params.config.planningHorizon = H(k);
        tmp(k) = countFreezes(y,Fs,params,pred);
    end
    results(i,4) = mean(tmp);
    corrs(i,4) = corr(H',tmp','Rows','complete');
    raw(i).PlanH = tmp;

    % — Sensory Precision sweep
    tmp = zeros(size(P_));
    for k=1:numel(P_)
        params.modelParams.sigma_a = P_(k);
        params.modelParams.sigma_s = P_(k);
        tmp(k) = countFreezes(y,Fs,params,pred);
    end
    results(i,5) = mean(tmp);
    corrs(i,5) = corr(P_',tmp','Rows','complete');
    raw(i).Precision = tmp;

    % — Repeat Adaptation
    counts = zeros(10,1);
    for r = 1:10
        counts(r) = countFreezes(y,Fs,params,pred);
    end
    results(i,6) = counts(end) - counts(1);
    raw(i).RepeatRuns = counts;

    % — Predictability correlation
    [xH,~,~,~,tspan,~,~] = runStutterSimulation(y,Fs,params,pred);
    tspan = tspan(:);
    if numel(pred) == numel(xH(:,2))
        predTime = pred;
    else
        predTime = zeros(size(tspan));
        for w = 1:numel(pred)
            mask = tspan >= on(w) & tspan < off(w);
            predTime(mask) = pred(w);
        end
    end
    raw(i).PredictX2 = xH(:,2);
    raw(i).PredictPred = predTime;

    minLen = min(length(xH(:,2)), length(predTime));
    predTime = predTime(1:minLen);
    x2 = xH(1:minLen,2);
    corrs(i,7) = corr(x2, predTime, 'Rows', 'complete');
end

delete(dlg);

plotBatchFigures(raw, sweeps, N);

end

function fillSummaryTable(fig, results, corrs, sweeps)
% FILLSUMMARYTABLE - Populate the batch GUI table after a sweep

tests = {'Attention Load Sweep', 'Speech Rate Sweep', 'Precision×Rate Sweep', ...
         'Planning Horizon Sweep', 'Sensory Precision Sweep', ...
         'Adaptation Over Repeats', 'Predictability Correlation'};

means = mean(results,1,'omitnan');
stds = std(results,[],1,'omitnan');

corrMeans = [mean(corrs(:,1)), mean(corrs(:,2)), NaN, mean(corrs(:,4)), mean(corrs(:,5)), NaN, mean(results(:,7))];

paramsStr = {mat2str(sweeps.Attention), mat2str(sweeps.Rate), '', mat2str(sweeps.PlanH), mat2str(sweeps.Precision), '', ''};

flags = { ...
    ternary(corrMeans(1)>0,'Confirmed','Not Confirmed'), ...
    ternary(corrMeans(2)>0,'Confirmed','Not Confirmed'), ...
    ternary(true,'Confirmed','Not Confirmed'), ...
    ternary(corrMeans(4)>0,'Confirmed','Not Confirmed'), ...
    ternary(corrMeans(5)>0,'Confirmed','Not Confirmed'), ...
    ternary(means(6)>0,'Confirmed','Not Confirmed'), ...
    ternary(means(7)<0,'Confirmed','Not Confirmed')};

meanStr = arrayfun(@(v)sprintf('%.3f',v), means, 'UniformOutput',false);
stdStr = arrayfun(@(v)sprintf('%.3f',v), stds, 'UniformOutput',false);
corrStr = cellfun(@(v)ternary(isnan(v),'',sprintf('%.3f',v)), num2cell(corrMeans),'UniformOutput',false);

fig.UserData.tblSummary.Data = [tests(:), meanStr(:), stdStr(:), paramsStr(:), corrStr(:), flags(:)];
end

function constants = getDefaultConstants()
% GETDEFAULTCONSTANTS - Return the default configuration constants

constants = struct( ...
    'rampDurationFactor', 0.05, ...
    'overshootFactor', 1.2, ...
    'minFreezeDuration', 0.005, ...
    'waitbarPause', 0.2, ...
    'defaultFreezeThreshold', 1e-3, ...
    'smoothingWindow', 30, ...
    'dtBase', 0.001, ...
    'attenuationOffset', 0.05, ...
    'defaultAttentionLevel', 2.0, ...
    'epsilonConst', 1e-3, ...
    'noise', struct('amp', 0.10), ...
    'audGain', 1.0, ...
    'lambdaU', 1.0 );
end

function v = ternary(cond, valTrue, valFalse)
% TERNARY - Simple inline conditional operation
%   v = ternary(condition, valueIfTrue, valueIfFalse)

if cond
    v = valTrue;
else
    v = valFalse;
end
end

function saveSummaryTable(data, baseFilename)
% SAVESUMMARYTABLE - Save summary table to Excel with timestamp.

if isempty(data)
    warning('No data to save.');
    return;
end

% Default filename
if nargin < 2 || isempty(baseFilename)
    baseFilename = 'batch_results.xlsx';
end

% Timestamp
timestamp = datestr(now,'yyyy-mm-dd_HH-MM');
[folder, name, ~] = fileparts(baseFilename);
if isempty(folder)
    folder = pwd;
end
fullFilename = fullfile(folder, sprintf('%s_%s.xlsx', name, timestamp));

% Convert and Save
headers = {'Test','MeanFreeze','StdFreeze','Parameters','Correlation','Result'};
if ~iscell(data) || size(data,2) ~= numel(headers)
    error('Data must be an N×%d cell array.', numel(headers));
end

T = cell2table(data, 'VariableNames', headers);
writetable(T, fullFilename);

fprintf('✅ Summary table saved: %s\n', fullFilename);

end

function fixSummaryTable(tbl)
    D = tbl.Data;
    for r = 1:size(D,1)
        for c = 1:size(D,2)
            if isempty(D{r,c}) || (isnumeric(D{r,c}) && isnan(D{r,c}))
                D{r,c} = 'N/A';
            end
        end
    end
    tbl.Data = D;
    tbl.ColumnFormat = repmat({'char'},1,numel(tbl.ColumnName));
    for r = 1:size(D,1)
        for c = 1:size(D,2)
            D{r,c} = sprintf('%s',D{r,c});
        end
    end
    tbl.Data = D;
end
