function [raw, results, corrs] = runSweeps(fig, audioFiles, annotFiles, cfg, sweeps)
    constants = fig.UserData.constants;
    N = numel(audioFiles);

    % Correct initialization
    raw(N,1) = struct('Attention', [], 'Rate', [], 'PrecRate', [], ...
                      'PlanH', [], 'Precision', [], 'RepeatRuns', [], ...
                      'PredictX2', [], 'PredictPred', []);

    results = nan(N,7);
    corrs   = nan(N,7);
    dlg = uiprogressdlg(fig,'Title','Batch Progress','Message','Starting...','Cancelable','off');

    for i = 1:N
        dlg.Value   = (i-1)/N;
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
            ann = generateDefaultAnnotations(numel(y)/Fs);
            pred = cell2mat(ann(:,4));
            on = cell2mat(ann(:,1));
            off = cell2mat(ann(:,2));
        end

        params.modelParams = struct('freezeThreshold',1e-3,'sigma_a',0.1,'sigma_s',0.1, ...
                                    'mu1_prior',1.0,'sigma_1',0.1,'sigma_2',1.0,'k',0.8,'y_a',1.0,'y_s',1.0);
        params.config = cfg;
        params.speechRate = 1.0;
        params.constants = constants;

        % Attention Sweep
        A = sweeps.Attention;
        tmp = zeros(size(A));
        for k=1:numel(A)
            params.config.defaultAttentionLevel = A(k);
            tmp(k) = countFreezes(y,Fs,params,pred);
        end
        results(i,1) = mean(tmp);
        corrs(i,1) = corr(A',tmp','Rows','complete');
        raw(i).Attention = tmp;

        % Speech Rate Sweep
        R = sweeps.Rate;
        tmp = zeros(size(R));
        for k=1:numel(R)
            params.speechRate = R(k);
            tmp(k) = countFreezes(y,Fs,params,pred);
        end
        results(i,2) = mean(tmp);
        corrs(i,2) = corr(R',tmp','Rows','complete');
        raw(i).Rate = tmp;

        % Precision × Rate Sweep
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

        % Planning Horizon Sweep
        H = sweeps.PlanH;
        tmp = zeros(size(H));
        for k=1:numel(H)
            params.config.planningHorizon = H(k);
            tmp(k) = countFreezes(y,Fs,params,pred);
        end
        results(i,4) = mean(tmp);
        corrs(i,4) = corr(H',tmp','Rows','complete');
        raw(i).PlanH = tmp;

        % Sensory Precision Sweep
        tmp = zeros(size(P_));
        for k=1:numel(P_)
            params.modelParams.sigma_a = P_(k);
            params.modelParams.sigma_s = P_(k);
            tmp(k) = countFreezes(y,Fs,params,pred);
        end
        results(i,5) = mean(tmp);
        corrs(i,5) = corr(P_',tmp','Rows','complete');
        raw(i).Precision = tmp;

        % Repeat Adaptation
       counts = zeros(10,1);
for r = 1:10
    counts(r) = countFreezes(y,Fs,params,pred);
end
results(i,6) = counts(end) - counts(1);
raw(i).RepeatRuns = counts;

        % Predictability correlation
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

% >>> Fix sizes before correlation:
minLen = min(length(xH(:,2)), length(predTime));
predTime = predTime(1:minLen);
x2 = xH(1:minLen,2);

corrs(i,7) = corr(x2, predTime, 'Rows', 'complete');
    end
    delete(dlg);

    % Update Summary Table
    plotBatchFigures(raw, sweeps, N);
end

fig.UserData.tblSummary.Data = [tests(:), meanStr(:), stdStr(:), paramsStr(:), corrStr(:), flags(:)];
