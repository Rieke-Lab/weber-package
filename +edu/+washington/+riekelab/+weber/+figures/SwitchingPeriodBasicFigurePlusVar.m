classdef SwitchingPeriodBasicFigurePlusVar < symphonyui.core.FigureHandler
    
    properties (SetAccess = private)
        
        periodDur                       % Switching period (s)
        
        numEpochs                       % Number of epochs
        
        frequencyCutoff                 % Noise frequency cutoff for smoothing (Hz)
        numberOfFilters                 % Number of filters in cascade for noise smoothing
        
        amp                             % Input amplifier
        
        binSize                         % Size of histogram bin for PSTH (ms)
        
    end
    
    properties (Access = private)
        axesHandle
        allResponses
        epochCount
        mostRecentAvg
        mostRecentVar
        numBinsKeep
    end
    
    methods
        
        function obj = SwitchingPeriodBasicFigurePlusVar(amp,binSize,numEpochs)
            obj.amp = amp;
            obj.binSize = binSize;
            obj.allResponses = [];
            obj.epochCount = 0;
            
            %%%% flip axes ud
            obj.axesHandle(1) = subplot(4,1,1:2,...
                'Parent',obj.figureHandle);
            xlabel(obj.axesHandle(1), 'Time (s)');
            ylabel(obj.axesHandle(1), 'Epoch');
            ylim(obj.axesHandle(1), [1 numEpochs+1]);
            
            obj.axesHandle(2) = subplot(4,1,3,...
                'Parent',obj.figureHandle);
            xlabel(obj.axesHandle(2), 'Time (s)');
            ylabel(obj.axesHandle(2), 'Firing rate (sp/s)');
            
            obj.axesHandle(3) = subplot(4,1,4,...
                'Parent',obj.figureHandle);
            xlabel(obj.axesHandle(3), 'Time (s)');
            ylabel(obj.axesHandle(3), 'Firing rate var (sp^2/s^2)');
        end
        
        function handleEpoch(obj, epoch)
            
            response = epoch.getResponse(obj.amp);
            epochResponseTrace = response.getData();
            sampleRate = response.sampleRate.quantityInBaseUnits;
            edges = 0:obj.binSize/1000*sampleRate:length(epochResponseTrace);
            centers = (edges(1:end-1)+obj.binSize/1000*sampleRate/2)/sampleRate;
            
            if isempty(obj.numBinsKeep)
                obj.numBinsKeep = length(edges)-1;
            end
            %%% for spikes
            S = edu.washington.riekelab.weber.utils.spikeDetectorOnline(epochResponseTrace);
            %%%
            
            newHist = histc(S.sp,edges);
            if isempty(newHist)
                newHist = zeros(size(edges));
            end
            obj.allResponses = cat(1,obj.allResponses,newHist(1:obj.numBinsKeep));
            obj.epochCount = obj.epochCount + 1;
            
            %%% plot raster
            for spNum = 1:length(S.sp)
                
                line([S.sp(spNum) S.sp(spNum)]/sampleRate,[0 .8]+obj.epochCount,...
                    'Parent', obj.axesHandle(1),'Color','k');
            end
            xlim(obj.axesHandle(1),[0 length(epochResponseTrace-1)/sampleRate]);
            
            %%% plot running average PSTH
            cla(obj.axesHandle(2))
            
            % take average of whatever epochs available and plot
            sumEpochs = sum(obj.allResponses(1:obj.epochCount,:),1);
            obj.mostRecentAvg = sumEpochs/length(1:obj.epochCount)/(obj.binSize/1000);
            % only have one line to plot
            line(centers(1:obj.numBinsKeep),obj.mostRecentAvg,...
                'Parent', obj.axesHandle(2),'Color',[0 0 0]);
            
            %%% plot running variance over time
            cla(obj.axesHandle(3))
            
            % take var of whatever epochs available and plot
            obj.mostRecentVar = var(obj.allResponses(1:obj.epochCount,:)/(obj.binSize/1000),[],1);
            % only have one line to plot
            line(centers(1:obj.numBinsKeep),obj.mostRecentVar,...
                'Parent', obj.axesHandle(3),'Color',[0 0 0]);
            
        end
        
    end
    
    
end
