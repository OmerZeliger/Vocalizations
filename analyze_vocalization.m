function [vocs,baselineIdx,f,filepath,ops] = analyze_vocalization(filepath,ops)
% handle inputs
if ~exist('filepath','var') || isempty(filepath)
    %filepath = '/Users/omer/Downloads/T0000009.wav';
    filepath = fullfile(fileparts(which("analyze_vocalization.m")),'Recordings','marked_853626_260625.wav');
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
    ops.freqRange = [300 125000];
end
if ~isfield(ops,'fitFormants')
    ops.fitFormants = true;
end
if ~isfield(ops,'nFormants')
    ops.nFormants = 2;
end
if ~isfield(ops,'minVocalizationLength')
    ops.minVocalizationLength = 0.1;
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
    ops.fitGaussian = true;
end
if ~isfield(ops,'nPeaks')
    ops.nPeaks = 10;
end
if ~isfield(ops,'hoarseCutoff')
    ops.hoarseCutoff = 200;
end
if ~isfield(ops,'gainAdj')
    ops.gainAdj = 1; % multiply y by this number for comparing across recordings with different gains
end
if ~isfield(ops,'clip')
    ops.clip = false; % after gain adjustment, clip values >1 or <-1
end


% load data
[wf,fs] = audioread(filepath);
wf = wf .* ops.gainAdj;
if ops.clip
    wf(wf>1) = 1;
    wf(wf<-1) = -1;
end


% create spectrogram
[~,f,t,pwr] = spectrogram(wf,round(fs*ops.window),round(fs*ops.window * ops.overlap),ops.freqs,fs);

% cut out frequency ranges outside of ops.freqrange
pwr(f<ops.freqRange(1) | f>ops.freqRange(2),:) = [];
f(f<ops.freqRange(1) | f>ops.freqRange(2)) = [];

% smooth time-wise
smoothPower = smoothdata(pwr,2,"gaussian",round(fs*ops.window*ops.overlap*.003));
% smooth frequency-wise
smoothPower = smoothdata(smoothPower,1,"gaussian",3);

% option to pick baseline period through gui
if ops.manuallyPickBaseline
    numBaselineBins = 1/diff(t(1:2));
    fig = figure(999);
    ax = gca();
    imagesc(ax,t,f,log(smoothPower));
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
    baselineIdx = baselineStart:baselineStart+numBaselineBins-1;
else
    baselineIdx = find(t<=1);
end

% identify likely vocalization timing by comparing to baseline (first second of recording)
baseline = mean(smoothPower(:,baselineIdx),2) + 5.*std(smoothPower(:,baselineIdx),[],2);
powerAboveBaseline = smoothPower > baseline;
backgroundNoise = mean(smoothPower(:,baselineIdx),2);

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
    %fprintf('Analyzing vocalization %d of %d\n',i,length(vocalizationTiming));
    voc = vocalizationTiming{i}(1):vocalizationTiming{i}(3);
    sp = smoothPower(:,voc);

    % note timepoints when vocalization is too quiet relative to baseline
    vocOn = sum(sp,1) > sum(baseline);

    % save data
    vocs(end+1).Time = t(voc);
    vocs(end).SmoothedPower = sp;
    vocs(end).VocalizationOn = vocOn;

end
%hold off;

%% ANALYSIS
% gross analysis on general vocalization properties
for i = 1:length(vocs)
    voc = vocs(i).VocalizationOn;
    
    % total duration
    vocs(i).Duration = max(vocs(i).Time(voc)) - min(vocs(i).Time(voc));%range(vocs(i).Time(voc));

    % total power across all frequencies
    vocs(i).TotalPower = sum(vocs(i).SmoothedPower-backgroundNoise,1);

    % peak to noise ratio
    % minimum distance between peaks = 300 Hz (theoretical minimum frequency of rat vocalization?)
    peakToNoiseRatio = nan(size(voc));
    minDist = find(f-f(1) <= 300,1,'last');
    for j = 1:length(vocs(i).VocalizationOn)
        % first find peaks
        [peaks,locs] = findpeaks(vocs(i).SmoothedPower(:,j) - backgroundNoise,"MinPeakDistance",minDist,"SortStr","descend");
        peaks = peaks(1:ops.nPeaks); locs = locs(1:ops.nPeaks);
        [locs,idx] = sort(locs); peaks = peaks(idx);

        % next find valleys
        % find minimum power between each peak
        edges = [1;locs;min(locs(end)+locs(1),length(f))];
        for k = 1:ops.nPeaks+1
            searchIdx = edges(k):edges(k+1);
            temp = nan(size(backgroundNoise));
            temp(searchIdx) = vocs(i).SmoothedPower(searchIdx,j) - backgroundNoise(searchIdx);
            [valley(k),valleyLoc(k)] = min(temp);
        end

        % integrate area under connected peaks and under connected valleys using trapezoidal method
        % (source: hoarseness paper)
        peakAOC = trapz(f(locs),peaks);
        valleyAOC = trapz(f(valleyLoc),valley);

        peakToNoiseRatio(j) = peakAOC/valleyAOC;
    end
    % figure;
    % subplot(2,1,1);
    % imagesc(sqrt(vocs(i).SmoothedPower(:,vocs(i).VocalizationOn)))
    % subplot(2,1,2);
    % plot(peakToNoiseRatio(vocs(i).VocalizationOn))
    vocs(i).PeakToNoiseRatio = peakToNoiseRatio;

    % figure; subplot(3,1,1); plot(y(round(vocs(i).Time(1)*fs):round(vocs(i).Time(end)*fs)));
    % subplot(3,1,2); imagesc(log(vocs(i).SmoothedPower));
    % subplot(3,1,3); plot(peakToNoiseRatio);

    clipped = false(size(vocs(i).Time));
    for j = 1:length(vocs(i).Time)
        yIdx = round(fs * [vocs(i).Time(j)-(ops.window/2) vocs(i).Time(j)+(ops.window/2)]);
        yIdx(1) = max(yIdx(1),1);
        clipped(j) = any(ops.gainAdj-abs(wf(yIdx(1):yIdx(2))) < (0.0001 * ops.gainAdj));
    end
    vocs(i).Clipped = clipped;
end


%% FORMANT FITTING
if ops.fitFormants
    for i = 1:length(vocs)
        fprintf('Fitting vocalization %d of %d\n',i,length(vocalizationTiming));
        voc = vocalizationTiming{i}(1):vocalizationTiming{i}(3);
        %peak = vocalizationTiming{i}(2);

        formantFrequencies = nan(ops.nFormants+1,size(vocs(i).PeakToNoiseRatio,2));
        formantPower = formantFrequencies;
        formantSpread = formantFrequencies;

        segmentsOn = find(diff([false vocs(i).PeakToNoiseRatio > ops.hoarseCutoff]) == 1);
        segmentsOff = find(diff([vocs(i).PeakToNoiseRatio > ops.hoarseCutoff false]) == -1);
        segments = [segmentsOn' segmentsOff'];
        segments(diff(segments,[],2) < sum(t<=ops.chunkLength),:) = []; % if the segment is less than a single chunk, don't fit
        for j = 1:size(segments,1)
            segment = segments(j,1):segments(j,2);
            sp = smoothPower(:,voc(segment));
            [~,peak] = max(vocs(i).PeakToNoiseRatio(segment));

            % guess f0 based on distance between peaks?
            localPeaks = find(islocalmax(sp(:,peak)));
            peakPowers = sp(localPeaks,peak);
            [~,idx] = sort(peakPowers);
            localPeaks = localPeaks(idx);
            peakFrequencies = f(localPeaks(end-9:end));

            estimatedF0 = median(diff(sort(peakFrequencies)));

            % make sure estimated frequency isn't below the measured frequencies
            estimatedF0 = max(estimatedF0,min(f)); estimatedF0 = min(estimatedF0,max(f));

            % look at chunks of time and track each formant over time
            [~,edges,chunks] = histcounts(t(voc(segment)),t(voc(segment(1))):ops.chunkLength:t(voc(segment(end)))+ops.chunkLength);
            [~,~,peakChunk] = histcounts(t(peak + voc(segment(1)) - 1),edges);

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
            overlaps = diff(roughFormantFrequencies,1,1) < roughFormantFrequencies(1,:)./2;
            for o = 1:size(overlaps,1)
                % remove overlaps
                roughFormantFrequencies(o:o+1,overlaps(o,:)) = nan;

                % interpolate between overlaps
                roughFormantFrequencies = fillmissing(roughFormantFrequencies,'linear',2);
            end

            % detect each estimated formant's peak frequency
            %formantFrequencies = nan(size(roughFormantFrequencies));
            %formantPower = formantFrequencies;
            %formantSpread = formantFrequencies;
            for timepoint = 1:length(segment)
                for formant = 1:ops.nFormants+1
                    searchFrequencies = f > roughFormantFrequencies(formant,timepoint)-(.2*roughFormantFrequencies(1,timepoint)) & ...
                        f < roughFormantFrequencies(formant,timepoint)+(.2*roughFormantFrequencies(1,timepoint));
                    temp = sp(:,timepoint); temp(~searchFrequencies) = nan;
                    [~,idx] = max(temp);
                    formantFrequencies(formant,segment(timepoint)) = f(idx);
                end

                formantEdges = mean([0 formantFrequencies(:,segment(timepoint))'; ...
                    formantFrequencies(:,segment(timepoint))' ...
                    formantFrequencies(end,segment(timepoint))+formantFrequencies(1,segment(timepoint))],1);
                for formant = 1:ops.nFormants+1
                    % get total power of formant across all of its frequencies
                    searchFrequencies = f >= formantEdges(formant) & f < formantEdges(formant+1);
                    formantPower(formant,segment(timepoint)) = sum(sp(searchFrequencies,timepoint) - backgroundNoise(searchFrequencies));

                    % get relative spread of formant by fitting a gaussian
                    if ops.fitGaussian
                        try
                            %TODO: de-crapify
                            d1 = median(sp(searchFrequencies,timepoint));
                            %d1 = median(backgroundNoise);
                            %temp = f(searchFrequencies);
                            %[a1,b1] = max(sp(searchFrequencies,timepoint)); b1 = temp(b1);
                            %ft = fittype(sprintf('(a1*exp(-((x-%f)/c1)^2))+%f',b1,d1),'Coefficients',{'a1','c1'});

                            %ft = fittype('(a1*exp(-((x-b1)/c1)^2))+d1','Coefficients',{'a1','b1','c1','d1'});
                            %TODO: fix known coefficients - height, offset, baseline
                            %mdl = fit(f(searchFrequencies),sp(searchFrequencies,timepoint),'gauss1');
                            % mdl = fit(f(searchFrequencies),sp(searchFrequencies,timepoint)-d1,'gauss1',...
                            %     'StartPoint',[a1-d1 b1 100], ...
                            %     'Lower',[0 min(temp) 0], ...
                            %     'Upper',[2*max(sp(searchFrequencies,timepoint)) max(temp) 2000]);
                            mdl = fit(f(searchFrequencies),sp(searchFrequencies,timepoint)-d1,'gauss1');
                            %mdl = fit(f(searchFrequencies),sp(searchFrequencies,timepoint),ft,'StartPoint',[1 200]);
                            formantSpread(formant,segment(timepoint)) = mdl.c1;
                        catch
                            %formantSpread(formant,vocc(timepoint)) = nan;
                        end
                    %else
                    %    formantSpread(formant,vocc(timepoint)) = nan;
                    end
                end
            end
        end
        vocs(i).FormantFrequencies = formantFrequencies;
        vocs(i).FormantPower = formantPower;
        vocs(i).FormantSpread = formantSpread;
    end
else
    [vocs.FormantFrequencies] = deal(nan);
    [vocs.FormantPower] = deal(nan);
    [vocs.FormantSpread] = deal(nan);
end




%% MANUAL CURATION
%TODO: add "trimming" gui which lets the user mark where the vocalization is well-fit
% this shouldn't alter the data, it should just give the timepoints as another variable
figure;
for i = 1:length(vocs)
    % plot each formant
    clf; imagesc(vocs(i).Time,f,(vocs(i).SmoothedPower).^.4);
    if ops.fitFormants
        hold on;
        for j = 1:ops.nFormants+1
            plot(vocs(i).Time(vocs(i).VocalizationOn),...
                vocs(i).FormantFrequencies(j,vocs(i).VocalizationOn),...
                'Color',ops.formantColors{j});
        end
    end
    hold off;

    if ops.fitFormants
        vocs(i).ManualCuration = questdlg('Pick vocalization quality:','Manual curation','Well-fit','Poorly-fit','Noise','Cancel');
    else
        vocs(i).ManualCuration = questdlg('Pick vocalization quality:','Manual curation','Vocalization','Noise','Cancel');
    end
end

end



%% LOCAL FUNCTIONS
function pickBaseline(val,baselineRect,tit,y,width,t)
baselineRect.Position = [t(val) y(1) t(width)-t(1) diff(y)];
tit.String = sprintf('Use the slider to pick a quiet period as baseline: %d',val);
end