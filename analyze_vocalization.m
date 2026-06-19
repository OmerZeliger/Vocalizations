function [vocs,baselineTime,filepath,ops] = analyze_vocalization(filepath,ops)
% handle inputs
if ~exist('filepath','var') || isempty(filepath)
    %filepath = '/Users/omer/Downloads/T0000009.wav';
    filepath = fullfile(fileparts(which("analyze_vocalization.m")),'Recordings','T0000009.mat');
end
if ~exist('ops','var')
    ops = struct();
end

% seed rng for consistent fitting results
rng(1997);

% parameters
if ~isfield(ops,'window')
    ops.window = .01;
end
if ~isfield(ops,'overlap')
    ops.overlap = .8;
end
if ~isfield(ops,'freqs')
    ops.freqs = [];
end
if ~isfield(ops,'freqRange')
    ops.freqRange = [1000 100000];
end
if ~isfield(ops,'nFormants')
    ops.nFormants = 2;
end
if ~isfield(ops,'minVocalizationLength')
    ops.minVocalizationLength = 0.2;
end
if ~isfield(ops,'chunkLength')
    ops.chunkLength = 0.01;
end
if ~isfield(ops,'formantColors')
    ops.formantColors = {'red',[1 .5 0],'yellow','green','blue',[1 0 1]};
end
if ~isfield(ops,'manuallyPickBaseline')
    ops.manuallyPickBaseline = false;
end
if ~isfield(ops,'fitGaussian')
    ops.fitGaussian = false;
end
if ~isfield(ops,'nPeaks')
    ops.nPeaks = 10;
end

% load data
[y,fs] = audioread(filepath);


% create spectrogram
[~,f,t,pwr] = spectrogram(y,round(fs*ops.window),round(fs*ops.window * ops.overlap),ops.freqs,fs);

% smooth time-wise
smoothPower = smoothdata(pwr,2,"gaussian",round(fs*ops.window*ops.overlap*.003));
% smooth frequency-wise
smoothPower = smoothdata(smoothPower,1,"gaussian",6);

% option to pick baseline period through gui
if ops.manuallyPickBaseline
    numBaselineBins = 1/diff(t(1:2));
    fig = figure(999);
    ax = gca();
    imagesc(ax,t,f,sqrt(smoothPower));
    tit = title('Use the slider to pick a quiet period as baseline: 1');
    y = ylim;

    baselineRect = rectangle(ax,'Position',[t(1) y(1) t(numBaselineBins)-t(1) diff(y)],'LineWidth',2);

    pb = @(src,event,baselineRect,tit,y,width,t) pickBaseline(round(src.Value),baselineRect,tit,y,width,t);
    
    h_slider = uicontrol( ...
        'Parent',fig, ...
        'Style','slider', ...
        'Units','normalized', ...
        'Position',[0 0 1 0.035], ...
        'Min',1, ...
        'Max',length(t)-numBaselineBins+1, ...
        'Value',1, ...
        'SliderStep',[round(numBaselineBins/8) round(numBaselineBins/2)]/(length(t)-numBaselineBins+1), ...
        'Callback',{pb,baselineRect,tit,y,numBaselineBins,t});

    uiwait(fig);

    baselineStart = inputdlg('Please enter the background start index from the previous figure:','Background selection');
    baselineStart = str2num(baselineStart{1});
    baselineTime = baselineStart:baselineStart+numBaselineBins-1;
else
    baselineTime = t<=1;
end

% identify likely vocalization timing by comparing to baseline (first second of recording)
baseline = mean(smoothPower(:,baselineTime),2) + 5.*std(smoothPower(:,baselineTime),[],2);
powerAboveBaseline = smoothPower > baseline;
backgroundNoise = mean(smoothPower(:,baselineTime),2);

meanFreqIncrease = smoothdata(mean(powerAboveBaseline,1),"gaussian",round(fs*ops.window*ops.overlap*.01));
vocOnset = find(diff([false meanFreqIncrease>.2])==1);
vocOffset = find(diff([meanFreqIncrease>.2 false])==-1);
valleys = [1 find(islocalmin(meanFreqIncrease)) length(meanFreqIncrease)];

vocalizationTiming = {};
for i = 1:length(vocOnset)
    v1 = valleys(find(valleys <= vocOnset(i),1,'last'));
    v2 = valleys(find(valleys >= vocOffset(i),1,'first'));
    [~,peak] = max(meanFreqIncrease(v1:v2));
    if t(v2)-t(v1) >= ops.minVocalizationLength
        vocalizationTiming{end+1} = [v1 peak v2];
    end
end


%% LABEL VOCALIZATIONS
vocs = struct(); vocs(1) = [];
%imagesc(t,f,sqrt(smoothPower)); hold on; % visualize vocalizations + harmonic content
for i = 1:length(vocalizationTiming)
    fprintf('Analyzing vocalization %d of %d\n',i,length(vocalizationTiming));
    voc = vocalizationTiming{i}(1):vocalizationTiming{i}(3);
    sp = smoothPower(:,voc);
    peak = vocalizationTiming{i}(2);

    %TODO: guess f0 based on distance between peaks?
    localPeaks = find(islocalmax(sp(:,peak)));
    peakPowers = sp(localPeaks,peak);
    [~,idx] = sort(peakPowers);
    localPeaks = localPeaks(idx);
    peakFrequencies = f(localPeaks(end-9:end));

    estimatedF0 = median(diff(sort(peakFrequencies)));

    % look at chunks of time and track each formant over time
    [~,edges,chunks] = histcounts(t(voc),t(voc(1)):ops.chunkLength:t(voc(end))+ops.chunkLength);
    [~,~,peakChunk] = histcounts(t(peak + voc(1) - 1),edges);

    roughFormantFrequencies = cell(1,max(chunks));

    % find formants at vocalization peak
    chunk = peakChunk;
    chunkIdx = chunks==chunk;
    roughFormantFrequencies{chunk} = nan(ops.nFormants+1,sum(chunkIdx));
    for fid = 1:ops.nFormants+1
        searchFrequencies = (f > (fid*estimatedF0) - (estimatedF0/2)) & (f < (fid*estimatedF0) + (estimatedF0/2));
        fridge = tfridge(sp(searchFrequencies,chunkIdx),f(searchFrequencies),0.2);
        roughFormantFrequencies{chunk}(fid,:) = fridge;
    end
    estimatedF0 = roughFormantFrequencies{chunk}(1,end);

    % move forward
    for chunk = peakChunk+1:max(chunks)
        chunkIdx = chunks==chunk;
        roughFormantFrequencies{chunk} = nan(ops.nFormants+1,sum(chunkIdx));
        for fid = 1:ops.nFormants+1
            searchFrequencies = (f > (fid*estimatedF0) - (estimatedF0/2)) & (f < (fid*estimatedF0) + (estimatedF0/2));
            fridge = tfridge(sp(searchFrequencies,chunkIdx),f(searchFrequencies),0.2);
            roughFormantFrequencies{chunk}(fid,:) = fridge;
        end
        estimatedF0 = roughFormantFrequencies{chunk}(1,end);
    end

    % move backward
    estimatedF0 = roughFormantFrequencies{peakChunk}(1,1);
    for chunk = peakChunk-1:-1:1
        chunkIdx = chunks==chunk;
        roughFormantFrequencies{chunk} = nan(ops.nFormants+1,sum(chunkIdx));
        for fid = 1:ops.nFormants+1
            searchFrequencies = (f > (fid*estimatedF0) - (0.4*estimatedF0)) & (f < (fid*estimatedF0) + (0.4*estimatedF0));
            fridge = tfridge(sp(searchFrequencies,chunkIdx),f(searchFrequencies),0.2);
            roughFormantFrequencies{chunk}(fid,:) = fridge;
        end
        estimatedF0 = roughFormantFrequencies{chunk}(1,1);
    end

    % concatenate estimated formants
    roughFormantFrequencies = horzcat(roughFormantFrequencies{:});

    % detect and remove overlaps
    overlaps = diff(roughFormantFrequencies,1) < roughFormantFrequencies(1,:)./2;
    for o = 1:size(overlaps,1)
        % remove overlaps
        roughFormantFrequencies(o:o+1,overlaps(o,:)) = nan;

        % interpolate between overlaps
        roughFormantFrequencies = fillmissing(roughFormantFrequencies,'linear',2);
    end

    % detect each estimated formant's peak frequency
    formantFrequencies = nan(size(roughFormantFrequencies));
    formantPower = formantFrequencies;
    formantSpread = formantFrequencies;
    for timepoint = 1:length(voc)
        for formant = 1:ops.nFormants+1
            searchFrequencies = f > roughFormantFrequencies(formant,timepoint)-(.2*roughFormantFrequencies(1,timepoint)) & ...
                f < roughFormantFrequencies(formant,timepoint)+(.2*roughFormantFrequencies(1,timepoint));
            temp = sp(:,timepoint); temp(~searchFrequencies) = nan;
            [~,idx] = max(temp);
            formantFrequencies(formant,timepoint) = f(idx);
        end

        formantEdges = mean([0 formantFrequencies(:,timepoint)';formantFrequencies(:,timepoint)' formantFrequencies(end,timepoint)+formantFrequencies(1,timepoint)],1);
        for formant = 1:ops.nFormants+1
            % get total power of formant across all of its frequencies
            searchFrequencies = f >= formantEdges(formant) & f < formantEdges(formant+1);
            formantPower(formant,timepoint) = sum(sp(searchFrequencies,timepoint) - backgroundNoise(searchFrequencies));

            % get relative spread of formant by fitting a gaussian
            if ops.fitGaussian
                try
                    %TODO: de-crapify
                    d1 = median(sp(searchFrequencies,timepoint));
                    %d1 = median(backgroundNoise);
                    temp = f(searchFrequencies);
                    [~,b1] = max(sp(searchFrequencies,timepoint)); b1 = temp(b1);
                    %ft = fittype(sprintf('(a1*exp(-((x-%f)/c1)^2))+%f',b1,d1),'Coefficients',{'a1','c1'});

                    %ft = fittype('(a1*exp(-((x-b1)/c1)^2))+d1','Coefficients',{'a1','b1','c1','d1'});
                    %TODO: fix known coefficients - height, offset, baseline
                    %mdl = fit(f(searchFrequencies),sp(searchFrequencies,timepoint),'gauss1');
                    mdl = fit(f(searchFrequencies),sp(searchFrequencies,timepoint)-d1,'gauss1',...
                        'StartPoint',[1 b1 200],'Lower',[-Inf -Inf 200],'Upper',[Inf Inf 200]);
                    %mdl = fit(f(searchFrequencies),sp(searchFrequencies,timepoint),ft,'StartPoint',[1 200]);
                    formantSpread(formant,timepoint) = mdl.c1;
                catch
                    formantSpread(formant,timepoint) = missing;
                end
            end
        end
    end

    % note timepoints when vocalization is too quiet relative to baseline
    vocOn = sum(sp,1) > sum(baseline);
    %plot(sum(sp,1)); hold on; plot([1 size(sp,2)],[sum(baseline) sum(baseline)]); plot(vocOn);
    %vocOn = ~(smoothdata(sign(mean(formantPower,1)),"movmean",5) < .5);

    % % plot each formant
    % %figure; imagesc(t(voc),f,sp); hold on;
    % for j = 1:ops.nFormants+1
    %     plot(t(voc(vocOn)),formantFrequencies(j,vocOn),'Color',ops.formantColors{j});
    % end
    % %hold off;

    % save data
    vocs(end+1).FormantFrequencies = formantFrequencies;
    vocs(end).Time = t(voc);
    vocs(end).RawPower = sp;
    vocs(end).VocalizationOn = vocOn;
    vocs(end).FormantPower = formantPower;
    vocs(end).FormantSpread = formantSpread;

end
%hold off;

%% ANALYSIS
% gross analysis on general vocalization properties
for i = 1:length(vocs)
    voc = vocs(i).VocalizationOn;
    
    % total duration
    vocs(i).Duration = range(vocs(i).Time(voc));

    % total power across all frequencies
    vocs(i).TotalPower = sum(vocs(i).RawPower-backgroundNoise,1);

    % peak to noise ratio
    % minimum distance between peaks = 800 Hz (theoretical minimum frequency of rat vocalization?)
    peakToNoiseRatio = nan(size(voc));
    minDist = find(f-f(1) <= 800,1,'last');
    for j = 1:length(vocs(i).VocalizationOn)
        % first find peaks
        [peaks,locs] = findpeaks(vocs(i).RawPower(:,j) - backgroundNoise,"MinPeakDistance",minDist,"SortStr","descend");
        peaks = peaks(1:ops.nPeaks); locs = locs(1:ops.nPeaks);
        [locs,idx] = sort(locs); peaks = peaks(idx);

        % next find valleys
        % find minimum power between each peak
        edges = [1;locs;min(locs(end)+locs(1),length(f))];
        for k = 1:ops.nPeaks+1
            searchIdx = edges(k):edges(k+1);
            temp = nan(size(backgroundNoise));
            temp(searchIdx) = vocs(i).RawPower(searchIdx,j) - backgroundNoise(searchIdx);
            [valley(k),valleyLoc(k)] = min(temp);
        end

        % integrate area under connected peaks and under connected valleys
        % using trapezoidal method
        % (source: hoarseness paper)
        peakAOC = trapz(f(locs),peaks);
        valleyAOC = trapz(f(valleyLoc),valley);

        peakToNoiseRatio(j) = peakAOC/valleyAOC;
    end
    vocs(i).PeakToNoiseRatio = peakToNoiseRatio;
end




%% MANUAL CURATION
%TODO: add "trimming" gui which lets the user mark where the vocalization is well-fit
% this shouldn't alter the data, it should just give the timepoints as another variable
figure;
for i = 1:length(vocs)
    % plot each formant
    clf; imagesc(vocs(i).Time,f,(vocs(i).RawPower).^.4); hold on;
    for j = 1:ops.nFormants+1
        plot(vocs(i).Time(vocs(i).VocalizationOn),...
            vocs(i).FormantFrequencies(j,vocs(i).VocalizationOn),...
            'Color',ops.formantColors{j});
    end
    hold off;

    vocs(i).ManualCuration = questdlg('Pick vocalization quality:','Manual curation','Well-fit','Poorly-fit','Noise','Cancel');
end

end



%% LOCAL FUNCTIONS
function pickBaseline(val,baselineRect,tit,y,width,t)
baselineRect.Position = [t(val) y(1) t(width)-t(1) diff(y)];
tit.String = sprintf('Use the slider to pick a quiet period as baseline: %d',val);
end