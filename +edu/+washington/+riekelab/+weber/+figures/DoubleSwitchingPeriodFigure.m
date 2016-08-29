classdef DoubleSwitchingPeriodFigure < symphonyui.core.FigureHandler
    
    properties (SetAccess = private)
              
        periodDur1              % Switching period 1 (s)
        periodDur2              % Switching period 2 (s)
        epochsPerBlock          % Number of epochs (for each switching period) within each block
        amp                     % Input amplifier
        binSize                 % Size of histogram bin for PSTH (ms)
    end
    
    properties (Access = private)
        epochCount
        axesHandle
        lineHandle
        allHists
    end
    
    methods
        
        function obj = DoubleSwitchingPeriodFigure(amp,sampleRate,periodDur1,periodDur2,epochsPerBlock,binSize)
            obj.amp = amp;
            obj.periodDur1 = periodDur1;
            obj.periodDur2 = periodDur2;
            obj.epochsPerBlock = epochsPerBlock;
            obj.binSize = binSize;
            
            obj.epochCount = zeros(epochsPerBlock*2,1);
           
            % first period
            obj.axesHandle(1) = subplot(1,2,1,...
                'Parent',obj.figureHandle);
            xlabel(obj.axesHandle(1), 'Time (s)');
            ylabel(obj.axesHandle(1), 'Firing rate (sp/s)');

            % second period
            obj.axesHandle(2) = subplot(1,2,2,...
                'Parent',obj.figureHandle);
            xlabel(obj.axesHandle(2), 'Time (s)');
            ylabel(obj.axesHandle(2), 'Firing rate (sp/s)');
            
            periodDurs = [obj.periodDur1 obj.periodDur2];
            obj.allHists = cell(double(obj.epochsPerBlock)*2,1);
            
            % initialize lines
            tintFactors = linspace(0,1,double(obj.epochsPerBlock)+1);
            count = 0;
            for periodNum = 1:2
                edges = 0:obj.binSize/1000*sampleRate:periodDurs(periodNum)*sampleRate;
                centers = (edges(1:end-1)+obj.binSize/1000*sampleRate/2)/sampleRate;
                
                title(obj.axesHandle(periodNum),['Period Duration: ' num2str(periodDurs(periodNum))]);
                xlim(obj.axesHandle(periodNum),[0 periodDurs(periodNum)]);
                for lineNum = 1:obj.epochsPerBlock
                    count = count+1;
                    obj.lineHandle(count) = line(centers,zeros(size(centers)),...
                        'Parent', obj.axesHandle(periodNum),'color',[1 1 1]*tintFactors(lineNum)+[0 0 0]);
                    obj.allHists{count} = zeros(size(centers));
                end
            end

        end
       
        function handleEpoch(obj, epoch)
            positionInBlock = epoch.parameters('positionInBlock');

            obj.epochCount(positionInBlock) = obj.epochCount(positionInBlock) + 1;
           
            response = epoch.getResponse(obj.amp);
            epochResponseTrace = response.getData();
            sampleRate = response.sampleRate.quantityInBaseUnits;
            
            edges = 0:obj.binSize/1000*sampleRate:length(epochResponseTrace);

            %%% for spikes
            S = edu.washington.riekelab.turner.utils.spikeDetectorOnline(epochResponseTrace);
            %%%
            
            newHist = histc(S.sp,edges);
            if isempty(newHist)
                newHist = zeros(size(edges));
            end
            obj.allHists{positionInBlock} = obj.allHists{positionInBlock} + newHist(1:end-1);
            
            %%% plot PSTH by updating single line
            numTrialsAvg = obj.epochCount(positionInBlock); % number of trials averaged over
            set(obj.lineHandle(positionInBlock),'ydata',obj.allHists{positionInBlock}/double(numTrialsAvg)/(obj.binSize/1000));
            
        end
        
    end
    
    
end
