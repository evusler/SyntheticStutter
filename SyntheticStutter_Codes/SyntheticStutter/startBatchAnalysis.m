function startBatchAnalysis()
% STARTBATCHANALYSIS - Easy launcher for BatchAnalysisGUI
%
%  Usage:
%     >> startBatchAnalysis

    % Step 1. Add the BatchAnalysisGUI folder to MATLAB path
    guiFolder = fileparts(mfilename('fullpath'));
    addpath(guiFolder);

    % Step 2. Open the GUI
    BatchAnalysisGUI();
end
