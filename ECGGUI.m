classdef ECGGUI < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                      matlab.ui.Figure
        VisualizeButton               matlab.ui.control.Button
        FilessupportedmatdatLabel     matlab.ui.control.Label
        ECGProcessingLabel            matlab.ui.control.Label
        ClickheretouploadafileButton  matlab.ui.control.Button
        StatusLabel                   matlab.ui.control.Label
        StatusLabel2                   matlab.ui.control.Label
        WarningLabel     matlab.ui.control.Label
        ECGInstance ECGProcessor
        SettingsButton matlab.ui.control.Button % New Settings Button
        SettingsFigure matlab.ui.Figure
        LowPassCheckbox matlab.ui.control.CheckBox
        HighPassCheckbox matlab.ui.control.CheckBox
        FrequencySpectrumCheckbox matlab.ui.control.CheckBox
    end

    % Callbacks that handle component events
    methods (Access = private)
        function signalResized = resizeSignal(app, signal, newLength)
            if length(signal) > newLength
                % Truncate the signal if it's longer than desired
                signalResized = signal(1:newLength);
            elseif length(signal) < newLength
                % Extend the signal with zeros if it's shorter than desired
                signalResized = [signal; zeros(newLength - length(signal), 1)];
            else
                % If the length is already matching, just return the original signal
                signalResized = signal;
            end
        end
        function createSettingsDialog(app)
        % Create a settings figure, hidden by default
            app.SettingsFigure = uifigure('Name', 'Settings', 'Visible', 'off', 'Position', [100, 100, 300, 200], 'CloseRequestFcn', @(src, event) app.toggleSettingsVisibility(false));
            app.LowPassCheckbox = uicheckbox(app.SettingsFigure, 'Text', 'Enable Lowpass Filter', 'Position', [10, 150, 150, 20]);
            app.LowPassCheckbox.Value = true;
            app.HighPassCheckbox = uicheckbox(app.SettingsFigure, 'Text', 'Enable Highpass Filter', 'Position', [10, 120, 150, 20]);
            app.HighPassCheckbox.Value = true; 
            app.FrequencySpectrumCheckbox = uicheckbox(app.SettingsFigure, 'Text', 'Frequency Spectrum', 'Position', [10, 90, 150, 20]);
            app.FrequencySpectrumCheckbox.Value = true;
        end

    % Callback function for the Settings Button
 
    
        % Function to toggle the visibility of the settings dialog
        function toggleSettingsVisibility(app, isVisible)
            if isVisible
                app.SettingsFigure.Visible = 'on';
            else
                app.SettingsFigure.Visible = 'off';
            end
        end

        % Button pushed function: ClickheretouploadafileButton
        function ClickheretouploadafileButtonPushed(app, event)
            % Ask the user to select .dat files only
            [dat_files, path] = uigetfile({'*.dat', 'Data Files (*.dat)'}, 'Select .dat files', 'MultiSelect', 'on');
            
            % If the user selects 'Cancel', exit the function
            if isequal(dat_files, 0)
                app.StatusLabel.Text = 'File selection cancelled.';
                app.StatusLabel.FontColor = [1, 0, 0]; % Red text
                pause(0.1); %Pause
                figure(app.UIFigure);
                return;
            end
            
            % Ensure 'dat_files' is a cell array even when a single file is selected
            if ischar(dat_files)
                dat_files = {dat_files};
            end
            
            % Store the original directory to revert back to it later
            originalDir = pwd; %pwd is the current folder
            
            %List to keep track of skipped files
            skippedFiles = {};
            
            % Change the current directory to where the .dat and .hea files are located
            cd(path);
            
            % Process each .dat file
            processedMatFiles = {};
            
            % Process each .dat file
            for i = 1:length(dat_files)
                baseFileName = dat_files{i};
                [~, name, ~] = fileparts(baseFileName);
                datFilePath = fullfile(path, baseFileName);
                heaFilePath = fullfile(path, [name '.hea']);
                
                % Check if both .dat and .hea files exist
                if exist(datFilePath, 'file') == 2 && exist(heaFilePath, 'file') == 2
                    try
                        [sig1, Fs1, tm1] = rdsamp(name, [1]);  % Read only the first channel
                        matFileName = fullfile(path, [name '.mat']);
                        save(matFileName, 'sig1', 'Fs1', 'tm1');
                        processedMatFiles{end+1} = matFileName; % Store the path of the processed .mat file
                    catch ME
                        disp(['Error reading file: ' name ' - ' ME.message]);
                        skippedFiles{end+1} = baseFileName;
                    end
                else
                    skippedFiles{end+1} = baseFileName;
                end
            end
            
            % Now create an ECGProcessor instance with the paths of the processed files
            if ~isempty(processedMatFiles)
                app.ECGInstance = ECGProcessor(processedMatFiles);
            end
            
            % Optionally, display the paths of the processed files
            for i = 1:length(processedMatFiles)
                disp(processedMatFiles{i});
            end
            
            % Change back to the original directory
            cd(originalDir);
            
            % Update the status label to reflect skipped files
            if isempty(skippedFiles)
                app.StatusLabel.Text = 'All files converted successfully.';
                app.StatusLabel2.Text = '';
                app.StatusLabel.FontColor = [0, 1, 0]; % Green text
                pause(0.1); %Pause
                figure(app.UIFigure);
            else
                app.StatusLabel.Text = 'Some files were skipped.';
                app.StatusLabel.FontColor = [1, 0, 0]; % Red text
                % Display the names of the skipped files
                app.StatusLabel2.Text = ['Skipped files (missing .hea or load error): ' strjoin(skippedFiles, ', ')];
                pause(0.1); %Pause
                figure(app.UIFigure);
            end
        end
        function VisualizeButtonPushed(app, event)
            if isempty(app.ECGInstance) || isempty(app.ECGInstance.Time) || isempty(app.ECGInstance.Signal)
                uialert(app.UIFigure, 'ECG data not loaded or invalid.', 'Error');
                return;
            end
           timevalue = app.ECGInstance.Time;
           signal = app.ECGInstance.Signal;
           disp(num2str(length(signal)))
            % Ensure timevalue is monotonically increasing and signal is aligned
            if any(diff(timevalue) <= 0) || length(timevalue) ~= length(signal)
                uialert(app.UIFigure, 'Time values are not monotonically increasing or signal length mismatch.', 'Error');
                return;
            end
            try
                assignin('base', 'timevalue', app.ECGInstance.Time);
                assignin('base', 'signal', app.ECGInstance.Signal);
                sim("Filter");
                lowpass = evalin('base', 'lowpass');
                highpass = evalin('base', 'highpass');
                desiredLength = length(timevalue);
                lowpass = app.resizeSignal(lowpass, desiredLength);
                highpass = app.resizeSignal(highpass, desiredLength);
            catch ME
                uialert(app.UIFigure, ['Error running Simulink model: ' ME.message], 'Simulink Error');
                return;
            end
                app.ECGInstance.plotOriginalSignal();
                if app.LowPassCheckbox.Value
                    app.ECGInstance = app.ECGInstance.applyLowPassFilter(lowpass);
                end
                if app.HighPassCheckbox.Value
                    app.ECGInstance = app.ECGInstance.applyHighPassFilter(highpass);
                    bpm = app.ECGInstance.computeHeartRate(app.ECGInstance.FilteredSignalHigh);
                end
                if app.FrequencySpectrumCheckbox.Value
                    app.ECGInstance.plotFrequencySpectrum()
                end
        end
    end


    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            screenSize = get(groot, 'ScreenSize'); % [left, bottom, width, height]
            screenWidth = screenSize(3);
            screenHeight = screenSize(4);
    
            % Define the app window size
            appWidth = 640;
            appHeight = 480;
    
            % Calculate the position to center the app on the screen
            positionLeft = (screenWidth - appWidth) / 2;
            positionBottom = (screenHeight - appHeight) / 2;
    
            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [positionLeft, positionBottom, appWidth, appHeight];
            app.UIFigure.Name = 'ECG Signal Processing Beta';
            app.UIFigure.Resize = 'off';
            app.UIFigure.Tag = 'ECGUniqueTag';

            % Create ClickheretouploadafileButton
            app.ClickheretouploadafileButton = uibutton(app.UIFigure, 'push');
            app.ClickheretouploadafileButton.ButtonPushedFcn = createCallbackFcn(app, @ClickheretouploadafileButtonPushed, true);
            app.ClickheretouploadafileButton.FontSize = 18;
            app.ClickheretouploadafileButton.FontWeight = 'bold';
            app.ClickheretouploadafileButton.Position = [203 194 251 131];
            app.ClickheretouploadafileButton.Text = 'Click here to upload files';

            % Create ECGProcessingLabel
            app.ECGProcessingLabel = uilabel(app.UIFigure);
            app.ECGProcessingLabel.FontSize = 24;
            app.ECGProcessingLabel.FontWeight = 'bold';
            app.ECGProcessingLabel.Position = [232 413 194 47];
            app.ECGProcessingLabel.Text = 'ECG Processing';

            app.WarningLabel = uilabel(app.UIFigure);
            app.WarningLabel.HorizontalAlignment = 'center';
            app.WarningLabel.WordWrap = 'on';
            app.WarningLabel.FontName = 'Lucida Bright';
            app.WarningLabel.FontSize = 14;
            app.WarningLabel.FontWeight = 'bold';
            app.WarningLabel.FontColor = [0.6353 0.0784 0.1843];
            app.WarningLabel.Position = [71 334 500 61];
            app.WarningLabel.Text = 'Warning:If your file(s) are .dat, make sure to have header(.hea) files within the same directory!';

            % Create FilessupportedmatdatLabel
            app.FilessupportedmatdatLabel = uilabel(app.UIFigure);
            app.FilessupportedmatdatLabel.HorizontalAlignment = 'center';
            app.FilessupportedmatdatLabel.FontName = 'Arial';
            app.FilessupportedmatdatLabel.FontSize = 14;
            app.FilessupportedmatdatLabel.FontColor = [1 0 0];
            app.FilessupportedmatdatLabel.Position = [245 210 167 22];
            app.FilessupportedmatdatLabel.Text = 'Files supported: .dat';
            % Create StatusLabel
            app.StatusLabel = uilabel(app.UIFigure);
            app.StatusLabel.HorizontalAlignment = 'center';
            app.StatusLabel.WordWrap = 'on';
            app.StatusLabel.FontName = 'Lucida Bright';
            app.StatusLabel.FontSize = 18;
            app.StatusLabel.FontColor = [1 0 0]; % Red text
            app.StatusLabel.Position = [203 140 251 50]; % Set this to position the label below the button
            app.StatusLabel.Text = '';
            % Create StatusLabel2
            app.StatusLabel2= uilabel(app.UIFigure);
            app.StatusLabel2.HorizontalAlignment = 'center';
            app.StatusLabel2.WordWrap = 'on';
            app.StatusLabel2.FontName = 'Lucida Bright';
            app.StatusLabel2.FontSize = 16;
            app.StatusLabel2.FontColor = [1 0 0]; % Red text
            app.StatusLabel2.Position = [116 30 425 120]; % Set this to position the label below the button
            app.StatusLabel2.Text = '';
            % VisualizeBUtton
            app.VisualizeButton = uibutton(app.UIFigure, 'push');
            app.VisualizeButton.ButtonPushedFcn = createCallbackFcn(app, @VisualizeButtonPushed, true);
            app.VisualizeButton.FontSize = 16;
            app.VisualizeButton.FontWeight = 'bold';
            app.VisualizeButton.Position = [506 12 125 33];
            app.VisualizeButton.Text = 'Visualize';
            % Create SettingsButton
            app.SettingsButton = uibutton(app.UIFigure, 'push');
            app.SettingsButton.ButtonPushedFcn = createCallbackFcn(app, @SettingsButtonPushed, true);
            app.SettingsButton.Position = [10, 10, 100, 22];
            app.SettingsButton.FontWeight = 'bold';
            app.SettingsButton.Text = 'Settings';
            app.UIFigure.CloseRequestFcn = @(src, event) closeApp(app, event);

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = ECGGUI

            % Find any existing app instances and close them
            app.createSettingsDialog(); % Ensure this is called in the constructor
            existingApp = findall(0, 'Type', 'Figure', 'Tag', 'ECGUniqueTag');
            if ~isempty(existingApp)
                delete(existingApp); % Changed from 'close' to 'delete'
            end

            % Create UIFigure and components
            createComponents(app);

            % Register the app with App Designer
            registerApp(app, app.UIFigure);

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end
