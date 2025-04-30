%% BatchHelpers.m
% All helper functions for BatchAnalysisGUI

%––––––––––––––––––––––––––––––––––––––––––––––––––––––––––

function n = countFreezes(y,Fs,params,pred)
    [xH,~,~,~,tspan,~,~] = runStutterSimulation(y,Fs,params,pred);
    mask = getImprovedFreezeMask(tspan, xH(:,2), params.config.defaultFreezeThreshold, params.config.smoothingWindow, params.config.dtBase);
    n = sum(mask);
end

%––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
% 
% function T = loadAnnotationsExcel(excelFile,simDuration)
%     opts = detectImportOptions(excelFile);
%     T = readtable(excelFile,opts);
%     T.Properties.VariableNames = lower(T.Properties.VariableNames);
%     if ~ismember('predictability',T.Properties.VariableNames)
%         error('Excel must contain a ''predictability'' column.');
%     end
%     n = height(T);
%     if ~ismember('onset',T.Properties.VariableNames) || ~ismember('offset',T.Properties.VariableNames)
%         durW = simDuration/n;
%         T.onset  = (0:n-1)'*durW;
%         T.offset = (1:n)'*durW;
%     end
% end

%––––––––––––––––––––––––––––––––––––––––––––––––––––––––––

function ann = generateDefaultAnnotations(simDuration)
    txt = lower(regexprep('Alice was beginning to get very tired','[^a-z ]',''));
    words = split(txt); words = words(~cellfun('isempty',words));
    Nw = numel(words);
    probs = linspace(0.001,0.1,Nw); info = -log2(probs)';
    durW = simDuration/Nw;
    on  = (0:Nw-1)'*durW;
    off = (1:Nw)'*durW;
    ann = [num2cell(on),num2cell(off),words,num2cell(info)];
end

%––––––––––––––––––––––––––––––––––––––––––––––––––––––––––

function mP = getProfileParams()
    mP.freezeThreshold = 1e-3;
    mP.sigma_a = 0.1; 
    mP.sigma_s = 0.1;
    mP.mu1_prior = 1.0;
    mP.sigma_1 = 0.1;
    mP.sigma_2 = 1.0;
    mP.k = 0.8;
    mP.y_a = 1.0;
    mP.y_s = 1.0;
end

%––––––––––––––––––––––––––––––––––––––––––––––––––––––––––

function color = updateSummaryColors(tbl, indices)
    row = indices(1);
    col = indices(2);
    color = [1 1 1]; % default white
    if col == 1
        try
            result = tbl.Data{row,6};
            if strcmp(result,'✅')
                color = [0.85 1.0 0.85]; % light green
            elseif strcmp(result,'❌')
                color = [1.0 0.85 0.85]; % light red
            end
        catch
            color = [1 1 1];
        end
    end
end

%––––––––––––––––––––––––––––––––––––––––––––––––––––––––––

function mask = getImprovedFreezeMask(tspan,signal,th,sw,~)
    sm = movmean(signal,sw);
    mask = sm < th;
end

%––––––––––––––––––––––––––––––––––––––––––––––––––––––––––

function v = ternary(cond,tVal,fVal)
    if cond
        v = tVal;
    else
        v = fVal;
    end
end

function color = updateSummaryColors(tbl, indices)
    % Updates cell background color based on "Result" column (column 6)
    row = indices(1);
    col = indices(2);
    color = [1 1 1]; % default white background
    
    if col == 6  % Only color the "Result" column
        try
            result = tbl.Data{row,6};
            if contains(lower(result),'confirmed')
                color = [0.85 1.0 0.85]; % light green
            elseif contains(lower(result),'not confirmed')
                color = [1.0 0.85 0.85]; % light red
            end
        catch
            color = [1 1 1];
        end
    end
end

