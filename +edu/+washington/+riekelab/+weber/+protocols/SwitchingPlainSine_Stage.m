classdef SwitchingPlainSine_Stage < edu.washington.riekelab.protocols.RiekeLabStageProtocol
    
    properties
        periodDur = 4                   % Switching period (s)
        sinFreq = 8;                    % Frequency of sine wave (Hz)
        
        lum = .5                        % Luminance
        baseContr = .1                  % Contrast for first half of epoch
        stepContr = 1                   % Contrast for second half of epoch
        startLow = false                % Start at baseLum/baseContr or stepLum/stepContr
        
        epochsPerBlock = uint16(20)     % Number of epochs (for each switching period) within each block
        numBlocks = uint16(10)          % Number of blocks
        
        amp                             % Input amplifier
        
        binSize = 50;                   % Size of histogram bin for PSTH (ms)
        numEpochsAvg = uint16(25);       % Number of epochs to average for each PSTH trace
        numAvgsPlot = uint16(5);        % Number of PSTHs to keep on plot
                
        apertureDiameter = 0 % um
        backgroundIntensity = 0.5 % (0-1)

        onlineAnalysis = 'none'
        numberOfAverages = uint16(10) % number of epochs to queue
    end

    properties (Hidden)
        ampType
        onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'exc', 'inh'})
        preTime = 0;
        tailTime = 0;
    end
    
    methods
        
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end
         
        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);

            obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));
%             obj.showFigure('edu.washington.riekelab.weber.figures.FrameTimingFigure',...
%                 obj.rig.getDevice('Stage'), obj.rig.getDevice('Frame Monitor'));
            
            obj.showFigure('edu.washington.riekelab.figures.ProgressFigure', obj.epochsPerBlock*2*obj.numBlocks);

            if ~strcmp(obj.onlineAnalysis,'none')
                obj.showFigure('edu.washington.riekelab.weber.figures.SwitchingPeriodBasicFigure',obj.rig.getDevice(obj.amp),obj.binSize,obj.numEpochsAvg,obj.numAvgsPlot,obj.epochsPerBlock*2*obj.numBlocks,obj.onlineAnalysis);
            end
        end
        
        function prepareEpoch(obj, epoch)
            
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, epoch);
            
            epochNum = obj.numEpochsPrepared;
            positionInBlock = mod(epochNum,double(obj.epochsPerBlock)*2); % calculate whether in first or second half of each full block
            if positionInBlock == 0
                positionInBlock = double(obj.epochsPerBlock)*2;
            end
            if  positionInBlock <= obj.epochsPerBlock
                mult = 1;
            else
                mult = -1;
            end
            roundedPeriodDur = round(obj.periodDur/2/(1/obj.sinFreq))*(1/obj.sinFreq)*2;
            if  positionInBlock == obj.epochsPerBlock ||  positionInBlock == obj.epochsPerBlock *2
                periodDurActual = roundedPeriodDur + 1/obj.sinFreq/2;
            else
                periodDurActual = roundedPeriodDur;
            end
            
            epoch.addParameter('mult', mult);
            epoch.addParameter('positionInBlock', positionInBlock);
            epoch.addParameter('periodDurActual', periodDurActual);
            device = obj.rig.getDevice(obj.amp);
            duration = periodDurActual;
            epoch.addDirectCurrentStimulus(device, device.background, duration, obj.sampleRate);
            epoch.addResponse(device);
            
            
        end
        
        function p = createPresentation(obj)
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            
            %convert from microns to pixels...
            apertureDiameterPix = obj.rig.getDevice('Stage').um2pix(obj.apertureDiameter);
            
            p = stage.core.Presentation(obj.periodDur); %create presentation of specified duration
            p.setBackgroundColor(obj.lum); % Set background intensity
            
            % Create sine switching stimulus.
            stimRect = stage.builtin.stimuli.Rectangle();
            stimRect.size = canvasSize;
            stimRect.position = canvasSize/2;
            p.addStimulus(stimRect);
            epochNum = obj.numEpochsPrepared;
            stimValue = stage.builtin.controllers.PropertyController(stimRect, 'color',...
                @(state)getStimIntensity(obj, state.frame, epochNum));
            p.addController(stimValue); %add the controller
            
            %%%% big function to get stimulus intensity at particular frame
            function i = getStimIntensity(obj, frame, epochNum)
                persistent intensity;
                % determine which periodDur to use
                positionInBlock = mod(epochNum,double(obj.epochsPerBlock)*2); % calculate whether in first or second half of each full block
                if positionInBlock == 0
                    positionInBlock = double(obj.epochsPerBlock)*2;
                end
                if  positionInBlock <= obj.epochsPerBlock
                    mult = 1;
                else
                    mult = -1;
                end
                roundedPeriodDur = round(obj.periodDur/2/(1/obj.sinFreq))*(1/obj.sinFreq)*2;
                
                framesInFirstHalf = roundedPeriodDur/2*60; % assume 60 frames/sec for now
                
                intensity = sin(2*pi*obj.sinFreq*frame/60); 
                
                if frame <= framesInFirstHalf  % in first half
                    if obj.startLow  % start with baseContr
                        intensity = intensity*obj.baseContr;
                    else 
                        intensity = intensity*obj.stepContr;
                    end
                else % in second half
                    if obj.startLow
                        intensity = intensity*obj.stepContr;
                    else
                        intensity = intensity*obj.baseContr;
                    end
                end
                
                intensity = intensity*mult + obj.lum;  % add mean in
                i = intensity;
            end
            %%%%%%%
            
            if (obj.apertureDiameter > 0) %% Create aperture
                aperture = stage.builtin.stimuli.Rectangle();
                aperture.position = canvasSize/2;
                aperture.color = obj.backgroundIntensity;
                aperture.size = [max(canvasSize) max(canvasSize)];
                mask = stage.core.Mask.createCircularAperture(apertureDiameterPix/max(canvasSize), 1024); %circular aperture
                aperture.setMask(mask);
                p.addStimulus(aperture); %add aperture
            end
            
        end
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.epochsPerBlock*2*obj.numBlocks;
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.epochsPerBlock*2*obj.numBlocks;        
        end
    end
    
end