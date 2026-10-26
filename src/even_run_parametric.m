function [PartA, PartB, info] = even_run_parametric(group, files, varargin)
%EVEN_RUN_PARAMETRIC Generate a community parametric study (Group A, B or C).
%
%   [PARTA, PARTB, INFO] = EVEN_RUN_PARAMETRIC(GROUP, FILES) runs the annual
%   EVEN community simulation once for every combination in the chosen
%   parametric group and returns the results in the format read by the
%   Parametric tab of the community module.
%
%   GROUP is 'A', 'B' or 'C':
%     'A'  Demand reduction 0-50 % (6 levels) x microgrid supply scenarios
%          1, 2 and 3 (3 curves).                               18 runs
%     'B'  EV penetration 5-50 % in 5 % steps (10 levels) x EV battery
%          56, 75 and 100 kWh (3 curves).                       30 runs
%     'C'  PV penetration 25-65 % in 5 % steps (9 levels) x household
%          battery share 11 % / 30 % with a standard or emergency
%          inverter (4 curves).                                 36 runs
%
%   FILES is a struct with the paths of the three community input files:
%     FILES.MGFile, FILES.HHLoadFile, FILES.HHPVFile
%   Any dataset with the documented variables works, including the
%   400-household demo subset and the full 5357-household dataset.
%
%   Optional name-value arguments:
%     'OutputFile'   Save the results to this .mat file. Omit to skip saving.
%     'ProgressFcn'  Function handle called before each run as
%                    keepGoing = fcn(k, n, description). Return false to
%                    stop; the runs completed so far are returned.
%
%   Outputs
%     PARTA  5 x levels x curves. Rows: deficit-day ratio before sharing,
%            deficit-day ratio after sharing, self-consumption,
%            self-sufficiency, mean battery degradation (all fractions).
%     PARTB  5 x levels x curves. Battery degradation distribution:
%            minimum, 25th, 50th and 75th percentile, maximum.
%     INFO   The sweep values, curve labels, input files, number of
%            households and run time, also saved in the output file.
%
%   Settings reproduce the original parametric study scripts, which differ
%   from the single-scenario defaults in three respects: microgrid and
%   household battery efficiency 0.95 (single scenario: 0.9), EV penetration
%   fixed at 35 % in Groups A and C, and in Group C a vehicle power limit
%   of 0.2 x battery capacity. Change them in studySettings below.
%
%   Example
%     f.MGFile     = 'input_files/community/MG_supply_demand.mat';
%     f.HHLoadFile = 'input_files/community/HH_Load_demo400.mat';
%     f.HHPVFile   = 'input_files/community/HH_PV_supply2_demo400.mat';
%     even_run_parametric('B', f, 'OutputFile', 'results/Parametric_GroupB.mat');
%
%   See also EVEN_RUN_SCENARIO, EVEN_PARAMETERS.

p = inputParser;
addRequired(p, 'group', @(g) any(strcmpi(g, {'A','B','C'})));
addRequired(p, 'files', @isstruct);
addParameter(p, 'OutputFile', '', @(s) ischar(s) || isstring(s));
addParameter(p, 'ProgressFcn', [], @(f) isempty(f) || isa(f, 'function_handle'));
parse(p, group, files, varargin{:});
group = upper(char(group));
outFile = char(p.Results.OutputFile);
progressFcn = p.Results.ProgressFcn;

required = {'MGFile', 'HHLoadFile', 'HHPVFile'};
for k = 1:numel(required)
    if ~isfield(files, required{k}) || ~isfile(files.(required{k}))
        error('even_run_parametric:MissingFile', ...
            'FILES.%s is missing or does not point to an existing file.', required{k});
    end
end

[levels, curves, levelName, curveLabels, runFcn] = studySettings(group);
nLevels = numel(levels);
nCurves = numel(curves);
nRuns = nLevels * nCurves;

PartA = nan(5, nLevels, nCurves);
PartB = nan(5, nLevels, nCurves);
households = nan(nLevels, nCurves);
completed = 0;
tStart = tic;

for c = 1:nCurves
    for l = 1:nLevels
        k = (c - 1) * nLevels + l;
        description = sprintf('Group %s: %s, %s = %g', group, curveLabels{c}, levelName, levels(l));
        if ~isempty(progressFcn)
            if ~progressFcn(k, nRuns, description)
                break;
            end
        end

        scenario = runFcn(levels(l), curves(c));
        scenario.MGFile     = files.MGFile;
        scenario.HHLoadFile = files.HHLoadFile;
        scenario.HHPVFile   = files.HHPVFile;

        R = even_run_scenario(scenario);
        PartA(:, l, c) = R.OUTPUT_paramatric_PartA(:, 1, 1);
        PartB(:, l, c) = R.OUTPUT_paramatric_PartB(:, 1, 1);
        households(l, c) = R.num_houses;
        completed = completed + 1;
    end
    if completed < c * nLevels
        break;   % stopped from the progress function
    end
end

info = struct();
info.Group = group;
info.LevelName = levelName;
info.Levels = levels;
info.CurveLabels = curveLabels;
info.Households = households;
info.Files = files;
info.CompletedRuns = completed;
info.TotalRuns = nRuns;
info.RunTimeSeconds = toc(tStart);
info.Created = datestr(now, 'yyyy-mm-dd HH:MM');

if ~isempty(outFile)
    outDir = fileparts(outFile);
    if ~isempty(outDir) && ~isfolder(outDir)
        mkdir(outDir);
    end
    OUTPUT_paramatric_PartA = PartA; %#ok<NASGU>
    OUTPUT_paramatric_PartB = PartB; %#ok<NASGU>
    ParametricInfo = info; %#ok<NASGU>
    save(outFile, 'OUTPUT_paramatric_PartA', 'OUTPUT_paramatric_PartB', 'ParametricInfo');
end

end

% -------------------------------------------------------------------------
function [levels, curves, levelName, curveLabels, runFcn] = studySettings(group)
% Sweep definitions and fixed settings of the original parametric scripts.

base = even_parameters();
base.community.MG_battery_efficiency = 0.95;
base.community.HH_battery_efficiency = 0.95;

switch group
    case 'A'
        levels = [0 10 20 30 40 50];                 % demand reduction, %
        curves = [1 2 3];                            % microgrid supply scenario
        levelName = 'demand reduction (%)';
        curveLabels = {'MG Supply 1', 'MG Supply 2', 'MG Supply 3'};
        runFcn = @(lev, cur) struct( ...
            'MGSupplyCase', cur, 'DemandScale', 1 - lev/100, ...
            'EV_PenetrationLevel', 0.35, 'PV_penetration', 0.25, ...
            'Battery_penetration', 0.11, 'scenario_inverter', 1, ...
            'scenario_auction', 2, 'MG_B', 2000, 'EVB', 56, 'Parameters', base);

    case 'B'
        levels = 5:5:50;                             % EV penetration, %
        curves = [56 75 100];                        % EV battery, kWh
        levelName = 'EV penetration (%)';
        curveLabels = {'EV battery 56 kWh', 'EV battery 75 kWh', 'EV battery 100 kWh'};
        runFcn = @(lev, cur) struct( ...
            'MGSupplyCase', 1, 'DemandScale', 1, ...
            'EV_PenetrationLevel', lev/100, 'PV_penetration', 0.25, ...
            'Battery_penetration', 0.11, 'scenario_inverter', 1, ...
            'scenario_auction', 2, 'MG_B', 2000, 'EVB', cur, 'Parameters', base);

    case 'C'
        levels = 25:5:65;                            % PV penetration, %
        curves = 1:4;                                % battery share x inverter
        levelName = 'PV penetration (%)';
        curveLabels = {'11% battery, standard inverter', '30% battery, standard inverter', ...
                       '11% battery, emergency inverter', '30% battery, emergency inverter'};
        batteryShare = [0.11 0.30 0.11 0.30];
        inverter     = [1 1 2 2];
        baseC = base;
        baseC.community.EV_power_limit_kW = 0.2 * 56;   % original Group C setting
        runFcn = @(lev, cur) struct( ...
            'MGSupplyCase', 1, 'DemandScale', 1, ...
            'EV_PenetrationLevel', 0.35, 'PV_penetration', lev/100, ...
            'Battery_penetration', batteryShare(cur), 'scenario_inverter', inverter(cur), ...
            'scenario_auction', 2, 'MG_B', 2000, 'EVB', 56, 'Parameters', baseC);
end
end
