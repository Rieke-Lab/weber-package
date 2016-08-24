classdef SwitchingPeriodBasicFigure < symphonyui.core.FigureHandler
    
    properties (SetAccess = private)
        
        periodDur                       % Switching period (s)
        
        baseLum                         % Luminance for first half of epoch
        baseContr                       % Contrast for first half of epoch
        stepLum                         % Luminance for second half of epoch
        stepContr                       % Contrast for second half of epoch
        
        numEpochs                       % Number of epochs
        
        frequencyCutoff                 % Noise frequency cutoff for smoothing (Hz)
        numberOfFilters                 % Number of filters in cascade for noise smoothing
        
        amp                             % Input amplifier
        
        smoothWindow                    % Std of Gaussian smoothing window for PSTH (ms)
        numEpochsAvg                    % Number of epochs to average for each PSTH trace
        numAvgsPlot                     % Number of PSTHs to keep on plot
        
    end
    
    properties (Access = private)
        axesHandle
        allResponses
        epochCount
        mostRecentAvgs
    end
    
    methods
        
        function obj = SwitchingPeriodBasicFigure(amp)
            obj.amp = amp;
            
            %%%% flip axes ud
            obj.axesHandle(1) = subplot(3,1,1:2,...
                'Parent',obj.figureHandle);
            xlabel(obj.axesHandle(1), 'Time (ms)');
            ylabel(obj.axesHandle(1), 'Epoch');
            
            obj.axesHandle(1) = subplot(3,1,3,...
                'Parent',obj.figureHandle);
            xlabel(obj.axesHandle(2), 'Time (ms)');
            ylabel(obj.axesHandle(2), 'Firing rate (sp/s)');
            title(obj.axesHandle(2),'PSTH');
            
            obj.allResponses = [];
            obj.epochCount = 0;
            obj.mostRecentAvgs = [];
            
        end
        
        function handleEpoch(obj, epoch)
            
            response = epoch.getResponse(obj.amp);
            epochResponseTrace = response.getData();
            sampleRate = response.sampleRate.quantityInBaseUnits;
            timeVec = 0:length(response)-1)/sampleRate;
            sig = obj.smoothWindow/1000*sampleRate;
            x = -5*sig:5*sig;
            smoothKernel = 1/(sig*sqrt(2*pi))*exp(-x.^2/(2*sig^2));
            
            %%% for spikes
            newResponse = zeros(size(epochResponseTrace));
            S = edu.washington.riekelab.turner.utils.spikeDetectorOnline(epochResponseTrace);
            newResponse(S.sp) = 1;
            %%%
            
            obj.allResponses = cat(1,obj.allResponses,newResponse);
            obj.epochCount = obj.epochCount + 1;
            
            %%% plot raster
            for spNum = 1:length(s.sp)
                
                line([S.sp(spNum) S.sp(spNum)]/sampleRate,[0 .8]+obj.epochCount,...
                    'Parent', obj.axesHandle(1),'Color','k');
            end
            
            %%% plot running average PSTH
            if obj.epochCount <= obj.numEpochsAvg % if fewer epochs completed that would like to average
                
                % take average of whatever epochs available and plot
                sumEpochs = sum(obj.allResponses(1:obj.epochCount,:),1);
                smoothedPSTH = conv(sumEpochs,smoothKernel,'same');  % PSTH for all epochs available
                obj.mostRecentAvgs = smoothedPSTH;
            else
                % take average of 'numEpochsAvg' most recent epochs and add
                % on
                sumEpochs = sum(obj.allResponses(obj.epochCount-obj.numEpochsAvg:obj.epochCount,:),1);
                smoothedPSTH = conv(sumEpochs,smoothKernel,'same');  % PSTH for all epochs available
                obj.mostRecentAvgs = [smoothedPSTH; obj.mostRecentAvgs];
            end
            
            tintFactors = linespace(0,1,obj.numAvgsPlot+1);
            for lineNum = 1:obj.numAvgsPlot
                line(timeVec,obj.mostRecentAvgs(lineNum,:),...
                    'Parent', obj.axesHandle(2),'Color',[1 1 1]*tintFactors(lineNum)+[0 0 0]);
            end
            
            
        end
        
    end
    
    
end
