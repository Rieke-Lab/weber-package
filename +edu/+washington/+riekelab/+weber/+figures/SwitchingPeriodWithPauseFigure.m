classdef SwitchingPeriodWithPauseFigure < symphonyui.core.FigureHandler
    
    properties (SetAccess = private)
              
        periodDur               % Switching period 1 (s)
        pauseDur                % Switching period 2 (s)
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
        
        function obj = SwitchingPeriodWithPauseFigure(amp,sampleRate,periodDur,pauseDur,epochsPerBlock,binSize)
            obj.amp = amp;
            obj.periodDur = periodDur;
            obj.pauseDur = pauseDur;
            obj.epochsPerBlock = epochsPerBlock;
            obj.binSize = binSize;
            
            obj.epochCount = zeros(epochsPerBlock,1);
           
            obj.axesHandle(1) = subplot(1,1,1,...
                'Parent',obj.figureHandle);
            xlabel(obj.axesHandle(1), 'Time (s)');
            ylabel(obj.axesHandle(1), 'Firing rate (sp/s)');
           
            periodDur = obj.periodDur;
            obj.allHists = cell(double(obj.epochsPerBlock),1);
            
            % initialize lines
            tintFactors = linspace(0,1,double(obj.epochsPerBlock)+1);
            edges = 0:obj.binSize/1000*sampleRate:periodDur*sampleRate;
            centers = (edges(1:end-1)+obj.binSize/1000*sampleRate/2)/sampleRate;
            
%             title(obj.axesHandle(1),['Period Duration: ' num2str(periodDur)]);
            xlim(obj.axesHandle(1),[0 periodDur]);
            for lineNum = 1:obj.epochsPerBlock
                obj.lineHandle(lineNum) = line(centers,zeros(size(centers)),...
                    'Parent', obj.axesHandle(1),'color',[1 1 1]*tintFactors(lineNum)+[0 0 0],'linewidth',2);
                obj.allHists{lineNum} = zeros(size(centers));
            end

        end
       
        function handleEpoch(obj, epoch)
            positionInBlock = epoch.parameters('positionInBlock');
            if positionInBlock>0
                obj.epochCount(positionInBlock) = obj.epochCount(positionInBlock) + 1;
                
                response = epoch.getResponse(obj.amp);
                epochResponseTrace = response.getData();
                sampleRate = response.sampleRate.quantityInBaseUnits;
                
                edges = 0:obj.binSize/1000*sampleRate:length(epochResponseTrace);
                
                %%% for spikes
                S = edu.washington.riekelab.weber.utils.spikeDetectorOnline(epochResponseTrace);
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
    
    
end
