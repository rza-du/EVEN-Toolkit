classdef Clinic_Backup_GUI_App < matlab.apps.AppBase

    properties (Access = public)
        UIFigure matlab.ui.Figure
        HeaderPanel matlab.ui.container.Panel
        TitleLabel matlab.ui.control.Label
        SubtitleLabel matlab.ui.control.Label
        TabGroup matlab.ui.container.TabGroup
        SingleTab matlab.ui.container.Tab
        OverallTab matlab.ui.container.Tab
        SensitivityTab matlab.ui.container.Tab

        UploadClinicButton matlab.ui.control.Button
        UploadSolarButton matlab.ui.control.Button
        ClinicFileLabel matlab.ui.control.Label
        SolarFileLabel matlab.ui.control.Label
        EVBDropDown matlab.ui.control.DropDown
        NumEVDropDown matlab.ui.control.DropDown
        TravelDropDown matlab.ui.control.DropDown
        MonthDropDown matlab.ui.control.DropDown
        StationDropDown matlab.ui.control.DropDown
        RunButton matlab.ui.control.Button
        ExportButton matlab.ui.control.Button
        ResultsTable matlab.ui.control.Table
        UIAxes matlab.ui.control.UIAxes
        StatusLabel matlab.ui.control.Label

        SetupPanel matlab.ui.container.Panel
        ResultsPanel matlab.ui.container.Panel
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
        PlotPanel matlab.ui.container.Panel

        OverallControlPanel matlab.ui.container.Panel
        OverallEncodingPanel matlab.ui.container.Panel
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
        SensitivityScenarioTable matlab.ui.control.Table
        SensitivityRadarAxes matlab.ui.control.UIAxes
        SensitivityBarAxes matlab.ui.control.UIAxes
        SensitivityAnalysisText matlab.ui.control.TextArea
    end

    properties (Access = private)
        lastResult = []
        clinicLoaded = false
        solarLoaded = false
        clinicFile = ''
        solarFile = ''
        allResultsTable = table()
        sensitivityResultsTable = table()
    end

    methods (Access = private)

        function startupFcn(app)
            app.ClinicFileLabel.Text = 'No clinic MAT uploaded';
            app.SolarFileLabel.Text = 'No solar MAT uploaded';
            app.StatusLabel.Text = 'Ready';
            app.OverallInfoLabel.Text = 'Upload clinic and solar MAT files, then click Run All Scenarios.';
            app.SensitivityInfoLabel.Text = 'Upload clinic and solar MAT files, then run representative sensitivity scenarios.';
            if isprop(app,'KPI1Value'); app.KPI1Value.Text = '--'; end
            if isprop(app,'KPI2Value'); app.KPI2Value.Text = '--'; end
            if isprop(app,'KPI3Value'); app.KPI3Value.Text = '--'; end
            if isprop(app,'KPI4Value'); app.KPI4Value.Text = '--'; end
        end

        function UploadClinicButtonPushed(app, ~)
            [file, path] = uigetfile('*.mat', 'Select Clinic Load MAT File');
            if isequal(file, 0)
                app.StatusLabel.Text = 'Clinic MAT upload cancelled';
                return;
            end
            try
                % The file is read from where the user selected it. Nothing
                % is copied into the working folder.
                app.clinicFile = fullfile(path, file);
                app.clinicLoaded = true;
                app.ClinicFileLabel.Text = ['Clinic MAT: ', file];
                app.StatusLabel.Text = 'Clinic MAT uploaded successfully';
            catch ME
                uialert(app.UIFigure, ME.message, 'Clinic Upload Error');
            end
        end

        function UploadSolarButtonPushed(app, ~)
            [file, path] = uigetfile('*.mat', 'Select Solar Excess MAT File');
            if isequal(file, 0)
                app.StatusLabel.Text = 'Solar MAT upload cancelled';
                return;
            end
            try
                app.solarFile = fullfile(path, file);
                app.solarLoaded = true;
                app.SolarFileLabel.Text = ['Solar MAT: ', file];
                app.StatusLabel.Text = 'Solar MAT uploaded successfully';
            catch ME
                uialert(app.UIFigure, ME.message, 'Solar Upload Error');
            end
        end

        function tf = filesReady(app)
            tf = app.clinicLoaded && app.solarLoaded && ...
                isfile(app.clinicFile) && isfile(app.solarFile);
            if ~app.clinicLoaded
                uialert(app.UIFigure, 'Please upload clinic MAT file first.', 'Missing Clinic File');
            elseif ~app.solarLoaded
                uialert(app.UIFigure, 'Please upload solar MAT file first.', 'Missing Solar File');
            end
        end

        function monthNum = getMonthNumber(app)
            monthNames = app.monthNames();
            monthNum = find(strcmp(monthNames, app.MonthDropDown.Value));
        end

        function RunButtonPushed(app, ~)
            if ~app.filesReady(); return; end

            % Custom values typed into the editable dropdowns are validated
            % here, before they are passed to the simulation engine.
            [EVB, okEVB]            = app.parseCustomValue(app.EVBDropDown.Value, ...
                'EV battery capacity', 10, 250, false, 'kWh');
            [N_EVs, okNum]          = app.parseCustomValue(app.NumEVDropDown.Value, ...
                'Number of EVs', 1, 200, true, 'vehicles');
            [travel_km, okTravel]   = app.parseCustomValue(app.TravelDropDown.Value, ...
                'Travel distance', 0, 200, false, 'km');
            [station_capacity, okStation] = app.parseCustomValue(app.StationDropDown.Value, ...
                'Station battery capacity', 0, 5000, false, 'kWh');
            monthNum = app.getMonthNumber();

            if ~(okEVB && okNum && okTravel && okStation)
                return;
            end

            % A vehicle starts at its initial state of charge and must keep its
            % minimum reserve plus the energy for the trip. If the one-way trip
            % needs more than that, no vehicle can ever supply the clinic.
            P = even_parameters();
            usableKWh = (P.clinic.EV_SOC_initial - P.clinic.EV_SOC_min) * EVB;
            maxTripKm = usableKWh / P.clinic.travel_energy_kWh_per_km;
            if travel_km >= maxTripKm
                choice = uiconfirm(app.UIFigure, sprintf(['A %g kWh vehicle can drive at most %.0f km one way ' ...
                    'and still supply the clinic. At %g km no vehicle can deliver energy, so only the ' ...
                    'stationary battery will supply the load. Run anyway?'], EVB, maxTripKm, travel_km), ...
                    'Trip Too Long for EV Battery', 'Options', {'Run anyway', 'Cancel'}, ...
                    'DefaultOption', 2, 'CancelOption', 2, 'Icon', 'warning');
                if strcmp(choice, 'Cancel')
                    return;
                end
            end

            if N_EVs > 60
                app.StatusLabel.Text = sprintf(['Running %d EVs. Fleets larger than 60 reuse the same ' ...
                    '60 household solar profiles, so charging opportunities are shared.'], N_EVs);
            end

            try
                result = simulate_clinic_backup(EVB, N_EVs, travel_km, monthNum, true, station_capacity, app.clinicFile, app.solarFile);
                app.lastResult = result;
                app.updateSingleResults(result);
                app.plotSingleScenario(result);
                app.StatusLabel.Text = 'Simulation completed successfully';
            catch ME
                uialert(app.UIFigure, ME.message, 'Simulation Error');
                app.StatusLabel.Text = 'Simulation failed';
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

        function updateSingleResults(app, result)
            supplyAvail = 100 * result.Total_Delivered_KWh / max(result.Total_Demand_kWh, eps);
            costs = app.calculateReferenceCosts(result);
            hybridCostPerKWh = costs.Hybrid_Cost_per_kWh_SEK;
            fullDieselCostPerKWh = result.Diesel_FullLoad_Cost_SEK / max(result.Total_Demand_kWh, eps);

            technicalNames = {
                'Month'
                'EV Battery Size'
                'Number of EVs'
                'Travel Distance'
                'Station Battery Size'
                'Total Demand'
                'Delivered Energy'
                'Unmet Load'
                'Supply Availability'
                'Unserved Hours'
                'EV Efficiency Losses'
                'Travel Energy'
                'Station Discharge'
                'Station Charge'
            };

            technicalValues = {
                app.monthName(result.Month)
                sprintf('%.0f kWh', result.EVB_kWh)
                sprintf('%.0f', result.Num_EVs)
                sprintf('%.0f km', result.Travel_km)
                sprintf('%.0f kWh', result.Station_kWh)
                sprintf('%.2f kWh', result.Total_Demand_kWh)
                sprintf('%.2f kWh', result.Total_Delivered_KWh)
                sprintf('%.2f kWh', result.Total_Unmet_kWh)
                sprintf('%.2f %%', supplyAvail)
                sprintf('%.0f h', result.Unserved_Hours)
                sprintf('%.2f kWh', result.EV_Eff_Losses_kWh)
                sprintf('%.2f kWh', result.Total_Travel_Energy_kWh)
                sprintf('%.2f kWh', result.Station_Discharge_kWh)
                sprintf('%.2f kWh', result.Station_Charge_kWh)
            };

            economicNames = {
                'Hybrid Diesel Fuel'
                'Hybrid CO2 Emissions'
                'Hybrid Diesel Cost'
                'EV System Cost'
                'Hybrid Total Cost'
                'Hybrid Cost per kWh'
                'Full Diesel Fuel'
                'Full Diesel CO2'
                'Full Diesel Cost'
                'Full Diesel Cost per kWh'
                'Same-EV Diesel Fuel'
                'Same-EV Diesel CO2'
                'Same-EV Diesel Cost'
            };

            economicValues = {
                sprintf('%.2f L', result.Diesel_Hybrid_Fuel_L)
                sprintf('%.2f kg', result.Diesel_Hybrid_CO2_kg)
                sprintf('%.2f SEK', result.Diesel_Hybrid_Cost_SEK)
                sprintf('%.2f SEK', costs.EV_System_Cost_SEK)
                sprintf('%.2f SEK', costs.Hybrid_Total_Cost_SEK)
                sprintf('%.2f SEK/kWh', hybridCostPerKWh)
                sprintf('%.2f L', result.Diesel_FullLoad_Fuel_L)
                sprintf('%.2f kg', result.Diesel_FullLoad_CO2_kg)
                sprintf('%.2f SEK', result.Diesel_FullLoad_Cost_SEK)
                sprintf('%.2f SEK/kWh', fullDieselCostPerKWh)
                sprintf('%.2f L', result.Diesel_SameEV_Fuel_L)
                sprintf('%.2f kg', result.Diesel_SameEV_CO2_kg)
                sprintf('%.2f SEK', result.Diesel_SameEV_Cost_SEK)
            };

            app.TechnicalTable.Data = table(technicalNames, technicalValues, ...
                'VariableNames', {'Technical Parameter','Value'});

            app.EconomicTable.Data = table(economicNames, economicValues, ...
                'VariableNames', {'Economic / Environmental Parameter','Value'});

            % Keep the old combined table populated for compatibility if it exists.
            app.ResultsTable.Data = table([technicalNames; economicNames], [technicalValues; economicValues], ...
                'VariableNames', {'Parameter','Value'});

            app.KPI1Value.Text = sprintf('%.1f %%', supplyAvail);
            app.KPI2Value.Text = sprintf('%.2f SEK/kWh', hybridCostPerKWh);
            app.KPI3Value.Text = sprintf('%.1f kWh', result.Total_Unmet_kWh);
            app.KPI4Value.Text = sprintf('%.1f kg', result.Diesel_Hybrid_CO2_kg);
        end

        function plotSingleScenario(app, result)
            hours = 1:length(result.Hourly_Load);
            cla(app.UIAxes);
            plot(app.UIAxes, hours, result.Hourly_Load, 'LineWidth', 1.5);
            hold(app.UIAxes, 'on');
            plot(app.UIAxes, hours, result.Supplied_Load_Hourly, 'LineWidth', 1.5);
            plot(app.UIAxes, hours, result.unmet_Load, 'LineWidth', 1.5);
            hold(app.UIAxes, 'off');
            xlabel(app.UIAxes, 'Hour');
            ylabel(app.UIAxes, 'Energy (kWh)');
            title(app.UIAxes, 'Clinic Load, Supplied Load, and Unmet Load');
            legend(app.UIAxes, {'Clinic Load','Supplied Load','Unmet Load'}, 'Location', 'best');
            grid(app.UIAxes, 'on');
        end

        function ExportButtonPushed(app, ~)
            if isempty(app.lastResult)
                uialert(app.UIFigure, 'Run a simulation first.', 'No Results');
                return;
            end
            [file, path] = uiputfile('Clinic_Backup_Result.xlsx', 'Save Results As');
            if isequal(file, 0)
                app.StatusLabel.Text = 'Export cancelled';
                return;
            end
            result = app.lastResult;
            fullFile = fullfile(path, file);
            summaryTable = app.resultToSummaryRow(result, 1);
            hourlyTable = table((1:length(result.Hourly_Load))', result.Hourly_Load(:), result.Supplied_Load_Hourly(:), result.unmet_Load(:), ...
                'VariableNames', {'Hour','Clinic_Load_kWh','Supplied_Load_kWh','Unmet_Load_kWh'});
            writetable(summaryTable, fullFile, 'Sheet', 'Summary');
            writetable(hourlyTable, fullFile, 'Sheet', 'Hourly_Profiles');
            app.StatusLabel.Text = ['Exported: ', file];
        end

        function RunAllButtonPushed(app, ~)
            if ~app.filesReady(); return; end

            EVB_set = [60 100];
            N_EVs_set = [4 12 20];
            travel_set = [5 10];
            station_set = [20 100 200];
            month_set = 1:12;
            totalRuns = numel(EVB_set)*numel(N_EVs_set)*numel(travel_set)*numel(station_set)*numel(month_set);
            T = table();
            scenarioID = 1;
            counter = 0;

            d = uiprogressdlg(app.UIFigure, 'Title', 'Running Overall Performance', 'Message', 'Please wait...', 'Indeterminate', 'off');
            try
                for evb = EVB_set
                    for n = N_EVs_set
                        for dist = travel_set
                            for sb = station_set
                                for m = month_set
                                    counter = counter + 1;
                                    d.Value = counter / totalRuns;
                                    d.Message = sprintf('Running scenario %d of %d...', counter, totalRuns);
                                    r = simulate_clinic_backup(evb, n, dist, m, false, sb, app.clinicFile, app.solarFile);
                                    T = [T; app.resultToSummaryRow(r, scenarioID)]; %#ok<AGROW>
                                    scenarioID = scenarioID + 1;
                                end
                            end
                        end
                    end
                end
                close(d);
                app.allResultsTable = T;
                app.AllResultsTable.Data = T;
                app.plotOverallPerformance(T);
                app.OverallInfoLabel.Text = sprintf('Completed %d scenarios.', height(T));
                app.StatusLabel.Text = sprintf('Overall performance completed: %d scenarios', height(T));
            catch ME
                try close(d); catch, end
                uialert(app.UIFigure, ME.message, 'Overall Analysis Error');
                app.StatusLabel.Text = 'Overall performance failed';
            end
        end

        function costs = calculateReferenceCosts(app, result) %#ok<INUSD>
            % Cost constants are defined centrally in even_parameters.m
            P = even_parameters();
            solar_LCOE_SEK_per_kWh = P.clinic.solar_LCOE_SEK_per_kWh;
            degradation_SEK_per_kWh = P.clinic.degradation_cost_SEK_per_kWh;

            costs.Energy_Loss_kWh = result.EV_Eff_Losses_kWh + result.Total_Travel_Energy_kWh;
            costs.Battery_Degradation_Cost_SEK = result.Total_Delivered_KWh * degradation_SEK_per_kWh;
            costs.Energy_Cost_SEK = (result.Total_Delivered_KWh + costs.Energy_Loss_kWh) * solar_LCOE_SEK_per_kWh;
            costs.EV_System_Cost_SEK = costs.Battery_Degradation_Cost_SEK + costs.Energy_Cost_SEK;
            costs.Hybrid_Total_Cost_SEK = costs.EV_System_Cost_SEK + result.Diesel_Hybrid_Cost_SEK;
            costs.Hybrid_Cost_per_kWh_SEK = costs.Hybrid_Total_Cost_SEK / max(result.Total_Delivered_KWh, eps);
        end

        function row = resultToSummaryRow(app, result, scenarioID)
            costs = app.calculateReferenceCosts(result);
            totalCost = costs.Hybrid_Total_Cost_SEK;
            supplyAvail = 100 * result.Total_Delivered_KWh / max(result.Total_Demand_kWh, eps);
            costPerKWh = costs.Hybrid_Cost_per_kWh_SEK;
            row = table(scenarioID, {app.monthName(result.Month)}, app.seasonGroup(result.Month), ...
                result.EVB_kWh, result.Num_EVs, result.Travel_km, result.Station_kWh, ...
                result.Total_Demand_kWh, result.Total_Delivered_KWh, result.Total_Unmet_kWh, supplyAvail, ...
                result.Unserved_Hours, result.EV_Eff_Losses_kWh, result.Total_Travel_Energy_kWh, ...
                result.Station_Discharge_kWh, result.Station_Charge_kWh, ...
                result.Diesel_Hybrid_Fuel_L, result.Diesel_Hybrid_CO2_kg, result.Diesel_Hybrid_Cost_SEK, ...
                costs.Energy_Loss_kWh, costs.Battery_Degradation_Cost_SEK, costs.Energy_Cost_SEK, costs.EV_System_Cost_SEK, ...
                totalCost, costPerKWh, ...
                'VariableNames', {'ScenarioID','Month','Season','EVB_kWh','Num_EVs','Travel_km','Station_kWh', ...
                'Total_Demand_kWh','Total_Delivered_KWh','Total_Unmet_kWh','Supply_Availability_pct', ...
                'Unserved_Hours','EV_Eff_Losses_kWh','Total_Travel_Energy_kWh','Station_Discharge_kWh','Station_Charge_kWh', ...
                'Diesel_Hybrid_Fuel_L','Diesel_Hybrid_CO2_kg','Diesel_Hybrid_Cost_SEK', ...
                'Energy_Loss_kWh','Battery_Degradation_Cost_SEK','Energy_Cost_SEK','EV_System_Cost_SEK', ...
                'Total_Cost_SEK','Cost_per_kWh_SEK'});
        end

        function plotOverallPerformance(app, T)
            app.plotClinicScatter(app.AllAxes1, T, 'Spring & Summer', 5, 'Total_Cost_SEK', 'Total_Unmet_kWh', ...
                '(a) Spring & Summer, short distance (5 km)', 'Total Cost (SEK)', 'Total Unmet Load (kWh)');
            app.plotClinicScatter(app.AllAxes2, T, 'Autumn & Winter', 5, 'Total_Cost_SEK', 'Total_Unmet_kWh', ...
                '(b) Autumn & Winter, short distance (5 km)', 'Total Cost (SEK)', 'Total Unmet Load (kWh)');
            app.plotClinicScatter(app.AllAxes3, T, 'Spring & Summer', 10, 'Cost_per_kWh_SEK', 'Supply_Availability_pct', ...
                '(c) Spring & Summer, long distance (10 km)', 'Cost per kWh (SEK/kWh)', 'Supply Availability (%)');
            app.plotClinicScatter(app.AllAxes4, T, 'Autumn & Winter', 10, 'Cost_per_kWh_SEK', 'Supply_Availability_pct', ...
                '(d) Autumn & Winter, long distance (10 km)', 'Cost per kWh (SEK/kWh)', 'Supply Availability (%)');
        end

        function plotClinicScatter(app, ax, T, season, travelKm, xVar, yVar, ttl, xlab, ylab)
            cla(ax); hold(ax, 'on');
            clinicBatteries = [20 100 200];
            colors = [0.47 0.67 0.19; 0.00 0.45 0.74; 0.93 0.49 0.19];
            evBatteries = [60 100];
            markers = {'o','s'};
            evNums = [4 12 20];
            sizes = [25 70 130];
            for isb = 1:numel(clinicBatteries)
                for iev = 1:numel(evBatteries)
                    for in = 1:numel(evNums)
                        idx = strcmp(T.Season, season) & T.Travel_km == travelKm & ...
                              T.Station_kWh == clinicBatteries(isb) & T.EVB_kWh == evBatteries(iev) & T.Num_EVs == evNums(in);
                        if any(idx)
                            scatter(ax, T.(xVar)(idx), T.(yVar)(idx), sizes(in), ...
                                'Marker', markers{iev}, 'MarkerFaceColor', colors(isb,:), ...
                                'MarkerEdgeColor', [0.25 0.25 0.25], 'MarkerFaceAlpha', 0.70, 'LineWidth', 0.7);
                        end
                    end
                end
            end
            title(ax, ttl, 'FontSize', 10, 'FontWeight', 'bold');
            xlabel(ax, xlab, 'FontSize', 9);
            ylabel(ax, ylab, 'FontSize', 9);
            grid(ax, 'on'); box(ax, 'on'); ax.FontSize = 8;
            hold(ax, 'off');
        end

        function ExportAllButtonPushed(app, ~)
            if isempty(app.allResultsTable) || height(app.allResultsTable) == 0
                uialert(app.UIFigure, 'Run all scenarios first.', 'No Overall Results');
                return;
            end
            [file, path] = uiputfile('Clinic_Backup_All_Scenarios.xlsx', 'Save Overall Results As');
            if isequal(file, 0); return; end
            writetable(app.allResultsTable, fullfile(path, file), 'Sheet', 'All_Scenarios');
            app.StatusLabel.Text = ['Overall results exported: ', file];
        end

        function RunSensitivityButtonPushed(app, ~)
            if ~app.filesReady(); return; end
            scenarios = app.buildSensitivityScenarioTable();
            n = height(scenarios);
            d = uiprogressdlg(app.UIFigure, 'Title', 'Running Sensitivity Analysis', 'Message', 'Please wait...', 'Indeterminate', 'off');
            try
                for i = 1:n
                    d.Value = i/n;
                    d.Message = sprintf('Running %s (%d of %d)...', scenarios.Scenario{i}, i, n);
                    r = simulate_clinic_backup(scenarios.EVB_kWh(i), scenarios.Num_EVs(i), scenarios.Distance_km(i), scenarios.MonthNum(i), false, scenarios.Station_kWh(i), app.clinicFile, app.solarFile);
                    costs = app.calculateReferenceCosts(r);
                    scenarios.Total_Cost_SEK(i) = costs.Hybrid_Total_Cost_SEK;
                    scenarios.Cost_per_kWh_SEK(i) = costs.Hybrid_Cost_per_kWh_SEK;
                    scenarios.Energy_Supplied_kWh(i) = r.Total_Delivered_KWh;
                    scenarios.Unmet_Load_kWh(i) = r.Total_Unmet_kWh;
                    scenarios.Energy_Loss_kWh(i) = costs.Energy_Loss_kWh;
                    scenarios.Supply_Availability_pct(i) = 100*r.Total_Delivered_KWh/max(r.Total_Demand_kWh, eps);
                    scenarios.Source_Energy_kWh(i) = r.Total_Delivered_KWh + r.EV_Eff_Losses_kWh + r.Total_Travel_Energy_kWh;
                    scenarios.Delivered_Energy_kWh(i) = r.Total_Delivered_KWh;
                    scenarios.Charging_Loss_kWh(i) = r.EV_Eff_Losses_kWh;
                    scenarios.Driving_Loss_kWh(i) = r.Total_Travel_Energy_kWh;
                end
                close(d);
                app.sensitivityResultsTable = scenarios;
                app.SensitivityScenarioTable.Data = scenarios(:, {'Scenario','VaryingFactor','EVB_kWh','Station_kWh','Num_EVs','Distance_km','MonthName','Total_Cost_SEK','Energy_Supplied_kWh','Unmet_Load_kWh','Energy_Loss_kWh'});
                app.SensitivityFactorDropDown.Items = unique(scenarios.VaryingFactor, 'stable');
                app.SensitivityFactorDropDown.Value = app.SensitivityFactorDropDown.Items{1};
                app.plotSensitivityResults();
                app.updateSensitivityText();
                app.StatusLabel.Text = sprintf('Sensitivity analysis completed: %d scenarios', n);
            catch ME
                try close(d); catch, end
                uialert(app.UIFigure, ME.message, 'Sensitivity Error');
            end
        end

        function T = buildSensitivityScenarioTable(app)
            scen = {}; factor = {}; evb=[]; sb=[]; nev=[]; dist=[]; m=[]; mname={};
            sn = 1;
            % EV battery size variation
            for v = [60 100]
                [scen,factor,evb,sb,nev,dist,m,mname,sn] = app.addSensRow(scen,factor,evb,sb,nev,dist,m,mname,sn,'EV Battery Size',v,100,12,10,6);
            end
            % Stationary battery size variation
            for v = [20 100 200]
                [scen,factor,evb,sb,nev,dist,m,mname,sn] = app.addSensRow(scen,factor,evb,sb,nev,dist,m,mname,sn,'SB Size',60,v,12,10,6);
            end
            % Distance variation
            for v = [5 10]
                [scen,factor,evb,sb,nev,dist,m,mname,sn] = app.addSensRow(scen,factor,evb,sb,nev,dist,m,mname,sn,'Distance',60,100,12,v,6);
            end
            % Number of EVs variation
            for v = [4 12 30]
                [scen,factor,evb,sb,nev,dist,m,mname,sn] = app.addSensRow(scen,factor,evb,sb,nev,dist,m,mname,sn,'No. of EVs',60,100,v,10,6);
            end
            % Month variation
            for v = [1 4 6 9 11]
                [scen,factor,evb,sb,nev,dist,m,mname,sn] = app.addSensRow(scen,factor,evb,sb,nev,dist,m,mname,sn,'Month',60,100,12,10,v);
            end
            T = table(scen, factor, evb, sb, nev, dist, m, mname, ...
                'VariableNames', {'Scenario','VaryingFactor','EVB_kWh','Station_kWh','Num_EVs','Distance_km','MonthNum','MonthName'});
            T.Total_Cost_SEK = zeros(height(T),1);
            T.Cost_per_kWh_SEK = zeros(height(T),1);
            T.Energy_Supplied_kWh = zeros(height(T),1);
            T.Unmet_Load_kWh = zeros(height(T),1);
            T.Energy_Loss_kWh = zeros(height(T),1);
            T.Supply_Availability_pct = zeros(height(T),1);
            T.Source_Energy_kWh = zeros(height(T),1);
            T.Delivered_Energy_kWh = zeros(height(T),1);
            T.Charging_Loss_kWh = zeros(height(T),1);
            T.Driving_Loss_kWh = zeros(height(T),1);
        end

        function [scen,factor,evb,sb,nev,dist,m,mname,sn] = addSensRow(app,scen,factor,evb,sb,nev,dist,m,mname,sn,f,e,b,n,d,mon)
            scen{end+1,1} = sprintf('SN%d', sn); sn = sn + 1;
            factor{end+1,1} = f;
            evb(end+1,1) = e; sb(end+1,1) = b; nev(end+1,1) = n; dist(end+1,1) = d; m(end+1,1) = mon;
            mn = app.monthNames(); mname{end+1,1} = mn{mon};
        end

        function SensitivityFactorDropDownValueChanged(app, ~)
            app.plotSensitivityResults();
            app.updateSensitivityText();
        end

        function plotSensitivityResults(app)
            T = app.sensitivityResultsTable;
            if isempty(T) || height(T) == 0; return; end
            factor = app.SensitivityFactorDropDown.Value;
            G = T(strcmp(T.VaryingFactor, factor), :);
            app.plotRadar(app.SensitivityRadarAxes, G, factor);
            app.plotEnergyBars(app.SensitivityBarAxes, T);
        end

        function plotRadar(app, ax, G, factorName)
            cla(ax);
            if isempty(G) || height(G) == 0
                return;
            end

            metrics = {'Total Cost (SEK)', 'Energy Supplied (kWh)', 'Unmet load (kWh)', 'Energy Loss (kWh)'};
            M = [G.Total_Cost_SEK, G.Energy_Supplied_kWh, G.Unmet_Load_kWh, G.Energy_Loss_kWh];

            maxVals = max(M, [], 1);
            maxVals(maxVals <= 0 | isnan(maxVals)) = 1;
            axesLimits = [zeros(1, numel(maxVals)); maxVals * 1.15];

            labels = cell(height(G),1);
            for i = 1:height(G)
                labels{i} = app.sensitivityLegendLabel(G(i,:));
            end

            baseColors = [
                0.93, 0.49, 0.19
                0.02, 0.02, 0.57
                0.50, 0.03, 0.09
                0.10, 0.55, 0.20
                0.45, 0.18, 0.75
                0.20, 0.55, 0.55];

            if height(G) <= size(baseColors,1)
                colors = baseColors(1:height(G),:);
            else
                colors = lines(height(G));
            end

            switch factorName
                case 'EV Battery Size'
                    plotTitle = 'EV battery size variation';
                case 'SB Size'
                    plotTitle = 'Stationary battery size variation';
                case 'Distance'
                    plotTitle = 'Distance variation';
                case 'No. of EVs'
                    plotTitle = 'Number of EVs variation';
                case 'Month'
                    plotTitle = 'Month variation';
                otherwise
                    plotTitle = factorName;
            end

            radarOpts = struct('Rings', 4, 'Precision', [0 1 1 1], 'FillAlpha', 0.22, ...
                'LineWidth', 1.8, 'MarkerSize', 35, 'AxisFontSize', 9, 'LabelFontSize', 11, ...
                'LabelOffset', 0.25);
            h = even_radar_plot(ax, M, metrics, axesLimits, colors, radarOpts);
            title(ax, plotTitle, 'FontSize', 13, 'FontWeight', 'bold');
            legend(ax, h, labels, 'Location', 'eastoutside', 'FontSize', 9);
        end

        function s = sensitivityLegendLabel(app, row)
            f = row.VaryingFactor{1};
            switch f
                case 'EV Battery Size'
                    s = sprintf('%s (%d kWh)', row.Scenario{1}, row.EVB_kWh);
                case 'SB Size'
                    s = sprintf('%s (%d kWh)', row.Scenario{1}, row.Station_kWh);
                case 'Distance'
                    s = sprintf('%s (%d km)', row.Scenario{1}, row.Distance_km);
                case 'No. of EVs'
                    s = sprintf('%s (%d EVs)', row.Scenario{1}, row.Num_EVs);
                case 'Month'
                    s = sprintf('%s (%s)', row.Scenario{1}, row.MonthName{1});
                otherwise
                    s = row.Scenario{1};
            end
        end

        function plotEnergyBars(app, ax, T)
            cla(ax);
            X = categorical(T.Scenario); X = reordercats(X, T.Scenario);
            Y = [T.Source_Energy_kWh, T.Delivered_Energy_kWh, T.Charging_Loss_kWh, T.Driving_Loss_kWh];
            bar(ax, X, Y, 'grouped', 'EdgeColor', 'none');
            ylabel(ax, 'Energy (kWh)');
            title(ax, 'Energy Efficiency for Representative Clinic Backup Scenarios', 'FontWeight','bold');
            legend(ax, {'Total Source Energy','Delivered Energy','Charging Loss','Driving Loss'}, 'Location','northoutside', 'Orientation','horizontal');
            grid(ax,'on'); ax.XTickLabelRotation = 45;
        end

        function updateSensitivityText(app)
            T = app.sensitivityResultsTable;
            if isempty(T) || height(T)==0; return; end
            [~, bestIdx] = max(T.Supply_Availability_pct);
            [~, lowCostIdx] = min(T.Total_Cost_SEK);
            [~, unmetIdx] = max(T.Unmet_Load_kWh);
            app.SensitivityAnalysisText.Value = {
                'Sensitivity interpretation'; '';
                sprintf('Best supply availability: %s = %.2f %%', T.Scenario{bestIdx}, T.Supply_Availability_pct(bestIdx));
                sprintf('Lowest total cost: %s = %.2f SEK', T.Scenario{lowCostIdx}, T.Total_Cost_SEK(lowCostIdx));
                sprintf('Highest unmet load: %s = %.2f kWh', T.Scenario{unmetIdx}, T.Unmet_Load_kWh(unmetIdx)); '';
                'Radar plot compares total cost, delivered energy, unmet load, and energy loss for one varying factor.';
                'Grouped bars compare source energy, delivered energy, charging losses, and driving losses.'};
        end

        function ExportSensitivityButtonPushed(app, ~)
            if isempty(app.sensitivityResultsTable) || height(app.sensitivityResultsTable) == 0
                uialert(app.UIFigure, 'Run sensitivity analysis first.', 'No Sensitivity Results'); return;
            end
            [file, path] = uiputfile('Clinic_Backup_Sensitivity.xlsx', 'Save Sensitivity Results As');
            if isequal(file, 0); return; end
            writetable(app.sensitivityResultsTable, fullfile(path, file), 'Sheet', 'Sensitivity_Scenarios');
            app.StatusLabel.Text = ['Sensitivity results exported: ', file];
        end

        function names = monthNames(app) %#ok<MANU>
            names = {'January','February','March','April','May','June','July','August','September','October','November','December'};
        end

        function name = monthName(app, monthNum)
            names = app.monthNames();
            name = names{monthNum};
        end

        function season = seasonGroup(app, monthNum) %#ok<MANU>
            if ismember(monthNum, 4:9)
                season = {'Spring & Summer'};
            else
                season = {'Autumn & Winter'};
            end
        end
    end

    methods (Access = private)

        function createComponents(app)
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [80 80 1250 720];
            app.UIFigure.Name = 'EVEN Toolkit - Critical Infrastructure';
            app.UIFigure.Color = [1 1 1];

            app.HeaderPanel = uipanel(app.UIFigure);
            app.HeaderPanel.Position = [0 620 1250 100];
            app.HeaderPanel.BackgroundColor = [0.02 0.16 0.32];
            app.HeaderPanel.BorderType = 'none';

            app.TitleLabel = uilabel(app.HeaderPanel);
            app.TitleLabel.Position = [30 50 1190 40];
            app.TitleLabel.Text = 'Critical Infrastructure: EV Fleet Backup for a Health Clinic';
            app.TitleLabel.FontSize = 25;
            app.TitleLabel.FontWeight = 'bold';
            app.TitleLabel.FontColor = [1 1 1];
            app.TitleLabel.HorizontalAlignment = 'center';

            app.SubtitleLabel = uilabel(app.HeaderPanel);
            app.SubtitleLabel.Position = [30 18 1190 26];
            app.SubtitleLabel.Text = 'EVEN Toolkit  |  Long-term backup by an EV fleet with solar and a stationary battery, compared with diesel';
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

            % Single scenario tab
            app.SetupPanel = uipanel(app.SingleTab);
            app.SetupPanel.Position = [10 10 310 510];
            app.SetupPanel.Title = 'Scenario Setup';
            app.SetupPanel.FontWeight = 'bold';
            app.SetupPanel.FontSize = 14;
            app.SetupPanel.BackgroundColor = [1 1 1];

            app.UploadClinicButton = uibutton(app.SetupPanel, 'push');
            app.UploadClinicButton.Position = [25 440 260 32];
            app.UploadClinicButton.Text = 'Upload Clinic MAT';
            app.UploadClinicButton.FontWeight = 'bold';
            app.UploadClinicButton.BackgroundColor = [0.00 0.45 0.74];
            app.UploadClinicButton.FontColor = [1 1 1];
            app.UploadClinicButton.ButtonPushedFcn = @(src,event) UploadClinicButtonPushed(app,event);

            app.ClinicFileLabel = uilabel(app.SetupPanel);
            app.ClinicFileLabel.Position = [25 412 260 22];
            app.ClinicFileLabel.Text = 'No clinic MAT uploaded';

            app.UploadSolarButton = uibutton(app.SetupPanel, 'push');
            app.UploadSolarButton.Position = [25 372 260 32];
            app.UploadSolarButton.Text = 'Upload Solar MAT';
            app.UploadSolarButton.FontWeight = 'bold';
            app.UploadSolarButton.BackgroundColor = [0.00 0.45 0.74];
            app.UploadSolarButton.FontColor = [1 1 1];
            app.UploadSolarButton.ButtonPushedFcn = @(src,event) UploadSolarButtonPushed(app,event);

            app.SolarFileLabel = uilabel(app.SetupPanel);
            app.SolarFileLabel.Position = [25 344 260 22];
            app.SolarFileLabel.Text = 'No solar MAT uploaded';

            uilabel(app.SetupPanel, 'Position', [25 305 130 22], 'Text', 'EV Battery kWh', 'FontWeight', 'bold');
            app.EVBDropDown = uidropdown(app.SetupPanel);
            app.EVBDropDown.Position = [165 305 120 24];
            app.EVBDropDown.Items = {'60','100'};
            app.EVBDropDown.Value = '60';
            app.EVBDropDown.Editable = 'on';
            app.EVBDropDown.Tooltip = 'Select a preset or type any value between 10 and 250 kWh.';

            uilabel(app.SetupPanel, 'Position', [25 265 130 22], 'Text', 'Number of EVs', 'FontWeight', 'bold');
            app.NumEVDropDown = uidropdown(app.SetupPanel);
            app.NumEVDropDown.Position = [165 265 120 24];
            app.NumEVDropDown.Items = {'4','8','12','20','30'};
            app.NumEVDropDown.Value = '4';
            app.NumEVDropDown.Editable = 'on';
            app.NumEVDropDown.Tooltip = 'Select a preset or type a whole number of vehicles (1 to 200).';

            uilabel(app.SetupPanel, 'Position', [25 225 130 22], 'Text', 'Travel km', 'FontWeight', 'bold');
            app.TravelDropDown = uidropdown(app.SetupPanel);
            app.TravelDropDown.Position = [165 225 120 24];
            app.TravelDropDown.Items = {'5','10'};
            app.TravelDropDown.Value = '5';
            app.TravelDropDown.Editable = 'on';
            app.TravelDropDown.Tooltip = 'Select a preset or type any value between 0 and 200 km.';

            uilabel(app.SetupPanel, 'Position', [25 185 130 22], 'Text', 'Month', 'FontWeight', 'bold');
            app.MonthDropDown = uidropdown(app.SetupPanel);
            app.MonthDropDown.Position = [165 185 120 24];
            app.MonthDropDown.Items = app.monthNames();
            app.MonthDropDown.Value = 'January';

            uilabel(app.SetupPanel, 'Position', [25 145 130 22], 'Text', 'Station kWh', 'FontWeight', 'bold');
            app.StationDropDown = uidropdown(app.SetupPanel);
            app.StationDropDown.Position = [165 145 120 24];
            app.StationDropDown.Items = {'20','100','200'};
            app.StationDropDown.Value = '100';
            app.StationDropDown.Editable = 'on';
            app.StationDropDown.Tooltip = 'Select a preset or type any value between 0 and 5000 kWh.';

            app.RunButton = uibutton(app.SetupPanel, 'push');
            app.RunButton.Position = [25 82 260 34];
            app.RunButton.Text = 'Run Simulation';
            app.RunButton.FontWeight = 'bold';
            app.RunButton.BackgroundColor = [0.10 0.55 0.20];
            app.RunButton.FontColor = [1 1 1];
            app.RunButton.ButtonPushedFcn = @(src,event) RunButtonPushed(app,event);

            app.ExportButton = uibutton(app.SetupPanel, 'push');
            app.ExportButton.Position = [25 38 260 30];
            app.ExportButton.Text = 'Export Excel';
            app.ExportButton.BackgroundColor = [0.90 0.50 0.10];
            app.ExportButton.FontColor = [1 1 1];
            app.ExportButton.ButtonPushedFcn = @(src,event) ExportButtonPushed(app,event);

            app.TechnicalPanel = uipanel(app.SingleTab);
            app.TechnicalPanel.Position = [345 300 405 210];
            app.TechnicalPanel.Title = 'Technical Performance';
            app.TechnicalPanel.FontWeight = 'bold';
            app.TechnicalPanel.FontSize = 14;
            app.TechnicalPanel.BackgroundColor = [1 1 1];
            app.TechnicalPanel.HighlightColor = [0.00 0.35 0.70];

            app.TechnicalTable = uitable(app.TechnicalPanel);
            app.TechnicalTable.Position = [15 15 375 160];

            app.EconomicPanel = uipanel(app.SingleTab);
            app.EconomicPanel.Position = [775 300 405 210];
            app.EconomicPanel.Title = 'Economic and Environmental Performance';
            app.EconomicPanel.FontWeight = 'bold';
            app.EconomicPanel.FontSize = 14;
            app.EconomicPanel.BackgroundColor = [1 1 1];
            app.EconomicPanel.HighlightColor = [0.10 0.55 0.20];

            app.EconomicTable = uitable(app.EconomicPanel);
            app.EconomicTable.Position = [15 15 375 160];

            % Hidden compatibility table used by older export/result logic.
            app.ResultsPanel = uipanel(app.SingleTab);
            app.ResultsPanel.Position = [5 5 1 1];
            app.ResultsPanel.Visible = 'off';
            app.ResultsTable = uitable(app.ResultsPanel);
            app.ResultsTable.Position = [1 1 1 1];

            app.KPI1Panel = uipanel(app.SingleTab);
            app.KPI1Panel.Position = [345 225 190 55];
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
            app.KPI2Panel.Position = [560 225 190 55];
            app.KPI2Panel.BackgroundColor = [0.97 1 0.97];

            app.KPI2Title = uilabel(app.KPI2Panel);
            app.KPI2Title.Position = [10 30 170 18];
            app.KPI2Title.Text = 'Hybrid Cost per kWh';
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
            app.KPI3Title.Text = 'Unmet Load';
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
            app.KPI4Title.Text = 'Hybrid CO2 Emissions';
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

            app.PlotPanel = uipanel(app.SingleTab);
            app.PlotPanel.Position = [345 15 840 195];
            app.PlotPanel.Title = 'Hourly Clinic Backup Performance';
            app.PlotPanel.FontWeight = 'bold';
            app.PlotPanel.BackgroundColor = [1 1 1];

            app.UIAxes = uiaxes(app.PlotPanel);
            app.UIAxes.Position = [15 10 810 150];

            % Overall tab - revised professional layout
            % Left column: controls and plot encoding. Right side: large plots.
            % Bottom: larger full-width results table.
            app.OverallControlPanel = uipanel(app.OverallTab);
            app.OverallControlPanel.Position = [10 400 300 120];
            app.OverallControlPanel.Title = 'Overall Scenario Analysis';
            app.OverallControlPanel.FontWeight = 'bold';
            app.OverallControlPanel.FontSize = 12;
            app.OverallControlPanel.BackgroundColor = [1 1 1];
            app.OverallControlPanel.HighlightColor = [0.02 0.16 0.32];

            app.RunAllButton = uibutton(app.OverallControlPanel, 'push');
            app.RunAllButton.Position = [20 62 260 32];
            app.RunAllButton.Text = 'Run All Scenarios';
            app.RunAllButton.FontWeight = 'bold';
            app.RunAllButton.BackgroundColor = [0.10 0.55 0.20];
            app.RunAllButton.FontColor = [1 1 1];
            app.RunAllButton.ButtonPushedFcn = @(src,event) RunAllButtonPushed(app,event);

            app.ExportAllButton = uibutton(app.OverallControlPanel, 'push');
            app.ExportAllButton.Position = [20 24 260 30];
            app.ExportAllButton.Text = 'Export Overall Results';
            app.ExportAllButton.FontWeight = 'bold';
            app.ExportAllButton.BackgroundColor = [0.90 0.50 0.10];
            app.ExportAllButton.FontColor = [1 1 1];
            app.ExportAllButton.ButtonPushedFcn = @(src,event) ExportAllButtonPushed(app,event);

            app.OverallInfoLabel = uilabel(app.OverallControlPanel);
            app.OverallInfoLabel.Position = [20 2 260 20];
            app.OverallInfoLabel.Text = 'Upload MAT files, then run all scenarios.';
            app.OverallInfoLabel.FontSize = 11;
            app.OverallInfoLabel.FontColor = [0.25 0.25 0.25];
            app.OverallInfoLabel.HorizontalAlignment = 'center';

            app.OverallEncodingPanel = uipanel(app.OverallTab);
            app.OverallEncodingPanel.Position = [10 190 300 200];
            app.OverallEncodingPanel.Title = 'Plot Encoding';
            app.OverallEncodingPanel.FontWeight = 'bold';
            app.OverallEncodingPanel.FontSize = 12;
            app.OverallEncodingPanel.BackgroundColor = [1 1 1];
            app.OverallEncodingPanel.HighlightColor = [0.02 0.16 0.32];

            % Encoding legend arranged vertically for readability.
            uilabel(app.OverallEncodingPanel, 'Position', [18 154 260 20], ...
                'Text', 'Color = station battery capacity', 'FontSize', 11, 'FontWeight', 'bold');
            uilabel(app.OverallEncodingPanel, 'Position', [35 132 90 20], ...
                'Text', [char(9679) '  20 kWh'], 'FontSize', 12, 'FontColor', [0.47 0.67 0.19]);
            uilabel(app.OverallEncodingPanel, 'Position', [135 132 95 20], ...
                'Text', [char(9679) '  100 kWh'], 'FontSize', 12, 'FontColor', [0.00 0.45 0.74]);
            uilabel(app.OverallEncodingPanel, 'Position', [35 112 95 20], ...
                'Text', [char(9679) '  200 kWh'], 'FontSize', 12, 'FontColor', [0.93 0.49 0.19]);

            uilabel(app.OverallEncodingPanel, 'Position', [18 83 260 20], ...
                'Text', 'Shape = EV battery size', 'FontSize', 11, 'FontWeight', 'bold');
            uilabel(app.OverallEncodingPanel, 'Position', [35 62 85 20], ...
                'Text', [char(9679) '  60 kWh'], 'FontSize', 12, 'FontColor', [0.20 0.20 0.20]);
            uilabel(app.OverallEncodingPanel, 'Position', [135 62 95 20], ...
                'Text', [char(9632) '  100 kWh'], 'FontSize', 12, 'FontColor', [0.20 0.20 0.20]);

            uilabel(app.OverallEncodingPanel, 'Position', [18 34 260 20], ...
                'Text', 'Marker size = number of EVs', 'FontSize', 11, 'FontWeight', 'bold');
            uilabel(app.OverallEncodingPanel, 'Position', [35 12 65 20], ...
                'Text', [char(8226) '  4 EVs'], 'FontSize', 12, 'FontColor', [0.20 0.20 0.20]);
            uilabel(app.OverallEncodingPanel, 'Position', [112 12 75 20], ...
                'Text', [char(9679) '  12 EVs'], 'FontSize', 12, 'FontColor', [0.20 0.20 0.20]);
            uilabel(app.OverallEncodingPanel, 'Position', [205 9 80 24], ...
                'Text', [char(11044) '  20 EVs'], 'FontSize', 15, 'FontColor', [0.20 0.20 0.20]);

            PlotAreaPanel = uipanel(app.OverallTab);
            PlotAreaPanel.Position = [330 190 865 330];
            PlotAreaPanel.Title = 'Seasonal Overall Performance Plots';
            PlotAreaPanel.FontWeight = 'bold';
            PlotAreaPanel.FontSize = 12;
            PlotAreaPanel.BackgroundColor = [1 1 1];

            app.AllAxes1 = uiaxes(PlotAreaPanel);
            app.AllAxes1.Position = [25 170 400 125];
            app.AllAxes2 = uiaxes(PlotAreaPanel);
            app.AllAxes2.Position = [445 170 400 125];
            app.AllAxes3 = uiaxes(PlotAreaPanel);
            app.AllAxes3.Position = [25 25 400 125];
            app.AllAxes4 = uiaxes(PlotAreaPanel);
            app.AllAxes4.Position = [445 25 400 125];

            TablePanel = uipanel(app.OverallTab);
            TablePanel.Position = [10 10 1185 170];
            TablePanel.Title = 'Overall Scenario Results';
            TablePanel.FontWeight = 'bold';
            TablePanel.FontSize = 12;
            TablePanel.BackgroundColor = [1 1 1];

            app.AllResultsTable = uitable(TablePanel);
            app.AllResultsTable.Position = [10 8 1165 135];
            app.AllResultsTable.FontSize = 11;

            % Sensitivity tab
            app.SensitivityControlPanel = uipanel(app.SensitivityTab);
            app.SensitivityControlPanel.Position = [10 380 285 130];
            app.SensitivityControlPanel.Title = 'Representative Scenario Sensitivity';
            app.SensitivityControlPanel.FontWeight = 'bold';
            app.SensitivityControlPanel.BackgroundColor = [1 1 1];

            app.SensitivityInfoLabel = uilabel(app.SensitivityControlPanel);
            app.SensitivityInfoLabel.Position = [15 78 255 25];
            app.SensitivityInfoLabel.Text = 'Run representative clinic backup sensitivity scenarios.';
            app.SensitivityInfoLabel.WordWrap = 'on';

            uilabel(app.SensitivityControlPanel, 'Position', [15 53 95 20], 'Text', 'Factor:', 'FontWeight', 'bold');
            app.SensitivityFactorDropDown = uidropdown(app.SensitivityControlPanel);
            app.SensitivityFactorDropDown.Position = [78 53 192 22];
            app.SensitivityFactorDropDown.Items = {'EV Battery Size','SB Size','Distance','No. of EVs','Month'};
            app.SensitivityFactorDropDown.ValueChangedFcn = @(src,event) SensitivityFactorDropDownValueChanged(app,event);

            app.RunSensitivityButton = uibutton(app.SensitivityControlPanel, 'push');
            app.RunSensitivityButton.Position = [15 25 255 25];
            app.RunSensitivityButton.Text = 'Run Sensitivity Analysis';
            app.RunSensitivityButton.FontWeight = 'bold';
            app.RunSensitivityButton.BackgroundColor = [0.10 0.55 0.20];
            app.RunSensitivityButton.FontColor = [1 1 1];
            app.RunSensitivityButton.ButtonPushedFcn = @(src,event) RunSensitivityButtonPushed(app,event);

            app.ExportSensitivityButton = uibutton(app.SensitivityControlPanel, 'push');
            app.ExportSensitivityButton.Position = [15 0 255 22];
            app.ExportSensitivityButton.Text = 'Export Sensitivity Results';
            app.ExportSensitivityButton.BackgroundColor = [0.90 0.50 0.10];
            app.ExportSensitivityButton.FontColor = [1 1 1];
            app.ExportSensitivityButton.ButtonPushedFcn = @(src,event) ExportSensitivityButtonPushed(app,event);

            app.SensitivityScenarioTable = uitable(app.SensitivityTab);
            app.SensitivityScenarioTable.Position = [10 15 285 350];

            app.SensitivityRadarAxes = uiaxes(app.SensitivityTab);
            app.SensitivityRadarAxes.Position = [320 225 620 285];

            app.SensitivityBarAxes = uiaxes(app.SensitivityTab);
            app.SensitivityBarAxes.Position = [320 25 860 180];

            app.SensitivityAnalysisText = uitextarea(app.SensitivityTab);
            app.SensitivityAnalysisText.Position = [960 300 220 190];
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
        function app = Clinic_Backup_GUI_App
            createComponents(app)
            startupFcn(app)
        end

        function delete(app)
            delete(app.UIFigure)
        end
    end
end
