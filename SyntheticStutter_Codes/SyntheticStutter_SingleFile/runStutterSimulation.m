function [xHist, U_hist, sigmaA_hist, stutteredAudio, tspan, FE_hist, freezeMask] = runStutterSimulation(audData, Fs, params, P)
%RUNSTUTTERSIMULATION  Two‐state predictive‐processing stutter sim with
%                     organic freezes that only trigger on the largest F‐peaks.
%
%   [xHist,U_hist,sigmaA_hist,stutteredAudio,tspan,FE_hist,freezeMask] =
%       runStutterSimulation(audData, Fs, params, P)

%% 1) Unpack constants, config, modelParams
C   = params.constants;
cfg = params.config;
mp  = params.modelParams;

%% 2) Set defaults
if ~isfield(mp,'k'),          mp.k          = 1.0;       end
if ~isfield(mp,'sigma1'),     mp.sigma1     = 1.0;       end
if ~isfield(mp,'sigma2'),     mp.sigma2     = 1.0;       end
if ~isfield(mp,'sigmaA'),     mp.sigmaA     = 1.0;       end
if ~isfield(mp,'sigmaS'),     mp.sigmaS     = 1.0;       end
if ~isfield(mp,'xp1'),        mp.xp1        = 0.0;       end
if ~isfield(mp,'xp2'),        mp.xp2        = 0.0;       end
if ~isfield(mp,'alpha'),      mp.alpha      = 1.0;       end  % U→Π gain
if ~isfield(mp,'beta'),       mp.beta       = 1.0;       end  % Π→inhibition gain
if ~isfield(mp,'attention'),  mp.attention = cfg.defaultAttentionLevel; end

% gamma now acts as a free‐energy threshold: only peaks > gamma trigger freezes
if ~isfield(mp,'gamma'),      mp.gamma      = 50.0;      end  

if ~isfield(C,'freezeHoldDuration'), C.freezeHoldDuration = 0.150; end  % seconds
if ~isfield(C,'eps'),         C.eps         = 1e-3;     end
if ~isfield(C,'noise')||~isfield(C.noise,'amp'), C.noise.amp=0.10; end
if ~isfield(C,'dtBase'),      C.dtBase      = 0.001;    end

%% 3) Time vector & preallocate
dt      = C.dtBase;
tspan   = 0:dt:(numel(audData)-1)/Fs;
nSteps  = numel(tspan);

xHist          = zeros(nSteps,2);
U_hist         = zeros(nSteps,1);
sigmaA_hist    = zeros(nSteps,1);
FE_hist        = zeros(nSteps,1);
freezeMask     = false(nSteps,1);
stutteredAudio = audData;

%% 4) Initial states & freeze timer
xHist(1,:)   = [mp.xp1, mp.xp2];
freezeTimer  = 0;

%% 5) Main loop
for i = 2:nSteps
    % 5.1) Uncertainty from annotations P
    if numel(P)==nSteps
        U = P(i);
    else
        idx = min(numel(P), ceil(i/nSteps * numel(P)));
        U = P(idx);
    end
    U_hist(i) = U;

    % 5.2) Baseline precision modulated by attention
    Pi0 = mp.attention / max(mp.sigmaA, C.eps);
    Pi_t = Pi0 * (1 + mp.alpha * U);
    sigmaA_hist(i) = Pi_t;

    % 5.3) Compute free energy & gradient
    mp_dyn         = mp;
    mp_dyn.sigmaA  = 1 / Pi_t;
    sa = audData(i);
    ss = 0;
    [F, dFdx] = fe_full(xHist(i-1,:)', mp_dyn, sa, ss, C, []);
    FE_hist(i) = F;

    % 5.4) Inhibition grows with precision
    inhibition = 1 + mp.beta * Pi_t;

    % 5.5) Detect large F‐peak
    isNewPeak = i>2 && ...
                FE_hist(i-1)>FE_hist(i-2) && ...
                FE_hist(i-1)>FE_hist(i) && ...
                FE_hist(i-1) > mp.gamma;

    if freezeTimer==0 && isNewPeak
        freezeTimer = round(C.freezeHoldDuration / dt);
    end

    % 5.6) State updates & holding logic
    dx1 = - mp.k * dFdx(1);
    x1n = xHist(i-1,1) + dx1 * dt;

    if freezeTimer > 0
        % hold (stall) x2 for the duration
        x2n = xHist(i-1,2);
        freezeTimer = freezeTimer - 1;
        freezeMask(i) = true;
    else
        % normal damped gradient‐descent + noise
        dx2 = - mp.k * dFdx(2) / inhibition;
        x2n = xHist(i-1,2) + dx2 * dt + sqrt(dt)*C.noise.amp*randn;
    end

    xHist(i,:) = [x1n, x2n];
end

%% 6) Build stuttered audio by holding samples during freezes
for idx = find(freezeMask)'
    samp = round((idx-1)*dt*Fs) + 1;
    if samp>1 && samp<=numel(stutteredAudio)
        stutteredAudio(samp) = stutteredAudio(samp-1);
    end
end

end
