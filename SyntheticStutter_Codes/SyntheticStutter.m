function SyntheticStutter()
%% SyntheticStutter: GUI for hierarchical predictive‐processing simulation of speech fluency.

   %% — Add helper functions to path —
    helperPath = fullfile(pwd, 'helpers');
    if exist(helperPath,'dir')
        addpath(helperPath);
    else
        warning('Helper folder not found: %s', helperPath);
    end

    %% — Constants & Configuration —
    constants = struct( ...
      'rampDurationFactor',     0.05, ...
      'overshootFactor',        1.2,  ...
      'minFreezeDuration',      0.005,...
      'waitbarPause',           0.2,  ...
      'defaultFreezeThreshold', 1e-3, ...
      'smoothingWindow',        30,   ...
      'dtBase',                 0.001,...
      'attenuationOffset',      0.05, ...
      'defaultAttentionLevel',  2.0,  ...
      'eps',                    1e-3, ...
      'noise',     struct('amp',0.10), ...
      'audGain',                1.0,  ...
      'lambdaU',                1.0   ...
    );
    constants.noiseAmplitude = constants.noise.amp;
    constants.attenuationAtt = constants.attenuationOffset;

    config = struct( ...
      'debug',                 true,  ...
      'dtBase',                constants.dtBase, ...
      'smoothingWindow',       constants.smoothingWindow, ...
      'defaultFreezeThreshold',constants.defaultFreezeThreshold, ...
      'useForcedAlignment',    false, ...
      'defaultAttentionLevel', constants.defaultAttentionLevel ...
    );

    guiConfig = struct( ...
      'bgColor',    [0.95,0.95,0.95], ...
      'panelColor', [0.90,0.90,0.90], ...
      'textColor',  [0,0,0], ...
      'accentColor',[0.90,0.40,0.20] ...
    );

   %% — Create Figure & Initialize UserData —
    fig = figure( ...
      'Name','SyntheticStutterGUI', ...
      'Units','normalized','Position',[0.02,0.02,0.96,0.96], ...
      'Color',guiConfig.bgColor,'MenuBar','none','NumberTitle','off' ...
    );
    set(fig,'DefaultUicontrolFontName','Arial','DefaultUicontrolFontSize',12);

    fig.UserData.constants       = constants;
    fig.UserData.config          = config;
    fig.UserData.guiConfig       = guiConfig;
    fig.UserData.audioFilePath   = '';
    fig.UserData.audioData       = [];
    fig.UserData.Fs              = [];
    fig.UserData.transcriptTable = [];
    fig.UserData.annotations     = {};
    fig.UserData.wordLabels      = {};
    fig.UserData.wordOnsets      = [];
    fig.UserData.summaryTableData= {};

    %% — Build GUI Panels & Controls —
    handles = struct();

    % Audio panel
    handles.audioPanel = uipanel(fig, 'Title','Audio File', ...
      'Units','normalized','Position',[0.02,0.85,0.30,0.08], ...
      'BackgroundColor',guiConfig.panelColor);
    handles.btnSelectAudio = uicontrol(handles.audioPanel, ...
      'Style','pushbutton','String','Select Audio File', ...
      'Units','normalized','Position',[0.05,0.55,0.45,0.35], ...
      'BackgroundColor',guiConfig.accentColor,'ForegroundColor',[1 1 1], ...
      'Callback',@selectAudio);
    handles.btnPlayAudio = uicontrol(handles.audioPanel, ...
      'Style','pushbutton','String','Play Original Audio', ...
      'Units','normalized','Position',[0.52,0.55,0.45,0.35], ...
      'BackgroundColor',guiConfig.accentColor,'ForegroundColor',[1 1 1], ...
      'Callback',@playOriginalAudio);
    handles.lblAudioFile = uicontrol(handles.audioPanel, ...
      'Style','text','Tag','lblAudioFile','String','No file selected', ...
      'Units','normalized','Position',[0.05,0.10,0.90,0.35], ...
      'BackgroundColor',guiConfig.panelColor,'HorizontalAlignment','left');

    % Alignment panel
    handles.alignmentPanel = uipanel(fig, 'Title','Alignment Options', ...
      'Units','normalized','Position',[0.02,0.70,0.30,0.12], ...
      'BackgroundColor',guiConfig.panelColor);
    handles.cbForcedAlignment = uicontrol(handles.alignmentPanel, ...
      'Style','checkbox','String','Use Forced Alignment (forthcoming)', ...
      'Units','normalized','Position',[0.05,0.65,0.90,0.25], ...
      'Value',config.useForcedAlignment,'Callback',@toggleForcedAlignment);
    handles.btnSelectTranscript = uicontrol(handles.alignmentPanel, ...
      'Style','pushbutton','String','Select Transcript', ...
      'Units','normalized','Position',[0.05,0.35,0.90,0.25], ...
      'BackgroundColor',guiConfig.accentColor,'ForegroundColor',[1 1 1], ...
      'Callback',@selectTranscript);
    handles.lblTranscript = uicontrol(handles.alignmentPanel, ...
      'Style','text','Tag','lblTranscript','String','No transcript uploaded', ...
      'Units','normalized','Position',[0.05,0.05,0.90,0.25], ...
      'BackgroundColor',guiConfig.panelColor,'HorizontalAlignment','left');

    % Attention panel
    handles.attentionPanel = uipanel(fig, 'Title','Attention Level', ...
      'Units','normalized','Position',[0.02,0.58,0.30,0.08], ...
      'BackgroundColor',guiConfig.panelColor,'HighlightColor',guiConfig.accentColor);
    uicontrol(handles.attentionPanel, ...
      'Style','text','String','Attention Level:', ...
      'Units','normalized','Position',[0.05,0.60,0.50,0.30], ...
      'BackgroundColor',guiConfig.panelColor,'FontWeight','bold');
    handles.slAttention = uicontrol(handles.attentionPanel, ...
      'Style','slider','Min',0.5,'Max',10, ...
      'Value',constants.defaultAttentionLevel, ...
      'Units','normalized','Position',[0.05,0.15,0.65,0.30], ...
      'Callback',@updateAttentionLabel);
    handles.attentionValue = uicontrol(handles.attentionPanel, ...
      'Style','text','Tag','slAttentionVal', ...
      'String',sprintf('%.2f',constants.defaultAttentionLevel), ...
      'Units','normalized','Position',[0.75,0.15,0.20,0.30], ...
      'BackgroundColor',guiConfig.panelColor,'FontWeight','bold');

    % Speech Settings panel
    handles.speechPanel = uipanel(fig, 'Title','Speech Settings', ...
      'Units','normalized','Position',[0.02,0.46,0.30,0.08], ...
      'BackgroundColor',guiConfig.panelColor);
    uicontrol(handles.speechPanel, ...
      'Style','text','String','Speech Rate:', ...
      'Units','normalized','Position',[0.05,0.55,0.30,0.35], ...
      'BackgroundColor',guiConfig.panelColor);
    handles.editSpeechRate = uicontrol(handles.speechPanel, ...
      'Style','edit','String','1.0', ...
      'Units','normalized','Position',[0.40,0.55,0.45,0.35]);

        % Model Parameters panel
    handles.modelPanel = uipanel(fig, 'Title','Model Parameters', ...
      'Units','normalized','Position',[0.02,0.12,0.30,0.30], ...
      'BackgroundColor',guiConfig.panelColor,'HighlightColor',guiConfig.accentColor);

    % Subtitle: variance vs precision
    uicontrol(handles.modelPanel,'Style','text', ...
      'String','Variance σ ', ...
      'Units','normalized','Position',[0.05,0.92,0.90,0.05], ...
      'BackgroundColor',guiConfig.panelColor, ...
      'FontAngle','italic','FontSize',10,'HorizontalAlignment','center');

    % Now list 8 parameters, 4 rows x 2 cols
    paramInfo = { ...
      'Coupling Factor (k):',           'editK',        '0.8'; 
      'Syllable Scale (yₛ):',           'editYs',       '1.0';
      'Articulatory Variance (σ₂):',    'editSigma2',   '1.0';
      'Somatosensory Variance (σₛ):',   'editSigmaS',   '0.5';
      'Cognitive Prior (x₁ᵖ):',         'editX1Prior',  '1.0';
      'Cognitive Variance (σ₁):',       'editSigma1',   '0.1';
      'Auditory Scale (yₐ):',           'editYa',       '1.0';
      'Auditory Variance (σₐ):',        'editSigmaA',   '0.6' ...
    };

    nRows = 4; 
    nCols = 2;
    pad   = 0.05;
    cellW = (1-2*pad)/nCols; 
    cellH = (1-2*pad)/nRows;
    for idx = 1:size(paramInfo,1)
        row = ceil(idx/nCols)-1;
        col = mod(idx-1,nCols);
        x0  = pad + col*cellW;
        y0  = 0.85 - row*cellH;    
        lblW = 0.6*cellW; 
        lblH = 0.4*cellH;
        edtW = 0.35*cellW; 
        edtH = lblH;

        uicontrol(handles.modelPanel,'Style','text', ...
            'String',paramInfo{idx,1}, ...
            'Units','normalized','Position',[x0,y0,lblW,lblH], ...
            'BackgroundColor',guiConfig.panelColor, ...
            'HorizontalAlignment','right','FontWeight','bold');

        handles.(paramInfo{idx,2}) = uicontrol(handles.modelPanel,'Style','edit', ...
            'String',paramInfo{idx,3}, ...
            'Units','normalized','Position',[x0+lblW+0.02,y0,edtW,edtH]);
    end

     % Advanced Parameters panel
    handles.advancedPanel = uipanel(fig, 'Title','Advanced Parameters', ...
      'Units','normalized','Position',[0.35,0.70,0.30,0.25], ...
      'BackgroundColor',guiConfig.panelColor,'HighlightColor',guiConfig.accentColor);

    advSpecs = { ...
      'Eta K',              'slider','hEtaK',            0.001, 1,   0.1; 
      'Planning Horizon',   'slider','hPlanningHorizon', 10,    100,  50; 
      'Eta Word',           'slider','hEtaWord',        0.001, 1,   0.1; 
      'Surprisal Exponent', 'slider','hSurprisalExponent', 0, 3,   1; 
      'Freeze Threshold',   'edit',  'hFreezeThresh',       [],    [],   '0.001'};

    for i=1:size(advSpecs,1)
        y0    = 1 - pad - i*cellH + 0.02;
        label = advSpecs{i,1};
        ctype = advSpecs{i,2};
        tag   = advSpecs{i,3};
        mn    = advSpecs{i,4};
        mx    = advSpecs{i,5};
        df    = advSpecs{i,6};

        % label
        uicontrol(handles.advancedPanel,'Style','text', ...
            'String',label,'Units','normalized', ...
            'Position',[pad,y0+0.4*cellH,0.6,0.3*cellH], ...
            'BackgroundColor',guiConfig.panelColor,'FontWeight','bold');

        if strcmp(ctype,'slider')
            % slider + value display
            handles.(tag) = uicontrol(handles.advancedPanel,'Style','slider', ...
                'Tag',tag,'Min',mn,'Max',mx,'Value',df, ...
                'Units','normalized','Position',[pad,y0,0.7,0.3*cellH], ...
                'Callback',@updateSliderLabel);
            handles.([tag 'Val']) = uicontrol(handles.advancedPanel,'Style','text', ...
                'Tag',[tag 'Val'],'String',sprintf('%.2f',df), ...
                'Units','normalized','Position',[pad+0.72,y0,0.25,0.3*cellH], ...
                'BackgroundColor',guiConfig.panelColor);
        else
            % plain edit box
            handles.(tag) = uicontrol(handles.advancedPanel,'Style','edit', ...
                'Tag',tag,'String',df, ...
                'Units','normalized','Position',[pad,y0,0.7,0.3*cellH]);
        end
    end

      % Quick Information panel
    handles.infoPanel = uipanel(fig, 'Title','Quick Information', ...
      'Units','normalized','Position',[0.35,0.12,0.30,0.55], ...
      'BackgroundColor',guiConfig.panelColor,'HighlightColor',guiConfig.accentColor);
    
 infoLines = {
'=== USAGE GUIDE: SYNTHETIC STUTTER GUI ==='
''
'=== AUDIO & INPUT ==='
'Select Audio File – Load a speech sample in WAV, MP3, or FLAC format. This is the primary simulation input.'
'Load Transcript – Optional. Upload .txt or .xls/.xlsx for forced-alignment. Enables word-level predictability-based analysis.'
''
'=== MODEL CONTROLS ==='
'Speech Rate – Playback speed multiplier (affects simulation timestep).'
'Elongation Factor – Stretches phoneme durations without altering overall speech rate.'
'Attention Level – Controls defaultAttentionLevel (scales sensitivity to prediction errors).'
'Freeze Threshold – Minimum x2 velocity for motor freeze detection.'
'Smoothing Window – Controls moving average window size for plots.'
'Reset to Default – Restores all simulation parameters to their default state.'
''
'=== AUDIO PANEL ==='
'Play Audio – Listen to the original input audio (pre-simulation).'
''
'=== SIMULATION ==='
'Run Simulation – Executes the predictive processing simulation, computes latent trajectories, freeze mask, free energy, and uncertainty.'
'Overview Plot – Displays waveform, spectrogram, and freeze mask.'
'Statistics Plot – Shows time series of x1, x2, free energy, and sensory precision.'
''
'=== TESTING PANEL (HYPOTHESIS SWEEPS) ==='
'Sweep Attention – Varies attention. Tests whether high error sensitivity leads to more disfluency.'
'Sweep Rate – Varies speech rate and observes change in freeze percentage.'
'Sweep Precision x Rate – Sweeps both noise factor and speech rate. Generates heatmap.'
'Sweep Planning Horizon – Sweeps the number of future steps considered. Hypothesis: freeze % follows a U-shaped curve.'
'Sweep Precision – Varies sensory variance (sigmaA and sigmaS). Tests whether increased sensory precision increases freezing.'
'Sweep Repetition – Repeats the same utterance 10 times to test for adaptation (decline in FE and freeze).'
'Sweep Predictability – Correlates word-level predictability with freeze occurrence.'
'Run All Tests – Executes all tests above and logs to summary table.'
'Write Results – Saves results from the Test Summary table to results/test_summary.csv.'
'Analyze Causal Loop – Performs lagged correlation/causal analysis between model variables (x2, FreeEnergy, Precision, Uncertainty, Freeze) within a ±0.5s window. Produces a directed graph with edge weights.'
''
'=== TEST SUMMARY TABLE COLUMNS ==='
'Test – Name of the hypothesis test.'
'Hypothesis – What the test is evaluating.'
'M1–M3 – Metric values (e.g., freeze % at low/med/high or slope/contrast values).'
'M4 – Mean number of freeze episodes or total freeze duration.'
'M5 – Mean free energy or freeze duration.'
'Result – Marked as "Confirmed" or "Not Confirmed".'
''
'=== ADVANCED PARAMETERS ==='
'Coupling (k) – Strength of feedback from latent to sensory states.'
'etaA – Learning rate for auditory model.'
'etaS – Learning rate for somatosensory model.'
'Planning Horizon – Number of future time steps considered during belief update.'
''
'=== TROUBLESHOOTING ==='
'If the GUI becomes unresponsive, use the Quit button and restart MATLAB.'
'If plots fail to display, check that simulation results are properly stored in figHandle.UserData.simulationResults.'
'For long audio (>30s), consider increasing dtBase or reducing smoothingWindow.'
''
'=== DOCUMENTATION & SUPPORT ==='
'Full documentation available in docs/README.md.'
'Bug reports and feature requests: dev-team@project.org.'
'License: MIT (see /LICENSE in the project root).'
''
'=== REQUIRED FILES (must be on MATLAB path) ==='
'SyntheticStutter63.m                Main GUI and logic'
'runStutterSimulation.m              Core simulation engine'
'plotDetailedSimulationResults.m     Plotting function for overview + stats'
'getParamsForTest.m                  Reads parameter state from GUI'
'runAttentionSweep.m                 Attention sweep test'
'runRateSweep.m                      Speech rate sweep'
'runPrecisionRateSweep.m             2D precision × rate sweep'
'runPlanningHorizonSweep.m           Planning horizon sweep'
'runPrecisionSweep.m                 Sensory precision sweep'
'runRepetitionSweep.m                Repetition (adaptation) sweep'
'runPredictabilitySweep.m            Predictability correlation test'
'analyzeCausalLoop.m'
};
handles.infoText = uicontrol(handles.infoPanel, ...
      'Style','edit','String',infoLines, ...
      'Units','normalized','Position',[0.02,0.02,0.96,0.96], ...
      'BackgroundColor',[1 1 1],'ForegroundColor',guiConfig.textColor, ...
      'HorizontalAlignment','left','Max',numel(infoLines),'Enable','inactive');

% Test Summary panel
handles.summaryPanel = uipanel(fig, 'Title','Test Summary', ...
  'Units','normalized','Position',[0.68,0.60,0.28,0.35], ...
  'BackgroundColor',guiConfig.panelColor);

handles.summaryTable = uitable(handles.summaryPanel, ...
  'Units','normalized', 'Position',[0,0,1,1], ...
  'Data',{}, ...
  'ColumnName',{'Test','Hypothesis','M1','M2','M3','M4','M5','Result'}, ...
  'ColumnWidth',{90,180,60,60,60,60,60,110}, ...
  'RowName',[], ...
  'ColumnEditable',false(1,8), ...
  'FontSize',10, ...
  'Tag','summaryTable');

    % Log panel
    handles.logPanel = uipanel(fig, 'Title','Log', ...
      'Units','normalized','Position',[0.68,0.32,0.28,0.25], ...
      'BackgroundColor',guiConfig.panelColor);
    handles.debugLog = uicontrol(handles.logPanel, ...
      'Style','edit', ...
      'Tag','debugLog', ...
      'Max',100,'Min',1, ...
      'Enable','inactive', ...
      'HorizontalAlignment','left', ...
      'Units','normalized','Position',[0,0,1,1], ...
      'BackgroundColor',[1 1 1], ...
      'FontName','Courier New', ...
      'FontSize',10, ...
      'String',{'Log:'});

    % Simulation Tests panel
    handles.testsPanel = uipanel(fig, 'Title','Simulation Tests', ...
      'Units','normalized','Position',[0.68,0.12,0.28,0.13], ...
      'BackgroundColor',guiConfig.panelColor,'Tag','testsPanel');

    fig.UserData.handles = handles;

    % Create the three test buttons
    createTestButtons(fig);

    % Bottom buttons panel
    bottomBtns = createBottomButtonsPanel(fig,guiConfig,config,handles);
    handles      = mergeHandles(handles,bottomBtns);
    fig.UserData.handles = handles;

    % ─── Unified Panel Styling ───────────────────────────────────────────
    panelNames = { ...
      'audioPanel','alignmentPanel','attentionPanel', ...
      'speechPanel','modelPanel','advancedPanel', ...
      'infoPanel','summaryPanel','logPanel','testsPanel' ...
    };
    for i = 1:numel(panelNames)
        p = handles.(panelNames{i});
        set(p, ...
            'BorderType',     'line', ...
            'BorderWidth',    2, ...
            'HighlightColor', guiConfig.accentColor, ...
            'ShadowColor',    guiConfig.accentColor * 0.7, ...
            'FontName',       'Arial', ...
            'FontSize',       12, ...
            'FontWeight',     'bold' ...
        );
    end
end  % end SyntheticStutter

%% ─── Local helper implementations ─────────────────────────────────────
function toggleForcedAlignment(src,~)
    fig = gcbf;
    fig.UserData.config.useForcedAlignment = src.Value;
end

function updateAttentionLabel(src,~)
    val = src.Value;
    % update the UI label
    lbl = findobj(src.Parent,'Tag','slAttentionVal');
    lbl.String = sprintf('%.2f', val);

    % store in both config *and* constants so the simfn actually sees it
    fig = gcbf;
    ud  = fig.UserData;
    ud.config.defaultAttentionLevel   = val;
    ud.constants.defaultAttentionLevel = val;
    fig.UserData = ud;
end

function updateSliderLabel(src,~)
    tagVal = [src.Tag 'Val'];
    % search entire GUI for that tag
    lbl = findobj(gcbf, 'Tag', tagVal);
    if isempty(lbl)
        % if not found, just skip (or log a warning)
        return;
    end
    lbl.String = sprintf('%.3g', src.Value);
end

function selectAudio(~,~)
    fig = gcbf;
    [file,path] = uigetfile({'*.wav;*.mp3;*.flac','Audio Files'});
    if isequal(file,0)
        logMessage('INFO','No audio file selected.');
        return;
    end
    fullPath = fullfile(path,file);
    try
        [y,Fs] = audioread(fullPath);
    catch ME
        errordlg(sprintf('Failed to read audio:\n%s',ME.message),'Audio Read Error');
        logMessage('ERROR',ME.message);
        return;
    end
    if size(y,2)>1, y = mean(y,2); end
    y = y / max(abs(y));  % normalize

    fig.UserData.audioData     = y;
    fig.UserData.Fs            = Fs;
    fig.UserData.audioFilePath = fullPath;
    set(findobj(fig,'Tag','lblAudioFile'),'String',file);
    logMessage('INFO',['Audio file loaded: ' fullPath]);

    createTestButtons(fig);
end

function playOriginalAudio(~,~)
    fig = gcbf; ud = fig.UserData;
    if isempty(ud.audioData)||isempty(ud.Fs)
        logMessage('ERROR','No audio loaded – select a file first.');
        return;
    end
    sound(ud.audioData,ud.Fs);
    logMessage('INFO','Playing original audio...');
end

% ── 1) selectTranscript.m ───────────────────────────────────────────────
function selectTranscript(~,~)
    fig = gcbf;
    [file,path] = uigetfile({'*.xls;*.xlsx','Transcript Files'});
    if isequal(file,0), return; end

    T = readtable(fullfile(path,file));

    % Predictabilities
    if ismember('Predictability', T.Properties.VariableNames)
        fig.UserData.annotations = T.Predictability;
    else
        error('Transcript must contain a Predictability column.');
    end

    % Word labels
    if ismember('Word', T.Properties.VariableNames)
        fig.UserData.wordLabels = table2cell(T(:, 'Word'));
    else
        fig.UserData.wordLabels = {};
    end

    % Onset times (seconds)
    if ismember('Onset', T.Properties.VariableNames)
        % assume Onset column is in seconds
        fig.UserData.wordOnsets = T.Onset;
    else
        fig.UserData.wordOnsets = [];
    end

    % GUI update & log
    set(findobj(fig,'Tag','lblTranscript'),'String',file);
    logMessage('INFO',['Transcript loaded: ' file]);
    createTestButtons(fig);
end

function createTestButtons(fig)
    % Get panel to add buttons to
    hPanel = fig.UserData.handles.testsPanel;
    delete(hPanel.Children);  % Clear previous buttons

    % 1) Button labels and corresponding callbacks
    names = {
      'Attention', ...
      'Rate', ...
      'Precision×Rate', ...
      'Planning Horizon', ...
      'Precision', ...
      'Repetition', ...
      'Predictability' ...
    };

    callbacks = {
      @(~,~) runAttentionSweep(fig), ...
      @(~,~) runRateSweep(fig), ...
      @(~,~) runPrecisionRateSweep(fig), ...
      @(~,~) runPlanningHorizonSweep(fig), ...
      @(~,~) runPrecisionSweep(fig), ...
      @(~,~) runRepetitionSweep(fig), ...
      @(~,~) runPredictabilitySweep(fig) ...
    };

    % 2) Define button colors (extend or truncate if needed)
    defaultCol = [0.9 0.9 0.9];  % fallback gray
    presetCols = [
        fig.UserData.guiConfig.accentColor;  % Stress
        0.8  0.9  1.0;  % Attention
        1.0  1.0  0.6;  % Rate
        0.85 0.70 1.0;  % Precision×Rate
        0.6  0.8  0.9;  % Planning Horizon
        0.9  0.8  1.0;  % Precision
        0.95 0.85 0.75; % Repetition
        1.0  0.9  0.8   % Predictability
    ];

    % Pad or trim colors if needed
    n = numel(names);
    if size(presetCols,1) < n
        cols = [presetCols; repmat(defaultCol, n - size(presetCols,1), 1)];
    else
        cols = presetCols(1:n,:);
    end

    % 3) Layout
    margin = 0.02;
    btnW   = (1 - 2*margin) / n;
    y0     = 0.05;
    hgt    = 0.90;

    % 4) Create buttons
    for k = 1:n
        xpos = margin + (k-1)*btnW;
        uicontrol( ...
            'Parent',         hPanel, ...
            'Style',          'pushbutton', ...
            'String',         names{k}, ...
            'Units',          'normalized', ...
            'Position',       [xpos, y0, btnW, hgt], ...
            'BackgroundColor',cols(k,:), ...
            'ForegroundColor',[0 0 0], ...
            'FontName',       'Arial', ...
            'FontSize',       11, ...
            'FontWeight',     'bold', ...
            'Callback',       callbacks{k} ...
        );
    end

    % 6) Save handles back
    fig.UserData.handles = fig.UserData.handles;
end

function bottomHandles = createBottomButtonsPanel(fig, guiConfig, config, handles)
    bottomPanel = uipanel(fig, ...
      'Units','normalized','Position',[0.02,0.00,0.96,0.08],...
      'BackgroundColor',guiConfig.bgColor,'BorderType','none');

    % 1) Updated labels: removed 'Inspect Correlations'
    labels = { ...
      'Run Simulation', ...
      'Gradient Descent', ...
      'Write Results', ...
      'Reset to Default', ...
      'Analyze Causal Loop', ...
      'Quit' ...
    };

    % 2) Callbacks must match labels
    callbacks = { ...
      @(~,~) simulationCallback(fig), ...
      @(~,~) gradientDescentCallback(fig), ...
      @(~,~) writeTestResultsToFile(fig), ...
      @(~,~) customReset(), ...
      @(~,~) runAutoFigureTest(), ...
      @(~,~) close(fig) ...
    };

    % 3) Color palette (one row per button)
    palette = [ ...
      0.67 0.87 0.90; ...  % Run Simulation
      0.80 0.70 0.90; ...  % Gradient Descent
      0.70 0.95 0.95; ...  % Write Results
      0.80 0.95 0.80; ...  % Reset to Default
      0.95 0.87 0.70; ...  % Analyze Causal Loop
      0.70 0.80 0.95       % Quit
    ];

    n     = numel(labels);
    margin = 0.01;                % 1% margin each side
    totalW = 1 - 2*margin;
    btnW   = totalW / n;
    xs     = margin + (0:(n-1))*btnW;
    h      = 0.80; y0 = 0.10;

    bottomHandles = struct();
    for i = 1:n
        btn = uicontrol(bottomPanel, ...
          'Style','pushbutton', ...
          'String', labels{i}, ...
          'Units','normalized', ...
          'Position', [xs(i), y0, btnW, h], ...
          'BackgroundColor', palette(i,:), ...
          'FontWeight','bold', ...
          'Callback', callbacks{i});
        % store handle if you need it later
        bottomHandles.(['btn_' matlab.lang.makeValidName(labels{i})]) = btn;
    end
end

function c = getBottomButtonColor(i)
    palette = [ ...
      0.67 0.87 0.90; ...
      0.80 0.70 0.90; ...
      0.70 0.95 0.95; ...
      0.80 0.95 0.80; ...
      0.95 0.80 0.80; ...
      0.95 0.87 0.70; ...
      0.70 0.80 0.95 ...
    ];
    c = palette(mod(i-1,size(palette,1))+1,:);
end

function customReset()
    % close current GUI
    f = gcbf;
    if ~isempty(f), close(f); end

    % restart using the correct entry‐point in SyntheticStutter63.m
    SyntheticStutter63();
end

% ── 2) simulationCallback ──────────────────────────────────────
function simulationCallback(figHandle)
%SIMULATIONCALLBACK   Run sim, then post‐process into multiple, human‐like blocks.

    %% 1) Unpack GUI state & inputs
    ud      = figHandle.UserData;
    audData = ud.audioData;
    Fs      = ud.Fs;
    P       = ud.annotations;
    if iscell(P), P = cell2mat(P); end

    %% 2) Ensure modelParams exist
    if ~isfield(ud,'modelParams') || isempty(ud.modelParams)
        [mpDefault,~]  = getProfileParams('non-stuttering');
        ud.modelParams = mpDefault;
    end

    %% 3) Tweak for multiple, longer freezes
    % (a) Moderate freeze‐threshold so not *everything* freezes
    ud.modelParams.freezeThreshold = 5e-3;

    % (b) Increase sensory precision slightly (optional)
    ud.modelParams.sigmaA = 0.05;
    ud.modelParams.sigmaS = 0.05;

    % (c) Light smoothing to preserve x₂ detail
    ud.config.smoothingWindow    = 10;  % ~10 ms
    ud.constants.smoothingWindow = 10;

    figHandle.UserData = ud;

    %% 4) Run the predictive‐processing simulation
    params.constants   = ud.constants;
    params.config      = ud.config;
    params.modelParams = ud.modelParams;
    [ xHist, U_hist, sigmaA_hist, stutAudio, ...
      tspan, FE_hist, rawMask ] = ...
        runStutterSimulation(audData, Fs, params, P);

    %% 5) Post‐process to get clean, separate blocks
    dt = mean(diff(tspan));

    % 5.1 Merge any tiny gaps <50 ms to avoid spurious splits
    gapDur = 0.050;                          % seconds
    gapWin = round(gapDur / dt);
    maskClosed = imclose(rawMask, ones(1,gapWin));

    % 5.2 Remove any events shorter than 150 ms
    minDur   = 0.150;                        % seconds
    minWin   = round(minDur / dt);
    cleanMask = bwareaopen(maskClosed, minWin);

    % 5.3 Identify the final blocks & their durations
    CC   = bwconncomp(cleanMask);
    durs = cellfun(@numel, CC.PixelIdxList) * dt;

    % Summaries
    nBlocks       = numel(durs);
    totalBlockTime= sum(durs);
    meanBlockDur  = mean(durs);
    freezePct     = totalBlockTime / (tspan(end)-tspan(1)) * 100;

    logMessage('INFO', sprintf( ...
      '→ %d blocks (≥%.0f ms), total %.1f ms', ...
       nBlocks, minDur*1e3, totalBlockTime*1e3));

    %% 6) Store results back into UserData
    simResults = struct( ...
      'xHist',xHist, ...
      'U_hist',U_hist, ...
      'sigmaA_hist',sigmaA_hist, ...
      'FE_hist',FE_hist, ...
      'rawMask',rawMask, ...
      'cleanMask',cleanMask, ...
      'tspan',tspan, ...
      'blockDurations',durs, ...
      'nBlocks',nBlocks, ...
      'totalBlockTime',totalBlockTime, ...
      'meanBlockDur',meanBlockDur, ...
      'freezePct',freezePct, ...
      'stutteredAudio',stutAudio, ...
      'originalAudio',audData, ...
      'Fs',Fs, ...
      'P',P, ...
      'constants',params.constants, ...
      'config',params.config, ...
      'modelParams',params.modelParams ...
    );
    figHandle.UserData.simulationResults = simResults;

    %% 7) (Re)plot if not in silent mode
    if ~isfield(ud,'silent') || ~ud.silent
        plotDetailedSimulationResults( ...
          audData, Fs, ...
          xHist, U_hist, sigmaA_hist, FE_hist, ...
          stutAudio, tspan, ...
          [], ud.wordLabels, ...
          params.config, params.modelParams, ...
          cleanMask );
    end
end

function writeTestResultsToFile(figHandle)
%WRITETESTRESULTSTOFILE  Export the GUI Test Summary table to CSV.
    % Find the table and pull its data
    hTable   = findobj(figHandle,'Tag','summaryTable');
    data     = get(hTable,'Data');
    colNames = hTable.ColumnName;

    % Ensure # of names matches # of columns
    nCols = size(data, 2);
    if numel(colNames) ~= nCols
        warning('writeTestResultsToFile:ColumnMismatch', ...
                'Table has %d columns but %d names; truncating names.', ...
                nCols, numel(colNames));
        colNames = colNames(1:nCols);
    end

    % Make valid field names and build table
    varNames = matlab.lang.makeValidName(colNames);
    T = cell2table(data, 'VariableNames', varNames);

    % Write out
    outdir = fullfile(pwd, 'results');
    if ~exist(outdir, 'dir'), mkdir(outdir); end
    writetable(T, fullfile(outdir, 'test_summary.csv'));

    logMessage('INFO', sprintf('Test results saved to %s', outdir));
end

function runAllTestsCallback(fig)
    if isempty(fig.UserData.audioData)
        errordlg('Please load an audio file before running tests','No Audio');
        return;
    end
    if isempty(fig.UserData.annotations)
        errordlg('Please upload a transcript before running tests','No Transcript');
        return;
    end

    simulationCallback(fig);

    tester = SyntheticStutterTests();
    results = tester.runAllTests(fig);

    fig.UserData.summaryTableData = results;
    set(findobj(fig,'Tag','summaryTable'),'Data',results);
    logMessage('INFO','All tests complete — summary table updated.');
end

function logMessage(level,message)
    ts    = datestr(now,'yyyy-mm-dd HH:MM:SS');
    entry = sprintf('%s [%s]: %s',ts,upper(level),message);
    fprintf('%s\n',entry);
    fig = gcbf; if isempty(fig), return; end
    hBox = findobj(fig,'Tag','debugLog');
    if isempty(hBox), return; end
    curr = hBox.String; if ischar(curr), curr={curr}; end
    curr{end+1} = entry;
    hBox.String = curr; hBox.Value = numel(curr);
end

function merged = mergeHandles(oldHandles,newHandles)
    merged = oldHandles;
    fnames = fieldnames(newHandles);
    for i=1:numel(fnames)
        merged.(fnames{i}) = newHandles.(fnames{i});
    end
end