classdef DoubleSwitchingPeriod < edu.washington.riekelab.protocols.RiekeLabProtocol

    % presents either contrast or luminance steps with a given period,
    % intended to evaluate the timescale of adaptation
    
    properties
        led                             % Output LED
        
        periodDur1 = 2                  % Switching period 1 (s)
        periodDur2 = 10;                % Switching period 2 (s)

        baseLum = 0;                    % Luminance for first half of epoch
        baseContr = .06;                % Contrast for first half of epoch
        stepLum = 1;                    % Luminance for second half of epoch
        stepContr = .06;                % Contrast for second half of epoch

        epochsPerBlock = 6              % Number of epochs (for each switching period) within each block
        numBlocks = 20                  % Number of blocks

        frequencyCutoff = 60            % Noise frequency cutoff for smoothing (Hz)
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
            
            %obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));
            %obj.showFigure('edu.washington.riekelab.weber.figures.DoubleSwitchingPeriodFigure',obj.rig.getDevice(obj.amp),obj.periodDur1,obj.periodDur2,obj.epochsPerBlock,obj.numBlocks,obj.binSize);
           
            device = obj.rig.getDevice(obj.led);
            device.background = symphonyui.core.Measurement(obj.baseLum, device.background.displayUnits);
        end
        
        function [stim,seed1,seed2] = createLedStimulus(obj, epochNum)
            
%             if isempty(obj.numEpochsPrepared)
%                 obj.numEpochsPrepared = 0;
%             end
            % determine which periodDur to use
            if mod(epochNum,obj.epochsPerBlock*2) <= obj.epochsPerBlock && mod(epochNum,obj.epochsPerBlock*2)~= 0
                periodDur = obj.periodDur1;
            else
                periodDur = obj.periodDur2;
            end
                
            % make baseline steps
            gen = symphonyui.builtin.stimuli.PulseGenerator();
            
            gen.preTime = periodDur*1000/2; % convert to ms
            gen.stimTime = periodDur*1000/2;  
            gen.tailTime = 0;
            gen.mean = obj.baseLum;
            gen.amplitude = obj.stepLum - obj.baseLum;
            gen.sampleRate = obj.sampleRate;
            gen.units = obj.rig.getDevice(obj.led).background.displayUnits;
            
            stepStimulus = gen.generate();
        
            % now make noise
            %%% noise 1
            gen = edu.washington.riekelab.stimuli.GaussianNoiseGeneratorV2();
            
            seed1 = RandStream.shuffleSeed;
            
            gen.preTime = 0; % convert to ms
            gen.stimTime = periodDur*1000/2;  
            gen.tailTime = periodDur*1000/2;
            gen.stDev = obj.baseLum * obj.baseContr;
            gen.freqCutoff = obj.frequencyCutoff;
            gen.numFilters = obj.numberOfFilters;
            gen.mean = 0;
            gen.seed = seed1;
            gen.sampleRate = obj.sampleRate;
            gen.units = obj.rig.getDevice(obj.led).background.displayUnits;
                       
            noiseStimuli{1} = gen.generate();
            
            %%% noise 2
            gen = edu.washington.riekelab.stimuli.GaussianNoiseGeneratorV2();
            
            seed2 = RandStream.shuffleSeed;
            
            gen.preTime = periodDur*1000/2; % convert to ms
            gen.stimTime = periodDur*1000/2;  
            gen.tailTime = 0;
            gen.stDev = obj.stepLum * obj.stepContr;
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
                
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, epoch);
            
            epochNum = obj.numEpochsPrepared;
            [stim,seed1,seed2] = obj.createLedStimulus(epochNum);

            epoch.addParameter('seed1', seed1);
            epoch.addParameter('seed2', seed2);
            epoch.addStimulus(obj.rig.getDevice(obj.led), stim);
            epoch.addResponse(obj.rig.getDevice(obj.amp));
            
        end
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.epochsPerBlock*2*obj.numBlocks;
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.epochsPerBlock*2*obj.numBlocks;
            disp(tf);
        end
                

    end
    
end

