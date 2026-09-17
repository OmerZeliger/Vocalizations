filepath = fileparts(which("_analyze_processed_vocalizations.m"));
resultsPath = fullfile(filepath,"_results");

resultFiles = dir(fullfile(resultsPath,"*_results*.mat"));

allData = struct([]);
for i = 1:length(resultFiles)
    dat = load(fullfile(resultsPath,resultFiles(i).name));
    
    % append experimental info to vocalizations
    temp = dat.vocs;
    temp = rmfield(temp,{'SmoothedPower','Time'});
    [temp.Age] = deal(dat.age);
    [temp.RecordingID] = deal(dat.recordingID);
    [temp.ControlGel] = deal(dat.controlGel);
    [temp.DecorinGel] = deal(dat.decorinGel);
    [temp.Treatment] = deal(dat.treatment);
    [temp.PostSurgery] = deal(dat.postSurgery);

    % concatenate to table with all vocalizations
    allData = [allData temp];
end





%% plot pre vs post-surgery
postSurgery = logical([allData.PostSurgery]);
vocalization = strcmp({allData.ManualCuration},'Vocalization');
treatment = double([allData.Treatment]);
treatmentTypes = unique(treatment);

% cut out non-vocalization timepoints
vocOn = {allData.VocalizationOn};
totalPower = {allData.TotalPower};
totalPower = cellfun(@(X,T) X(T),totalPower,vocOn,'UniformOutput',false);
peakToNoise = {allData.PeakToNoiseRatio};
peakToNoise = cellfun(@(X,T) X(T),peakToNoise,vocOn,'UniformOutput',false);


%%
% maximum vocalization power summed across all frequencies
figure;
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
% pre-surgery
ax(1) = subplot(1,2,1); hold on;
for i = 1:length(treatmentTypes)
    currentTreatment = treatmentTypes(i);

    medianPNR{1,i} = cellfun(@(X) median(X),peakToNoise(~postSurgery & vocalization & treatment==currentTreatment));

    boxplot(medianPNR{1,i},Positions=currentTreatment);
    scatter(currentTreatment*ones(size(medianPNR{1,i})),medianPNR{1,i});
end
hold off;


% post-surgery
ax(2) = subplot(1,2,2); hold on;
for i = 1:length(treatmentTypes)
    currentTreatment = treatmentTypes(i);

    medianPNR{2,i} = cellfun(@(X) median(X),peakToNoise(postSurgery & vocalization & treatment==currentTreatment));

    boxplot(medianPNR{2,i},Positions=currentTreatment);
    scatter(currentTreatment*ones(size(medianPNR{2,i})),medianPNR{2,i});
end
hold off;
linkaxes(ax(1:2),'y');


%%

% proportion of vocalization hoarse (hoarse: peak-to-trough < 1000)
hoarseCutoff = 1000;
figure;
% pre-surgery
ax(1) = subplot(1,2,1); hold on;
for i = 1:length(treatmentTypes)
    currentTreatment = treatmentTypes(i);

    propHoarse{1,i} = cellfun(@(X) mean(X<hoarseCutoff),peakToNoise(~postSurgery & vocalization & treatment==currentTreatment));

    boxplot(propHoarse{1,i},Positions=currentTreatment);
    scatter(currentTreatment*ones(size(propHoarse{1,i})),propHoarse{1,i});
end
hold off;


% post-surgery
ax(2) = subplot(1,2,2); hold on;
for i = 1:length(treatmentTypes)
    currentTreatment = treatmentTypes(i);

    propHoarse{2,i} = cellfun(@(X) mean(X<hoarseCutoff),peakToNoise(postSurgery & vocalization & treatment==currentTreatment));

    boxplot(propHoarse{2,i},Positions=currentTreatment);
    scatter(currentTreatment*ones(size(propHoarse{2,i})),propHoarse{2,i});
end
hold off;
linkaxes(ax(1:2),'y');