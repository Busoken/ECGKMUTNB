classdef ECGProcessor
    properties
        Signal
        Time
        Fs %Frequency Sampling Rate
        PatientNumber
        FilteredSignalLow
        FilteredSignalHigh
        Frequency
        FFTData
        FFTDataLow
        FFTDataHigh
        FilePaths
        N
        f
    end
    
    methods
        function obj = ECGProcessor(filePaths)
            obj.FilePaths = filePaths;
            [obj.Signal, obj.Time, obj.Fs] = obj.loadECGData();
            obj = obj.performFFT();
            obj.N = size(obj.Time,1);
            obj.f = -(obj.Fs)/2:obj.Fs/(obj.N):obj.Fs/2-obj.Fs/obj.N;
        end

        
        function plotOriginalSignal(obj)
            h= figure;
            set(h, 'Position', [0, 300, 500, 400]);
            plot(obj.Time, obj.Signal);
            title('Unfiltered Signal');
            xlabel('Time(sec)');
            ylabel('Voltage(mVolts)');
        end
        
        function obj = applyLowPassFilter(obj, signal)
            % Update the FilteredSignalLow property
            obj.FilteredSignalLow = signal;
        
            % Debugging: Check the lengths of the vectors
            disp(['Length of Time vector: ', num2str(length(obj.Time))]);
            disp(['Length of Filtered Signal vector: ', num2str(length(obj.FilteredSignalLow))]);
        
            % Ensure the vectors are the same length before plotting
            if length(obj.Time) == length(obj.FilteredSignalLow)
                h = figure;
                set(h, 'Position', [550, 300, 500, 400]);
                plot(obj.Time, obj.FilteredSignalLow);
                title('Low Pass Filtered Signal');
                xlabel('Time (sec)');
                ylabel('Voltage (mVolts)');
                obj.FFTDataLow = fftshift(fft(obj.FilteredSignalLow));
            else
                error('Time and Signal vectors are not the same length.');
            end
        end

        
        function obj = applyHighPassFilter(obj,signal)
            h = figure;
            set(h, 'Position', [1100, 300, 500, 400]);
            obj.FilteredSignalHigh = signal;
            obj.FFTDataHigh = fftshift(fft(obj.FilteredSignalHigh));
            plot(obj.Time, obj.FilteredSignalHigh);
            title('High Pass Filtered Signal');
            xlabel('Time(sec)');
            ylabel('Voltage(mVolts)');
        end
        
        
        function plotFrequencySpectrum(obj)
            h = figure;
            set(h, 'Position', [1500, 300, 500, 400]);
            ax(1) = subplot(3,1,1);
            plot(obj.f,abs(obj.FFTData)/obj.N);
            title('Frequency Spectrum of Unfiltered Signal');
            xlabel('Frequency(Hz)');
            ylabel('Amplitude');
            ax(2) = subplot(3,1,2);
            plot(obj.f,abs(obj.FFTDataLow)/obj.N);
            title('Frequency Spectrum of Low Pass filtered Signal');
            xlabel('Frequency(Hz)');
            ylabel('Amplitude');
            ax(3) = subplot(3,1,3);
            plot(obj.f,abs(obj.FFTDataHigh)/obj.N);
            linkaxes(ax,'y');
            title('Frequency Spectrum of Filtered Signal');
            xlabel('Frequency(Hz)');
            ylabel('Amplitude');
        end
        
        function obj = performFFT(obj)
            obj.FFTData = fftshift(fft(obj.Signal));
        end
        
        function [c, l, ap, cd1, cd2, cd3, cd4] = applyWaveletTransform(obj)
            [c, l] = wavedec(obj.FilteredSignalHigh, 4, 'sym4');
            ap = appcoef(c, l, 'sym4');
            [cd1, cd2, cd3, cd4] = detcoef(c, l, [1 2 3 4]);
        end
        
        function y = reconstructSignal(obj, c, l)
            c_filt = cat(1, zeros(size(ap)), cd4, cd3, zeros(size(cd2)), zeros(size(cd1)));
            y = waverec(c_filt, l, 'sym4');
        end
        
        function bpm = computeHeartRate(obj, y)
            y_peak = abs(y).^2;
            avg = mean(y_peak);
            [Rpeaks, peaks] = findpeaks(y_peak, obj.Time, 'MinPeakHeight', 8*avg, 'MinPeakDistance', 0.3);
            totalpeaks = length(peaks);
            bpm = totalpeaks * 60 / obj.Time(end);
            fprintf('\nBPM = %f\n',bpm);
        end
        function [sig, t, Fs] = loadECGData(obj)
            sig = [];
            t = [];
            for i = 1:length(obj.FilePaths)
                loadedData = load(obj.FilePaths{i});
                sig = cat(1, sig, loadedData.sig1);
                disp(['Length of signal after processing file ', num2str(i), ': ', num2str(length(sig))]);
                t = cat(1, t, loadedData.tm1 + ((i-1)*10));
                if i < length(obj.FilePaths)
                    t(end) = [];  % Remove the last time value to avoid overlap
                    sig(end) = []; % Remove the last signal value to avoid overlap
                end
            end
            Fs = loadedData.Fs1;
        end
    end
end
