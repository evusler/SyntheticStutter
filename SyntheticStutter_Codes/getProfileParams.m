function [mp,msg] = getProfileParams(profileName)
    %GETPROFILEPARAMS  Return modelParams struct & log message for a profile
    defaultFreezeThreshold = 1e-3;
    switch lower(profileName)
      case 'non-stuttering'
        mp.k             = 0.8;  mp.x1_prior = 0;  mp.sigma_1 = 0.1;  mp.sigma_2 = 1.0;
        mp.y_a           = 0.9;  mp.y_s      = 1.1; mp.sigmaA  = 0.6;  mp.sigma_s = 0.5;
        mp.freezeThreshold = defaultFreezeThreshold;
        msg = 'Using Non-Stuttering Profile.';
      case 'mild stuttering'
        mp.k             = 0.85; mp.x1_prior = 0;  mp.sigma_1 = 0.3;  mp.sigma_2 = 1.4;
        mp.y_a           = 0.85; mp.y_s      = 1.15; mp.sigmaA  = 0.5;  mp.sigma_s = 0.7;
        mp.freezeThreshold = defaultFreezeThreshold;
        msg = 'Using Mild Stuttering Profile.';
      case 'severe stuttering'
        mp.k             = 0.90; mp.x1_prior = 0;  mp.sigma_1 = 0.5;  mp.sigma_2 = 1.8;
        mp.y_a           = 0.80; mp.y_s      = 1.2;  mp.sigmaA  = 0.4;  mp.sigma_s = 0.9;
        mp.freezeThreshold = defaultFreezeThreshold;
        msg = 'Using Severe Stuttering Profile.';
      case 'cluttering'
        mp.k             = 0.8;  mp.x1_prior = 0;  mp.sigma_1 = 0.1;  mp.sigma_2 = 3.0;
        mp.y_a           = 1.0;  mp.y_s      = 1.0;  mp.sigmaA  = 1.2;  mp.sigma_s = 0.8;
        mp.freezeThreshold = defaultFreezeThreshold;
        msg = 'Using Cluttering Profile.';
      otherwise
        mp.k             = 0.8;  mp.x1_prior = 0;  mp.sigma_1 = 0.1;  mp.sigma_2 = 1.0;
        mp.y_a           = 0.9;  mp.y_s      = 1.1; mp.sigmaA  = 0.6;  mp.sigma_s = 0.5;
        mp.freezeThreshold = defaultFreezeThreshold;
        msg = sprintf('Unknown profile "%s"; using default.',profileName);
    end
end
