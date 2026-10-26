function R = even_run_scenario(params)
%EVEN_RUN_SCENARIO Run one annual EVEN community resilience scenario.
%
%   R = EVEN_RUN_SCENARIO(PARAMS) assigns the scenario parameters in this
%   function's workspace, runs the annual simulation, and returns the
%   results in the struct R. Nothing is written to the base workspace and
%   the caller's current folder is not changed.
%
%   PARAMS is a struct. Every field is optional; omitted fields fall back
%   to the defaults defined in even_annual_simulation.m, so calling
%   EVEN_RUN_SCENARIO(struct()) reproduces the original default scenario.
%
%     MGFile              Path to the microgrid supply/demand MAT file
%     HHLoadFile          Path to the household load MAT file
%     HHPVFile            Path to the household PV supply MAT file
%     MGSupplyCase        Microgrid supply scenario, 1, 2 or 3
%     DemandScale         Household demand multiplier, e.g. 0.8 for a
%                         20 percent demand reduction
%     EV_PenetrationLevel Fraction of households with an EV, 0 to 1
%     PV_penetration      Fraction of EV households with PV, 0 to 1
%     Battery_penetration Fraction of PV households with a battery, 0 to 1
%     scenario_inverter   1 standard inverter, 2 emergency inverter
%     scenario_auction    Balancing strategy passed to the auction function
%     MG_B                Community battery capacity in kWh
%     EVB                 EV battery capacity in kWh
%     Parameters          Constants struct from EVEN_PARAMETERS, to override
%                         efficiencies, limits or travel energy for one run
%
%   Returned fields (R)
%     num_houses                    Households simulated. Derived as
%                                   round(total households in the load file
%                                   * EV_PenetrationLevel).
%     Num_PV_B, Num_PVOnly, Num_NoPV
%                                   Households with PV and a battery, with
%                                   PV only, and with neither.
%     MG_daily_demand, MG_daily_supply
%                                   Microgrid demand and supply, 365x1, kWh.
%     HH_daily_demand, HH_daily_supply
%                                   Household demand and supply, 365 by
%                                   number of households, kWh.
%     Output_daily_EBalance_before  Daily energy balance per participant
%                                   WITHOUT vehicle-enabled sharing, 365 by
%                                   participants, kWh. Column 1 is the
%                                   microgrid, the rest are households.
%                                   Negative means a deficit.
%     Output_daily_EBalance_after   The same balance WITH sharing. The
%                                   difference between the two is the
%                                   resilience benefit.
%     Output_daily_transition       Energy moved per day, kWh, in three
%                                   columns: microgrid to consumers,
%                                   prosumers to microgrid, prosumers to
%                                   consumers.
%     Output_daily_index_Eloss      Energy lost in transactions, kWh.
%     Output_daily_Action           Buy or sell action per participant per
%                                   day; negative is selling.
%     Degradation                   Annual battery degradation per vehicle,
%                                   as a fraction. Multiply by 100 for a
%                                   percentage.
%     MG_SoCB                       Microgrid battery state of charge.
%     OUTPUT_paramatric_PartA       Five summary indicators: deficit-day
%                                   ratio before, deficit-day ratio after,
%                                   self-consumption, self-sufficiency, and
%                                   mean degradation, all as fractions.
%     OUTPUT_paramatric_PartB       Degradation distribution: minimum,
%                                   quartiles, maximum.
%     SC, SS                        Self-consumption and self-sufficiency
%                                   before sharing, as fractions.
%     ScenarioParameters            The parameter values this run used.
%
%   A full-size run covers 5357 households over 365 days and takes a long
%   time. Use the reduced demo dataset in input_files/community/ while developing.
%
%   Example
%       p.HHLoadFile          = 'input_files/community/HH_Load_demo400.mat';
%       p.HHPVFile            = 'input_files/community/HH_PV_supply2_demo400.mat';
%       p.MGFile              = 'input_files/community/MG_supply_demand.mat';
%       p.EV_PenetrationLevel = 0.20;   % 20 percent of households
%       p.MG_B                = 3000;   % 3000 kWh community battery
%       R = even_run_scenario(p);
%       before = 100*nnz(R.Output_daily_EBalance_before<0)/numel(R.Output_daily_EBalance_before);
%       after  = 100*nnz(R.Output_daily_EBalance_after<0)/numel(R.Output_daily_EBalance_after);
%       fprintf('deficit days %.1f%% -> %.1f%%\n', before, after);
%
%   See also EVEN_ANNUAL_SIMULATION, EVEN_PARAMETERS.

if nargin < 1 || isempty(params)
    params = struct();
end
if ~isstruct(params)
    error('even_run_scenario:BadInput', 'PARAMS must be a struct.');
end

% Map the struct fields onto the variable names the simulation expects.
% Only fields the caller actually supplied are assigned, so anything left
% out keeps the default defined inside the simulation itself.
fieldMap = { ...
    'MGFile',              'GUI_MGFile'; ...
    'HHLoadFile',          'GUI_HHLoadFile'; ...
    'HHPVFile',            'GUI_HHPVFile'; ...
    'MGSupplyCase',        'GUI_MGSupplyCase'; ...
    'DemandScale',         'GUI_DemandScale'; ...
    'EV_PenetrationLevel', 'EV_PenetrationLevel'; ...
    'PV_penetration',      'PV_penetration'; ...
    'Battery_penetration', 'Battery_penetration'; ...
    'scenario_inverter',   'scenario_inverter'; ...
    'scenario_auction',    'scenario_auction'; ...
    'MG_B',                'MG_B'; ...
    'EVB',                 'EVB'; ...
    'Parameters',          'P_even'};

for k = 1:size(fieldMap, 1)
    if isfield(params, fieldMap{k,1}) && ~isempty(params.(fieldMap{k,1}))
        eval([fieldMap{k,2} ' = params.(fieldMap{k,1});']);
    end
end

% Check the input files before spending time on the simulation.
inputFields = {'MGFile','HHLoadFile','HHPVFile'};
for k = 1:numel(inputFields)
    if isfield(params, inputFields{k}) && ~isempty(params.(inputFields{k}))
        if ~isfile(params.(inputFields{k}))
            error('even_run_scenario:MissingInput', ...
                'Input file not found: %s', params.(inputFields{k}));
        end
    end
end

% The script executes in this function's workspace, so it sees the
% variables assigned above and its own defaults for everything else.
even_annual_simulation; %#ok<*NASGU>

% Collect the outputs the graphical interface and the analysis scripts use.
wanted = {'num_houses','Num_PV_B','Num_PVOnly','Num_NoPV', ...
    'MG_daily_demand','MG_daily_supply','HH_daily_demand','HH_daily_supply', ...
    'Output_daily_EBalance_before','Output_daily_EBalance_after', ...
    'Output_daily_transition','Output_daily_index_Eloss', ...
    'Output_sum_index_Ndays_deficits','Output_sum_Indiv_index_Edeficits', ...
    'Output_sum_Indiv_index_Esurplus','Degradation', ...
    'OUTPUT_paramatric_PartA','OUTPUT_paramatric_PartB', ...
    'Output_daily_Action','MG_SoCB','SC','SS'};

R = struct();
for k = 1:numel(wanted)
    if exist(wanted{k}, 'var')
        R.(wanted{k}) = eval(wanted{k});
    end
end

% Record the parameters the run actually used, so a result can be traced
% back to its scenario without relying on what the caller passed in.
used = struct();
for k = 1:size(fieldMap, 1)
    if exist(fieldMap{k,2}, 'var')
        used.(fieldMap{k,1}) = eval(fieldMap{k,2});
    end
end
R.ScenarioParameters = used;

end
