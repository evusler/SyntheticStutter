function runProfileSweep(figHandle)
%RUNPROFILESWEEP   Sweep profiles & report extended metrics, standalone version.

  % Guard: must have run simulation first
    if nargin<1 || isempty(figHandle) || ...
       ~isfield(figHandle.UserData,'simulationResults') || ...
       isempty(figHandle.UserData.simulationResults)
      errordlg( ...
        'Please load an audio file and run the simulation before using this sweep.', ...
        'Sweep Error' ...
      );
      return;
    end

    % Ensure we have a base simulation to copy constants/config
    if ~isfield(figHandle.UserData,'simulationResults')
        simulationCallback(figHandle);
    end

    % Unpack
    sim      = figHandle.UserData.simulationResults;
    C0       = sim.constants;
    cfg0     = sim.config;
    audio    = sim.originalAudio;
    Fs       = sim.Fs;
P = sim.P;

    profiles = {'Non-stuttering','Mild stuttering','Severe stuttering','Cluttering'};
    n        = numel(profiles);

    % Preallocate metrics
    freezePct     = zeros(1,n);
    freezeCount   = zeros(1,n);
    meanDuration  = zeros(1,n);

    for i = 1:n
        % — Get the default profile params —
        [mp, msg] = getProfileParams(profiles{i});
        % Always use a canonical freeze threshold
        mp.freezeThreshold = 1e-3;

        % Override sensory precision per profile
        switch profiles{i}
          case 'Non-stuttering'
            mp.sigmaA = 1.0; mp.sigmaS = 1.0;
          case 'Mild stuttering'
            mp.sigmaA = 0.5; mp.sigmaS = 0.5;
          case 'Severe stuttering'
            mp.sigmaA = 0.1; mp.sigmaS = 0.1;
          case 'Cluttering'
            mp.sigmaA = 2.0; mp.sigmaS = 2.0;
        end

        % Pack params and run sim
        params.constants   = C0;
        params.config      = cfg0;
        params.modelParams = mp;
        [xH,~,~,~,tspan,~,freezeMask] = runStutterSimulation(audio, Fs, params, P);

        % Compute metrics
        dt = mean(diff(tspan));
        freezePct(i)    = mean(freezeMask)*100;
        CC              = bwconncomp(freezeMask);
        freezeCount(i)  = CC.NumObjects;
        if CC.NumObjects>0
            areas          = [regionprops(CC,'Area').Area];
            meanDuration(i)= mean(areas)*dt;
        else
            meanDuration(i)= 0;
        end
    end

    % Plot % time frozen
    figure('Color','w');
    cats = categorical(profiles,profiles,'Ordinal',true);
    bar(cats,freezePct,'FaceColor',[0.91 0.41 0.17],'EdgeColor','none');
    ylabel('% Time Frozen','FontWeight','bold');
    title('Profile Sweep: % Time Frozen vs. Profile','FontWeight','bold');
    ylim([0 max(freezePct)*1.1]);
    text(1:n, freezePct+eps, ...
         arrayfun(@(x) sprintf('%.1f%%',x),freezePct,'uni',0), ...
         'HorizontalAlignment','center','FontWeight','bold');

    % Hypothesis: freezing should rise Non→Mild→Severe then drop for Cluttering
    cond = (freezePct(2)>freezePct(1)) && (freezePct(3)>freezePct(2)) && (freezePct(3)>freezePct(4));
    if cond
        resultText = 'Confirmed';
    else
        resultText = 'Not Confirmed';
    end

    % Build summary row (M4=Mavg count, M5=Mavg duration)
    M1 = freezePct(1);
    M2 = freezePct(2);
    M3 = freezePct(3);
    M4 = mean(freezeCount);
    M5 = mean(meanDuration);
    newRow = { ...
      'Profile Sweep', ...
      'Non<Mild<Severe; Clutter<Severe', ...
      M1, M2, M3, M4, M5, resultText ...
    };

    % Append to GUI table
    hTable = findobj(figHandle,'Tag','summaryTable');
    data   = get(hTable,'Data');
    if isempty(data), data = {}; end
    updated = [data; newRow];
    figHandle.UserData.summaryTableData = updated;
    set(hTable,'Data',updated);
end
