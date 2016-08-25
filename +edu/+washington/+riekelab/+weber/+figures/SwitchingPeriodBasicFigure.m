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
        
        binSize                         % Size of histogram bin for PSTH (ms)
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
        
        function obj = SwitchingPeriodBasicFigure(amp,binSize,numEpochsAvg,numAvgsPlot,numEpochs)
            obj.amp = amp;
            obj.binSize = binSize;
            obj.numEpochsAvg = numEpochsAvg;
            obj.numAvgsPlot = numAvgsPlot;
            
            %%%% flip axes ud
            obj.axesHandle(1) = subplot(3,1,1:2,...
                'Parent',obj.figureHandle);
            xlabel(obj.axesHandle(1), 'Time (s)');
            ylabel(obj.axesHandle(1), 'Epoch');
            ylim(obj.axesHandle(1), [1 numEpochs+1]);

            obj.axesHandle(2) = subplot(3,1,3,...
                'Parent',obj.figureHandle);
            xlabel(obj.axesHandle(2), 'Time (s)');
            ylabel(obj.axesHandle(2), 'Firing rate (sp/s)');       
        end
        
        function clear(obj)  % executed each time 'play' button is hit
            cla(obj.axesHandle(1))
            cla(obj.axesHandle(2))
            obj.allResponses = [];
            obj.epochCount = 0;
            obj.mostRecentAvgs = [];
        end
        
        function handleEpoch(obj, epoch)
            
            response = epoch.getResponse(obj.amp);
            epochResponseTrace = response.getData();
            sampleRate = response.sampleRate.quantityInBaseUnits;
            edges = 0:obj.binSize/1000*sampleRate:length(epochResponseTrace);
            centers = (edges(1:end-1)+obj.binSize/1000*sampleRate/2)/sampleRate;
            
            %%% for spikes
            S = edu.washington.riekelab.turner.utils.spikeDetectorOnline(epochResponseTrace);
            %%%
            
            newHist = histc(S.sp,edges);
            if isempty(newHist)
                newHist = zeros(size(edges));
            end
            obj.allResponses = cat(1,obj.allResponses,newHist(1:end-1));
            obj.epochCount = obj.epochCount + 1;
            
            %%% plot raster
            for spNum = 1:length(S.sp)
                
                line([S.sp(spNum) S.sp(spNum)]/sampleRate,[0 .8]+obj.epochCount,...
                    'Parent', obj.axesHandle(1),'Color','k');
            end
            xlim(obj.axesHandle(1),[0 length(epochResponseTrace-1)/sampleRate]);
                
            %%% plot running average PSTH
            cla(obj.axesHandle(2))
            if obj.epochCount <= obj.numEpochsAvg % if fewer epochs completed that would like to average
                
                % take average of whatever epochs available and plot
                sumEpochs = sum(obj.allResponses(1:obj.epochCount,:),1);
                obj.mostRecentAvgs = sumEpochs/length(1:obj.epochCount)/(obj.binSize/1000);
                % only have one line to plot
                line(centers,obj.mostRecentAvgs,...
                    'Parent', obj.axesHandle(2),'Color',[0 0 0]);
                
            else
                % take average of 'numEpochsAvg' most recent epochs and add
                % on
                sumEpochs = sum(obj.allResponses(obj.epochCount-obj.numEpochsAvg+1:obj.epochCount,:),1);
                obj.mostRecentAvgs = [sumEpochs/obj.numEpochsAvg/(obj.binSize/1000); obj.mostRecentAvgs];
                
                tintFactors = linspace(0,1,obj.numAvgsPlot+1);
                for lineNum = 1:min(obj.numAvgsPlot,(obj.epochCount-obj.numEpochsAvg+1))
                    line(centers,obj.mostRecentAvgs(lineNum,:),...
                        'Parent', obj.axesHandle(2),'Color',[1 1 1]*tintFactors(lineNum)+[0 0 0]);
                end
                % keep first 'numEpochsAvg' as reference
                line(centers,obj.mostRecentAvgs(end,:),...
                    'Parent', obj.axesHandle(2),'Color',[1 0 0]);

            end
            
            
        end
        
    end
    
    
end
