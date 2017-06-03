classdef DoubleSwitchingSine < edu.washington.riekelab.protocols.RiekeLabProtocol

    % Presents sinewave-modulated contrast, alternating between 2 different
    % frequencies
    
    properties
        led                             % Output LED
        
        sinFreq1 = 2                    % Frequency of first sine wave (Hz)
        sinFreq2 = 10                   % Frequency of second sine wave (Hz)

        lum = .5                        % Mean luminance of sine wav
        contr = .36                     % Contrast for first half of epoch
        
        epochsPerBlock = uint16(6)      % Number of epochs, i.e. number of cycles, (for each frequency) within each block
        numBlocks = uint16(100)         % Number of blocks

        frequencyCutoff = 400           % Noise frequency cutoff for contrast stimulus (Hz)
        numberOfFilters = 4             % Number of filters in cascade for noise smoothing

        amp                             % Input amplifier

        binSize = 50;                   % Size of histogram bin for PSTH (ms)
    end
    
    
    properties (Hidden)
        ledType
        ampType
    end
    
    methods
        
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);
            
            [obj.led, obj.ledType] = obj.createDeviceNamesProperty('LED');
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end
        
        function p = getPreview(obj, panel)
            p = symphonyui.builtin.previews.StimuliPreview(panel, @()obj.createLedStimulus(1));
        end
        
        function obj = prepareRun(obj)
            prepareRun@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);
            
            obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));
            obj.showFigure('edu.washington.riekelab.weber.figures.DoubleSwitchingPeriodFigure',obj.rig.getDevice(obj.amp),obj.sampleRate,1/obj.sinFreq1,1/obj.sinFreq2,obj.epochsPerBlock,obj.binSize);
            obj.showFigure('edu.washington.riekelab.figures.ProgressFigure', obj.epochsPerBlock*2*obj.numBlocks);
            
            device = obj.rig.getDevice(obj.led);
            device.background = symphonyui.core.Measurement(obj.lum, device.background.displayUnits);
        end
        
        function [stim,seed,positionInBlock,sinFreq] = createLedStimulus(obj, epochNum)
            
            % determine which sinFreq to use
            positionInBlock = mod(epochNum,double(obj.epochsPerBlock)*2); % calculate whether in first or second half of each full block
            if positionInBlock == 0
                positionInBlock = double(obj.epochsPerBlock)*2;
            end
            if  positionInBlock <= obj.epochsPerBlock
                sinFreq = obj.sinFreq1;
            else
                sinFreq = obj.sinFreq2;
            end
            
            % create stim
            gen = edu.washington.riekelab.weber.stimuli.SineModulatedNoiseGenerator();
            
            seed = RandStream.shuffleSeed;
            
            gen.preTime = 0; 
            gen.tailTime = 0;

            gen.stDev = obj.contr*obj.lum;
            gen.stimTime = 1/sinFreq * 1000; % ms
            gen.freqCutoff = obj.frequencyCutoff;
            gen.numFilters = obj.numberOfFilters;
            gen.sinFreq = sinFreq;
            gen.mean = obj.lum;
            gen.seed = seed;
            gen.sampleRate = obj.sampleRate;
            gen.units = obj.rig.getDevice(obj.led).background.displayUnits;
                       
            stim = gen.generate();

        end
                
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, epoch);
            
            epochNum = obj.numEpochsPrepared;
            [stim,seed,positionInBlock,sinFreq] = obj.createLedStimulus(epochNum);

            epoch.addParameter('seed', seed);
            epoch.addParameter('positionInBlock', positionInBlock);
            epoch.addParameter('sinFreq', sinFreq);
            epoch.addStimulus(obj.rig.getDevice(obj.led), stim);
            epoch.addResponse(obj.rig.getDevice(obj.amp));
            
        end
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.epochsPerBlock*2*obj.numBlocks;
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.epochsPerBlock*2*obj.numBlocks;        
        end
                

    end
    
end

