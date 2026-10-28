classdef Community_Microgrid_GUI_App < matlab.apps.AppBase

    properties (Access = public)
        UIFigure matlab.ui.Figure
        HeaderPanel matlab.ui.container.Panel
        TitleLabel matlab.ui.control.Label
        SubtitleLabel matlab.ui.control.Label
        TabGroup matlab.ui.container.TabGroup
        SingleTab matlab.ui.container.Tab
        OverallTab matlab.ui.container.Tab
        ParametricTab matlab.ui.container.Tab

        SetupPanel matlab.ui.container.Panel
        UploadMGButton matlab.ui.control.Button
        UploadHHLoadButton matlab.ui.control.Button
        UploadHHPVButton matlab.ui.control.Button
        DataStatusLabel matlab.ui.control.Label
        MGSupplyDropDown matlab.ui.control.DropDown
        DemandCutDropDown matlab.ui.control.DropDown
        EVPenDropDown matlab.ui.control.DropDown
        EVBatteryDropDown matlab.ui.control.DropDown
        PVPenDropDown matlab.ui.control.DropDown
        BatteryPenDropDown matlab.ui.control.DropDown
        InverterDropDown matlab.ui.control.DropDown
        AuctionDropDown matlab.ui.control.DropDown
        MGBatteryDropDown matlab.ui.control.DropDown
        RunButton matlab.ui.control.Button
        ExportButton matlab.ui.control.Button
        ResetButton matlab.ui.control.Button

        TechnicalPanel matlab.ui.container.Panel
        ResiliencePanel matlab.ui.container.Panel
        TechnicalTable matlab.ui.control.Table
        ResilienceTable matlab.ui.control.Table
        KPI1Panel matlab.ui.container.Panel
        KPI2Panel matlab.ui.container.Panel
        KPI3Panel matlab.ui.container.Panel
        KPI4Panel matlab.ui.container.Panel
        KPI1Value matlab.ui.control.Label
        KPI2Value matlab.ui.control.Label
        KPI3Value matlab.ui.control.Label
        KPI4Value matlab.ui.control.Label
        SingleAxes matlab.ui.control.UIAxes

        OverallControlPanel matlab.ui.container.Panel
        OverallViewDropDown matlab.ui.control.DropDown
        RefreshOverallButton matlab.ui.control.Button
        ExportOverallButton matlab.ui.control.Button
        OverallInfoLabel matlab.ui.control.Label
        OverallAxes1 matlab.ui.control.UIAxes
        OverallAxes2 matlab.ui.control.UIAxes
        OverallAxes3 matlab.ui.control.UIAxes
        OverallAxes4 matlab.ui.control.UIAxes
        OverallTable matlab.ui.control.Table

        ParamControlPanel matlab.ui.container.Panel
        ParamGroupDropDown matlab.ui.control.DropDown
        LoadParamButton matlab.ui.control.Button
        GenerateParamButton matlab.ui.control.Button
        ExportParamButton matlab.ui.control.Button
        ParamInfoLabel matlab.ui.control.Label
        ParamAxes1 matlab.ui.control.UIAxes
        ParamAxes2 matlab.ui.control.UIAxes
        ParamAxes3 matlab.ui.control.UIAxes
        ParamAxes4 matlab.ui.control.UIAxes
        ParamTable matlab.ui.control.Table
        ParamText matlab.ui.control.TextArea

        StatusLabel matlab.ui.control.Label
    end

    properties (Access = private)
        codeFolder string = ""
        mgDataFile string = ""
        hhLoadFile string = ""
        hhPVFile string = ""
        lastResults struct = struct()
        paramData struct = struct()
    end

    methods (Access = private)

        function startupFcn(app)
            app.codeFolder = string(fileparts(mfilename('fullpath')));
            app.StatusLabel.Text = 'Ready - upload the three annual input MAT files.';
            app.DataStatusLabel.Text = 'MG: not loaded  |  HH load: not loaded  |  HH PV: not loaded';
            app.OverallInfoLabel.Text = 'Run a community scenario first.';
            app.ParamInfoLabel.Text = 'Load stored results, or generate them from the files uploaded on the first tab.';
        end

        function UploadMGData(app, ~)
            [f,p] = uigetfile('*.mat','Select MG supply and demand MAT file');
            if isequal(f,0), return; end
            app.mgDataFile = string(fullfile(p,f));
            app.updateDataStatus();
            app.StatusLabel.Text = ['MG data uploaded: ' f];
        end

        function UploadHHLoadData(app, ~)
            [f,p] = uigetfile('*.mat','Select household load MAT file');
            if isequal(f,0), return; end
            app.hhLoadFile = string(fullfile(p,f));
            app.updateDataStatus();
            app.StatusLabel.Text = ['Household load uploaded: ' f];
        end

        function UploadHHPVData(app, ~)
            [f,p] = uigetfile('*.mat','Select household PV supply MAT file');
            if isequal(f,0), return; end
            app.hhPVFile = string(fullfile(p,f));
            app.updateDataStatus();
            app.StatusLabel.Text = ['Household PV data uploaded: ' f];
        end

        function updateDataStatus(app)
            mg = 'not loaded'; hh = 'not loaded'; pv = 'not loaded';
            if strlength(app.mgDataFile)>0, [~,n,e]=fileparts(char(app.mgDataFile)); mg=[n e]; end
            if strlength(app.hhLoadFile)>0, [~,n,e]=fileparts(char(app.hhLoadFile)); hh=[n e]; end
            if strlength(app.hhPVFile)>0, [~,n,e]=fileparts(char(app.hhPVFile)); pv=[n e]; end
            app.DataStatusLabel.Text = sprintf('MG: %s  |  HH load: %s  |  HH PV: %s',mg,hh,pv);
        end

        function tf = validateInputs(app)
            tf = false;
            if strlength(app.mgDataFile)==0 || ~isfile(app.mgDataFile)
                uialert(app.UIFigure,'Please upload the MG supply-demand MAT file.','Missing MG Data'); return;
            end
            if strlength(app.hhLoadFile)==0 || ~isfile(app.hhLoadFile)
                uialert(app.UIFigure,'Please upload the household load MAT file.','Missing Household Load'); return;
            end
            if strlength(app.hhPVFile)==0 || ~isfile(app.hhPVFile)
                uialert(app.UIFigure,'Please upload the household PV supply MAT file.','Missing Household PV Data'); return;
            end
            required = {'even_run_scenario.m','even_annual_simulation.m','even_run_parametric.m','even_parameters.m','f_MG_OnlyBattery.m','f_BatteryOnly.m', ...
                'f_AuctionAndBalancingMarket_V2MG.m','func_rainflow.m','func_dod_cycle.m'};
            missing = {};
            for i=1:numel(required)
                if ~isfile(fullfile(app.codeFolder,required{i})), missing{end+1}=required{i}; end %#ok<AGROW>
            end
            if ~isempty(missing)
                uialert(app.UIFigure,sprintf('Keep these code files in the same folder as the GUI:\n%s',strjoin(missing,newline)),'Missing Code Files'); return;
            end
            tf = true;
        end

        function RunButtonPushed(app, ~)
            if ~app.validateInputs(), return; end

            % Custom values typed into the editable dropdowns are validated
            % here, before they are written into the simulation parameters.
            [demandCutPct, okCut]  = app.parseCustomValue(app.DemandCutDropDown.Value, ...
                'Demand reduction', 0, 90, false, 'percent');
            [evPenPct, okEVPen]    = app.parseCustomValue(app.EVPenDropDown.Value, ...
                'EV penetration level', 0.1, 100, false, 'percent');
            [evBattery, okEVB]     = app.parseCustomValue(app.EVBatteryDropDown.Value, ...
                'EV battery capacity', 10, 250, false, 'kWh');
            [pvPenPct, okPVPen]    = app.parseCustomValue(app.PVPenDropDown.Value, ...
                'PV penetration level', 0, 100, false, 'percent');
            [batPenPct, okBatPen]  = app.parseCustomValue(app.BatteryPenDropDown.Value, ...
                'PV battery deployment', 0, 100, false, 'percent');
            [mgBattery, okMGB]     = app.parseCustomValue(app.MGBatteryDropDown.Value, ...
                'MG battery capacity', 0, 50000, false, 'kWh');

            if ~(okCut && okEVPen && okEVB && okPVPen && okBatPen && okMGB)
                return;
            end

            if evPenPct > 50
                choice = uiconfirm(app.UIFigure, sprintf(['An EV penetration of %g percent means roughly %d ' ...
                    'households are simulated over a full year. This can take a long time. Continue?'], ...
                    evPenPct, round(5357*evPenPct/100)), 'Long Simulation', ...
                    'Options',{'Continue','Cancel'}, 'DefaultOption',2, 'Icon','warning');
                if strcmp(choice,'Cancel')
                    return;
                end
            end

            dlg = uiprogressdlg(app.UIFigure,'Title','Running Community Scenario', ...
                'Message','Running the annual simulation. This may take several minutes...','Indeterminate','on');
            cleanupDlg = onCleanup(@() delete(dlg));

            try
                % Build the scenario and run it. The simulation executes
                % inside even_run_scenario, so the base workspace and the
                % current folder are left untouched.
                scenario = struct();
                scenario.MGFile              = char(app.mgDataFile);
                scenario.HHLoadFile          = char(app.hhLoadFile);
                scenario.HHPVFile            = char(app.hhPVFile);
                scenario.MGSupplyCase        = app.MGSupplyDropDown.Value;
                scenario.DemandScale         = 1 - demandCutPct/100;
                scenario.EV_PenetrationLevel = evPenPct/100;
                scenario.PV_penetration      = pvPenPct/100;
                scenario.Battery_penetration = batPenPct/100;
                scenario.scenario_inverter   = app.InverterDropDown.Value;
                scenario.scenario_auction    = app.AuctionDropDown.Value;
                scenario.MG_B                = mgBattery;
                scenario.EVB                 = evBattery;

                app.lastResults = even_run_scenario(scenario);

                % Update the Single Scenario tab directly. Keeping this logic
                % inside the callback avoids method-resolution problems in some
                % MATLAB releases and path configurations.
                R = app.lastResults;
                beforeRatio = nnz(R.Output_daily_EBalance_before < 0) / numel(R.Output_daily_EBalance_before) * 100;
                afterRatio = nnz(R.Output_daily_EBalance_after < 0) / numel(R.Output_daily_EBalance_after) * 100;
                demandAll = [R.MG_daily_demand, R.HH_daily_demand(:,1:R.num_houses)];
                supplyAfter = R.Output_daily_EBalance_after + demandAll;
                demandMet = min(demandAll, supplyAfter);
                P = even_parameters();
                actionDelivery = R.Output_daily_Action(:,2:end);
                evTravelMG = nnz(actionDelivery) * P.community.EV_travel_to_MG_kWh;
                evTravel = nnz(R.Output_daily_EBalance_before(:,2:end) > P.community.EV_travel_kWh_per_day) ...
                    * P.community.EV_travel_kWh_per_day;
                EVsum = evTravelMG + evTravel;
                sc = (sum(demandMet,'all') + EVsum) / (sum(demandAll,'all') + EVsum) * 100;
                localSupply = sum(R.MG_daily_supply) + sum(R.HH_daily_supply(:,1:(R.Num_PV_B+R.Num_PVOnly)),'all');
                ss = (sum(demandMet,'all') + EVsum) / max(localSupply,eps) * 100;
                meanDeg = mean(R.Degradation) * 100;
                trans = sum(abs(R.Output_daily_transition),1) / 1000;
                loss = sum(R.Output_daily_index_Eloss(:,1)) / 1000;

                techNames = {'Participating households';'HH1: EV + PV + battery';'HH2: EV + PV';'HH3: EV only'; ...
                    'Annual MG demand';'Annual MG supply';'MG to consumers';'Prosumers to MG'; ...
                    'Prosumers to consumers';'Transaction energy loss'};
                techValues = [R.num_houses;R.Num_PV_B;R.Num_PVOnly;R.Num_NoPV; ...
                    sum(R.MG_daily_demand)/1000;sum(R.MG_daily_supply)/1000;trans(1);trans(2);trans(3);loss];
                techUnits = {'households';'households';'households';'households'; ...
                    'MWh/year';'MWh/year';'MWh/year';'MWh/year';'MWh/year';'MWh/year'};
                app.TechnicalTable.Data = table(techNames,techValues,techUnits, ...
                    'VariableNames',{'Technical Parameter','Value','Unit'});

                deficitBefore = sum(abs(min(R.Output_daily_EBalance_before,0)),'all') / 1000;
                deficitAfter = sum(abs(min(R.Output_daily_EBalance_after,0)),'all') / 1000;
                resNames = {'Deficit-day ratio before EVEN';'Deficit-day ratio after EVEN';'Deficit-day reduction'; ...
                    'Aggregated self-consumption';'Aggregated self-sufficiency'; ...
                    'Mean EV battery degradation';'Total deficit before';'Total deficit after'};
                resValues = [beforeRatio;afterRatio;beforeRatio-afterRatio;sc;ss;meanDeg;deficitBefore;deficitAfter];
                resUnits = {'%';'%';'percentage points';'%';'%';'%';'MWh/year';'MWh/year'};
                app.ResilienceTable.Data = table(resNames,resValues,resUnits, ...
                    'VariableNames',{'Resilience Parameter','Value','Unit'});

                app.KPI1Value.Text = sprintf('%.1f %%',beforeRatio-afterRatio);
                app.KPI2Value.Text = sprintf('%.1f %%',sc);
                app.KPI3Value.Text = sprintf('%.1f %%',ss);
                app.KPI4Value.Text = sprintf('%.2f %%',meanDeg);

                cla(app.SingleAxes);
                hold(app.SingleAxes,'on');
                plot(app.SingleAxes,sum(R.Output_daily_EBalance_before,2)/1000,'LineWidth',1.2);
                plot(app.SingleAxes,sum(R.Output_daily_EBalance_after,2)/1000,'LineWidth',1.5);
                yline(app.SingleAxes,0,'--');
                hold(app.SingleAxes,'off');
                grid(app.SingleAxes,'on');
                xlabel(app.SingleAxes,'Day of year');
                ylabel(app.SingleAxes,'Community energy balance (MWh)');
                title(app.SingleAxes,'Community Energy Balance Before and After EVEN','FontWeight','bold');
                legend(app.SingleAxes,{'Before EVEN','After EVEN'},'Location','best');

                % Populate the overall dashboard directly.
                axs = [app.OverallAxes1 app.OverallAxes2 app.OverallAxes3 app.OverallAxes4];
                for ax = axs
                    cla(ax);
                end
                plot(app.OverallAxes1,R.Output_daily_EBalance_before(:,1)/1000,'LineWidth',1.1);
                hold(app.OverallAxes1,'on');
                plot(app.OverallAxes1,R.Output_daily_EBalance_after(:,1)/1000,'LineWidth',1.3);
                yline(app.OverallAxes1,0,'--');
                hold(app.OverallAxes1,'off');
                title(app.OverallAxes1,'Microgrid Balance');
                ylabel(app.OverallAxes1,'MWh');
                grid(app.OverallAxes1,'on');
                legend(app.OverallAxes1,{'Before','After'});

                plot(app.OverallAxes2,sum(R.Output_daily_EBalance_before(:,2:end),2)/1000,'LineWidth',1.1);
                hold(app.OverallAxes2,'on');
                plot(app.OverallAxes2,sum(R.Output_daily_EBalance_after(:,2:end),2)/1000,'LineWidth',1.3);
                yline(app.OverallAxes2,0,'--');
                hold(app.OverallAxes2,'off');
                title(app.OverallAxes2,'Household Aggregate Balance');
                ylabel(app.OverallAxes2,'MWh');
                grid(app.OverallAxes2,'on');
                legend(app.OverallAxes2,{'Before','After'});

                plot(app.OverallAxes3,cumsum(abs(R.Output_daily_transition(:,1)))/1000,'LineWidth',1.4);
                hold(app.OverallAxes3,'on');
                plot(app.OverallAxes3,cumsum(abs(R.Output_daily_transition(:,2)))/1000,'LineWidth',1.4);
                plot(app.OverallAxes3,cumsum(abs(R.Output_daily_transition(:,3)))/1000,'LineWidth',1.4);
                hold(app.OverallAxes3,'off');
                title(app.OverallAxes3,'Cumulative Electricity Delivery');
                ylabel(app.OverallAxes3,'MWh');
                grid(app.OverallAxes3,'on');
                legend(app.OverallAxes3,{'MG2C','P2MG','P2C'});

                bar(app.OverallAxes4,[sum(R.Output_sum_index_Ndays_deficits(1,:)), ...
                    sum(R.Output_sum_index_Ndays_deficits(2,:))]);
                app.OverallAxes4.XTickLabel = {'Before','After'};
                title(app.OverallAxes4,'Total Participant-Days with Deficits');
                grid(app.OverallAxes4,'on');

                overallMetric = {'MG to consumers';'Prosumers to MG';'Prosumers to consumers'; ...
                    'Energy loss';'Mean degradation'};
                overallValue = [trans(1);trans(2);trans(3);loss;meanDeg];
                overallUnit = {'MWh/year';'MWh/year';'MWh/year';'MWh/year';'%'};
                app.OverallTable.Data = table(overallMetric,overallValue,overallUnit, ...
                    'VariableNames',{'Metric','Value','Unit'});

                app.StatusLabel.Text = 'Community scenario completed successfully.';
                app.OverallInfoLabel.Text = 'Annual results are available. Select a view or export the summary.';
            catch ME
                errorText = ME.message;
                if ~isempty(ME.stack)
                    errorText = sprintf('%s\n\nFile: %s\nLine: %d', ...
                        ME.message, ME.stack(1).name, ME.stack(1).line);
                end
                uialert(app.UIFigure,errorText,'Simulation Error');
                app.StatusLabel.Text = 'Simulation failed.';
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

        function updateSingleTab(app)
            R=app.lastResults;
            beforeRatio=nnz(R.Output_daily_EBalance_before<0)/numel(R.Output_daily_EBalance_before)*100;
            afterRatio=nnz(R.Output_daily_EBalance_after<0)/numel(R.Output_daily_EBalance_after)*100;
            demandAll=[R.MG_daily_demand,R.HH_daily_demand(:,1:R.num_houses)];
            supplyAfter=R.Output_daily_EBalance_after+demandAll;
            demandMet=min(demandAll,supplyAfter);
            actionDelivery=R.Output_daily_Action(:,2:end);
            evTravelMG=nnz(actionDelivery)*1.218;
            evTravel=nnz(R.Output_daily_EBalance_before(:,2:end)>2.48)*2.48;
            EVsum=evTravelMG+evTravel;
            sc=(sum(demandMet,'all')+EVsum)/(sum(demandAll,'all')+EVsum)*100;
            localSupply=sum(R.MG_daily_supply)+sum(R.HH_daily_supply(:,1:(R.Num_PV_B+R.Num_PVOnly)),'all');
            ss=(sum(demandMet,'all')+EVsum)/max(localSupply,eps)*100;
            meanDeg=mean(R.Degradation)*100;
            trans=sum(abs(R.Output_daily_transition),1)/1000;
            loss=sum(R.Output_daily_index_Eloss(:,1))/1000;

            techNames={'Participating households';'HH1: EV + PV + battery';'HH2: EV + PV';'HH3: EV only'; ...
                'Annual MG demand';'Annual MG supply';'MG to consumers';'Prosumers to MG';'Prosumers to consumers';'Transaction energy loss'};
            techValues=[R.num_houses;R.Num_PV_B;R.Num_PVOnly;R.Num_NoPV; ...
                sum(R.MG_daily_demand)/1000;sum(R.MG_daily_supply)/1000;trans(1);trans(2);trans(3);loss];
            techUnits={'households';'households';'households';'households'; ...
                'MWh/year';'MWh/year';'MWh/year';'MWh/year';'MWh/year';'MWh/year'};
            app.TechnicalTable.Data=table(techNames,techValues,techUnits, ...
                'VariableNames',{'Technical Parameter','Value','Unit'});

            resNames={'Deficit-day ratio before EVEN';'Deficit-day ratio after EVEN';'Deficit-day reduction';'Aggregated self-consumption'; ...
                'Aggregated self-sufficiency';'Mean EV battery degradation';'Total deficit before';'Total deficit after'};
            deficitBefore=sum(abs(min(R.Output_daily_EBalance_before,0)),'all')/1000;
            deficitAfter=sum(abs(min(R.Output_daily_EBalance_after,0)),'all')/1000;
            resValues=[beforeRatio;afterRatio;beforeRatio-afterRatio;sc;ss;meanDeg;deficitBefore;deficitAfter];
            resUnits={'%';'%';'percentage points';'%';'%';'%';'MWh/year';'MWh/year'};
            app.ResilienceTable.Data=table(resNames,resValues,resUnits, ...
                'VariableNames',{'Resilience Parameter','Value','Unit'});

            app.KPI1Value.Text=sprintf('%.1f %%',beforeRatio-afterRatio);
            app.KPI2Value.Text=sprintf('%.1f %%',sc);
            app.KPI3Value.Text=sprintf('%.1f %%',ss);
            app.KPI4Value.Text=sprintf('%.2f %%',meanDeg);

            cla(app.SingleAxes); hold(app.SingleAxes,'on');
            plot(app.SingleAxes,sum(R.Output_daily_EBalance_before,2)/1000,'LineWidth',1.2);
            plot(app.SingleAxes,sum(R.Output_daily_EBalance_after,2)/1000,'LineWidth',1.5);
            yline(app.SingleAxes,0,'--'); hold(app.SingleAxes,'off'); grid(app.SingleAxes,'on');
            xlabel(app.SingleAxes,'Day of year'); ylabel(app.SingleAxes,'Community energy balance (MWh)');
            title(app.SingleAxes,'Community Energy Balance Before and After EVEN','FontWeight','bold');
            legend(app.SingleAxes,{'Before EVEN','After EVEN'},'Location','best');
        end

        function updateOverallPlots(app, ~)
            if isempty(fieldnames(app.lastResults)), return; end
            R=app.lastResults; view=app.OverallViewDropDown.Value;
            if strcmp(view,'Annual Balance Dashboard')
                app.plotBalanceDashboard(R);
            else
                app.plotDeliveryDashboard(R);
            end
            app.OverallTable.Data=app.makeOverallSummary(R);
        end

        function plotBalanceDashboard(app,R)
            axs=[app.OverallAxes1 app.OverallAxes2 app.OverallAxes3 app.OverallAxes4];
            for ax=axs, cla(ax); end
            plot(app.OverallAxes1,R.Output_daily_EBalance_before(:,1)/1000,'LineWidth',1.1); hold(app.OverallAxes1,'on');
            plot(app.OverallAxes1,R.Output_daily_EBalance_after(:,1)/1000,'LineWidth',1.3); yline(app.OverallAxes1,0,'--'); hold(app.OverallAxes1,'off');
            title(app.OverallAxes1,'Microgrid Balance'); ylabel(app.OverallAxes1,'MWh'); grid(app.OverallAxes1,'on'); legend(app.OverallAxes1,{'Before','After'});
            plot(app.OverallAxes2,sum(R.Output_daily_EBalance_before(:,2:end),2)/1000,'LineWidth',1.1); hold(app.OverallAxes2,'on');
            plot(app.OverallAxes2,sum(R.Output_daily_EBalance_after(:,2:end),2)/1000,'LineWidth',1.3); yline(app.OverallAxes2,0,'--'); hold(app.OverallAxes2,'off');
            title(app.OverallAxes2,'Household Aggregate Balance'); ylabel(app.OverallAxes2,'MWh'); grid(app.OverallAxes2,'on'); legend(app.OverallAxes2,{'Before','After'});
            plot(app.OverallAxes3,cumsum(abs(R.Output_daily_transition(:,1)))/1000,'LineWidth',1.4); hold(app.OverallAxes3,'on');
            plot(app.OverallAxes3,cumsum(abs(R.Output_daily_transition(:,2)))/1000,'LineWidth',1.4);
            plot(app.OverallAxes3,cumsum(abs(R.Output_daily_transition(:,3)))/1000,'LineWidth',1.4); hold(app.OverallAxes3,'off');
            title(app.OverallAxes3,'Cumulative Electricity Delivery'); ylabel(app.OverallAxes3,'MWh'); grid(app.OverallAxes3,'on'); legend(app.OverallAxes3,{'MG2C','P2MG','P2C'});
            bar(app.OverallAxes4,[sum(R.Output_sum_index_Ndays_deficits(1,:)),sum(R.Output_sum_index_Ndays_deficits(2,:))]);
            app.OverallAxes4.XTickLabel={'Before','After'}; title(app.OverallAxes4,'Total Participant-Days with Deficits'); grid(app.OverallAxes4,'on');
        end

        function plotDeliveryDashboard(app,R)
            axs=[app.OverallAxes1 app.OverallAxes2 app.OverallAxes3 app.OverallAxes4]; for ax=axs, cla(ax); end
            bar(app.OverallAxes1,abs(R.Output_daily_transition)/1000,'stacked'); title(app.OverallAxes1,'Daily Delivery by Route'); ylabel(app.OverallAxes1,'MWh'); grid(app.OverallAxes1,'on'); legend(app.OverallAxes1,{'MG2C','P2MG','P2C'});
            bar(app.OverallAxes2,R.Output_daily_index_Eloss(:,1)/1000); title(app.OverallAxes2,'Daily Transaction Energy Loss'); ylabel(app.OverallAxes2,'MWh'); grid(app.OverallAxes2,'on');
            scatter(app.OverallAxes3,1:numel(R.Degradation),R.Degradation*100,18,'filled'); title(app.OverallAxes3,'EV Battery Degradation'); xlabel(app.OverallAxes3,'Household ID'); ylabel(app.OverallAxes3,'%'); grid(app.OverallAxes3,'on');
            reduction=R.Output_sum_Indiv_index_Edeficits(1,2:end)-R.Output_sum_Indiv_index_Edeficits(2,2:end);
            scatter(app.OverallAxes4,R.Degradation*100,reduction/1000,18,'filled'); title(app.OverallAxes4,'Degradation vs Deficit Reduction'); xlabel(app.OverallAxes4,'Degradation (%)'); ylabel(app.OverallAxes4,'Deficit reduction (MWh)'); grid(app.OverallAxes4,'on');
        end

        function T=makeOverallSummary(app,R) %#ok<INUSL>
            route=sum(abs(R.Output_daily_transition),1)/1000;
            metric={'MG to consumers';'Prosumers to MG';'Prosumers to consumers';'Energy loss';'Mean degradation'};
            value=[route(1);route(2);route(3);sum(R.Output_daily_index_Eloss(:,1))/1000;mean(R.Degradation)*100];
            unit={'MWh/year';'MWh/year';'MWh/year';'MWh/year';'%'};
            T=table(metric,value,unit,'VariableNames',{'Metric','Value','Unit'});
        end

        function LoadParametric(app, ~)
            group=app.ParamGroupDropDown.Value;
            file=app.findParametricFile(group);
            if isempty(file)
                uialert(app.UIFigure,sprintf(['No results found for Group %s. Press Generate to create them ' ...
                    'from the files uploaded on the first tab.'],group),'Missing Parametric Results'); return;
            end
            app.paramData=load(file);
            app.plotParametric();
            [~,n,e]=fileparts(file); [~,d]=fileparts(fileparts(file));
            app.StatusLabel.Text=sprintf('Loaded Parametric Group %s from %s/%s%s.',group,d,n,e);
        end

        function plotParametric(app, ~)
            if isempty(fieldnames(app.paramData)), return; end
            A=app.paramData.OUTPUT_paramatric_PartA; group=app.ParamGroupDropDown.Value;
            switch group
                case 'A', x=[0 10 20 30 40 50]; legends={'MG Supply 1','MG Supply 2','MG Supply 3'}; xlabelText='Demand cut ratio (%)';
                case 'B', x=5:5:50; legends={'EV battery 56 kWh','EV battery 75 kWh','EV battery 100 kWh'}; xlabelText='EV penetration (%)';
                otherwise, x=25:5:65; legends={'11% battery, standard inverter','30% battery, standard inverter','11% battery, emergency inverter','30% battery, emergency inverter'}; xlabelText='PV penetration (%)';
            end
            % Files made by even_run_parametric describe their own sweep.
            if isfield(app.paramData,'ParametricInfo')
                I=app.paramData.ParametricInfo;
                x=I.Levels; legends=I.CurveLabels;
                xlabelText=[upper(I.LevelName(1)) I.LevelName(2:end)];
            end
            axs=[app.ParamAxes1 app.ParamAxes2 app.ParamAxes3 app.ParamAxes4]; metrics=[2 5 3 4]; titles={'Ratio of Days with Deficits','Mean EV Battery Degradation','Aggregated Self-Consumption','Aggregated Self-Sufficiency'};
            for ia=1:4
                ax=axs(ia); cla(ax); hold(ax,'on');
                for s=1:size(A,3), plot(ax,x,squeeze(A(metrics(ia),:,s))*100,'-o','LineWidth',1.3,'MarkerSize',4); end
                hold(ax,'off'); grid(ax,'on'); title(ax,titles{ia},'FontWeight','bold'); xlabel(ax,xlabelText); ylabel(ax,'%');
                if ia==1, legend(ax,legends,'Location','best','FontSize',8); end
            end
            deficitVals=squeeze(A(2,:,:))*100;
            degradeVals=squeeze(A(5,:,:))*100;
            scVals=squeeze(A(3,:,:))*100;
            ssVals=squeeze(A(4,:,:))*100;
            indicator={'Deficit-day ratio';'Mean EV battery degradation';'Aggregated self-consumption';'Aggregated self-sufficiency'};
            best=[min(deficitVals,[],'all');min(degradeVals,[],'all');max(scVals,[],'all');max(ssVals,[],'all')];
            worst=[max(deficitVals,[],'all');max(degradeVals,[],'all');min(scVals,[],'all');min(ssVals,[],'all')];
            unit={'%';'%';'%';'%'};
            app.ParamTable.Data=table(indicator,best,worst,unit,'VariableNames',{'Indicator','BestCase','WorstCase','Unit'});
            app.ParamText.Value={['Parametric Group ' group];'';'The four plots show how the selected study variables affect community resilience.';'';'Preferred direction:';' Lower deficit-day ratio';' Lower EV battery degradation';' Higher self-consumption';' Higher self-sufficiency'};
            app.ParamInfoLabel.Text=['Loaded Parametric Group ' group '.'];
        end

        function file = findParametricFile(app, group)
            % Newly generated results take priority over the bundled ones.
            name=['Parametric_Group' group '.mat'];
            root=fileparts(char(app.codeFolder));
            candidates={fullfile(root,'results',name), fullfile(root,'input_files','community','parametric_results',name), fullfile(char(app.codeFolder),name)};
            file='';
            for i=1:numel(candidates)
                if isfile(candidates{i}), file=candidates{i}; return; end
            end
        end

        function GenerateParametric(app, ~)
            % Runs the chosen parametric group on the files uploaded on the
            % Single Scenario tab, saves the results and plots them.
            if ~app.validateInputs(), return; end
            group=app.ParamGroupDropDown.Value;
            runs=struct('A',18,'B',30,'C',36);
            nRuns=runs.(group);

            % Rough run time from the number of households in the load file.
            nHH=NaN;
            try
                w=whos('-file',char(app.hhLoadFile));
                nHH=max(arrayfun(@(v) v.size(end), w));
            catch
            end
            if isnan(nHH)
                estimate='an unknown time';
            else
                mins=nRuns*(2+0.017*nHH)/60;
                if mins<2, estimate='about a minute'; else, estimate=sprintf('about %.0f minutes',mins); end
            end
            [~,hhName,hhExt]=fileparts(char(app.hhLoadFile));
            choice=uiconfirm(app.UIFigure,sprintf(['Group %s runs the annual simulation %d times using the uploaded files ' ...
                '(%s%s, %s households). This takes %s. Continue?'],group,nRuns,hhName,hhExt,num2str(nHH),estimate), ...
                'Generate Parametric Results','Options',{'Generate','Cancel'},'DefaultOption',1,'CancelOption',2);
            if strcmp(choice,'Cancel'), return; end

            files=struct('MGFile',char(app.mgDataFile),'HHLoadFile',char(app.hhLoadFile),'HHPVFile',char(app.hhPVFile));
            dlg=uiprogressdlg(app.UIFigure,'Title',['Generating Parametric Group ' group], ...
                'Message','Starting...','Cancelable','on','Indeterminate','off');
            progress=@(k,n,d) app.updateParamProgress(dlg,k,n,d);
            try
                [PartA,PartB,info]=even_run_parametric(group,files,'ProgressFcn',progress);
            catch ME
                close(dlg);
                uialert(app.UIFigure,ME.message,'Generation Failed'); return;
            end
            close(dlg);

            root=fileparts(char(app.codeFolder));
            outDir=fullfile(root,'results');
            if ~isfolder(outDir), mkdir(outDir); end
            if info.CompletedRuns<info.TotalRuns
                outFile=fullfile(outDir,['Parametric_Group' group '_partial.mat']);
            else
                outFile=fullfile(outDir,['Parametric_Group' group '.mat']);
            end
            OUTPUT_paramatric_PartA=PartA; OUTPUT_paramatric_PartB=PartB; ParametricInfo=info; %#ok<NASGU>
            save(outFile,'OUTPUT_paramatric_PartA','OUTPUT_paramatric_PartB','ParametricInfo');

            app.paramData=load(outFile);
            app.plotParametric();
            if info.CompletedRuns<info.TotalRuns
                msg=sprintf('Stopped after %d of %d runs. Partial results saved to results/%s; missing points are blank.', ...
                    info.CompletedRuns,info.TotalRuns,['Parametric_Group' group '_partial.mat']);
            else
                msg=sprintf('Generated Group %s: %d runs in %.1f min, saved to results/Parametric_Group%s.mat.', ...
                    group,info.TotalRuns,info.RunTimeSeconds/60,group);
            end
            app.ParamInfoLabel.Text=msg;
            app.StatusLabel.Text=msg;
        end

        function keepGoing = updateParamProgress(app, dlg, k, n, description) %#ok<INUSL>
            dlg.Value=(k-1)/n;
            dlg.Message=sprintf('Run %d of %d\n%s',k,n,description);
            drawnow;
            keepGoing=~dlg.CancelRequested;
        end

        function ExportSingle(app, ~)
            if isempty(fieldnames(app.lastResults)), uialert(app.UIFigure,'Run a scenario first.','No Results'); return; end
            [f,p]=uiputfile('Community_Microgrid_Scenario.xlsx'); if isequal(f,0), return; end
            writetable(app.TechnicalTable.Data,fullfile(p,f),'Sheet','Technical');
            writetable(app.ResilienceTable.Data,fullfile(p,f),'Sheet','Resilience');
            app.StatusLabel.Text='Scenario results exported.';
        end

        function ExportOverall(app, ~)
            if isempty(app.OverallTable.Data), uialert(app.UIFigure,'Run a scenario first.','No Results'); return; end
            [f,p]=uiputfile('Community_Microgrid_Overall.xlsx'); if isequal(f,0), return; end
            writetable(app.OverallTable.Data,fullfile(p,f));
        end

        function ExportParam(app, ~)
            if isempty(fieldnames(app.paramData)), uialert(app.UIFigure,'Load a parametric group first.','No Results'); return; end
            [f,p]=uiputfile('Community_Microgrid_Parametric.xlsx'); if isequal(f,0), return; end
            A=app.paramData.OUTPUT_paramatric_PartA; writematrix(A(:),fullfile(p,f),'Sheet','Raw_Output');
        end

        function ResetApp(app, ~)
            app.lastResults=struct(); app.paramData=struct();
            app.mgDataFile=""; app.hhLoadFile=""; app.hhPVFile="";
            app.updateDataStatus();
            app.TechnicalTable.Data=table(); app.ResilienceTable.Data=table(); app.OverallTable.Data=table(); app.ParamTable.Data=table();
            app.KPI1Value.Text='--'; app.KPI2Value.Text='--'; app.KPI3Value.Text='--'; app.KPI4Value.Text='--';
            cla(app.SingleAxes); cla(app.OverallAxes1); cla(app.OverallAxes2); cla(app.OverallAxes3); cla(app.OverallAxes4);
            cla(app.ParamAxes1); cla(app.ParamAxes2); cla(app.ParamAxes3); cla(app.ParamAxes4);
            app.StatusLabel.Text='Reset complete.';
        end

        function createComponents(app)
            navy=[0.02 0.16 0.32]; blue=[0.00 0.45 0.74]; green=[0.10 0.55 0.20]; orange=[0.90 0.50 0.10];
            app.UIFigure=uifigure('Visible','off','Position',[60 50 1320 780],'Name','EVEN Toolkit - Municipality / Community','Color',[1 1 1]);
            app.HeaderPanel=uipanel(app.UIFigure,'Position',[0 680 1320 100],'BackgroundColor',navy,'BorderType','none');
            app.TitleLabel=uilabel(app.HeaderPanel,'Position',[30 50 1260 40],'Text','Municipality / Community: EV-Based Virtual Electricity Network','FontSize',25,'FontWeight','bold','FontColor',[1 1 1],'HorizontalAlignment','center');
            app.SubtitleLabel=uilabel(app.HeaderPanel,'Position',[30 18 1260 26],'Text','EVEN Toolkit  |  Annual community energy sharing between households, a microgrid and electric vehicles','FontSize',14,'FontColor',[0.85 0.92 1],'HorizontalAlignment','center');
            app.TabGroup=uitabgroup(app.UIFigure,'Position',[20 55 1280 610]);
            app.SingleTab=uitab(app.TabGroup,'Title','Community Scenario','BackgroundColor',[1 1 1]);
            app.OverallTab=uitab(app.TabGroup,'Title','Overall Performance','BackgroundColor',[1 1 1]);
            app.ParametricTab=uitab(app.TabGroup,'Title','Parametric Analysis','BackgroundColor',[1 1 1]);

            app.SetupPanel=uipanel(app.SingleTab,'Position',[10 10 310 560],'Title','Scenario Setup','FontSize',14,'FontWeight','bold','BackgroundColor',[1 1 1]);
            app.UploadMGButton=uibutton(app.SetupPanel,'push','Position',[25 495 82 32],'Text','Upload MG','FontWeight','bold','BackgroundColor',blue,'FontColor',[1 1 1],'ButtonPushedFcn',@(s,e)UploadMGData(app,e));
            app.UploadHHLoadButton=uibutton(app.SetupPanel,'push','Position',[114 495 82 32],'Text','HH Load','FontWeight','bold','BackgroundColor',blue,'FontColor',[1 1 1],'ButtonPushedFcn',@(s,e)UploadHHLoadData(app,e));
            app.UploadHHPVButton=uibutton(app.SetupPanel,'push','Position',[203 495 82 32],'Text','HH PV','FontWeight','bold','BackgroundColor',blue,'FontColor',[1 1 1],'ButtonPushedFcn',@(s,e)UploadHHPVData(app,e));
            app.DataStatusLabel=uilabel(app.SetupPanel,'Position',[25 462 260 28],'Text','MG: not loaded  |  HH load: not loaded  |  HH PV: not loaded','FontSize',9,'WordWrap','on');
            labels={'MG Supply Scenario (-)','Demand Reduction (%)','EV Penetration Level (%)','EV Battery Capacity (kWh)','PV Penetration Level (%)','PV Battery Deployment (%)','PV Inverter Type (-)','Balancing Strategy (-)','MG Battery Capacity (kWh)'};
            ys=425:-41:97;
            for i=1:numel(labels), uilabel(app.SetupPanel,'Position',[25 ys(i) 145 22],'Text',labels{i},'FontWeight','bold'); end
            app.MGSupplyDropDown=uidropdown(app.SetupPanel,'Position',[178 ys(1) 107 24], ...
                'Items',{'Scenario 1','Scenario 2','Scenario 3'},'ItemsData',[1 2 3],'Value',1);
            app.DemandCutDropDown=uidropdown(app.SetupPanel,'Position',[178 ys(2) 107 24], ...
                'Items',{'0','10','20','30','40','50'},'Value','0','Editable','on', ...
                'Tooltip','Select a preset or type any value between 0 and 90 percent.');
            app.EVPenDropDown=uidropdown(app.SetupPanel,'Position',[178 ys(3) 107 24], ...
                'Items',{'5','10','20','35','50'},'Value','5','Editable','on', ...
                'Tooltip','Select a preset or type any value between 0.1 and 100 percent. High values are slow to simulate.');
            app.EVBatteryDropDown=uidropdown(app.SetupPanel,'Position',[178 ys(4) 107 24], ...
                'Items',{'56','75','100'},'Value','56','Editable','on', ...
                'Tooltip','Select a preset or type any value between 10 and 250 kWh.');
            app.PVPenDropDown=uidropdown(app.SetupPanel,'Position',[178 ys(5) 107 24], ...
                'Items',{'25','35','45','55','65'},'Value','25','Editable','on', ...
                'Tooltip','Select a preset or type any value between 0 and 100 percent.');
            app.BatteryPenDropDown=uidropdown(app.SetupPanel,'Position',[178 ys(6) 107 24], ...
                'Items',{'11','30'},'Value','11','Editable','on', ...
                'Tooltip','Select a preset or type any value between 0 and 100 percent.');
            app.InverterDropDown=uidropdown(app.SetupPanel,'Position',[178 ys(7) 107 24], ...
                'Items',{'Standard inverter','Emergency inverter'},'ItemsData',[1 2],'Value',1);
            app.AuctionDropDown=uidropdown(app.SetupPanel,'Position',[178 ys(8) 107 24], ...
                'Items',{'Flexible contribution (2)'},'ItemsData',2,'Value',2);
            app.MGBatteryDropDown=uidropdown(app.SetupPanel,'Position',[178 ys(9) 107 24], ...
                'Items',{'1000','2000','3000','4000','5000'},'Value','2000','Editable','on', ...
                'Tooltip','Select a preset or type any value between 0 and 50000 kWh.');
            app.RunButton=uibutton(app.SetupPanel,'push','Position',[25 52 260 34],'Text','Run Community Simulation','FontWeight','bold','BackgroundColor',green,'FontColor',[1 1 1],'ButtonPushedFcn',@(s,e)RunButtonPushed(app,e));
            app.ExportButton=uibutton(app.SetupPanel,'push','Position',[25 12 125 30],'Text','Export','BackgroundColor',orange,'FontColor',[1 1 1],'ButtonPushedFcn',@(s,e)ExportSingle(app,e));
            app.ResetButton=uibutton(app.SetupPanel,'push','Position',[160 12 125 30],'Text','Reset','BackgroundColor',[0.55 0.55 0.55],'FontColor',[1 1 1],'ButtonPushedFcn',@(s,e)ResetApp(app,e));

            app.TechnicalPanel=uipanel(app.SingleTab,'Position',[340 345 455 225],'Title','Technical Performance','FontSize',14,'FontWeight','bold','BackgroundColor',[1 1 1]);
            app.TechnicalTable=uitable(app.TechnicalPanel,'Position',[15 15 425 175],'FontSize',11,'ColumnWidth',{210,95,100});
            app.ResiliencePanel=uipanel(app.SingleTab,'Position',[815 345 455 225],'Title','Resilience Performance','FontSize',14,'FontWeight','bold','BackgroundColor',[1 1 1]);
            app.ResilienceTable=uitable(app.ResiliencePanel,'Position',[15 15 425 175],'FontSize',11,'ColumnWidth',{205,90,115});
            titles={'Deficit Reduction','Self-Consumption','Self-Sufficiency','Mean Degradation'}; xpos=[340 575 815 1050]; vals={'KPI1Value','KPI2Value','KPI3Value','KPI4Value'};
            panels={'KPI1Panel','KPI2Panel','KPI3Panel','KPI4Panel'};
            for i=1:4
                app.(panels{i})=uipanel(app.SingleTab,'Position',[xpos(i) 275 220 55],'BackgroundColor',[0.97 0.98 1]);
                uilabel(app.(panels{i}),'Position',[10 30 200 18],'Text',titles{i},'FontSize',11,'HorizontalAlignment','center');
                app.(vals{i})=uilabel(app.(panels{i}),'Position',[10 4 200 26],'Text','--','FontSize',17,'FontWeight','bold','FontColor',blue,'HorizontalAlignment','center');
            end
            app.SingleAxes=uiaxes(app.SingleTab,'Position',[340 20 930 235]);

            app.OverallControlPanel=uipanel(app.OverallTab,'Position',[10 430 300 140],'Title','Overall Scenario Analysis','FontSize',12,'FontWeight','bold','BackgroundColor',[1 1 1]);
            uilabel(app.OverallControlPanel,'Position',[20 86 80 22],'Text','View:','FontWeight','bold');
            app.OverallViewDropDown=uidropdown(app.OverallControlPanel,'Position',[75 86 205 24],'Items',{'Annual Balance Dashboard','Delivery and Degradation'},'ValueChangedFcn',@(s,e)updateOverallPlots(app,e));
            app.RefreshOverallButton=uibutton(app.OverallControlPanel,'push','Position',[20 48 260 30],'Text','Refresh Overall Plots','FontWeight','bold','BackgroundColor',green,'FontColor',[1 1 1],'ButtonPushedFcn',@(s,e)updateOverallPlots(app,e));
            app.ExportOverallButton=uibutton(app.OverallControlPanel,'push','Position',[20 12 260 28],'Text','Export Overall Summary','BackgroundColor',orange,'FontColor',[1 1 1],'ButtonPushedFcn',@(s,e)ExportOverall(app,e));
            app.OverallInfoLabel=uilabel(app.OverallTab,'Position',[10 390 300 32],'Text','Run a community scenario first.','WordWrap','on','HorizontalAlignment','center');
            plotPanel=uipanel(app.OverallTab,'Position',[330 220 940 350],'Title','Annual Community Performance','FontSize',12,'FontWeight','bold','BackgroundColor',[1 1 1]);
            app.OverallAxes1=uiaxes(plotPanel,'Position',[20 185 435 130]); app.OverallAxes2=uiaxes(plotPanel,'Position',[485 185 435 130]);
            app.OverallAxes3=uiaxes(plotPanel,'Position',[20 25 435 130]); app.OverallAxes4=uiaxes(plotPanel,'Position',[485 25 435 130]);
            tablePanel=uipanel(app.OverallTab,'Position',[10 10 1260 195],'Title','Overall Scenario Results','FontSize',12,'FontWeight','bold','BackgroundColor',[1 1 1]);
            app.OverallTable=uitable(tablePanel,'Position',[10 10 1240 150],'FontSize',11,'ColumnWidth',{600,250,250});

            app.ParamControlPanel=uipanel(app.ParametricTab,'Position',[10 500 1260 70],'Title','Parametric Study Controls','FontSize',12,'FontWeight','bold','BackgroundColor',[1 1 1]);
            uilabel(app.ParamControlPanel,'Position',[20 16 90 22],'Text','Study Group:','FontWeight','bold');
            app.ParamGroupDropDown=uidropdown(app.ParamControlPanel,'Position',[115 15 165 25],'Items',{'A','B','C'},'Value','A');
            app.GenerateParamButton=uibutton(app.ParamControlPanel,'push','Position',[295 12 210 32],'Text','Generate from Uploaded Files','FontWeight','bold','BackgroundColor',blue,'FontColor',[1 1 1],'ButtonPushedFcn',@(s,e)GenerateParametric(app,e));
            app.LoadParamButton=uibutton(app.ParamControlPanel,'push','Position',[515 12 190 32],'Text','Load Parametric Results','FontWeight','bold','BackgroundColor',green,'FontColor',[1 1 1],'ButtonPushedFcn',@(s,e)LoadParametric(app,e));
            app.ExportParamButton=uibutton(app.ParamControlPanel,'push','Position',[715 12 170 32],'Text','Export Parametric Data','BackgroundColor',orange,'FontColor',[1 1 1],'ButtonPushedFcn',@(s,e)ExportParam(app,e));
            app.ParamInfoLabel=uilabel(app.ParamControlPanel,'Position',[895 8 355 40],'Text','Load stored results, or generate them from the uploaded files.','WordWrap','on','HorizontalAlignment','center','FontSize',10);
            ppanel=uipanel(app.ParametricTab,'Position',[10 145 1260 345],'Title','Parametric Performance Plots','FontSize',12,'FontWeight','bold','BackgroundColor',[1 1 1]);
            app.ParamAxes1=uiaxes(ppanel,'Position',[30 180 575 135]); app.ParamAxes2=uiaxes(ppanel,'Position',[650 180 575 135]);
            app.ParamAxes3=uiaxes(ppanel,'Position',[30 20 575 135]); app.ParamAxes4=uiaxes(ppanel,'Position',[650 20 575 135]);
            summaryPanel=uipanel(app.ParametricTab,'Position',[10 10 610 125],'Title','Parametric Summary','FontSize',12,'FontWeight','bold','BackgroundColor',[1 1 1]);
            app.ParamTable=uitable(summaryPanel,'Position',[10 10 590 85],'FontSize',11,'ColumnWidth',{245,105,105,70});
            interpretationPanel=uipanel(app.ParametricTab,'Position',[635 10 635 125],'Title','Interpretation','FontSize',12,'FontWeight','bold','BackgroundColor',[1 1 1]);
            app.ParamText=uitextarea(interpretationPanel,'Position',[10 10 615 85],'Editable','off','FontSize',11,'Value',{'Load a parametric group to view interpretation.'});

            app.StatusLabel=uilabel(app.UIFigure,'Position',[30 20 1260 25],'Text','Ready','FontColor',[0.3 0.3 0.3],'HorizontalAlignment','center');
            app.UIFigure.Visible='on';
        end
    end

    methods (Access = public)
        function app=Community_Microgrid_GUI_App
            createComponents(app); startupFcn(app);
        end
        function delete(app)
            delete(app.UIFigure);
        end
    end
end
