classdef DoubleSwitchingPeriodFigure < symphonyui.core.FigureHandler
    
    properties (SetAccess = private)
              
        periodDur1 = 2                  % Switching period 1 (s)
        periodDur2 = 10;                % Switching period 2 (s)

        baseLum = 0;                    % Luminance for first half of epoch
        baseContr = .06;                % Contrast for first half of epoch
        stepLum = 1;                    % Luminance for second half of epoch
        stepContr = .06;                % Contrast for second half of epoch

        epochsPerBlock = uint16(6)      % Number of epochs (for each switching period) within each block
        numBlocks = uint16(20)          % Number of blocks

        amp                             % Input amplifier

        binSize = 50;                   % Size of histogram bin for PSTH (ms)
        
    end
    
    properties (Access = private)
        axesHandle
        lineHandle
        allHists
        epochCount
    end
    
    methods
        
        function obj = SwitchingPeriodBasicFigure(amp,binSize)
            obj.amp = amp;
            obj.binSize = binSize;
            
            obj.epochCount = 0;

            % first period
            obj.axesHandle(1) = subplot(1,2,1,...
                'Parent',obj.figureHandle);
            xlabel(obj.axesHandle(1), 'Time (ms)');
            ylabel(obj.axesHandle(1), 'Firing rate (sp/s)');

            % second period
            obj.axesHandle(2) = subplot(1,2,2,...
                'Parent',obj.figureHandle);
            xlabel(obj.axesHandle(2), 'Time (ms)');
            ylabel(obj.axesHandle(2), 'Firing rate (sp/s)');       
        end
        
           
                
        function handleEpoch(obj, epoch)
            obj.epochCount = obj.epochCount + 1;
            idx = mod(obj.epochCount,obj.epochsPerBlock*2); % row index for allHists
            
            response = epoch.getResponse(obj.amp);
            epochResponseTrace = response.getData();
            sampleRate = response.sampleRate.quantityInBaseUnits;
            edges = 0:obj.binSize/1000*sampleRate:length(epochResponseTrace);
            centers = edges(1:end-1)+obj.binSize/1000*sampleRate/2;
            if obj.epochCount == 1
                obj.allHists = zeros(obj.epochsPerBlock*2,length(epochResponseTrace));
                % initialize figs
                obj.tintFactors = linspace(0,1,obj.epochsPerBlock+1);
                count = 0;
                for periodNum = 1:2
                    title(obj.axesHandle(periodNum),['PeriodDur' num2str(periodNum)]);
                    for lineNum = 1:obj.epochsPerBlock
                        count = count+1;
                        obj.lineHandle(count) = line(obj.axesHandle(periodNum),centers,zeros(size(centers)),...
                            'Parent', obj.axesHandle(2),'color',[1 1 1]*tintFactors(lineNum)+[0 0 0]);
                    end
                end
            end
            
            %%% for spikes
            S = edu.washington.riekelab.turner.utils.spikeDetectorOnline(epochResponseTrace);
            %%%
            
            newHist = histc(S.sp,edges);
            if isempty(newHist)
                newHist = zeros(size(edges));
            end
            obj.allHists(idx,:) = obj.allHists(idx,:) + newHist;
            
            %%% plot PSTH by updating single line
            numTrialsAvg = ceil(obj.epochCount/(obj.epochsPerBlock*2)); % number of trials averaged over
            set(obj.lineHandle(idx),'ydata',obj.allHists(idx,:)/numTrialsAvg/(obj.binSize/1000));
            
        end
        
    end
    
    
end
