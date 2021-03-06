classdef SwitchingPlainSine_FreqSwitch < edu.washington.riekelab.protocols.RiekeLabProtocol

    % presents sine waves switching between low and high contrast,
    % intended to evaluate the timescale of adaptation
    
    properties
        led                             % Output LED
        
        periodDur = 4                   % Switching period (s)
        sinFreq1 = 4;                   % Frequency of sine wave for first half of stim (Hz)
        sinFreq2 = 8;                   % Frequency of sine wave for second half of stim (Hz)
        
        lum = .5                        % Luminance
        baseContr = .1                  % Contrast for first half of epoch
        stepContr = 1                   % Contrast for second half of epoch
        startLow = false                % Start at baseLum/baseContr or stepLum/stepContr
        
        epochsPerBlock = uint16(10)     % Number of epochs (for each switching period) within each block
        numBlocks = uint16(4)           % Number of blocks

        amp                             % Input amplifier

        binSize = 50;                   % Size of histogram bin for PSTH (ms)
        numEpochsAvg = uint16(25);       % Number of epochs to average for each PSTH trace
        numAvgsPlot = uint16(5);        % Number of PSTHs to keep on plot
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
            obj.showFigure('edu.washington.riekelab.weber.figures.SwitchingPeriodBasicFigure',obj.rig.getDevice(obj.amp),obj.binSize,obj.numEpochsAvg,obj.numAvgsPlot,obj.epochsPerBlock*2*obj.numBlocks);
            obj.showFigure('edu.washington.riekelab.figures.ProgressFigure', obj.epochsPerBlock*2*obj.numBlocks);

            device = obj.rig.getDevice(obj.led);
            device.background = symphonyui.core.Measurement(obj.lum, device.background.displayUnits);
        end
        
        function [stim,mult,positionInBlock,periodDurActual] = createLedStimulus(obj, epochNum)
            
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
            roundedPeriodDur1 = round(obj.periodDur/2/(1/obj.sinFreq1))*(1/obj.sinFreq1);
            roundedPeriodDur2 = round(obj.periodDur/2/(1/obj.sinFreq2))*(1/obj.sinFreq2);
            if  positionInBlock == obj.epochsPerBlock ||  positionInBlock == obj.epochsPerBlock *2
                periodDurActual = roundedPeriodDur1 + roundedPeriodDur2 + 1/obj.sinFreq2/2;
            else
                periodDurActual = roundedPeriodDur1 + roundedPeriodDur2;
            end

            gen = edu.washington.riekelab.weber.stimuli.SineGenerator();
            gen.mean = obj.lum;
            gen.mult = mult;
            gen.sampleRate = obj.sampleRate;
            gen.units = obj.rig.getDevice(obj.led).background.displayUnits;

            if obj.startLow  % start with baseContr
                gen.preTime = 0;
                gen.stimTime = roundedPeriodDur1;
                gen.tailTime = periodDurActual - roundedPeriodDur1;
                gen.contr = obj.baseContr;
                gen.sinFreq = obj.sinFreq1;
                firstHalfStim = gen.generate();
                
                gen.preTime = roundedPeriodDur1;
                gen.stimTime = periodDurActual - roundedPeriodDur1;
                gen.tailTime = 0;
                gen.contr = obj.stepContr;
                gen.sinFreq = obj.sinFreq2;
                secondHalfStim = gen.generate();

            else % start with stepContr
                gen.preTime = 0;
                gen.stimTime = roundedPeriodDur1;
                gen.tailTime = periodDurActual - roundedPeriodDur1;
                gen.contr = obj.stepContr;
                gen.sinFreq = obj.sinFreq1;
                firstHalfStim = gen.generate();
                
                gen.preTime = roundedPeriodDur1;
                gen.stimTime = periodDurActual - roundedPeriodDur1;
                gen.tailTime = 0;
                gen.contr = obj.baseContr;
                gen.sinFreq = obj.sinFreq2;
                secondHalfStim = gen.generate();
            end
            
            % sum them into one stimulus
            sumGen = symphonyui.builtin.stimuli.SumGenerator();
            sumGen.stimuli = {firstHalfStim, secondHalfStim};
            stim = sumGen.generate();

        end
                
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, epoch);
            
            epochNum = obj.numEpochsPrepared;
            [stim,mult,positionInBlock,periodDurActual] = obj.createLedStimulus(epochNum);

            epoch.addParameter('mult', mult);
            epoch.addParameter('positionInBlock', positionInBlock);
            epoch.addParameter('periodDurActual', periodDurActual);
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

