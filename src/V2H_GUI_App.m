
classdef V2H_GUI_App < matlab.apps.AppBase

    properties (Access = public)
        UIFigure matlab.ui.Figure

        HeaderPanel matlab.ui.container.Panel
        TitleLabel matlab.ui.control.Label
        SubtitleLabel matlab.ui.control.Label

        TabGroup matlab.ui.container.TabGroup
        SingleTab matlab.ui.container.Tab
        OverallTab matlab.ui.container.Tab
        SensitivityTab matlab.ui.container.Tab

        SetupPanel matlab.ui.container.Panel
        UploadButton matlab.ui.control.Button
        RunButton matlab.ui.control.Button
        ExportButton matlab.ui.control.Button
        ResetButton matlab.ui.control.Button

        OwnershipDropDown matlab.ui.control.DropDown
        BatteryDropDown matlab.ui.control.DropDown
        OutageDropDown matlab.ui.control.DropDown
        DistanceDropDown matlab.ui.control.DropDown

        FileLabel matlab.ui.control.Label
        StatusLabel matlab.ui.control.Label

        TechnicalPanel matlab.ui.container.Panel
        EconomicPanel matlab.ui.container.Panel

        TechnicalTable matlab.ui.control.Table
        EconomicTable matlab.ui.control.Table

        KPI1Panel matlab.ui.container.Panel
        KPI2Panel matlab.ui.container.Panel
        KPI3Panel matlab.ui.container.Panel
        KPI4Panel matlab.ui.container.Panel

        KPI1Title matlab.ui.control.Label
        KPI1Value matlab.ui.control.Label
        KPI2Title matlab.ui.control.Label
        KPI2Value matlab.ui.control.Label
        KPI3Title matlab.ui.control.Label
        KPI3Value matlab.ui.control.Label
        KPI4Title matlab.ui.control.Label
        KPI4Value matlab.ui.control.Label

        UIAxes matlab.ui.control.UIAxes

        OverallControlPanel matlab.ui.container.Panel
        RunAllButton matlab.ui.control.Button
        ExportAllButton matlab.ui.control.Button
        OverallInfoLabel matlab.ui.control.Label
        AllResultsTable matlab.ui.control.Table
        AllAxes1 matlab.ui.control.UIAxes
        AllAxes2 matlab.ui.control.UIAxes
        AllAxes3 matlab.ui.control.UIAxes
        AllAxes4 matlab.ui.control.UIAxes

        SensitivityControlPanel matlab.ui.container.Panel
        RunSensitivityButton matlab.ui.control.Button
        ExportSensitivityButton matlab.ui.control.Button
        SensitivityFactorDropDown matlab.ui.control.DropDown
        SensitivityInfoLabel matlab.ui.control.Label
        UploadSensLowButton matlab.ui.control.Button
        UploadSensMediumButton matlab.ui.control.Button
        UploadSensHighButton matlab.ui.control.Button
        SensLowLabel matlab.ui.control.Label
        SensMediumLabel matlab.ui.control.Label
        SensHighLabel matlab.ui.control.Label
        SensitivityScenarioTable matlab.ui.control.Table
        SensitivityRadarAxes matlab.ui.control.UIAxes
        SensitivityBarAxes matlab.ui.control.UIAxes
        SensitivityAnalysisText matlab.ui.control.TextArea
    end

    properties (Access = private)
        load_profile = []
        uploadedFileName = ""
        lastResult = []
        allResultsTable = table()
        sensitivityResultsTable = table()
        sensLoadLow = []
        sensLoadMedium = []
        sensLoadHigh = []
        sensLoadLowName = ""
        sensLoadMediumName = ""
        sensLoadHighName = ""
    end

    methods (Access = private)

        function startupFcn(app)
            app.FileLabel.Text = 'No MAT file uploaded';
            app.StatusLabel.Text = 'Ready';
            app.OverallInfoLabel.Text = 'Upload a MAT load profile, then click Run All Scenarios.';
            app.SensitivityInfoLabel.Text = 'Uses the main MAT load profile. Load variation is skipped.';
        end

        function UploadButtonPushed(app, ~)

            [file, path] = uigetfile({'*.mat', 'MAT Files (*.mat)'}, ...
                'Select Load Profile MAT File');

            if isequal(file, 0)
                app.StatusLabel.Text = 'MAT upload cancelled';
                return;
            end

            fullFile = fullfile(path, file);

            try
                loadVec = app.readMATLoadProfileFile(fullFile);

                app.load_profile = loadVec;
                app.uploadedFileName = string(file);
                app.FileLabel.Text = ['Uploaded: ', file];
                if numel(loadVec) == 24
                    app.StatusLabel.Text = sprintf( ...
                        'Load profile loaded successfully (%d hourly values)', numel(loadVec));
                else
                    app.StatusLabel.Text = sprintf(['Load profile loaded (%d values). This module expects a ' ...
                        '24 hour daily profile, which is repeated for each outage day.'], numel(loadVec));
                end
                app.OverallInfoLabel.Text = ['Overall analysis will use uploaded profile: ', file];

            catch ME
                uialert(app.UIFigure, ['Error reading MAT file: ' ME.message], 'File Error');
            end
        end

        function RunButtonPushed(app, ~)

            if isempty(app.load_profile)
                uialert(app.UIFigure, 'Please upload a load profile MAT file first.', 'Missing Input');
                return;
            end

            ownership = app.OwnershipDropDown.Value;

            % Custom values typed into the editable dropdowns are validated
            % here, before they are passed to the simulation engine.
            [battery_kWh, okBattery]  = app.parseCustomValue(app.BatteryDropDown.Value, ...
                'Battery capacity', 10, 250, false, 'kWh');
            [outage_days, okOutage]   = app.parseCustomValue(app.OutageDropDown.Value, ...
                'Outage duration', 1, 14, true, 'day');
            [distance_km, okDistance] = app.parseCustomValue(app.DistanceDropDown.Value, ...
                'Travel distance', 0, 200, false, 'km');

            if ~(okBattery && okOutage && okDistance)
                return;
            end

            % The one-way trip to the charging point must leave some usable
            % energy above the minimum state of charge, otherwise the vehicle
            % can never supply the house.
            P = even_parameters();
            usableKWh = battery_kWh * (P.v2h.initial_SOC_pct - P.v2h.min_SOC_pct) / 100;
            maxTripKm = usableKWh / P.v2h.travel_energy_kWh_per_km;
            if distance_km >= maxTripKm
                uialert(app.UIFigure, sprintf(['A %g kWh vehicle keeps a %g %% reserve, so it can drive at most ' ...
                    '%.0f km one way to the charging point. A %g km trip leaves no energy for the house. ' ...
                    'Choose a shorter distance or a larger battery.'], battery_kWh, P.v2h.min_SOC_pct, ...
                    maxTripKm, distance_km), 'Trip Too Long for Battery');
                return;
            end

            try
                result = V2H_EconomicSimulator_HourlySOC( ...
                    ownership, battery_kWh, app.load_profile, outage_days, distance_km);

                app.lastResult = result;

                technicalNames = {
                    'Ownership'
                    'Battery Size'
                    'Outage Duration'
                    'Travel Distance'
                    'Supply Availability'
                    'Energy Loss'
                    'Charge Cycles Used'
                    'EV Unavailable Time'
                    'Total Energy Demand'
                    'Total Energy Supplied'
                };

                technicalValues = {
                    ownership
                    sprintf('%.0f', battery_kWh)
                    sprintf('%.0f', outage_days)
                    sprintf('%.0f', distance_km)
                    sprintf('%.2f', result.supply_availability * 100)
                    sprintf('%.2f', result.energy_loss_kWh)
                    sprintf('%.0f', result.charge_cycles_used)
                    sprintf('%.0f', result.ev_unavailable_time)
                    sprintf('%.2f', result.total_energy_demand)
                    sprintf('%.2f', result.total_energy_supplied)
                };

                technicalUnits = {
                    '-'
                    'kWh'
                    'day'
                    'km'
                    '%'
                    'kWh'
                    'cycles'
                    'h'
                    'kWh'
                    'kWh'
                };

                economicNames = {
                    'Cost per kWh'
                    'Total Cost'
                    'Driver Cost'
                    'Hire Cost'
                    'Compensation'
                    'Additional Cost'
                };

                economicValues = {
                    app.formatCostPerKWh(result.total_cost_per_kWh, '%.2f')
                    sprintf('%.2f', result.total_cost)
                    sprintf('%.2f', result.driver_cost)
                    sprintf('%.2f', result.hire_cost)
                    sprintf('%.2f', result.compensation_received)
                    sprintf('%.2f', result.additional_cost_after_compensation)
                };

                economicUnits = {
                    'SEK/kWh'
                    'SEK'
                    'SEK'
                    'SEK'
                    'SEK'
                    'SEK'
                };

                app.TechnicalTable.Data = table(technicalNames, technicalValues, technicalUnits, ...
                    'VariableNames', {'Technical Parameter', 'Value', 'Unit'});

                app.EconomicTable.Data = table(economicNames, economicValues, economicUnits, ...
                    'VariableNames', {'Economic Parameter', 'Value', 'Unit'});

                app.KPI1Value.Text = sprintf('%.1f %%', result.supply_availability * 100);
                app.KPI2Value.Text = app.formatCostPerKWh(result.total_cost_per_kWh, '%.2f SEK/kWh');
                app.KPI3Value.Text = sprintf('%.0f', result.charge_cycles_used);
                app.KPI4Value.Text = sprintf('%.1f kWh', result.total_energy_supplied);

                app.plotSingleScenario(result);

                app.StatusLabel.Text = 'Simulation completed successfully';

            catch ME
                uialert(app.UIFigure, ['Simulation error: ' ME.message], 'Run Error');
            end
        end

        function [val, ok] = parseCustomValue(app, raw, label, lo, hi, mustBeInteger, unitText)
            % Reads a value from an editable dropdown. Accepts both a preset
            % list entry and a value typed by the user, and rejects anything
            % the simulation engine cannot handle sensibly.
            ok = false;
            if isnumeric(raw)
                val = double(raw);
            else
                val = str2double(strrep(strtrim(char(raw)), ',', '.'));
            end

            if isempty(val) || isnan(val) || ~isfinite(val)
                uialert(app.UIFigure, sprintf(['%s must be a number. Enter a value between %g and %g %s, ' ...
                    'or choose one of the presets.'], label, lo, hi, unitText), 'Invalid Input');
                return;
            end
            if val < lo || val > hi
                uialert(app.UIFigure, sprintf('%s must be between %g and %g %s. You entered %g.', ...
                    label, lo, hi, unitText, val), 'Value Out of Range');
                return;
            end
            if mustBeInteger && abs(val - round(val)) > 1e-9
                uialert(app.UIFigure, sprintf('%s must be a whole number. You entered %g.', ...
                    label, val), 'Invalid Input');
                return;
            end
            if mustBeInteger
                val = round(val);
            end
            ok = true;
        end

        function txt = formatCostPerKWh(app, value, fmt) %#ok<INUSL>
            % Cost per kWh is undefined when no energy was delivered.
            if isnan(value)
                txt = 'n/a (nothing delivered)';
            else
                txt = sprintf(fmt, value);
            end
        end

        function plotSingleScenario(app, result)
            cla(app.UIAxes);
            hours = 1:length(result.soc_profile);

            yyaxis(app.UIAxes, 'left');
            plot(app.UIAxes, hours, result.soc_profile, 'b-', 'LineWidth', 2);
            ylabel(app.UIAxes, 'SOC (%)');
            ylim(app.UIAxes, [0 100]);

            yyaxis(app.UIAxes, 'right');
            bar(app.UIAxes, hours, result.unserved_load_profile, 0.5, ...
                'FaceAlpha', 0.4, 'EdgeColor', 'none');
            ylabel(app.UIAxes, 'Unserved Load (kWh)');

            xlabel(app.UIAxes, 'Hour');
            title(app.UIAxes, 'SOC and Unserved Load Profile');
            grid(app.UIAxes, 'on');
        end

        function RunAllButtonPushed(app, ~)

            if isempty(app.load_profile)
                uialert(app.UIFigure, 'Please upload a load profile MAT file first.', 'Missing Input');
                return;
            end

            ownership_types = {'Personal', 'Hired', '3rd Party with Driver'};
            battery_sizes = [60, 77, 100];
            outage_days_set = [1, 2];
            distance_km_set = [5, 10, 20, 30];

            results_table = table();
            scenario_id = 1;

            d = uiprogressdlg(app.UIFigure, ...
                'Title', 'Running All Scenarios', ...
                'Message', 'Please wait...', ...
                'Indeterminate', 'off');

            totalRuns = numel(ownership_types) * numel(battery_sizes) * ...
                numel(outage_days_set) * numel(distance_km_set);
            runCounter = 0;

            try
                for o = 1:length(ownership_types)
                    for b = 1:length(battery_sizes)
                        for dist = 1:length(distance_km_set)
                            for od = 1:length(outage_days_set)

                                ownership = ownership_types{o};
                                battery_kWh = battery_sizes(b);
                                outage_days = outage_days_set(od);
                                distance_km = distance_km_set(dist);

                                result = V2H_EconomicSimulator_HourlySOC( ...
                                    ownership, battery_kWh, app.load_profile, outage_days, distance_km);

                                row = table( ...
                                    scenario_id, {ownership}, battery_kWh, {'Uploaded'}, ...
                                    distance_km, outage_days, ...
                                    result.total_cost_per_kWh, result.total_cost, ...
                                    result.driver_cost, result.hire_cost, ...
                                    result.supply_availability, result.energy_loss_kWh, ...
                                    result.charge_cycles_used, result.ev_unavailable_time, ...
                                    result.compensation_received, result.additional_cost_after_compensation, ...
                                    result.total_energy_demand, result.total_energy_supplied, ...
                                    result.total_energy_demand - result.total_energy_supplied, ...
                                    'VariableNames', { ...
                                    'ScenarioID', 'Ownership', 'Battery_kWh', 'LoadType', ...
                                    'Distance_km', 'OutageDays', ...
                                    'Cost_per_kWh', 'Total_Cost', 'Driver_Cost', 'Hire_Cost', ...
                                    'Supply_Availability', 'Energy_Loss_kWh', ...
                                    'Charge_Cycles_Used', 'EV_Unavailable_Hours', ...
                                    'Compensation', 'Additional_Cost', ...
                                    'Total_Energy_Demand', 'Total_Energy_Supplied', ...
                                    'Total_Unmet_kWh'});

                                results_table = [results_table; row];
                                scenario_id = scenario_id + 1;

                                runCounter = runCounter + 1;
                                d.Value = runCounter / totalRuns;
                                d.Message = sprintf('Running scenario %d of %d...', runCounter, totalRuns);
                            end
                        end
                    end
                end

                close(d);

                app.allResultsTable = results_table;
                app.AllResultsTable.Data = results_table;

                app.plotOverallPerformance(results_table);

                app.StatusLabel.Text = sprintf('Overall performance completed: %d scenarios', height(results_table));
                app.OverallInfoLabel.Text = sprintf('Completed %d scenarios using uploaded load profile.', height(results_table));

            catch ME
                close(d);
                uialert(app.UIFigure, ['Overall analysis error: ' ME.message], 'Run All Error');
                app.StatusLabel.Text = 'Overall scenario analysis failed';
            end
        end

        function plotOverallPerformance(app, T)

            app.plotScatterByOwnership(app.AllAxes1, T, 1, ...
                'Total_Cost', 'Total_Unmet_kWh', ...
                'One-day outage: Unmet Load vs Total Cost', ...
                'Total Cost (SEK)', 'Unmet Load (kWh)', true);

            app.plotScatterByOwnership(app.AllAxes2, T, 2, ...
                'Total_Cost', 'Total_Unmet_kWh', ...
                'Two-day outage: Unmet Load vs Total Cost', ...
                'Total Cost (SEK)', 'Unmet Load (kWh)', true);

            app.plotScatterByOwnership(app.AllAxes3, T, 1, ...
                'Cost_per_kWh', 'Supply_Availability_Percent', ...
                'One-day outage: Availability vs Cost/kWh', ...
                'Cost per kWh (SEK/kWh)', 'Supply Availability (%)', false);

            app.plotScatterByOwnership(app.AllAxes4, T, 2, ...
                'Cost_per_kWh', 'Supply_Availability_Percent', ...
                'Two-day outage: Availability vs Cost/kWh', ...
                'Cost per kWh (SEK/kWh)', 'Supply Availability (%)', false);
        end

        function plotScatterByOwnership(app, ax, T, outageDays, xVar, yVar, ttl, xlab, ylab, showCompensation)
            cla(ax);
            hold(ax, 'on');

            % Add percentage column for availability plots.
            T.Supply_Availability_Percent = T.Supply_Availability * 100;

            % Publication-style encoding:
            % Color  = ownership model
            % Shape  = EV battery capacity
            % Size   = travel distance
            owners = {'Personal','Hired','3rd Party with Driver'};
            ownerLabels = {'Personal EV','Rented EV','Rented EV with driver'};
            ownerColors = [
                0.00 0.45 0.74;   % blue
                0.85 0.33 0.10;   % orange
                0.93 0.69 0.13];  % yellow

            batterySizes = [60 77 100];
            batteryMarkers = {'o','s','^'};

            distanceVals = [5 10 20 30];
            distanceSizes = [35 70 125 190];

            for iOwner = 1:numel(owners)
                for iBatt = 1:numel(batterySizes)
                    for iDist = 1:numel(distanceVals)

                        idx = strcmp(T.Ownership, owners{iOwner}) & ...
                              T.Battery_kWh == batterySizes(iBatt) & ...
                              T.Distance_km == distanceVals(iDist) & ...
                              T.OutageDays == outageDays;

                        if any(idx)
                            scatter(ax, T.(xVar)(idx), T.(yVar)(idx), ...
                                distanceSizes(iDist), ...
                                'Marker', batteryMarkers{iBatt}, ...
                                'MarkerFaceColor', ownerColors(iOwner,:), ...
                                'MarkerEdgeColor', [0.20 0.20 0.20], ...
                                'MarkerFaceAlpha', 0.70, ...
                                'MarkerEdgeAlpha', 0.90, ...
                                'LineWidth', 0.8);
                        end
                    end
                end
            end

            if showCompensation
                % Same rate the cost model uses, so the line cannot drift
                % away from the points plotted beside it.
                P = even_parameters();
                comp = P.v2h.compensation_SEK_per_day * outageDays;

                xline(ax, comp, '--k', 'LineWidth', 1.1);

                yl = ylim(ax);
                text(ax, comp + 0.02*(max(xlim(ax))-min(xlim(ax))), ...
                    yl(1) + 0.20*(yl(2)-yl(1)), ...
                    'Compensation', ...
                    'Rotation', 90, ...
                    'FontSize', 10, ...
                    'Color', [0.15 0.15 0.15], ...
                    'BackgroundColor', 'none', ...
                    'Margin', 1);
            end

            title(ax, ttl, 'FontSize', 9, 'FontWeight', 'bold');
            xlabel(ax, xlab, 'FontSize', 9);
            ylabel(ax, ylab, 'FontSize', 9);
            grid(ax, 'on');
            box(ax, 'on');
            ax.FontSize = 8;
            hold(ax, 'off');
        end




        function [loadVec, file] = readMATLoadProfile(app, dialogTitle)
            [file, path] = uigetfile({'*.mat', 'MAT Files (*.mat)'}, dialogTitle);
            if isequal(file, 0)
                loadVec = [];
                file = "";
                return;
            end

            fullFile = fullfile(path, file);
            loadVec = app.readMATLoadProfileFile(fullFile);
        end

        function loadVec = readMATLoadProfileFile(app, fullFile) %#ok<INUSD>
            S = load(fullFile);
            names = fieldnames(S);

            if isempty(names)
                error('The selected MAT file contains no variables.');
            end

            % Prefer common load-profile variable names.
            preferred = {'load_profile','loadProfile','LoadProfile', ...
                         'household_load','household_demand','load','Load','demand'};

            selected = [];
            selectedName = '';

            for i = 1:numel(preferred)
                if isfield(S, preferred{i})
                    v = S.(preferred{i});
                    if isnumeric(v) && ~isempty(v)
                        selected = v;
                        selectedName = preferred{i};
                        break;
                    end
                end
            end

            % Otherwise choose a numeric vector automatically.
            if isempty(selected)
                vectorCandidates = {};
                for i = 1:numel(names)
                    v = S.(names{i});
                    if isnumeric(v) && isvector(v) && ~isempty(v)
                        vectorCandidates{end+1} = names{i}; %#ok<AGROW>
                    end
                end

                if numel(vectorCandidates) == 1
                    selectedName = vectorCandidates{1};
                    selected = S.(selectedName);
                elseif numel(vectorCandidates) > 1
                    % Prefer a candidate whose name suggests load/demand/profile.
                    idx = find(contains(lower(string(vectorCandidates)), ...
                        ["load","demand","profile"]), 1);
                    if ~isempty(idx)
                        selectedName = vectorCandidates{idx};
                        selected = S.(selectedName);
                    else
                        error(['The MAT file contains multiple numeric vectors. ' ...
                               'Please store the load profile in a variable named ' ...
                               'load_profile, household_demand, load, or demand.']);
                    end
                end
            end

            % Final fallback: if there is exactly one numeric matrix, use column 1.
            if isempty(selected)
                matrixCandidates = {};
                for i = 1:numel(names)
                    v = S.(names{i});
                    if isnumeric(v) && ismatrix(v) && ~isempty(v)
                        matrixCandidates{end+1} = names{i}; %#ok<AGROW>
                    end
                end
                if numel(matrixCandidates) == 1
                    selectedName = matrixCandidates{1};
                    selected = S.(selectedName);
                else
                    error(['No unambiguous numeric load profile was found. ' ...
                           'Expected a numeric vector such as load_profile or household_demand.']);
                end
            end

            if isvector(selected)
                loadVec = selected(:).';
            else
                % If a numeric matrix is supplied, use the first column as the load profile.
                loadVec = selected(:,1).';
            end

            if isempty(loadVec)
                error('The selected load profile is empty.');
            end
            if any(isnan(loadVec)) || any(~isfinite(loadVec))
                error('The load profile contains invalid numeric values.');
            end
            if any(loadVec < 0)
                error('Load values must be non-negative.');
            end

            app.StatusLabel.Text = sprintf( ...
                'Loaded MAT variable "%s" with %d values', selectedName, numel(loadVec));
        end

        function UploadSensLowButtonPushed(app, ~)
            try
                [loadVec, file] = app.readMATLoadProfile('Select LOW load profile MAT file');
                if isempty(loadVec); return; end
                app.sensLoadLow = loadVec;
                app.sensLoadLowName = string(file);
                app.SensLowLabel.Text = ['Low: ', char(file)];
                app.StatusLabel.Text = 'Low sensitivity load profile uploaded';
            catch ME
                uialert(app.UIFigure, ME.message, 'Low Load Upload Error');
            end
        end

        function UploadSensMediumButtonPushed(app, ~)
            try
                [loadVec, file] = app.readMATLoadProfile('Select MEDIUM load profile MAT file');
                if isempty(loadVec); return; end
                app.sensLoadMedium = loadVec;
                app.sensLoadMediumName = string(file);
                app.SensMediumLabel.Text = ['Medium: ', char(file)];
                app.StatusLabel.Text = 'Medium sensitivity load profile uploaded';
            catch ME
                uialert(app.UIFigure, ME.message, 'Medium Load Upload Error');
            end
        end

        function UploadSensHighButtonPushed(app, ~)
            try
                [loadVec, file] = app.readMATLoadProfile('Select HIGH load profile MAT file');
                if isempty(loadVec); return; end
                app.sensLoadHigh = loadVec;
                app.sensLoadHighName = string(file);
                app.SensHighLabel.Text = ['High: ', char(file)];
                app.StatusLabel.Text = 'High sensitivity load profile uploaded';
            catch ME
                uialert(app.UIFigure, ME.message, 'High Load Upload Error');
            end
        end

        function tf = hasThreeSensitivityLoadProfiles(app)
            tf = ~isempty(app.sensLoadLow) && ~isempty(app.sensLoadMedium) && ~isempty(app.sensLoadHigh);
        end

        function loadVec = getSensitivityBaselineLoad(app)
            % Sensitivity analysis now uses only the main uploaded load profile.
            % No artificial load variation is created from a single MAT file.
            loadVec = app.load_profile;
        end

        function loadVec = getSensitivityLoadByIndex(app, ~)
            loadVec = app.getSensitivityBaselineLoad();
        end

        function RunSensitivityButtonPushed(app, ~)

            if isempty(app.getSensitivityBaselineLoad())
                uialert(app.UIFigure, 'Please upload the main MAT load profile in the Single Scenario tab first.', 'Missing Input');
                return;
            end

            try
                d = uiprogressdlg(app.UIFigure, ...
                    'Title', 'Running Sensitivity Analysis', ...
                    'Message', 'Preparing representative scenarios...', ...
                    'Indeterminate', 'off');

                scenario_table = app.buildSensitivityScenarioTable();
                n = height(scenario_table);

                for i = 1:n
                    d.Value = i / n;
                    d.Message = sprintf('Running %s (%d of %d)...', scenario_table.Scenario{i}, i, n);

                    loadVec = app.getSensitivityLoadByIndex(scenario_table.LoadProfileIndex(i));
                    result = V2H_EconomicSimulator_HourlySOC( ...
                        scenario_table.OwnershipModel{i}, ...
                        scenario_table.Battery_kWh(i), ...
                        loadVec, ...
                        scenario_table.OutageDays(i), ...
                        scenario_table.Distance_km(i));

                    scenario_table.Total_Cost_SEK(i) = result.total_cost;
                    scenario_table.Cost_per_kWh_SEK(i) = result.total_cost_per_kWh;
                    scenario_table.Energy_Loss_kWh(i) = result.energy_loss_kWh;
                    scenario_table.Energy_Supplied_kWh(i) = result.total_energy_supplied;
                    scenario_table.Unmet_Load_kWh(i) = result.total_energy_demand - result.total_energy_supplied;
                    scenario_table.Supply_Availability_pct(i) = result.supply_availability * 100;
                    scenario_table.Charge_Cycles(i) = result.charge_cycles_used;
                    scenario_table.EV_Unavailable_h(i) = result.ev_unavailable_time;

                    % Approximate source energy for bar comparison: delivered + losses + travel-related energy not explicitly returned.
                    scenario_table.Source_Energy_kWh(i) = result.total_energy_supplied + result.energy_loss_kWh;
                    scenario_table.Delivered_Energy_kWh(i) = result.total_energy_supplied;
                    scenario_table.Charging_Loss_kWh(i) = max(0, result.energy_loss_kWh);
                    scenario_table.Driving_Loss_kWh(i) = 2 * scenario_table.Distance_km(i) * result.charge_cycles_used * 0.2;
                end

                close(d);

                app.sensitivityResultsTable = scenario_table;
                factorsAvailable = unique(scenario_table.VaryingFactor, 'stable');
                app.SensitivityFactorDropDown.Items = factorsAvailable;
                if ~ismember(app.SensitivityFactorDropDown.Value, factorsAvailable)
                    app.SensitivityFactorDropDown.Value = factorsAvailable{1};
                end
                displayTable = scenario_table(:, {'Scenario','VaryingFactor','Load_kWh','OwnershipLabel','OutageDays','Battery_kWh','Distance_km', ...
                    'Total_Cost_SEK','Cost_per_kWh_SEK','Energy_Loss_kWh','Energy_Supplied_kWh','Unmet_Load_kWh','Supply_Availability_pct'});
                app.SensitivityScenarioTable.Data = displayTable;

                app.plotSensitivityResults();
                app.updateSensitivityAnalysisText();

                app.StatusLabel.Text = sprintf('Sensitivity analysis completed: %d representative scenarios', n);
                app.SensitivityInfoLabel.Text = 'Sensitivity analysis completed. Use the dropdown to change the Varation factor.';

            catch ME
                try
                    close(d);
                catch
                end
                uialert(app.UIFigure, ['Sensitivity analysis error: ' ME.message], 'Sensitivity Error');
                app.StatusLabel.Text = 'Sensitivity analysis failed';
            end
        end

        function T = buildSensitivityScenarioTable(app)
            % Representative sensitivity scenarios using ONE uploaded load profile.
            % Load variation is intentionally omitted because only one load file is uploaded.
            scenario = {};
            factor = {};
            loadCase = {};
            loadProfileIndex = [];
            load_kWh = [];
            ownershipLabel = {};
            ownershipModel = {};
            outage = [];
            battery = [];
            distance = [];

            baselineLoad = app.getSensitivityBaselineLoad();
            baselineEnergy = sum(baselineLoad);
            if baselineEnergy <= 0 || isnan(baselineEnergy)
                baselineEnergy = NaN;
            end

            sn = 1;

            % Ownership variation.
            ownersLabel = {'Personal','Rented','Rented with driver'};
            ownersModel = {'Personal','Hired','3rd Party with Driver'};
            for k = 1:3
                scenario{end+1,1} = sprintf('SN%d', sn); sn = sn + 1;
                factor{end+1,1} = 'Ownership';
                loadCase{end+1,1} = 'Uploaded baseline';
                loadProfileIndex(end+1,1) = 0;
                load_kWh(end+1,1) = baselineEnergy;
                ownershipLabel{end+1,1} = ownersLabel{k};
                ownershipModel{end+1,1} = ownersModel{k};
                outage(end+1,1) = 1;
                battery(end+1,1) = 60;
                distance(end+1,1) = 20;
            end

            % Outage duration variation.
            outageVals = [1 2];
            for k = 1:2
                scenario{end+1,1} = sprintf('SN%d', sn); sn = sn + 1;
                factor{end+1,1} = 'Outage duration';
                loadCase{end+1,1} = 'Uploaded baseline';
                loadProfileIndex(end+1,1) = 0;
                load_kWh(end+1,1) = baselineEnergy;
                ownershipLabel{end+1,1} = 'Personal';
                ownershipModel{end+1,1} = 'Personal';
                outage(end+1,1) = outageVals(k);
                battery(end+1,1) = 60;
                distance(end+1,1) = 20;
            end

            % Battery size variation.
            batteryVals = [60 77 100];
            for k = 1:3
                scenario{end+1,1} = sprintf('SN%d', sn); sn = sn + 1;
                factor{end+1,1} = 'Battery size';
                loadCase{end+1,1} = 'Uploaded baseline';
                loadProfileIndex(end+1,1) = 0;
                load_kWh(end+1,1) = baselineEnergy;
                ownershipLabel{end+1,1} = 'Personal';
                ownershipModel{end+1,1} = 'Personal';
                outage(end+1,1) = 1;
                battery(end+1,1) = batteryVals(k);
                distance(end+1,1) = 20;
            end

            % Distance variation.
            distanceVals = [10 20 30];
            for k = 1:3
                scenario{end+1,1} = sprintf('SN%d', sn); sn = sn + 1;
                factor{end+1,1} = 'Distance';
                loadCase{end+1,1} = 'Uploaded baseline';
                loadProfileIndex(end+1,1) = 0;
                load_kWh(end+1,1) = baselineEnergy;
                ownershipLabel{end+1,1} = 'Personal';
                ownershipModel{end+1,1} = 'Personal';
                outage(end+1,1) = 1;
                battery(end+1,1) = 60;
                distance(end+1,1) = distanceVals(k);
            end

            T = table(scenario, factor, loadCase, loadProfileIndex, load_kWh, ownershipLabel, ownershipModel, outage, battery, distance, ...
                'VariableNames', {'Scenario','VaryingFactor','LoadCase','LoadProfileIndex','Load_kWh','OwnershipLabel','OwnershipModel','OutageDays','Battery_kWh','Distance_km'});

            T.Total_Cost_SEK = zeros(height(T),1);
            T.Cost_per_kWh_SEK = zeros(height(T),1);
            T.Energy_Loss_kWh = zeros(height(T),1);
            T.Energy_Supplied_kWh = zeros(height(T),1);
            T.Unmet_Load_kWh = zeros(height(T),1);
            T.Supply_Availability_pct = zeros(height(T),1);
            T.Charge_Cycles = zeros(height(T),1);
            T.EV_Unavailable_h = zeros(height(T),1);
            T.Source_Energy_kWh = zeros(height(T),1);
            T.Delivered_Energy_kWh = zeros(height(T),1);
            T.Charging_Loss_kWh = zeros(height(T),1);
            T.Driving_Loss_kWh = zeros(height(T),1);
        end

        function SensitivityFactorDropDownValueChanged(app, ~)
            if isempty(app.sensitivityResultsTable) || height(app.sensitivityResultsTable) == 0
                return;
            end
            app.plotSensitivityResults();
            app.updateSensitivityAnalysisText();
        end

        function plotSensitivityResults(app)
            T = app.sensitivityResultsTable;
            if isempty(T) || height(T) == 0
                return;
            end

            factor = app.SensitivityFactorDropDown.Value;
            idx = strcmp(T.VaryingFactor, factor);
            if ~any(idx)
                idx = true(height(T),1);
            end
            G = T(idx,:);

            app.plotRadarAxes(app.SensitivityRadarAxes, G, factor);
            app.plotEnergyBarAxes(app.SensitivityBarAxes, T);
        end

        function plotRadarAxes(app, ax, G, factorName)
            cla(ax);
            if isempty(G) || height(G) == 0
                return;
            end

            metrics = {'Total Cost (SEK)', 'Energy Supplied (kWh)', 'Unmet load (kWh)', 'Energy Loss (kWh)'};
            M = [G.Total_Cost_SEK, G.Energy_Supplied_kWh, G.Unmet_Load_kWh, G.Energy_Loss_kWh];

            maxVals = max(M, [], 1);
            maxVals(maxVals <= 0 | isnan(maxVals)) = 1;
            axesLimits = [zeros(1, numel(maxVals)); maxVals * 1.15];

            labels = string(G.Scenario);
            if strcmp(factorName, 'Load variation')
                labels = labels + " (" + string(G.LoadCase) + ")";
            elseif strcmp(factorName, 'Ownership')
                labels = labels + " (" + string(G.OwnershipLabel) + ")";
            elseif strcmp(factorName, 'Outage duration')
                labels = labels + " (" + string(G.OutageDays) + " day)";
            elseif strcmp(factorName, 'Battery size')
                labels = labels + " (" + string(G.Battery_kWh) + " kWh)";
            elseif strcmp(factorName, 'Distance')
                labels = labels + " (" + string(G.Distance_km) + " km)";
            end

            baseColors = [0.93, 0.49, 0.19; 0.02, 0.02, 0.57; 0.50, 0.03, 0.09; 0.10, 0.55, 0.20];
            if height(G) <= size(baseColors,1)
                colors = baseColors(1:height(G),:);
            else
                colors = lines(height(G));
            end

            radarOpts = struct('Rings', 4, 'Precision', [0 1 1 1], 'FillAlpha', 0.22, ...
                'LineWidth', 1.5, 'AxisFontSize', 10, 'LabelFontSize', 12, 'LabelOffset', 0.25);
            h = even_radar_plot(ax, M, metrics, axesLimits, colors, radarOpts);
            title(ax, '', 'FontSize', 15);
            legend(ax, h, cellstr(labels), 'Location', 'eastoutside', 'FontSize', 8);
        end

        function plotEnergyBarAxes(app, ax, T)
            cla(ax);
            X = categorical(T.Scenario);
            X = reordercats(X, T.Scenario);
            Y = [T.Source_Energy_kWh, T.Delivered_Energy_kWh, T.Charging_Loss_kWh, T.Driving_Loss_kWh];

            bar(ax, X, Y, 'grouped','EdgeColor', 'none');
            ylabel(ax, 'Energy (kWh)');
            title(ax, 'Energy Efficiency by Representative Scenario', 'FontSize', 12, 'FontWeight', 'bold');
            legend(ax, {'Total Source Energy','Delivered Energy','Charging Loss','Driving Loss'}, ...
                'Location', 'northoutside', 'Orientation', 'horizontal');
            grid(ax, 'on');
            ax.XTickLabelRotation = 45;
        end

        function updateSensitivityAnalysisText(app)
            T = app.sensitivityResultsTable;
            if isempty(T) || height(T) == 0
                return;
            end

            [~, bestAvailIdx] = max(T.Supply_Availability_pct);
            [~, minCostIdx] = min(T.Total_Cost_SEK);
            [~, maxUnmetIdx] = max(T.Unmet_Load_kWh);

            app.SensitivityAnalysisText.Value = { ...
                'Sensitivity interpretation', ...
                ' ', ...
                sprintf('Best supply availability: %s = %.2f %%', T.Scenario{bestAvailIdx}, T.Supply_Availability_pct(bestAvailIdx)), ...
                sprintf('Lowest total cost: %s = %.2f SEK', T.Scenario{minCostIdx}, T.Total_Cost_SEK(minCostIdx)), ...
                sprintf('Highest unmet load: %s = %.2f kWh', T.Scenario{maxUnmetIdx}, T.Unmet_Load_kWh(maxUnmetIdx)), ...
                ' ', ...
                'Use the radar plot to compare four performance indicators for one varying factor at a time.', ...
                'Use the grouped bar chart to compare source energy, delivered energy, charging losses, and driving losses across all representative scenarios.'};
        end

        function ExportSensitivityButtonPushed(app, ~)

            if isempty(app.sensitivityResultsTable) || height(app.sensitivityResultsTable) == 0
                uialert(app.UIFigure, 'Please run sensitivity analysis before exporting.', 'No Sensitivity Results');
                return;
            end

            [file, path] = uiputfile('V2H_Sensitivity_Analysis.xlsx', 'Save Sensitivity Results As');
            if isequal(file, 0)
                app.StatusLabel.Text = 'Sensitivity export cancelled';
                return;
            end

            try
                writetable(app.sensitivityResultsTable, fullfile(path, file), 'Sheet', 'Sensitivity_Scenarios');
                app.StatusLabel.Text = ['Sensitivity results exported: ', file];
            catch ME
                uialert(app.UIFigure, ['Sensitivity export error: ' ME.message], 'Export Error');
            end
        end

        function ExportButtonPushed(app, ~)

            if isempty(app.lastResult)
                uialert(app.UIFigure, 'Please run a simulation before exporting.', 'No Results');
                return;
            end

            [file, path] = uiputfile('V2H_Result.xlsx', 'Save Results As');

            if isequal(file, 0)
                app.StatusLabel.Text = 'Export cancelled';
                return;
            end

            fullFile = fullfile(path, file);

            try
                ownership = app.OwnershipDropDown.Value;
                battery_kWh = str2double(app.BatteryDropDown.Value);
                outage_days = str2double(app.OutageDropDown.Value);
                distance_km = str2double(app.DistanceDropDown.Value);
                result = app.lastResult;

                summaryTable = table( ...
                    {ownership}, battery_kWh, outage_days, distance_km, ...
                    result.total_cost_per_kWh, result.total_cost, ...
                    result.driver_cost, result.hire_cost, ...
                    result.supply_availability, result.energy_loss_kWh, ...
                    result.charge_cycles_used, result.ev_unavailable_time, ...
                    result.compensation_received, result.additional_cost_after_compensation, ...
                    result.total_energy_demand, result.total_energy_supplied, ...
                    'VariableNames', { ...
                    'Ownership', 'Battery_kWh', 'OutageDays', 'Distance_km', ...
                    'Cost_per_kWh', 'Total_Cost', 'Driver_Cost', 'Hire_Cost', ...
                    'Supply_Availability', 'Energy_Loss_kWh', 'Charge_Cycles_Used', ...
                    'EV_Unavailable_Hours', 'Compensation', 'Additional_Cost', ...
                    'Total_Energy_Demand', 'Total_Energy_Supplied'});

                profileTable = table( ...
                    (1:length(result.soc_profile))', ...
                    result.soc_profile(:), ...
                    result.unserved_load_profile(:), ...
                    'VariableNames', {'Hour', 'SOC_Profile', 'Unserved_Load_Profile'});

                writetable(summaryTable, fullFile, 'Sheet', 'Summary');
                writetable(profileTable, fullFile, 'Sheet', 'Profiles');

                app.StatusLabel.Text = ['Results exported: ', file];

            catch ME
                uialert(app.UIFigure, ['Export error: ' ME.message], 'Export Error');
            end
        end

        function ExportAllButtonPushed(app, ~)

            if isempty(app.allResultsTable) || height(app.allResultsTable) == 0
                uialert(app.UIFigure, 'Please run all scenarios before exporting.', 'No Overall Results');
                return;
            end

            [file, path] = uiputfile('V2H_All_Scenarios.xlsx', 'Save Overall Results As');

            if isequal(file, 0)
                app.StatusLabel.Text = 'Overall export cancelled';
                return;
            end

            try
                writetable(app.allResultsTable, fullfile(path, file), 'Sheet', 'All_Scenarios');
                app.StatusLabel.Text = ['Overall results exported: ', file];
            catch ME
                uialert(app.UIFigure, ['Overall export error: ' ME.message], 'Export Error');
            end
        end

        function ResetButtonPushed(app, ~)

            app.load_profile = [];
            app.lastResult = [];
            app.uploadedFileName = "";
            app.allResultsTable = table();
            app.sensLoadLow = [];
            app.sensLoadMedium = [];
            app.sensLoadHigh = [];
            app.sensLoadLowName = "";
            app.sensLoadMediumName = "";
            app.sensLoadHighName = "";
            app.sensitivityResultsTable = table();

            app.FileLabel.Text = 'No MAT file uploaded';
            app.StatusLabel.Text = 'Reset complete';
            app.OverallInfoLabel.Text = 'Upload a MAT load profile, then click Run All Scenarios.';
            app.SensitivityInfoLabel.Text = 'Uses the main MAT load profile. Load variation is skipped.';

            app.TechnicalTable.Data = table();
            app.EconomicTable.Data = table();
            app.AllResultsTable.Data = table();
            app.SensitivityScenarioTable.Data = table();
            app.SensitivityAnalysisText.Value = {'Run sensitivity analysis to view interpretation.'};

            app.KPI1Value.Text = '--';
            app.KPI2Value.Text = '--';
            app.KPI3Value.Text = '--';
            app.KPI4Value.Text = '--';

            cla(app.UIAxes);
            cla(app.AllAxes1); cla(app.AllAxes2); cla(app.AllAxes3); cla(app.AllAxes4);
            cla(app.SensitivityRadarAxes); cla(app.SensitivityBarAxes);
        end
    end

    methods (Access = private)

        function createComponents(app)

            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [80 80 1250 720];
            app.UIFigure.Name = 'EVEN Toolkit - Single Family House';
            app.UIFigure.Color = [1 1 1];
           
            app.HeaderPanel = uipanel(app.UIFigure);
            app.HeaderPanel.Position = [0 620 1250 100];
            app.HeaderPanel.BackgroundColor = [0.02 0.16 0.32];
            app.HeaderPanel.BorderType = 'none';

            app.TitleLabel = uilabel(app.HeaderPanel);
            app.TitleLabel.Position = [30 50 1190 40];
            app.TitleLabel.Text = 'Single Family House: Vehicle-to-Home Backup';
            app.TitleLabel.FontSize = 25;
            app.TitleLabel.FontWeight = 'bold';
            app.TitleLabel.FontColor = [1 1 1];
            app.TitleLabel.HorizontalAlignment = 'center';

            app.SubtitleLabel = uilabel(app.HeaderPanel);
            app.SubtitleLabel.Position = [30 18 1190 26];
            app.SubtitleLabel.Text = 'EVEN Toolkit  |  Short-term residential backup from one electric vehicle during an outage';
            app.SubtitleLabel.FontSize = 14;
            app.SubtitleLabel.FontColor = [0.85 0.92 1];
            app.SubtitleLabel.HorizontalAlignment = 'center';

            app.TabGroup = uitabgroup(app.UIFigure);
            app.TabGroup.Position = [20 55 1210 550];

            app.SingleTab = uitab(app.TabGroup);
            app.SingleTab.Title = 'Single Scenario';
            app.SingleTab.BackgroundColor = [1 1 1];

            app.OverallTab = uitab(app.TabGroup);
            app.OverallTab.Title = 'Overall Performance';
            app.OverallTab.BackgroundColor = [1 1 1];

            app.SensitivityTab = uitab(app.TabGroup);
            app.SensitivityTab.Title = 'Sensitivity Analysis';
            app.SensitivityTab.BackgroundColor = [1 1 1];

            app.SetupPanel = uipanel(app.SingleTab);
            app.SetupPanel.Position = [10 10 300 510];
            app.SetupPanel.Title = 'Scenario Setup';
            app.SetupPanel.FontWeight = 'bold';
            app.SetupPanel.FontSize = 14;
            app.SetupPanel.BackgroundColor = [1 1 1];
            app.SetupPanel.HighlightColor = [0.02 0.16 0.32];

            app.UploadButton = uibutton(app.SetupPanel, 'push');
            app.UploadButton.Position = [30 430 240 38];
            app.UploadButton.Text = 'Upload Load Profile MAT';
            app.UploadButton.FontWeight = 'bold';
            app.UploadButton.BackgroundColor = [0.00 0.45 0.74];
            app.UploadButton.FontColor = [1 1 1];
            app.UploadButton.ButtonPushedFcn = @(src,event) UploadButtonPushed(app,event);

            app.FileLabel = uilabel(app.SetupPanel);
            app.FileLabel.Position = [25 395 250 25];
            app.FileLabel.Text = 'No MAT file uploaded';
            app.FileLabel.FontColor = [0.3 0.3 0.3];

            uilabel(app.SetupPanel, 'Position', [30 345 120 22], 'Text', 'Ownership Type', ...
                'FontWeight', 'bold');
            app.OwnershipDropDown = uidropdown(app.SetupPanel);
            app.OwnershipDropDown.Position = [30 318 240 25];
            app.OwnershipDropDown.Items = {'Personal', 'Hired', '3rd Party with Driver'};
            app.OwnershipDropDown.Value = 'Personal';

            uilabel(app.SetupPanel, 'Position', [30 275 175 22], 'Text', 'Battery Capacity (kWh)', ...
                'FontWeight', 'bold');
            app.BatteryDropDown = uidropdown(app.SetupPanel);
            app.BatteryDropDown.Position = [30 248 240 25];
            app.BatteryDropDown.Items = {'60', '77', '100'};
            app.BatteryDropDown.Value = '60';
            app.BatteryDropDown.Editable = 'on';
            app.BatteryDropDown.Tooltip = 'Select a preset or type any value between 10 and 250 kWh.';

            uilabel(app.SetupPanel, 'Position', [30 205 175 22], 'Text', 'Outage Duration (day)', ...
                'FontWeight', 'bold');
            app.OutageDropDown = uidropdown(app.SetupPanel);
            app.OutageDropDown.Position = [30 178 240 25];
            app.OutageDropDown.Items = {'1', '2'};
            app.OutageDropDown.Value = '1';
            app.OutageDropDown.Editable = 'on';
            app.OutageDropDown.Tooltip = 'Select a preset or type a whole number of days (1 to 14).';

            uilabel(app.SetupPanel, 'Position', [30 135 175 22], 'Text', 'Travel Distance (km)', ...
                'FontWeight', 'bold');
            app.DistanceDropDown = uidropdown(app.SetupPanel);
            app.DistanceDropDown.Position = [30 108 240 25];
            app.DistanceDropDown.Items = {'5', '10', '20', '30'};
            app.DistanceDropDown.Value = '5';
            app.DistanceDropDown.Editable = 'on';
            app.DistanceDropDown.Tooltip = 'Select a preset or type any value between 0 and 200 km.';

            app.RunButton = uibutton(app.SetupPanel, 'push');
            app.RunButton.Position = [30 55 240 36];
            app.RunButton.Text = 'Run Simulation';
            app.RunButton.FontWeight = 'bold';
            app.RunButton.BackgroundColor = [0.10 0.55 0.20];
            app.RunButton.FontColor = [1 1 1];
            app.RunButton.ButtonPushedFcn = @(src,event) RunButtonPushed(app,event);

            app.ExportButton = uibutton(app.SetupPanel, 'push');
            app.ExportButton.Position = [30 12 110 32];
            app.ExportButton.Text = 'Export';
            app.ExportButton.BackgroundColor = [0.90 0.50 0.10];
            app.ExportButton.FontColor = [1 1 1];
            app.ExportButton.ButtonPushedFcn = @(src,event) ExportButtonPushed(app,event);

            app.ResetButton = uibutton(app.SetupPanel, 'push');
            app.ResetButton.Position = [160 12 110 32];
            app.ResetButton.Text = 'Reset';
            app.ResetButton.BackgroundColor = [0.55 0.55 0.55];
            app.ResetButton.FontColor = [1 1 1];
            app.ResetButton.ButtonPushedFcn = @(src,event) ResetButtonPushed(app,event);

            app.TechnicalPanel = uipanel(app.SingleTab);
            app.TechnicalPanel.Position = [340 300 405 210];
            app.TechnicalPanel.Title = 'Technical Performance';
            app.TechnicalPanel.FontWeight = 'bold';
            app.TechnicalPanel.FontSize = 14;
            app.TechnicalPanel.BackgroundColor = [1 1 1];
            app.TechnicalPanel.HighlightColor = [0.00 0.35 0.70];

            app.TechnicalTable = uitable(app.TechnicalPanel);
            app.TechnicalTable.Position = [15 15 375 160];
            app.TechnicalTable.ColumnWidth = {190, 90, 75};
            app.TechnicalTable.FontSize = 11;

            app.EconomicPanel = uipanel(app.SingleTab);
            app.EconomicPanel.Position = [775 300 405 210];
            app.EconomicPanel.Title = 'Economic Performance';
            app.EconomicPanel.FontWeight = 'bold';
            app.EconomicPanel.FontSize = 14;
            app.EconomicPanel.BackgroundColor = [1 1 1];
            app.EconomicPanel.HighlightColor = [0.10 0.55 0.20];

            app.EconomicTable = uitable(app.EconomicPanel);
            app.EconomicTable.Position = [15 15 375 160];
            app.EconomicTable.ColumnWidth = {190, 90, 75};
            app.EconomicTable.FontSize = 11;

            app.KPI1Panel = uipanel(app.SingleTab);
            app.KPI1Panel.Position = [340 225 190 55];
            app.KPI1Panel.BackgroundColor = [0.96 0.98 1];

            app.KPI1Title = uilabel(app.KPI1Panel);
            app.KPI1Title.Position = [10 30 170 18];
            app.KPI1Title.Text = 'Supply Availability';
            app.KPI1Title.FontSize = 12;
            app.KPI1Title.FontColor = [0.25 0.25 0.25];
            app.KPI1Title.HorizontalAlignment = 'center';

            app.KPI1Value = uilabel(app.KPI1Panel);
            app.KPI1Value.Position = [10 5 170 25];
            app.KPI1Value.Text = '--';
            app.KPI1Value.FontSize = 17;
            app.KPI1Value.FontWeight = 'bold';
            app.KPI1Value.FontColor = [0.00 0.35 0.70];
            app.KPI1Value.HorizontalAlignment = 'center';

            app.KPI2Panel = uipanel(app.SingleTab);
            app.KPI2Panel.Position = [545 225 190 55];
            app.KPI2Panel.BackgroundColor = [0.97 1 0.97];

            app.KPI2Title = uilabel(app.KPI2Panel);
            app.KPI2Title.Position = [10 30 170 18];
            app.KPI2Title.Text = 'Cost per kWh';
            app.KPI2Title.FontSize = 12;
            app.KPI2Title.FontColor = [0.25 0.25 0.25];
            app.KPI2Title.HorizontalAlignment = 'center';

            app.KPI2Value = uilabel(app.KPI2Panel);
            app.KPI2Value.Position = [10 5 170 25];
            app.KPI2Value.Text = '--';
            app.KPI2Value.FontSize = 17;
            app.KPI2Value.FontWeight = 'bold';
            app.KPI2Value.FontColor = [0.10 0.55 0.20];
            app.KPI2Value.HorizontalAlignment = 'center';

            app.KPI3Panel = uipanel(app.SingleTab);
            app.KPI3Panel.Position = [775 225 190 55];
            app.KPI3Panel.BackgroundColor = [1 0.98 0.95];

            app.KPI3Title = uilabel(app.KPI3Panel);
            app.KPI3Title.Position = [10 30 170 18];
            app.KPI3Title.Text = 'Charge Cycles';
            app.KPI3Title.FontSize = 12;
            app.KPI3Title.FontColor = [0.25 0.25 0.25];
            app.KPI3Title.HorizontalAlignment = 'center';

            app.KPI3Value = uilabel(app.KPI3Panel);
            app.KPI3Value.Position = [10 5 170 25];
            app.KPI3Value.Text = '--';
            app.KPI3Value.FontSize = 17;
            app.KPI3Value.FontWeight = 'bold';
            app.KPI3Value.FontColor = [0.85 0.33 0.10];
            app.KPI3Value.HorizontalAlignment = 'center';

            app.KPI4Panel = uipanel(app.SingleTab);
            app.KPI4Panel.Position = [990 225 190 55];
            app.KPI4Panel.BackgroundColor = [0.98 0.98 0.98];

            app.KPI4Title = uilabel(app.KPI4Panel);
            app.KPI4Title.Position = [10 30 170 18];
            app.KPI4Title.Text = 'Energy Supplied';
            app.KPI4Title.FontSize = 12;
            app.KPI4Title.FontColor = [0.25 0.25 0.25];
            app.KPI4Title.HorizontalAlignment = 'center';

            app.KPI4Value = uilabel(app.KPI4Panel);
            app.KPI4Value.Position = [10 5 170 25];
            app.KPI4Value.Text = '--';
            app.KPI4Value.FontSize = 17;
            app.KPI4Value.FontWeight = 'bold';
            app.KPI4Value.FontColor = [0.20 0.20 0.20];
            app.KPI4Value.HorizontalAlignment = 'center';

            app.UIAxes = uiaxes(app.SingleTab);
            app.UIAxes.Position = [340 15 840 190];

            % ================= OVERALL PERFORMANCE TAB =================
            % Redesigned to match the clinic GUI layout:
            % left-side control/encoding panels, large 2x2 plot panel, full-width table.

            % --- Left control panel ---
            app.OverallControlPanel = uipanel(app.OverallTab);
            app.OverallControlPanel.Position = [10 385 305 135];
            app.OverallControlPanel.Title = 'Overall Scenario Analysis';
            app.OverallControlPanel.FontWeight = 'bold';
            app.OverallControlPanel.FontSize = 12;
            app.OverallControlPanel.BackgroundColor = [1 1 1];
            app.OverallControlPanel.HighlightColor = [0.02 0.16 0.32];

            app.RunAllButton = uibutton(app.OverallControlPanel, 'push');
            app.RunAllButton.Position = [20 76 265 32];
            app.RunAllButton.Text = 'Run All Scenarios';
            app.RunAllButton.FontWeight = 'bold';
            app.RunAllButton.BackgroundColor = [0.10 0.55 0.20];
            app.RunAllButton.FontColor = [1 1 1];
            app.RunAllButton.ButtonPushedFcn = @(src,event) RunAllButtonPushed(app,event);

            app.ExportAllButton = uibutton(app.OverallControlPanel, 'push');
            app.ExportAllButton.Position = [20 40 265 30];
            app.ExportAllButton.Text = 'Export Overall Results';
            app.ExportAllButton.FontWeight = 'bold';
            app.ExportAllButton.BackgroundColor = [0.90 0.50 0.10];
            app.ExportAllButton.FontColor = [1 1 1];
            app.ExportAllButton.ButtonPushedFcn = @(src,event) ExportAllButtonPushed(app,event);

            app.OverallInfoLabel = uilabel(app.OverallControlPanel);
            app.OverallInfoLabel.Position = [20 8 265 25];
            app.OverallInfoLabel.Text = 'Upload a MAT load profile, then click Run All Scenarios.';
            app.OverallInfoLabel.FontSize = 11;
            app.OverallInfoLabel.FontColor = [0.25 0.25 0.25];
            app.OverallInfoLabel.WordWrap = 'on';

            % --- Left plot encoding panel ---
            EncodingPanel = uipanel(app.OverallTab);
            EncodingPanel.Position = [10 205 305 180];
            EncodingPanel.Title = 'Plot Encoding';
            EncodingPanel.FontWeight = 'bold';
            EncodingPanel.FontSize = 12;
            EncodingPanel.BackgroundColor = [1 1 1];
            EncodingPanel.HighlightColor = [0.02 0.16 0.32];

            uilabel(EncodingPanel, 'Position', [20 135 260 20], ...
                'Text', 'Color = ownership model', 'FontSize', 11, 'FontWeight', 'bold');
            uilabel(EncodingPanel, 'Position', [35 114 95 20], ...
                'Text', [char(9679) ' Personal'], 'FontSize', 11, 'FontColor', [0.00 0.45 0.74]);
            uilabel(EncodingPanel, 'Position', [140 114 80 20], ...
                'Text', [char(9679) ' Hired'], 'FontSize', 11, 'FontColor', [0.85 0.33 0.10]);
            uilabel(EncodingPanel, 'Position', [35 94 210 20], ...
                'Text', [char(9679) ' 3rd Party with Driver'], 'FontSize', 11, 'FontColor', [0.93 0.69 0.13]);

            uilabel(EncodingPanel, 'Position', [20 68 260 20], ...
                'Text', 'Shape = EV battery capacity', 'FontSize', 11, 'FontWeight', 'bold');
            uilabel(EncodingPanel, 'Position', [35 46 72 20], ...
                'Text', [char(9679) ' 60 kWh'], 'FontSize', 11, 'FontColor', [0.20 0.20 0.20]);
            uilabel(EncodingPanel, 'Position', [115 46 72 20], ...
                'Text', [char(9632) ' 77 kWh'], 'FontSize', 11, 'FontColor', [0.20 0.20 0.20]);
            uilabel(EncodingPanel, 'Position', [195 46 90 20], ...
                'Text', [char(9650) ' 100 kWh'], 'FontSize', 11, 'FontColor', [0.20 0.20 0.20]);

            uilabel(EncodingPanel, 'Position', [20 21 260 20], ...
                'Text', 'Marker size = travel distance', 'FontSize', 11, 'FontWeight', 'bold');
            uilabel(EncodingPanel, 'Position', [35 2 55 20], ...
                'Text', [char(8226) ' 5 km'], 'FontSize', 11, 'FontColor', [0.20 0.20 0.20]);
            uilabel(EncodingPanel, 'Position', [95 2 60 20], ...
                'Text', [char(9679) ' 10 km'], 'FontSize', 11, 'FontColor', [0.20 0.20 0.20]);
            uilabel(EncodingPanel, 'Position', [165 2 65 20], ...
                'Text', [char(11044) ' 20 km'], 'FontSize', 12, 'FontColor', [0.20 0.20 0.20]);
            uilabel(EncodingPanel, 'Position', [235 2 65 20], ...
                'Text', [char(11044) ' 30 km'], 'FontSize', 14, 'FontColor', [0.20 0.20 0.20]);

            % --- Large plot panel on the right ---
            OverallPlotPanel = uipanel(app.OverallTab);
            OverallPlotPanel.Position = [335 205 860 315];
            OverallPlotPanel.Title = 'Overall Performance Plots';
            OverallPlotPanel.FontWeight = 'bold';
            OverallPlotPanel.FontSize = 12;
            OverallPlotPanel.BackgroundColor = [1 1 1];
            OverallPlotPanel.HighlightColor = [0.55 0.55 0.55];

            % app.AllAxes1 = uiaxes(OverallPlotPanel);
            % app.AllAxes1.Position = [35 145 400 155];
            % 
            % app.AllAxes2 = uiaxes(OverallPlotPanel);
            % app.AllAxes2.Position = [455 145 400 155];
            % 
            % app.AllAxes3 = uiaxes(OverallPlotPanel);
            % app.AllAxes3.Position = [35 5 400 155];
            % 
            % app.AllAxes4 = uiaxes(OverallPlotPanel);
            % app.AllAxes4.Position = [455 5 400 155];


 app.AllAxes1 = uiaxes(OverallPlotPanel);
app.AllAxes1.Position = [20 155 410 130];
app.AllAxes1.Toolbar.Visible = 'off';

app.AllAxes2 = uiaxes(OverallPlotPanel);
app.AllAxes2.Position = [430 155 410 130];
app.AllAxes2.Toolbar.Visible = 'off';

app.AllAxes3 = uiaxes(OverallPlotPanel);
app.AllAxes3.Position = [20 15 410 130];
app.AllAxes3.Toolbar.Visible = 'off';

app.AllAxes4 = uiaxes(OverallPlotPanel);
app.AllAxes4.Position = [430 15 410 130];
app.AllAxes4.Toolbar.Visible = 'off';
            % --- Full-width result table at the bottom ---
            OverallTablePanel = uipanel(app.OverallTab);
            OverallTablePanel.Position = [10 10 1185 185];
            OverallTablePanel.Title = 'Overall Scenario Results';
            OverallTablePanel.FontWeight = 'bold';
            OverallTablePanel.FontSize = 12;
            OverallTablePanel.BackgroundColor = [1 1 1];
            OverallTablePanel.HighlightColor = [0.55 0.55 0.55];

            app.AllResultsTable = uitable(OverallTablePanel);
            app.AllResultsTable.Position = [10 10 1165 145];
            app.AllResultsTable.FontSize = 10;

            app.SensitivityControlPanel = uipanel(app.SensitivityTab);
            app.SensitivityControlPanel.Position = [10 365 285 145];
            app.SensitivityControlPanel.Title = 'Representative Scenario Sensitivity';
            app.SensitivityControlPanel.FontWeight = 'bold';
            app.SensitivityControlPanel.BackgroundColor = [1 1 1];

            app.SensitivityInfoLabel = uilabel(app.SensitivityControlPanel);
            app.SensitivityInfoLabel.Position = [15 85 255 38];
            app.SensitivityInfoLabel.Text = 'Uses the main MAT load profile. Load variation is skipped.';
            app.SensitivityInfoLabel.WordWrap = 'on';

            uilabel(app.SensitivityControlPanel, 'Position', [12 68 95 20], 'Text', 'Variation Factor:', 'FontWeight', 'bold');
            app.SensitivityFactorDropDown = uidropdown(app.SensitivityControlPanel);
            app.SensitivityFactorDropDown.Position = [110 68 160 22];
            app.SensitivityFactorDropDown.Items = {'Ownership','Outage duration','Battery size','Distance'};
            app.SensitivityFactorDropDown.Value = 'Ownership';
            app.SensitivityFactorDropDown.ValueChangedFcn = @(src,event) SensitivityFactorDropDownValueChanged(app,event);

            app.RunSensitivityButton = uibutton(app.SensitivityControlPanel, 'push');
            app.RunSensitivityButton.Position = [15 35 255 28];
            app.RunSensitivityButton.Text = 'Run Sensitivity Analysis';
            app.RunSensitivityButton.FontWeight = 'bold';
            app.RunSensitivityButton.BackgroundColor = [0.10 0.55 0.20];
            app.RunSensitivityButton.FontColor = [1 1 1];
            app.RunSensitivityButton.ButtonPushedFcn = @(src,event) RunSensitivityButtonPushed(app,event);

            app.ExportSensitivityButton = uibutton(app.SensitivityControlPanel, 'push');
            app.ExportSensitivityButton.Position = [15 5 255 24];
            app.ExportSensitivityButton.Text = 'Export Sensitivity Results';
            app.ExportSensitivityButton.BackgroundColor = [0.90 0.50 0.10];
            app.ExportSensitivityButton.FontColor = [1 1 1];
            app.ExportSensitivityButton.ButtonPushedFcn = @(src,event) ExportSensitivityButtonPushed(app,event);

            app.SensitivityScenarioTable = uitable(app.SensitivityTab);
            app.SensitivityScenarioTable.Position = [10 15 285 335];

            app.SensitivityRadarAxes = uiaxes(app.SensitivityTab);
            app.SensitivityRadarAxes.Position = [305 220 650 290];

            app.SensitivityBarAxes = uiaxes(app.SensitivityTab);
            app.SensitivityBarAxes.Position = [305 25 860 175];

            app.SensitivityAnalysisText = uitextarea(app.SensitivityTab);
            app.SensitivityAnalysisText.Position = [970 285 195 205];
            app.SensitivityAnalysisText.Editable = 'off';
            app.SensitivityAnalysisText.FontSize = 12;
            app.SensitivityAnalysisText.Value = {'Run sensitivity analysis to view interpretation.'};

            app.StatusLabel = uilabel(app.UIFigure);
            app.StatusLabel.Position = [30 25 1170 25];
            app.StatusLabel.Text = 'Ready';
            app.StatusLabel.FontColor = [0.3 0.3 0.3];
            app.StatusLabel.HorizontalAlignment = 'center';

            app.UIFigure.Visible = 'on';
        end
    end

    methods (Access = public)

        function app = V2H_GUI_App
            createComponents(app)
            startupFcn(app)
        end

        function delete(app)
            delete(app.UIFigure)
        end
    end
end
