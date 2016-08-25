classdef DoubleSwitchingPeriodFigure < symphonyui.core.FigureHandler
    
    properties (SetAccess = private)
              
        periodDur1              % Switching period 1 (s)
        periodDur2              % Switching period 2 (s)

        baseLum                 % Luminance for first half of epoch
        baseContr               % Contrast for first half of epoch
        stepLum                 % Luminance for second half of epoch
        stepContr               % Contrast for second half of epoch

        epochsPerBlock          % Number of epochs (for each switching period) within each block
        numBlocks               % Number of blocks

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
        
        function obj = DoubleSwitchingPeriodFigure(amp,periodDur1,periodDur2,epochsPerBlock,numBlocks,binSize)
            obj.amp = amp;
            obj.periodDur1 = periodDur1;
            obj.periodDur2 = periodDur2;
            obj.epochsPerBlock = epochsPerBlock;
            obj.numBlocks = numBlocks;
            obj.binSize = binSize;
            
            obj.epochCount = 0;

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
        end
       
        function handleEpoch(obj, epoch)
            obj.epochCount = obj.epochCount + 1;
            idx = mod(obj.epochCount,obj.epochsPerBlock*2); % row index for allHists
            if idx == 0
                idx = obj.epochsPerBlock*2;
            end
            
            response = epoch.getResponse(obj.amp);
            epochResponseTrace = response.getData();
            sampleRate = response.sampleRate.quantityInBaseUnits;
            if obj.epochCount == 1
                periodDurs = [obj.periodDur1 obj.periodDur2];
                obj.allHists = cell(obj.epochsPerBlock*2,1);
                % initialize figs
                tintFactors = linspace(0,1,obj.epochsPerBlock+1);
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
            
            edges = 0:obj.binSize/1000*sampleRate:length(epochResponseTrace);

            %%% for spikes
            S = edu.washington.riekelab.turner.utils.spikeDetectorOnline(epochResponseTrace);
            %%%
            
            newHist = histc(S.sp,edges);
            if isempty(newHist)
                newHist = zeros(size(edges));
            end
            obj.allHists{idx} = obj.allHists{idx} + newHist(1:end-1);
            
            %%% plot PSTH by updating single line
            numTrialsAvg = ceil(obj.epochCount/(obj.epochsPerBlock*2)); % number of trials averaged over
            set(obj.lineHandle(idx),'ydata',obj.allHists{idx}/double(numTrialsAvg)/(obj.binSize/1000));
            
        end
        
    end
    
    
end
