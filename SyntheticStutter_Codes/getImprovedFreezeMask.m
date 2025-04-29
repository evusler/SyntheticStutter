function mask = getImprovedFreezeMask(tspan, x2, thresh, win, minDur)
    %GETIMPROVEDFREEZEMASK  Identify and remove spurious short freeze events

    dt  = mean(diff(tspan));
    vel = [0; abs(diff(x2))]/dt;
    sm  = movmean(vel, win);
    m   = sm < thresh;

    CC = bwconncomp(m);
    for i = 1:CC.NumObjects
        dur = numel(CC.PixelIdxList{i}) * dt;
        if dur < minDur
            m(CC.PixelIdxList{i}) = false;
        end
    end

    mask = m;
end
