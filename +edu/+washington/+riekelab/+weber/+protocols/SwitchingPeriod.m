classdef SwitchingPeriod < edu.washington.riekelab.protocols.RiekeLabProtocol

    % presents either contrast or luminance steps with a given period,
    % intended to evaluate the timescale of adaptation
    
    properties
        led                             % Output LED
        
        periodDur = 2                   % Switching period (s)

        baseLum = 0;                    % Luminance for first half of epoch
        baseContr = .06;                % Contrast for first half of epoch
        stepLum = 1;                    % Luminance for second half of epoch
        stepContr = .06;                % Contrast for second half of epoch

        numEpochs = uint16(5)           % Number of epochs

        frequencyCutoff = 60            % Noise frequency cutoff for smoothing (Hz)
        numberOfFilters = 4             % Number of filters in cascade for noise smoothing

        amp                             % Input amplifier

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
        
%         function p = getPreview(obj, panel)
%             p = symphonyui.builtin.previews.StimuliPreview(panel, @()createPreviewStimuli(obj));
%             function s = createPreviewStimuli(obj)
%                 s = cell(1, obj.numFlashTimes);
%                 for i = 1:obj.numFlashTimes
%                     s{i} = obj.createLedStimulus(i);
%                 end
%             end
%         end
        
        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);
            
            
%                 obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));
%                 obj.showFigure('symphonyui.builtin.figures.MeanResponseFigure', obj.rig.getDevice(obj.amp), ...
%                     'groupBy', {'variableFlashTime'});
%                 obj.showFigure('symphonyui.builtin.figures.ResponseStatisticsFigure', obj.rig.getDevice(obj.amp), {@mean, @var}, ...
%                     'baselineRegion', [0 obj.stepPre], ...
%                     'measurementRegion', [obj.stepPre obj.stepPre+obj.stepStim]);
            
            device = obj.rig.getDevice(obj.led);
            device.background = symphonyui.core.Measurement(obj.meanMagnitude, device.background.displayUnits);
        end
        
        function [stim, variableFlashTime] = createLedStimulus(obj, epochNum)
            variableFlashTime = obj.determineVariableFlashTime(epochNum);
            
            % make baseline steps
            gen = symphonyui.builtin.stimuli.PulseGenerator();
            
            gen.preTime = obj.periodDur*1000/2; % convert to ms
            gen.stimTime = obj.periodDur*1000/2;  
            gen.tailTime = 0;
            gen.mean = obj.baseLum;
            gen.amplitude = obj.stepLum - obj.baseLum;
            gen.sampleRate = obj.sampleRate;
            gen.units = obj.rig.getDevice(obj.led).background.displayUnits;
            
            stepStimulus = gen.generate();
        
            % now make noise
            %%% noise 1
            gen = edu.washington.riekelab.stimuli.GaussianNoiseGeneratorV2();
            
            seed = RandStream.shuffleSeed;
            
            gen.preTime = 0; % convert to ms
            gen.stimTime = obj.periodDur*1000/2;  
            gen.tailTime = obj.periodDur*1000/2;
            gen.stDev = obj.baseLum * obj.baseContr;
            gen.freqCutoff = obj.frequencyCutoff;
            gen.numFilters = obj.numberOfFilters;
            gen.mean = 0;
            gen.seed = seed;
            gen.sampleRate = obj.sampleRate;
            gen.units = obj.rig.getDevice(obj.led).background.displayUnits;
                       
            noiseStimuli{1} = gen.generate();
            
            %%% noise 2
            gen = edu.washington.riekelab.stimuli.GaussianNoiseGeneratorV2();
            
            seed = RandStream.shuffleSeed;
            
            gen.preTime = obj.periodDur*1000/2; % convert to ms
            gen.stimTime = obj.periodDur*1000/2;  
            gen.tailTime = 0;
            gen.stDev = obj.stepLum * obj.stepContr;
            gen.freqCutoff = obj.frequencyCutoff;
            gen.numFilters = obj.numberOfFilters;
            gen.mean = 0;
            gen.seed = seed;
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
            [stim] = obj.createLedStimulus(epochNum);

            epoch.addParameter('seed', seed);
            epoch.addStimulus(obj.rig.getDevice(obj.led), stim);
            epoch.addResponse(obj.rig.getDevice(obj.amp));
            
        end
        
        function prepareInterval(obj, interval)
            prepareInterval@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, interval);
            
            device = obj.rig.getDevice(obj.led);
            interval.addDirectCurrentStimulus(device, device.background, obj.interpulseInterval, obj.sampleRate);
        end
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numEpochs;
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numEpochs;
        end
                

    end
    
end

