function h = even_radar_plot(ax, M, axisLabels, axisLimits, colors, opts)
%EVEN_RADAR_PLOT Draw a radar (spider) chart into existing axes.
%
%   H = EVEN_RADAR_PLOT(AX, M, AXISLABELS, AXISLIMITS, COLORS) draws one
%   filled polygon per row of M on a circular web, and returns the polygon
%   handles in H so the caller can build a legend from them.
%
%   Inputs
%     AX          Target axes or uiaxes. Existing content is cleared.
%     M           Data, one row per series and one column per axis.
%     AXISLABELS  Cell array of axis names, one per column of M.
%     AXISLIMITS  2-by-N matrix: row 1 is the value at the centre of each
%                 axis, row 2 the value at the outer ring.
%     COLORS      Series colours, one RGB row per row of M.
%     OPTS        Optional struct; any field may be omitted:
%                   Rings          number of web rings              (4)
%                   Precision      decimals per axis for tick text  (1)
%                   FillAlpha      polygon fill transparency        (0.22)
%                   LineWidth      polygon edge width               (1.5)
%                   MarkerSize     vertex marker size, 0 for none   (0)
%                   AxisFontSize   tick label font size             (9)
%                   LabelFontSize  axis name font size              (11)
%                   LabelOffset    axis name distance beyond web    (0.30)
%                   ShowTicks      print ring values on every axis  (true)
%
%   The first axis points to the right and the remaining axes follow
%   counter-clockwise. Each axis is scaled independently between its own
%   limits, so quantities with different units can share one chart.
%
%   Written for the EVEN Toolkit; uses base MATLAB graphics only.

if nargin < 6 || isempty(opts)
    opts = struct();
end
opts = applyDefaults(opts);

[nSeries, nAxes] = size(M);
if numel(axisLabels) ~= nAxes
    error('even_radar_plot:Labels', ...
        'AXISLABELS has %d entries but M has %d columns.', numel(axisLabels), nAxes);
end
if ~isequal(size(axisLimits), [2 nAxes])
    error('even_radar_plot:Limits', 'AXISLIMITS must be a 2-by-%d matrix.', nAxes);
end
if size(colors, 1) < nSeries
    error('even_radar_plot:Colors', ...
        'COLORS has %d rows but M has %d series.', size(colors, 1), nSeries);
end

precision = opts.Precision;
if isscalar(precision)
    precision = repmat(precision, 1, nAxes);
end

cla(ax);
hold(ax, 'on');

theta = (0:nAxes-1) * 2*pi / nAxes;
webColour = [0.80 0.80 0.80];
circle = linspace(0, 2*pi, 181);

% Web: concentric rings and one spoke per axis.
for r = (1:opts.Rings) / opts.Rings
    plot(ax, r*cos(circle), r*sin(circle), '-', 'Color', webColour, ...
        'LineWidth', 0.6, 'HandleVisibility', 'off');
end
for k = 1:nAxes
    plot(ax, [0 cos(theta(k))], [0 sin(theta(k))], '-', 'Color', webColour, ...
        'LineWidth', 0.8, 'HandleVisibility', 'off');
end

% Ring values along every axis, in that axis's own units.
if opts.ShowTicks
    for k = 1:nAxes
        lo = axisLimits(1, k);
        hi = axisLimits(2, k);
        for i = 1:opts.Rings
            r = i / opts.Rings;
            value = lo + r * (hi - lo);
            text(ax, r*cos(theta(k)), r*sin(theta(k)), ...
                sprintf(['%.' num2str(precision(k)) 'f'], value), ...
                'FontSize', opts.AxisFontSize, 'Color', [0.35 0.35 0.35], ...
                'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
                'HandleVisibility', 'off');
        end
    end
end

% Axis names, placed just beyond the outer ring.
labelRadius = 1 + opts.LabelOffset;
for k = 1:nAxes
    c = cos(theta(k));
    if c > 0.2
        hAlign = 'left';
    elseif c < -0.2
        hAlign = 'right';
    else
        hAlign = 'center';
    end
    text(ax, labelRadius*c, labelRadius*sin(theta(k)), axisLabels{k}, ...
        'FontSize', opts.LabelFontSize, 'FontWeight', 'bold', ...
        'HorizontalAlignment', hAlign, 'VerticalAlignment', 'middle', ...
        'HandleVisibility', 'off');
end

% Series polygons. Values are scaled to 0..1 on each axis and clipped so a
% value outside the stated limits cannot draw beyond the web.
h = [];   % grows to one graphics handle per series
for i = 1:nSeries
    span = axisLimits(2, :) - axisLimits(1, :);
    span(span == 0) = 1;
    radius = (M(i, :) - axisLimits(1, :)) ./ span;
    radius(~isfinite(radius)) = 0;
    radius = min(max(radius, 0), 1);

    x = radius .* cos(theta);
    y = radius .* sin(theta);
    h(i, 1) = patch(ax, [x x(1)], [y y(1)], colors(i, :), ...
        'FaceAlpha', opts.FillAlpha, 'EdgeColor', colors(i, :), ...
        'LineWidth', opts.LineWidth);

    if opts.MarkerSize > 0
        scatter(ax, x, y, opts.MarkerSize, colors(i, :), 'filled', ...
            'HandleVisibility', 'off');
    end
end

axis(ax, 'equal');
axis(ax, 'off');
lim = labelRadius + 0.35;
xlim(ax, [-lim lim]);
ylim(ax, [-lim lim]);
hold(ax, 'off');

end

function opts = applyDefaults(opts)
defaults = struct( ...
    'Rings', 4, ...
    'Precision', 1, ...
    'FillAlpha', 0.22, ...
    'LineWidth', 1.5, ...
    'MarkerSize', 0, ...
    'AxisFontSize', 9, ...
    'LabelFontSize', 11, ...
    'LabelOffset', 0.30, ...
    'ShowTicks', true);
names = fieldnames(defaults);
for k = 1:numel(names)
    if ~isfield(opts, names{k}) || isempty(opts.(names{k}))
        opts.(names{k}) = defaults.(names{k});
    end
end
end
