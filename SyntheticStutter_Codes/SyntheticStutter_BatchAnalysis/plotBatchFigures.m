function plotBatchFigures(raw, sweeps, N)
% PLOTBATCHFIGURES - Generate summary sweep plots

tests = {'Attention','Rate','PlanH','Precision','Adaptation','Predictability'};
testTitles = {'Attention Load Sweep','Speech Rate Sweep','Planning Horizon Sweep', ...
              'Sensory Precision Sweep','Adaptation Across Repetitions','Predictability vs Latent x2'};
colors = lines(numel(tests));

fh = figure('Name','Sweep Summary','Position',[200 200 1600 600],'Color','w');
tl = tiledlayout(2,3,'TileSpacing','compact','Padding','compact');

% —— 1. Attention, Rate, PlanH, Precision
fields = {'Attention','Rate','PlanH','Precision'};
xFields = {'Attention','Rate','PlanH','Precision'};

for k = 1:4
    ax = nexttile(tl,k); hold(ax,'on');
    
    % Collect raw data
    allData = vertcat(raw.(fields{k}));
    x = sweeps.(xFields{k});
    
    mu = mean(allData,1,'omitnan');
    sd = std(allData,[],1,'omitnan');
    
    % Error fill
    fill(ax, [x(:); flipud(x(:))], [mu(:)+sd(:); flipud(mu(:)-sd(:))], ...
         colors(k,:), 'FaceAlpha', 0.3, 'EdgeColor','none');
    % Line
    plot(ax, x, mu, '-o', 'Color', colors(k,:), 'LineWidth',2, 'MarkerSize',6);
    
    xlabel(ax, xFields{k}, 'FontSize',14);
    ylabel(ax, 'Mean Freeze Count', 'FontSize',14);
    title(ax, testTitles{k}, 'FontWeight','bold','FontSize',15);
    grid(ax,'on');
    ax.YRuler.Exponent = 0;
end

% —— 2. Adaptation Plot
ax5 = nexttile(tl,5); hold(ax5,'on');

maxRepeats = 10;
allCounts = zeros(N, maxRepeats);
for i = 1:N
    counts = raw(i).RepeatRuns;
    if numel(counts) < maxRepeats
        counts(end+1:maxRepeats) = counts(end);
    end
    allCounts(i,:) = counts(:)';
end
m = mean(allCounts,1,'omitnan');
s = std(allCounts,[],1,'omitnan');

fill(ax5, [1:maxRepeats, fliplr(1:maxRepeats)], [m+s, fliplr(m-s)], ...
     [0.7 0.7 1], 'FaceAlpha', 0.4, 'EdgeColor','none');
plot(ax5, 1:maxRepeats, m, '-o', 'Color', [0.2 0.2 0.7], 'LineWidth',2, 'MarkerSize',6);

xlabel(ax5, 'Repetition', 'FontSize',14);
ylabel(ax5, 'Mean Freeze Count', 'FontSize',14);
title(ax5, 'Adaptation Across 10 Repetitions', 'FontWeight','bold','FontSize',15);
grid(ax5,'on');
ax5.YRuler.Exponent = 0;

% —— 3. Predictability vs Latent x2
ax6 = nexttile(tl,6); hold(ax6,'on');

allX2 = vertcat(raw.PredictX2);
allPred = vertcat(raw.PredictPred);

scatter(ax6, allPred, allX2, 10, 'filled', 'MarkerFaceAlpha',0.3);
ls = lsline(ax6);
ls.Color = [1 0 0];
ls.LineWidth = 2;

xlabel(ax6, 'Predictability', 'FontSize',14);
ylabel(ax6, 'Latent x2', 'FontSize',14);
title(ax6, 'Predictability vs Latent Motor x2', 'FontWeight','bold','FontSize',15);
grid(ax6,'on');
ax6.YRuler.Exponent = 0;

end
