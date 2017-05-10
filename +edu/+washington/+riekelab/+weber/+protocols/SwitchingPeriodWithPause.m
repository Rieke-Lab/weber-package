classdef SwitchingPeriodWithPause < edu.washington.riekelab.protocols.RiekeLabProtocol
    
    % presents either contrast or luminance steps with a given period,
    % separated by pauses without switching
    % intended to evaluate the timescale of adaptation
    
    properties
        led                             % Output LED
        
        periodDur = 5                  % Switching period (s)
        pauseDur = 15                  % Pause duration (s)
        
        baseLum = .5                    % Luminance for first half of epoch
        baseContr = .06                 % Contrast for first half of epoch
        stepLum = .5                    % Luminance for second half of epoch
        stepContr = .36                 % Contrast for second half of epoch
        startLow = true                 % Start at baseLum/baseContr or stepLum/stepContr
        
        epochsPerBlock = uint16(3)      % Number of epochs (for each switching period) within each block
        numBlocks = uint16(100)         % Number of blocks
        
        frequencyCutoff = 40            % Noise frequency cutoff for smoothing (Hz)
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
            obj.showFigure('edu.washington.riekelab.weber.figures.SwitchingPeriodWithPauseFigure',obj.rig.getDevice(obj.amp),obj.sampleRate,obj.periodDur,obj.pauseDur,obj.epochsPerBlock,obj.binSize);
            obj.showFigure('edu.washington.riekelab.figures.ProgressFigure', obj.epochsPerBlock*2*obj.numBlocks);
            
            device = obj.rig.getDevice(obj.led);
            device.background = symphonyui.core.Measurement(obj.baseLum, device.background.displayUnits);
        end
        
        function [stim,seed1,seed2,positionInBlock,periodDur] = createLedStimulus(obj, epochNum)
            
            % determine which periodDur to use
            positionInBlock = mod(epochNum,double(obj.epochsPerBlock)+1); % calculate whether in first or second half of each full block
            if positionInBlock == 0
                positionInBlock = double(obj.epochsPerBlock)+1;
            end
            positionInBlock = positionInBlock - 1;
            
            if  positionInBlock == 0 % if 0th position, i.e. pause
                periodDur = obj.pauseDur;
                
                gen = edu.washington.riekelab.stimuli.GaussianNoiseGeneratorV2();
                
                seed1 = RandStream.shuffleSeed;
                seed2 = 0;
                
                gen.preTime = 0; % convert to ms
                gen.tailTime = 0;
                gen.stimTime = periodDur*1000;

                if obj.startLow  % start with baseLum/baseContr
                    gen.mean = obj.baseLum;
                    gen.stDev = obj.baseLum * obj.baseContr;
                else % start with stepLum/stepContr
                    gen.mean = obj.stepLum;
                    gen.stDev = obj.stepLum * obj.stepContr;
                end
                gen.freqCutoff = obj.frequencyCutoff;
                gen.numFilters = obj.numberOfFilters;
                gen.seed = seed1;
                gen.sampleRate = obj.sampleRate;
                gen.units = obj.rig.getDevice(obj.led).background.displayUnits;
                
                stim = gen.generate();

            else % switching stimulus
                periodDur = obj.periodDur;
                
                % make baseline steps
                gen = symphonyui.builtin.stimuli.PulseGenerator();
                
                if obj.startLow  % start with baseLum/baseContr
                    gen.preTime = periodDur*1000/2; % convert to ms
                    gen.tailTime = 0;
                else % start with stepLum/stepContr
                    gen.preTime = 0; % convert to ms
                    gen.tailTime = periodDur*1000/2;
                end
                gen.stimTime = periodDur*1000/2;
                gen.mean = obj.baseLum;
                gen.amplitude = obj.stepLum - obj.baseLum;
                gen.sampleRate = obj.sampleRate;
                gen.units = obj.rig.getDevice(obj.led).background.displayUnits;
                
                stepStimulus = gen.generate();
                
                % now make noise
                %%% noise 1 (first half)
                gen = edu.washington.riekelab.stimuli.GaussianNoiseGeneratorV2();
                
                seed1 = RandStream.shuffleSeed;
                
                gen.preTime = 0; % convert to ms
                gen.tailTime = periodDur*1000/2;
                
                if obj.startLow  % start with baseLum/baseContr
                    gen.stDev = obj.baseLum * obj.baseContr;
                else % start with stepLum/stepContr
                    gen.stDev = obj.stepLum * obj.stepContr;
                end
                gen.stimTime = periodDur*1000/2;
                gen.freqCutoff = obj.frequencyCutoff;
                gen.numFilters = obj.numberOfFilters;
                gen.mean = 0;
                gen.seed = seed1;
                gen.sampleRate = obj.sampleRate;
                gen.units = obj.rig.getDevice(obj.led).background.displayUnits;
                
                noiseStimuli{1} = gen.generate();
                
                %%% noise 2 (second half)
                gen = edu.washington.riekelab.stimuli.GaussianNoiseGeneratorV2();
                
                seed2 = RandStream.shuffleSeed;
                
                gen.preTime = periodDur*1000/2; % convert to ms
                gen.tailTime = 0;
                
                if obj.startLow  % end with stepLum/stepContr
                    gen.stDev = obj.stepLum * obj.stepContr;
                else % end with baseLum/baseContr
                    gen.stDev = obj.baseLum * obj.baseContr;
                end
                gen.stimTime = periodDur*1000/2;
                gen.freqCutoff = obj.frequencyCutoff;
                gen.numFilters = obj.numberOfFilters;
                gen.mean = 0;
                gen.seed = seed2;
                gen.sampleRate = obj.sampleRate;
                gen.units = obj.rig.getDevice(obj.led).background.displayUnits;
                
                noiseStimuli{2} = gen.generate();
                
                % sum them into one stimulus
                sumGen = symphonyui.builtin.stimuli.SumGenerator();
                sumGen.stimuli = {stepStimulus, noiseStimuli{:}};
                stim = sumGen.generate();

            end
            
        end
        
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, epoch);
            
            epochNum = obj.numEpochsPrepared;
            [stim,seed1,seed2,positionInBlock,periodDur] = obj.createLedStimulus(epochNum);
            
            epoch.addParameter('seed1', seed1);
            epoch.addParameter('seed2', seed2);
            epoch.addParameter('positionInBlock', positionInBlock);
            epoch.addParameter('periodDur', periodDur);
            epoch.addStimulus(obj.rig.getDevice(obj.led), stim);
            epoch.addResponse(obj.rig.getDevice(obj.amp));
            
        end
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < (obj.epochsPerBlock+1)*obj.numBlocks;
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < (obj.epochsPerBlock+1)*obj.numBlocks;
        end
        
        
    end
    
end

