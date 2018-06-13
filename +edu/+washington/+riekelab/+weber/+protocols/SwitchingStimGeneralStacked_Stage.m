classdef SwitchingStimGeneralStacked_Stage < edu.washington.riekelab.protocols.RiekeLabStageProtocol
    
    properties
        periodDur = 2                   % Switching period (s)
        backgroundIntensity = 0.5       % Background intensity/luminance (0-1)
        contrPhase1 = .1                % Contrast for first half of period
        contrPhase2 = 1                 % Contrast for second half of period
        startLow = false                % Start at baseLum/baseContr or stepLum/stepContr
        mult = 1;                       % First cycle starts upward (1) or downward (-1)
        
        stimType = 'sine'               % 'sine','binary noise','noise steps','white noise'
        freqParam = 6;                  % sine: frequency of sine wave (Hz)
                                        % binary noise: dwell time for each draw
                                        % noise steps: dwell time for each draw 
                                        % white noise: low-pass frequency cutoff (Hz)
                                       
        periodsPerEpoch = uint16(10)    % Number of periods for each epoch
        numEpochs = uint16(10)          % Number of epochs
        
        amp                             % Input amplifier
        
        binSize = 50;                   % Size of histogram bin for PSTH (ms)
        numEpochsAvg = uint16(25);      % Number of epochs to average for each PSTH trace
        numAvgsPlot = uint16(5);        % Number of PSTHs to keep on plot
                
        aperatureDiameterPhase1 = 0     % Aperture diameter for first half of period (um); 0 gives full field
        apertureDiameterPhase2 = 0      % Aperture diameter for second half of period (um); 0 gives full field

        onlineAnalysis = 'none'
        numberOfAverages = uint16(10) % number of epochs to queue
    end

    properties (Hidden)
        ampType
        onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'exc', 'inh'})
        freqParamType = symphonyui.core.PropertyType('char', 'row', {'sine','binary noise','noise steps','white noise'})
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
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            
            % Set background intensity
            p = stage.core.Presentation(obj.periodDur*double(obj.periodsPerEpoch)); %create presentation of specified duration
            p.setBackgroundColor(obj.backgroundIntensity); 
            
            %%%%%
            % Create switching stimulus, first half of period.
            stimRect1 = stage.builtin.stimuli.Rectangle();
            stimRect1.size = canvasSize;
            stimRect1.position = canvasSize/2;
            
            % Create aperture
            if apertureDiameterPhase1 > 0
                apertureDiameterPhase1Pix = obj.rig.getDevice('Stage').um2pix(obj.apertureDiameterPhase1);
                mask1 = stage.core.Mask.createCircularAperture(apertureDiameterPhase1Pix);
                stimRect1.setMask(mask1);
            end
            
            p.addStimulus(stimRect1);
            stimValue = stage.builtin.controllers.PropertyController(stimRect1, 'color',...
                @(state)getStimIntensity(obj, state.frame));
            p.addController(stimValue); %add the controller
            
            
            %%%% big function to get stimulus intensity at particular frame
            function i = getStimIntensity(obj, frame)
                persistent intensity;
                
                % transform to get frame position within one cycle
                framesPerPeriod = 60*obj.periodDur;   % assume 60 frames/sec for now
                frameWithinOneCycle = rem(frame,framesPerPeriod);  
                if frameWithinOneCycle == 0
                    frameWithinOneCycle = framesPerPeriod;
                end
                
                framesInFirstHalfCycle = obj.periodDur/2*60; % assume 60 frames/sec for now
                
                intensity = sin(2*pi*obj.sinFreq*frameWithinOneCycle/60);
                
                if frameWithinOneCycle <= framesInFirstHalfCycle  % in first half
                    intensity = intensity*obj.contrPhase1;
                else % in second half
                    intensity = intensity*obj.contrPhase2;
                end
                
                intensity = intensity + obj.backgroundIntensity;  % add mean in
                i = intensity;
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