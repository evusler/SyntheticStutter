function yOut = applyFreezeBlock(audioData, freezeMask, Fs, C)
%APPLYFREEZEBLOCK  Apply a freeze‐mask (from dt‐grid) to audio with smooth ramps.
%
%   yOut = applyFreezeBlock(audioData, freezeMask, Fs, C)
%
%   Inputs:
%     audioData     – vector of audio samples (Nx1)
%     freezeMask    – logical vector (M×1) at dtBase resolution
%     Fs            – sample rate (Hz)
%     C             – constants struct with fields:
%                       .dtBase              (simulation timestep, sec)
%                       .rampDurationFactor  (seconds for ramp length)
%                       .overshootFactor     (not used here)
%
%   Output:
%     yOut          – stuttered audio, same length as audioData

    % Preallocate
    yOut = audioData;
    N    = numel(audioData);

    % --- 1) Upsample freezeMask to audio‐sample grid ---
    % simulation timesteps
    dt     = C.dtBase;
    M      = numel(freezeMask);
    t_mask = (0:M-1)' * dt;                     % [0, dt, 2dt, ..., (M-1)*dt]
    % audio sample times
    t_audio = (0:N-1)' / Fs;
    % nearest‐neighbor interpolation (fills outside with 0)
    freezeMask_audio = interp1(t_mask, double(freezeMask), t_audio, 'nearest', 0);
    freezeMask_audio = freezeMask_audio > 0.5;   % back to logical

    % --- 2) Compute ramp length in samples ---
    rampSamples = max(1, round(C.rampDurationFactor * Fs));

    % --- 3) Pad mask and find rise/fall edges ---
    padded = [false; freezeMask_audio; false];
    d      = diff(padded);
    starts = find(d ==  1);
    ends   = find(d == -1) - 1;  % adjust for padding

    % --- 4) Apply freezing with smooth ramps ---
    for i = 1:numel(starts)
        s = starts(i);
        e = ends(i);

        % zero‐out the frozen region
        yOut(s:e) = 0;

        % ramp‐down into the freeze
        idxIn = max(1, s-rampSamples+1) : s;
        L_in  = numel(idxIn);
        if L_in > 1
            rampIn = linspace(1,0,L_in).';
            yOut(idxIn) = yOut(idxIn) .* rampIn;
        end

        % ramp‐up out of the freeze
        idxOut = e : min(e+rampSamples-1, N);
        L_out  = numel(idxOut);
        if L_out > 1
            rampOut = linspace(0,1,L_out).';
            yOut(idxOut) = yOut(idxOut) .* rampOut;
        end
    end
end
