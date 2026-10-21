function analyze_processed_vocalizations()
filepath = fileparts(which("analyze_processed_vocalizations.m"));
resultsPath = fullfile(filepath,"_results");

resultFiles = dir(fullfile(resultsPath,"*_results*.mat"));

allData = struct([]);
for i = 1:length(resultFiles)
    dat = load(fullfile(resultsPath,resultFiles(i).name));
    
    if ~isempty(dat.vocs)
        % append experimental info to vocalizations
        temp = dat.vocs;
        %temp = rmfield(temp,{'SmoothedPower','Time'});
        [temp.Age] = deal(dat.age);
        [temp.RecordingID] = deal(dat.recordingID);
        [temp.ControlGel] = deal(dat.controlGel);
        [temp.DecorinGel] = deal(dat.decorinGel);
        [temp.Treatment] = deal(dat.treatment);
        [temp.PostSurgery] = deal(dat.postSurgery);
        vocTimes = {dat.vocs.Time}; vocStart = cellfun(@(X) X(1),vocTimes,'UniformOutput',false);
        [temp.StartTime] = vocStart{:};

        % concatenate to table with all vocalizations
        allData = [allData temp];
    end
end



%% plot pre vs post-surgery
postSurgery = logical([allData.PostSurgery]);
vocalization = strcmp({allData.ManualCuration},'Vocalization') | strcmp({allData.ManualCuration},'Well-fit') | strcmp({allData.ManualCuration},'Poorly-fit');
treatment = double([allData.Treatment]);
treatmentTypes = unique(treatment);
decorinGel = [allData.DecorinGel];

% cut out non-vocalization timepoints
vocOn = {allData.VocalizationOn};
totalPower = {allData.TotalPower};
totalPower = cellfun(@(X,T) X(T),totalPower,vocOn,'UniformOutput',false);
peakToNoise = {allData.PeakToNoiseRatio};
peakToNoise = cellfun(@(X,T) X(T),peakToNoise,vocOn,'UniformOutput',false);

%% plot data per rat
ratID = cellfun(@(X) strsplit(X,'_'),{allData.RecordingID},'UniformOutput',false);
ratID = cellfun(@(X) string([X{1:2}]),ratID);
rats = unique(ratID);

propHoarse = nan(length(rats),2);
hoarseness = propHoarse;
%loudness = propHoarse;
%numVocs = propHoarse;
scar = propHoarse;
decorin = propHoarse;
for i = 1:length(rats)
    ratVocs = strcmp(ratID,rats(i));
    for j = 1:2
        sessionVocs = ratVocs & vocalization & [allData.PostSurgery]==logical(j-1);
        sessionVocs = find(sessionVocs);
        
        propHoarse(i,j) = median(cellfun(@(X) mean(X<200),peakToNoise(sessionVocs)));
        hoarseness(i,j) = median(cellfun(@(X) median(X),peakToNoise(sessionVocs)));
        %loudness(i,j) = median(cellfun(@(X) median(X),totalPower(useableVocs)));
        %numVocs(i,j) = sum(sessionVocs);
        scar(i,j) = allData(sessionVocs(1)).Treatment;
        decorin(i,j) = allData(sessionVocs(1)).DecorinGel;
    end
end

figure; hold on;
for s = 0:1
    scarVocs = scar(:,1) == s;
    for g = 0:1
        decorinVocs = decorin(:,1) == g;

        currentVocs = scarVocs & decorinVocs;
        position = (4*g) + s;

        plot(([0 0.3] + position*ones(size(hoarseness(currentVocs,:))))',log(hoarseness(currentVocs,:))');
    end
end
hold off;
title('log median PNR');

figure; hold on;
for s = 0:1
    scarVocs = scar(:,1) == s;
    for g = 0:1
        decorinVocs = decorin(:,1) == g;

        currentVocs = scarVocs & decorinVocs;
        position = (4*g) + s;

        plot(([0 0.3] + position*ones(size(propHoarse(currentVocs,:))))',propHoarse(currentVocs,:)');
    end
end
hold off;
title('median time spent hoarse');


%% plot hoarseness progression as session progresses
sessions = unique({allData.RecordingID});
for i = 1:length(sessions)
    figure;
    sessionVocs = strcmp({allData.RecordingID},sessions{i});
    useableVocs = sessionVocs & vocalization;

    subplot(1,2,1);
    medianPower = cellfun(@(X) median(X),totalPower(useableVocs));
    scatter([allData(useableVocs).StartTime],medianPower);
    title(sessions{i});

    subplot(1,2,2);
    propHoarse = cellfun(@(X) mean(X<1000),peakToNoise(useableVocs));
    scatter([allData(useableVocs).StartTime],propHoarse);
    title(sessions{i});
end

%% plot change in hoarseness in first 10 vocalizations vs number of vocalizations in first session
ratID = cellfun(@(X) strsplit(X,'_'),{allData.RecordingID},'UniformOutput',false);
ratID = cellfun(@(X) string([X{1:2}]),ratID);
rats = unique(ratID);
hoarseness = nan(length(rats),2);
loudness = hoarseness;
numVocs = hoarseness;
scar = hoarseness;
for i = 1:length(rats)
    ratVocs = strcmp(ratID,rats(i));
    for j = 1:2
        sessionVocs = ratVocs & vocalization & [allData.PostSurgery]==logical(j-1);
        if sum(sessionVocs) < 10
            break;
        end
        useableVocs = find(sessionVocs,10,'first');
        hoarseness(i,j) = median(cellfun(@(X) mean(X<1000),peakToNoise(useableVocs)));
        loudness(i,j) = median(cellfun(@(X) median(X),totalPower(useableVocs)));
        numVocs(i,j) = sum(sessionVocs);
        scar(i,j) = allData(useableVocs(1)).Treatment;
    end
end

figure; subplot(1,2,1); hold on;
for t = 0:1
    curr = scar(:,1) == t;
    scatter(numVocs(curr,1),diff(hoarseness(curr,:),[],2),'filled');
end
hold off;

subplot(1,2,2); hold on;
for t = 0:1
    curr = scar(:,1) == t;
    scatter(numVocs(curr,1),diff(loudness(curr,:),[],2),'filled');
end
hold off;



%%

figure; subplot(1,2,1); hold on;
for t = 0:1
    curr = scar(:,1) == t;
    scatter(numVocs(curr,1),hoarseness(curr,2),'filled');
end
hold off;

subplot(1,2,2); hold on;
for t = 0:1
    curr = scar(:,1) == t;
    scatter(numVocs(curr,1),loudness(curr,2),'filled');
end
hold off;

%%
% maximum vocalization power summed across all frequencies
figure;
peakPower = {};
% pre-surgery
ax(1) = subplot(1,2,1); hold on;
for i = 1:length(treatmentTypes)
    currentTreatment = treatmentTypes(i);

    peakPower{1,i} = cellfun(@(X) max(X),totalPower(~postSurgery & vocalization & treatment==currentTreatment));

    boxplot(peakPower{1,i},Positions=currentTreatment);
    scatter(currentTreatment*ones(size(peakPower{1,i})),peakPower{1,i});
end
hold off;

% post-surgery
ax(2) = subplot(1,2,2); hold on;
for i = 1:length(treatmentTypes)
    currentTreatment = treatmentTypes(i);

    peakPower{2,i} = cellfun(@(X) max(X),totalPower(postSurgery & vocalization & treatment==currentTreatment));

    boxplot(peakPower{2,i},Positions=currentTreatment);
    scatter(currentTreatment*ones(size(peakPower{2,i})),peakPower{2,i});
end
hold off;
linkaxes(ax(1:2),'y');
%%






% median vocalization power
figure;
medianPower = {};
% pre-surgery
ax(1) = subplot(1,2,1); hold on;
for i = 1:length(treatmentTypes)
    currentTreatment = treatmentTypes(i);

    medianPower{1,i} = cellfun(@(X) median(X),totalPower(~postSurgery & vocalization & treatment==currentTreatment));

    boxplot(medianPower{1,i},Positions=currentTreatment);
    scatter(currentTreatment*ones(size(medianPower{1,i})),medianPower{1,i});
end
hold off;


% post-surgery
ax(2) = subplot(1,2,2); hold on;
for i = 1:length(treatmentTypes)
    currentTreatment = treatmentTypes(i);

    medianPower{2,i} = cellfun(@(X) median(X),totalPower(postSurgery & vocalization & treatment==currentTreatment));

    boxplot(medianPower{2,i},Positions=currentTreatment);
    scatter(currentTreatment*ones(size(medianPower{2,i})),medianPower{2,i});
end
hold off;
linkaxes(ax(1:2),'y');



%%



% median peak-to-noise ratio
figure;
medianPNR = {};
% pre-surgery
%ax(1) = subplot(1,2,1); hold on;
hold on;
for i = 1:length(treatmentTypes)
    currentTreatment = treatmentTypes(i);

    medianPNR{1,i,1} = cellfun(@(X) median(X),peakToNoise(~postSurgery & vocalization & treatment==currentTreatment & ~decorinGel));
    medianPNR{1,i,2} = cellfun(@(X) median(X),peakToNoise(~postSurgery & vocalization & treatment==currentTreatment & decorinGel));

    boxplot(log(medianPNR{1,i,1}),Positions=currentTreatment);
    scatter(currentTreatment*ones(size(medianPNR{1,i,1})),log(medianPNR{1,i,1}));
    boxplot(log(medianPNR{1,i,2}),Positions=currentTreatment + 3);
    scatter(3 + currentTreatment*ones(size(medianPNR{1,i,2})),log(medianPNR{1,i,2}));

end


% post-surgery
%ax(2) = subplot(1,2,2); hold on;
for i = 1:length(treatmentTypes)
    currentTreatment = treatmentTypes(i); 

    medianPNR{2,i,1} = cellfun(@(X) median(X),peakToNoise(postSurgery & vocalization & treatment==currentTreatment & ~decorinGel));
    medianPNR{2,i,2} = cellfun(@(X) median(X),peakToNoise(postSurgery & vocalization & treatment==currentTreatment & decorinGel));

    boxplot(log(medianPNR{2,i,1}),Positions=currentTreatment+0.3);
    scatter(0.3 + currentTreatment*ones(size(medianPNR{2,i,1})),log(medianPNR{2,i,1}));
    boxplot(log(medianPNR{2,i,2}),Positions=currentTreatment + 3.3);
    scatter(3.3 + currentTreatment*ones(size(medianPNR{2,i,2})),log(medianPNR{2,i,2}));
end
hold off;
%linkaxes(ax(1:2),'y');
title('log peak-to-noise ratio');



%%

% proportion of vocalization hoarse (hoarse: peak-to-trough < 200)
hoarseCutoff = 200;
figure;
propHoarse = {};
% pre-surgery
%ax(1) = subplot(1,2,1); hold on;
hold on;
for i = 1:length(treatmentTypes)
    currentTreatment = treatmentTypes(i);

    propHoarse{1,i,1} = cellfun(@(X) mean(X<hoarseCutoff),peakToNoise(~postSurgery & vocalization & treatment==currentTreatment & ~decorinGel));
    propHoarse{1,i,2} = cellfun(@(X) mean(X<hoarseCutoff),peakToNoise(~postSurgery & vocalization & treatment==currentTreatment & decorinGel));

    boxplot(propHoarse{1,i,1},Positions=currentTreatment);
    scatter(currentTreatment*ones(size(propHoarse{1,i,1})),propHoarse{1,i,1});
    boxplot(propHoarse{1,i,2},Positions=currentTreatment + 3);
    scatter(3 + currentTreatment*ones(size(propHoarse{1,i,2})),propHoarse{1,i,2});
end


% post-surgery
for i = 1:length(treatmentTypes)
    currentTreatment = treatmentTypes(i); 

    propHoarse{2,i,1} = cellfun(@(X) mean(X<hoarseCutoff),peakToNoise(postSurgery & vocalization & treatment==currentTreatment & ~decorinGel));
    propHoarse{2,i,2} = cellfun(@(X) mean(X<hoarseCutoff),peakToNoise(postSurgery & vocalization & treatment==currentTreatment & decorinGel));

    boxplot(propHoarse{2,i,1},Positions=currentTreatment+0.3);
    scatter(.3 + currentTreatment*ones(size(propHoarse{2,i,1})),propHoarse{2,i,1});
    boxplot(propHoarse{2,i,2},Positions=currentTreatment + 3.3);
    scatter(3.3 + currentTreatment*ones(size(propHoarse{2,i,2})),propHoarse{2,i,2});
end
hold off;
%linkaxes(ax(1:2),'y');
title('proportion spent hoarse');


%%

% vocalization duration
figure;
duration = {};
% pre-surgery
ax(1) = subplot(1,2,1); hold on;
for i = 1:length(treatmentTypes)
    currentTreatment = treatmentTypes(i);

    duration{1,i} = cellfun(@(X) length(X),peakToNoise(~postSurgery & vocalization & treatment==currentTreatment));

    boxplot(duration{1,i},Positions=currentTreatment);
    scatter(currentTreatment*ones(size(duration{1,i})),duration{1,i});
end
hold off;


% post-surgery
ax(2) = subplot(1,2,2); hold on;
for i = 1:length(treatmentTypes)
    currentTreatment = treatmentTypes(i);

    duration{2,i} = cellfun(@(X) length(X),peakToNoise(postSurgery & vocalization & treatment==currentTreatment));

    boxplot(duration{2,i},Positions=currentTreatment);
    scatter(currentTreatment*ones(size(duration{2,i})),duration{2,i});
end
hold off;
linkaxes(ax(1:2),'y');


%% try looking at fundamental


%% try looking at gaussian fit spread of fundamental