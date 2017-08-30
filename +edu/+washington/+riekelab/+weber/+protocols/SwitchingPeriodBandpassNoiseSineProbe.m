classdef SwitchingPeriodBandpassNoiseSineProbe < edu.washington.riekelab.protocols.RiekeLabProtocol
    
    % presents either contrast or luminance steps with a given period,
    % intended to evaluate the timescale of adaptation
    
    properties
        led                             % Output LED
        
        periodDur = 2                   % Switching period (s)
        
        lum = .5;                       % Luminance for first half of epoch
        noiseContr = .5;                % Contrast for first half of epoch, % of mean
        sineContr = 1;                  % Contrast for second half of epoch, % of mean
        forceThroughMean = true;        % Force start/end of each half cycle through mean
        
        numEpochs = uint16(25)          % Number of epochs
        
        sineProbeFreq = 8               % Frequency of sine probe (Hz), second half of stim
        frequencyCutoffHigh = 50        % Noise frequency cutoff for smoothing (Hz)
        frequencyCutoffLow = 4          % Noise frequency cutoff for smoothing (Hz)
        numberOfFilters = 6             % Number of filters in cascade for noise smoothing
        mult = 1                        % Multiplier on probing sine freq (+/- 1)
        
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
            p = symphonyui.builtin.previews.StimuliPreview(panel, @()obj.createLedStimulus());
        end
        
        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);
            
            obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));
            obj.showFigure('edu.washington.riekelab.weber.figures.SwitchingPeriodBasicFigurePlusVar',obj.rig.getDevice(obj.amp),obj.binSize,obj.numEpochs);
            
            device = obj.rig.getDevice(obj.led);
            device.background = symphonyui.core.Measurement(obj.lum, device.background.displayUnits);
        end
        
        function [stim,seed] = createLedStimulus(obj, epochNum)
            
            % make noise stim (first half)
            
            gen = edu.washington.riekelab.weber.stimuli.GaussianNoiseGeneratorBandpass();
            
            seed = RandStream.shuffleSeed;
            
            gen.preTime = 0; % convert to ms
            gen.tailTime = obj.periodDur*1000/2;
            gen.stimTime = obj.periodDur*1000/2;
            
            gen.stDev = obj.lum * obj.noiseContr;
            
            gen.freqCutoffHigh = obj.frequencyCutoffHigh;
            gen.freqCutoffLow = obj.frequencyCutoffLow;
            gen.numFilters = obj.numberOfFilters;
            gen.mean = obj.lum;  % (mean added by sine stim)
            gen.seed = seed;
            gen.sampleRate = obj.sampleRate;
            gen.units = obj.rig.getDevice(obj.led).background.displayUnits;
            gen.forceThroughMean = obj.forceThroughMean;
            
            noiseStimulus = gen.generate();
            
            
            %%% probing sine stim (second half)
            gen = edu.washington.riekelab.weber.stimuli.SineGeneratorV2();
            gen.sinFreq = obj.sineProbeFreq;
            gen.mean = obj.lum;
            gen.mult = obj.mult;
            gen.sampleRate = obj.sampleRate;
            gen.units = obj.rig.getDevice(obj.led).background.displayUnits;
            
            gen.preTime = obj.periodDur/2;
            gen.stimTime = obj.periodDur/2;
            gen.tailTime = 0;
            gen.contr = obj.sineContr;
            sineStimulus = gen.generate();
            
            %%% extra stim to subtract of mean (added to each half already)
            gen = symphonyui.builtin.stimuli.PulseGenerator();
            
            gen.preTime = 0;
            gen.tailTime = 0;
            gen.stimTime = obj.periodDur*1000;  
            gen.mean = -obj.lum;
            gen.amplitude = 0;
            gen.sampleRate = obj.sampleRate;
            gen.units = obj.rig.getDevice(obj.led).background.displayUnits;
            
            stepStimulus = gen.generate();

            
            % sum them into one stimulus
            sumGen = symphonyui.builtin.stimuli.SumGenerator();
            sumGen.stimuli = {sineStimulus, noiseStimulus, stepStimulus};
            stim = sumGen.generate();
        end
        
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, epoch);
            
            epochNum = obj.numEpochsPrepared;
            [stim,seed] = obj.createLedStimulus(epochNum);
            
            epoch.addParameter('seed', seed);
            epoch.addStimulus(obj.rig.getDevice(obj.led), stim);
            epoch.addResponse(obj.rig.getDevice(obj.amp));
            
        end
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numEpochs;
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numEpochs;
        end
        
        
    end
    
end

