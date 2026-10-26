classdef Main_Scenario_Selector_App_Visual < matlab.apps.AppBase

    properties (Access = public)
        UIFigure matlab.ui.Figure
        HeaderPanel matlab.ui.container.Panel
        TitleLabel matlab.ui.control.Label
        SubtitleLabel matlab.ui.control.Label

        HousePanel matlab.ui.container.Panel
        CriticalPanel matlab.ui.container.Panel
        MunicipalityPanel matlab.ui.container.Panel

        HouseImage matlab.ui.control.Image
        CriticalImage matlab.ui.control.Image
        MunicipalityImage matlab.ui.control.Image

        OpenHouseButton matlab.ui.control.Button
        OpenCriticalButton matlab.ui.control.Button
        OpenMunicipalityButton matlab.ui.control.Button

        FooterLabel matlab.ui.control.Label
    end

    properties (Access = private)
        HouseApp
        CriticalApp
        MunicipalityApp
        assetFolder string = ""
    end

    methods (Access = private)

        function OpenHouseButtonPushed(app, ~)
            try
                app.HouseApp = V2H_GUI_App;
            catch ME
                uialert(app.UIFigure, ME.message, 'Error Opening Household GUI');
            end
        end

        function OpenCriticalButtonPushed(app, ~)
            try
                app.CriticalApp = Clinic_Backup_GUI_App;
            catch ME
                uialert(app.UIFigure, ME.message, 'Error Opening Critical Infrastructure GUI');
            end
        end

        function OpenMunicipalityButtonPushed(app, ~)
            try
                app.MunicipalityApp = Community_Microgrid_GUI_App;
            catch ME
                uialert(app.UIFigure, ME.message, 'Error Opening Community Microgrid GUI');
            end
        end

        function addBulletList(app, parent, x, y, width, lines, color)
            %#ok<INUSD>
            for k = 1:numel(lines)
                yy = y - (k-1)*36;
                uilabel(parent, ...
                    'Position',[x yy 22 22], ...
                    'Text','o', ...
                    'FontSize',15, ...
                    'FontWeight','bold', ...
                    'FontColor',color, ...
                    'HorizontalAlignment','center');
                uilabel(parent, ...
                    'Position',[x+28 yy-1 width-28 24], ...
                    'Text',lines{k}, ...
                    'FontSize',16, ...
                    'FontColor',[0.12 0.16 0.22]);
            end
        end

        function setImageIfPresent(app, imgControl, fileName)
            % Sets the card image only when the file is present, so that a
            % missing asset leaves an empty panel instead of raising an error.
            candidate = fullfile(app.assetFolder, fileName);
            if isfile(candidate)
                imgControl.ImageSource = candidate;
            end
        end

        function createCardHeader(app, panel, titleText, titleColor)
            %#ok<INUSD>
            uilabel(panel, ...
                'Position',[20 590 390 42], ...
                'Text',titleText, ...
                'FontSize',28, ...
                'FontWeight','bold', ...
                'FontColor',titleColor, ...
                'HorizontalAlignment','center');
            uipanel(panel, ...
                'Position',[18 570 394 2], ...
                'BackgroundColor',titleColor, ...
                'BorderType','none');
        end

        function createComponents(app)
            navy = [0.02 0.16 0.32];
            blue = [0.02 0.34 0.68];
            orange = [0.90 0.36 0.02];
            green = [0.12 0.42 0.18];
            border = [0.82 0.85 0.88];

            app.assetFolder = string(fileparts(mfilename('fullpath')));

            app.UIFigure = uifigure('Visible','off');
            app.UIFigure.Position = [40 30 1460 930];
            app.UIFigure.Name = 'EV-Based Energy Resilience Assessment Platform';
            app.UIFigure.Color = [0.97 0.98 0.99];

            app.HeaderPanel = uipanel(app.UIFigure);
            app.HeaderPanel.Position = [0 835 1460 95];
            app.HeaderPanel.BackgroundColor = navy;
            app.HeaderPanel.BorderType = 'none';

            app.TitleLabel = uilabel(app.HeaderPanel);
            app.TitleLabel.Position = [40 48 1380 34];
            app.TitleLabel.Text = 'EV-Based Energy Resilience Assessment Platform';
            app.TitleLabel.FontSize = 32;
            app.TitleLabel.FontWeight = 'bold';
            app.TitleLabel.FontColor = [1 1 1];
            app.TitleLabel.HorizontalAlignment = 'center';

            app.SubtitleLabel = uilabel(app.HeaderPanel);
            app.SubtitleLabel.Position = [40 17 1380 24];
            app.SubtitleLabel.Text = 'Select a scenario to open the corresponding technical and economic assessment module';
            app.SubtitleLabel.FontSize = 17;
            app.SubtitleLabel.FontColor = [0.84 0.92 1];
            app.SubtitleLabel.HorizontalAlignment = 'center';

            % Card geometry
            cardY = 82;
            cardW = 430;
            cardH = 725;
            gap = 28;
            x1 = 28;
            x2 = x1 + cardW + gap;
            x3 = x2 + cardW + gap;

            app.HousePanel = uipanel(app.UIFigure);
            app.HousePanel.Position = [x1 cardY cardW cardH];
            app.HousePanel.BackgroundColor = [1 1 1];
            app.HousePanel.BorderType = 'line';
            app.HousePanel.HighlightColor = border;

            app.CriticalPanel = uipanel(app.UIFigure);
            app.CriticalPanel.Position = [x2 cardY cardW cardH];
            app.CriticalPanel.BackgroundColor = [1 1 1];
            app.CriticalPanel.BorderType = 'line';
            app.CriticalPanel.HighlightColor = border;

            app.MunicipalityPanel = uipanel(app.UIFigure);
            app.MunicipalityPanel.Position = [x3 cardY cardW cardH];
            app.MunicipalityPanel.BackgroundColor = [1 1 1];
            app.MunicipalityPanel.BorderType = 'line';
            app.MunicipalityPanel.HighlightColor = border;

            createCardHeader(app, app.HousePanel, 'Single Family House', blue);
            createCardHeader(app, app.CriticalPanel, 'Critical Infrastructure', orange);
            createCardHeader(app, app.MunicipalityPanel, 'Municipality / Community', green);

            app.HouseImage = uiimage(app.HousePanel);
            app.HouseImage.Position = [15 300 400 250];
            app.HouseImage.ScaleMethod = 'fit';
            app.setImageIfPresent(app.HouseImage,'selector_house_concept.png');

            app.CriticalImage = uiimage(app.CriticalPanel);
            app.CriticalImage.Position = [15 300 400 250];
            app.CriticalImage.ScaleMethod = 'fit';
            app.setImageIfPresent(app.CriticalImage,'selector_clinic_concept.png');

            app.MunicipalityImage = uiimage(app.MunicipalityPanel);
            app.MunicipalityImage.Position = [15 300 400 250];
            app.MunicipalityImage.ScaleMethod = 'fit';
            app.setImageIfPresent(app.MunicipalityImage,'selector_community_concept.png');

            uilabel(app.HousePanel, ...
                'Position',[30 280 370 28], ...
                'Text','Short-term residential backup using EVs.', ...
                'FontSize',18, ...
                'FontWeight','bold', ...
                'FontColor',blue, ...
                'HorizontalAlignment','center');

            uilabel(app.CriticalPanel, ...
                'Position',[30 280 370 28], ...
                'Text','Long-term backup for critical facilities.', ...
                'FontSize',18, ...
                'FontWeight','bold', ...
                'FontColor',orange, ...
                'HorizontalAlignment','center');

            uilabel(app.MunicipalityPanel, ...
                'Position',[30 260 370 40], ...
                'Text','Community-wide energy sharing and resilience.', ...
                'FontSize',18, ...
                'FontWeight','bold', ...
                'FontColor',green, ...
                'HorizontalAlignment','center', ...
                'WordWrap','on');

            addBulletList(app, app.HousePanel, 34, 250, 365, { ...
                'Household load support during outages', ...
                'EV battery utilization and SOC profile', ...
                'Unserved load and supply availability', ...
                'Cost and compensation analysis'}, blue);

            addBulletList(app, app.CriticalPanel, 34, 250, 365, { ...
                'EV fleet operation and scheduling', ...
                'Station battery and solar integration', ...
                'Diesel reduction and CO2 emissions', ...
                'Cost, savings and supply reliability'}, orange);

            addBulletList(app, app.MunicipalityPanel, 34, 230, 365, { ...
                'Microgrid and multi-site coordination', ...
                'Prioritized community load support', ...
                'Distributed energy resources', ...
                'Enhanced community resilience'}, green);

            app.OpenHouseButton = uibutton(app.HousePanel,'push');
            app.OpenHouseButton.Position = [28 28 374 60];
            app.OpenHouseButton.Text = 'Open Household Simulator';
            app.OpenHouseButton.FontSize = 18;
            app.OpenHouseButton.FontWeight = 'bold';
            app.OpenHouseButton.FontColor = [1 1 1];
            app.OpenHouseButton.BackgroundColor = blue;
            app.OpenHouseButton.ButtonPushedFcn = @(s,e)OpenHouseButtonPushed(app,e);

            app.OpenCriticalButton = uibutton(app.CriticalPanel,'push');
            app.OpenCriticalButton.Position = [28 28 374 60];
            app.OpenCriticalButton.Text = 'Open Infrastructure Simulator';
            app.OpenCriticalButton.FontSize = 18;
            app.OpenCriticalButton.FontWeight = 'bold';
            app.OpenCriticalButton.FontColor = [1 1 1];
            app.OpenCriticalButton.BackgroundColor = orange;
            app.OpenCriticalButton.ButtonPushedFcn = @(s,e)OpenCriticalButtonPushed(app,e);

            app.OpenMunicipalityButton = uibutton(app.MunicipalityPanel,'push');
            app.OpenMunicipalityButton.Position = [28 28 374 60];
            app.OpenMunicipalityButton.Text = 'Open Community Microgrid Simulator';
            app.OpenMunicipalityButton.FontSize = 18;
            app.OpenMunicipalityButton.FontWeight = 'bold';
            app.OpenMunicipalityButton.FontColor = [1 1 1];
            app.OpenMunicipalityButton.BackgroundColor = green;
            app.OpenMunicipalityButton.ButtonPushedFcn = @(s,e)OpenMunicipalityButtonPushed(app,e);

            app.FooterLabel = uilabel(app.UIFigure);
            app.FooterLabel.Position = [30 25 1400 25];
            app.FooterLabel.Text = 'Research Simulation Dashboard  |  Residential, Critical Infrastructure, and Community Microgrid Modules';
            app.FooterLabel.FontSize = 13;
            app.FooterLabel.FontColor = [0.38 0.42 0.48];
            app.FooterLabel.HorizontalAlignment = 'center';

            app.UIFigure.Visible = 'on';
        end
    end

    methods (Access = public)

        function app = Main_Scenario_Selector_App_Visual
            createComponents(app);
        end

        function delete(app)
            try
                if ~isempty(app.HouseApp)
                    delete(app.HouseApp);
                end
            catch
            end

            try
                if ~isempty(app.CriticalApp)
                    delete(app.CriticalApp);
                end
            catch
            end

            try
                if ~isempty(app.MunicipalityApp)
                    delete(app.MunicipalityApp);
                end
            catch
            end

            delete(app.UIFigure);
        end
    end
end
