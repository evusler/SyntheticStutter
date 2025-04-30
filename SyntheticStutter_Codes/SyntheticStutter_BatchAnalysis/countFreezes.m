function n = countFreezes(y, Fs, params, pred)
% COUNTFREEZES - Count number of motor freezes in a simulation.

    [xH, ~, ~, ~, tspan, ~, ~] = runStutterSimulation(y, Fs, params, pred);

    % Apply improved freeze mask
    mask = getImprovedFreezeMask(tspan, xH(:,2), ...
        params.config.defaultFreezeThreshold, ...
        params.config.smoothingWindow, ...
        params.config.dtBase);

    % Sum up the number of freezes
    n = sum(mask);
end
