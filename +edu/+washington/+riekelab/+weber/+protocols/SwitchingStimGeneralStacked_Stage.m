classdef SwitchingStimGeneralStacked_Stage < edu.washington.riekelab.protocols.RiekeLabStageProtocol
% No way to recover noise stims

    properties
        periodDur = 2                   % Switching period (s)
        backgroundIntensity = 0.5       % Background intensity/luminance (0-1)
        contrPhase1 = 1                 % Contrast for first half of period
        contrPhase2 = 0.1               % Contrast for second half of period
        apertureDiameterPhase1 = 0      % Aperture diameter for first half of period (um); 0 gives full field
        apertureDiameterPhase2 = 0      % Aperture diameter for second half of period (um); 0 gives full field

        stimType = 'sine'               % 'sine','binary noise','noise steps'
        freqParam = 6;                  % sine: frequency of sine wave (Hz),  binary noise: dwell time for each draw (ms), noise steps: dwell time for each draw (ms)
        mult = 1;                       % +/-1; only used for sine wave
        
        periodsPerEpoch = uint16(10)    % Number of periods for each epoch
        numEpochs = uint16(10)          % Number of epochs
       
        tailTime = 0.25                 % Time after stimulus
        amp                             % Input amplifier
        
        onlineAnalysis = 'none'
        binSize = 50;                   % Size of histogram bin for PSTH (ms)
        numEpochsAvg = uint16(25);      % Number of epochs to average for each PSTH trace
        numAvgsPlot = uint16(5);        % Number of PSTHs to keep on plot
    end

    properties (Hidden)
        ampType
        onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'exc', 'inh'})
        stimTypeType = symphonyui.core.PropertyType('char', 'row', {'sine','binary noise','noise steps'})
        dwellCount
        currentStep
    end
    

    methods
        
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end
         
        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));
            obj.showFigure('edu.washington.riekelab.weber.figures.FrameTimingFigure',...
                obj.rig.getDevice('Stage'), obj.rig.getDevice('Frame Monitor'));
            
            obj.showFigure('edu.washington.riekelab.figures.ProgressFigure', obj.numEpochs);

            if ~strcmp(obj.onlineAnalysis,'none')
                obj.showFigure('edu.washington.riekelab.weber.figures.SwitchingPeriodBasicFigure',obj.rig.getDevice(obj.amp),obj.binSize,obj.numEpochsAvg,obj.numAvgsPlot,obj.numEpochs,obj.onlineAnalysis);
            end
        end
        
        function prepareEpoch(obj, epoch)
            
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj, epoch);
                        
            device = obj.rig.getDevice(obj.amp);
            duration = obj.periodDur*double(obj.periodsPerEpoch);
            epoch.addDirectCurrentStimulus(device, device.background, duration, obj.sampleRate);
            epoch.addResponse(device);
            
        end
        
        function p = createPresentation(obj)
            obj.dwellCount = 1;
            obj.currentStep = 0;
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            
            %convert from microns to pixels...
            
            p = stage.core.Presentation(obj.periodDur*double(obj.periodsPerEpoch)+obj.tailTime); %create presentation of specified duration
            p.setBackgroundColor(obj.backgroundIntensity); % Set background intensity
            
            
            % Create switching stimulus.
            stimRect = stage.builtin.stimuli.Rectangle();
            stimRect.size = canvasSize;
            stimRect.position = canvasSize/2;
            switch obj.stimType
                case 'sine'
                    stimValue = stage.builtin.controllers.PropertyController(stimRect, 'color',...
                        @(state)getSineStimIntensity(obj, state.frame));
                case 'binary noise'
                    stimValue = stage.builtin.controllers.PropertyController(stimRect, 'color',...
                        @(state)getBinaryNoiseStimIntensity(obj, state.frame));
                case 'noise steps'
                    stimValue = stage.builtin.controllers.PropertyController(stimRect, 'color',...
                        @(state)getNoiseStepsStimIntensity(obj, state.frame));
            end
            
            p.addController(stimValue); %add the controller
            p.addStimulus(stimRect);
            
            
            % aperture 1
            if (obj.apertureDiameterPhase1 > 0) %% Create aperture
                apertureDiameterPix1 = obj.rig.getDevice('Stage').um2pix(obj.apertureDiameterPhase1);
                aperture1 = stage.builtin.stimuli.Rectangle();
                aperture1.position = canvasSize/2;
                aperture1.color = obj.backgroundIntensity;
                aperture1.size = [max(canvasSize) max(canvasSize)];
                mask = stage.core.Mask.createCircularAperture(apertureDiameterPix1/max(canvasSize), 1024); %circular aperture
                aperture1.setMask(mask);
                p.addStimulus(aperture1); %add aperture
                aperture1Visible = stage.builtin.controllers.PropertyController(aperture1, 'visible', ...
                    @(state) getPhase1(obj, state.frame) );
                p.addController(aperture1Visible);
            end

            % aperture 2
            if (obj.apertureDiameterPhase2 > 0) %% Create aperture
                apertureDiameterPix2 = obj.rig.getDevice('Stage').um2pix(obj.apertureDiameterPhase2);
                aperture2 = stage.builtin.stimuli.Rectangle();
                aperture2.position = canvasSize/2;
                aperture2.color = obj.backgroundIntensity;
                aperture2.size = [max(canvasSize) max(canvasSize)];
                mask = stage.core.Mask.createCircularAperture(apertureDiameterPix2/max(canvasSize), 1024); %circular aperture
                aperture2.setMask(mask);
                p.addStimulus(aperture2); %add aperture
                aperture2Visible = stage.builtin.controllers.PropertyController(aperture2, 'visible', ...
                    @(state) ~getPhase1(obj, state.frame) );
                p.addController(aperture2Visible);
            end
            
            % aperture for tail time
            apertureTail = stage.builtin.stimuli.Rectangle();
            apertureTail.position = canvasSize/2;
            apertureTail.color = obj.backgroundIntensity;
            apertureTail.size = [max(canvasSize) max(canvasSize)];
            maskTail = stage.core.Mask.createCircularAperture(0, 1024); %circular aperture
            apertureTail.setMask(maskTail);
            p.addStimulus(apertureTail); %add aperture
            apertureTailVisible = stage.builtin.controllers.PropertyController(apertureTail, 'visible', ...
                @(state) state.time>(obj.periodDur*obj.periodsPerEpoch) );
            p.addController(apertureTailVisible);
            
            
            %%%% function to get sine stimulus intensity at particular frame
            function i = getSineStimIntensity(obj, frame)
                persistent intensity;
               
                framesPerPeriod = 60*obj.periodDur;   % assume 60 frames/sec for now
                frameWithinOneCycle = rem(frame,framesPerPeriod);  % transform to get position within one cycle
                if frameWithinOneCycle == 0
                    frameWithinOneCycle = framesPerPeriod;
                end
                framesInFirstHalfCycle = obj.periodDur/2*60; % assume 60 frames/sec for now
                
                intensity = sin(2*pi*obj.freqParam*frameWithinOneCycle/60);
                
                if frameWithinOneCycle <= framesInFirstHalfCycle  % in first half
                    intensity = intensity*obj.backgroundIntensity*obj.contrPhase1;
                else % in second half
                    intensity = intensity*obj.backgroundIntensity*obj.contrPhase2;
                end
                
                intensity = intensity*obj.mult + obj.backgroundIntensity;  % add mean in
                i = intensity;
            end
            %%%%%%%
            
          %%%% function to get binary noise stimulus intensity at particular frame
            function i = getBinaryNoiseStimIntensity(obj, frame)
                persistent intensity;
               
                dwellFrames = ceil(obj.freqParam/1000*60); % assume 60 frames/sec
                framesPerPeriod = 60*obj.periodDur;   % assume 60 frames/sec for now
                frameWithinOneCycle = rem(frame,framesPerPeriod);  % transform to get position within one cycle
                if frameWithinOneCycle == 0
                    frameWithinOneCycle = framesPerPeriod;
                end
                framesInFirstHalfCycle = obj.periodDur/2*60; % assume 60 frames/sec for now
                               
                if frame==1 || (obj.dwellCount == dwellFrames || (frameWithinOneCycle > (framesInFirstHalfCycle) && (frameWithinOneCycle <= (framesInFirstHalfCycle+1)))) % potentially update
                    if frameWithinOneCycle <= framesInFirstHalfCycle  % in first half
                        obj.currentStep = sign(randn)*obj.backgroundIntensity*obj.contrPhase1;
                    else % in second half
                        obj.currentStep = sign(randn)*obj.backgroundIntensity*obj.contrPhase2;
                    end
                    obj.dwellCount = 1;
                else
                    obj.dwellCount = obj.dwellCount+1;
                end
                intensity = obj.currentStep + obj.backgroundIntensity;  % add mean in

                i = intensity;
            end
            %%%%%%%
            
          %%%% function to get noise step stimulus intensity at particular frame
            function i = getNoiseStepsStimIntensity(obj, frame)
                persistent intensity;
               
                dwellFrames = ceil(obj.freqParam/1000*60); % assume 60 frames/sec
                framesPerPeriod = 60*obj.periodDur;   % assume 60 frames/sec for now
                frameWithinOneCycle = rem(frame,framesPerPeriod);  % transform to get position within one cycle
                if frameWithinOneCycle == 0
                    frameWithinOneCycle = framesPerPeriod;
                end
                framesInFirstHalfCycle = obj.periodDur/2*60; % assume 60 frames/sec for now
                               
                if frame==1 || (obj.dwellCount == dwellFrames || (frameWithinOneCycle > (framesInFirstHalfCycle) && (frameWithinOneCycle <= (framesInFirstHalfCycle+1)))) % potentially update
                    if frameWithinOneCycle <= framesInFirstHalfCycle  % in first half
                        obj.currentStep = randn*obj.backgroundIntensity*obj.contrPhase1;
                    else % in second half
                        obj.currentStep = randn*obj.backgroundIntensity*obj.contrPhase2;
                    end
                    obj.dwellCount = 1;
                else
                    obj.dwellCount = obj.dwellCount+1;
                end
                intensity = obj.currentStep + obj.backgroundIntensity;  % add mean in

                i = intensity;
            end
            %%%%%%%

            %%%% function to get phase (first or second half of epoch)
            function p1 = getPhase1(obj, frame)
                persistent phase1Flag
               
                framesPerPeriod = 60*obj.periodDur;   % assume 60 frames/sec for now
                frameWithinOneCycle = rem(frame,framesPerPeriod);  % transform to get position within one cycle
                if frameWithinOneCycle == 0
                    frameWithinOneCycle = framesPerPeriod;
                end
                framesInFirstHalfCycle = obj.periodDur/2*60; % assume 60 frames/sec for now
                               
                if (frameWithinOneCycle <= framesInFirstHalfCycle)  % in first half
                    phase1Flag = 1;
                else
                    phase1Flag = 0;
                end
                
                p1 = phase1Flag;
            end
            %%%%%%%

            
        end
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numEpochs;
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numEpochs;        
        end
    end
    
end

 