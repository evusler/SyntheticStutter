function [xHist, U_hist, sigmaA_hist, stutteredAudio, tspan, FE_hist, freezeMask] = runStutterSimulation(audData, Fs, params, P)
%RUNSTUTTERSIMULATION  Two‐state predictive‐processing stutter sim (no x2 noise).
%   [xHist,U_hist,sigmaA_hist,stutteredAudio,tspan,FE_hist,freezeMask] =
%       runStutterSimulation(audData, Fs, params, P)
%
%   Inputs:
%     audData        – vector of audio samples
%     Fs             – sampling rate
%     params         – struct with fields .constants, .config, .modelParams
%     P              – vector of word‐predictability annotations
%
%   Outputs:
%     xHist          – [nSteps×2] state history (x1,x2)
%     U_hist         – [nSteps×1] word‐level uncertainty
%     sigmaA_hist    – [nSteps×1] precision (=1/uncertainty)
%     stutteredAudio – audio after applying freezes
%     tspan          – [1×nSteps] time vector
%     FE_hist        – [nSteps×1] free energy time course
%     freezeMask     – [nSteps×1] logical mask of freeze‐moments

    %% —— DEBUG DUMP —— 
    fprintf('>>> runStutterSimulation parameters:\n');
    fprintf('    noise.amp        = %.3g\n', params.constants.noise.amp);
    fprintf('    freezeThreshold  = %.3g\n\n', params.modelParams.freezeThreshold);

    %% Unpack
    C   = params.constants;    % dtBase, smoothingWindow, eps, noiseAmplitude, etc.
    cfg = params.config;       % dtBase, smoothingWindow, defaultFreezeThreshold, etc.
    mp  = params.modelParams;  % xp1, k, sigma1, sigma2, freezeThreshold, surprisalImpact

    %% Time step & learning rate
    dt = cfg.dtBase;
    if isfield(cfg,'learningRate')
        lr = cfg.learningRate;
    else
        lr = 0.01;
    end

    %% Noise amplitudes
    %cogNoise   = C.eps;              % small noise for x1
    cogNoise = C.epsilonConst;  % small noise for x1
    % motorNoise = C.noiseAmplitude; % removed: no noise on x2

    %% Time vector
    Nsamples = numel(audData);
    T_end    = (Nsamples-1)/Fs;
    tspan    = 0:dt:T_end;
    nSteps   = numel(tspan);

    %% Word‐level annotations
    P      = P(:);
    Nw     = numel(P);
    segDur = T_end / max(Nw,1);

    %% Preallocate & seed x1
    xHist        = zeros(nSteps,2);
    if isfield(mp,'xp1')
        xHist(1,1) = mp.xp1;
    end
    U_hist        = nan(nSteps,1);
    sigmaA_hist   = nan(nSteps,1);
    FE_hist       = nan(nSteps,1);

    %% Main simulation loop
    for k = 1:(nSteps-1)
        curr_x = xHist(k,:).';   % [x1; x2]
        t      = tspan(k);

        % — Word‐level uncertainty & surprisal —
        if Nw>0
            wi     = min(Nw, floor(t/segDur)+1);
            U_word = P(wi);
            S_word = -log(U_word + C.epsilonConst);
        else
            U_word = 1;
            S_word = 0;
        end
        U_hist(k)      = U_word;
        sigmaA_hist(k) = 1./(U_word + C.epsilonConst);

        % — Sensory sample —
        idxA = min(round(t*Fs)+1, Nsamples);
        sa   = audData(idxA);
        ss   = 0;

        % — Surprisal impact on x1 —
        if isfield(mp,'surprisalImpact')
            curr_x(1) = curr_x(1) + mp.surprisalImpact * S_word;
        end

        % — Compute free energy & gradient —
        FE_hist(k) = computeFreeEnergy(curr_x, mp, sa, ss, U_word, S_word, C);
        gradF = numericGradient( ...
            @(xx) computeFreeEnergy(xx, mp, sa, ss, U_word, S_word, C), ...
            curr_x, C.epsilonConst );


        % — State update with noise only on x1 —
        noise        = [cogNoise*randn; 0];   % zero motor noise on x2
        dx           = -lr*gradF + noise;
        xHist(k+1,:) = (curr_x + dx).';
    end

    %% Detect freezes by smoothed x2‐velocity threshold
    vel2    = [0; abs(diff(xHist(:,2)))]/dt;      % instantaneous x2‐speed
    W       = cfg.smoothingWindow;               
    vel_sm  = movmean(vel2, W);                  
    freezeMask = vel_sm < mp.freezeThreshold;     % freeze when slow

    %% Apply freezes to audio
    stutteredAudio = applyFreezeBlock(audData, freezeMask, Fs, C);
end

%% ─── computeFreeEnergy ─────────────────────────────────────────────────
function fe = computeFreeEnergy(x, mp, sa, ss, U_word, S_word, C)
    x1 = x(1); x2 = x(2);

    % — Prior term —
    if isfield(mp,'xp1'), pv = mp.xp1; else pv = 0; end
    if isfield(mp,'sigma1'), s1 = mp.sigma1; else s1 = 1; end
    priorErr = (x1 - pv)^2 / (2 * s1);

    % — Motor‐prediction term —
    if isfield(mp,'k'), kVal = mp.k; else kVal = 1; end
    if isfield(mp,'sigma2'), s2 = mp.sigma2; else s2 = 1; end
    predErr  = C.attenuationOffset * (x2 - kVal*x1)^2 / max(s2,1e-3);

    % — Uncertainty penalty —
    uncErr   = U_word * log(1 + S_word);

    fe = priorErr + predErr + uncErr;
end

%% ─── numericGradient ───────────────────────────────────────────────────
function g = numericGradient(fun, x0, epsStep)
    n = numel(x0);
    g = zeros(size(x0));
    for j = 1:n
        dp      = zeros(size(x0)); dp(j) = epsStep;
        f_plus  = fun(x0 + dp);
        f_minus = fun(x0 - dp);
        g(j)    = (f_plus - f_minus) / (2 * epsStep);
    end
end