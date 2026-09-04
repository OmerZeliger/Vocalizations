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
    [temp.ScarScore] = deal(dat.scarScore);
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



% maximum vocalization power summed across all frequencies
figure;
% pre-surgery
peakPower = cellfun(@(X) max(X),totalPower(~postSurgery & vocalization));
ax(1) = subplot(1,2,1); hold on;
boxplot(peakPower);
scatter(ones(size(peakPower)),peakPower);
hold off;

% post-surgery
ax(2) = subplot(1,2,2); hold on;
for i = 1:length(treatmentTypes)
    currentTreatment = treatmentTypes(i);

    peakPower = cellfun(@(X) max(X),totalPower(postSurgery & vocalization & treatment==currentTreatment));

    boxplot(peakPower,Positions=currentTreatment);
    scatter(currentTreatment*ones(size(peakPower)),peakPower);
end
hold off;
linkaxes(ax(1:2),'y');






% median peak-to-noise ratio
figure;
% pre-surgery
medianPNR = cellfun(@(X) median(X),peakToNoise(~postSurgery & vocalization));
ax(1) = subplot(1,2,1); hold on;
boxplot(medianPNR);
scatter(ones(size(medianPNR)),medianPNR);
hold off;

% post-surgery
ax(2) = subplot(1,2,2); hold on;
for i = 1:length(treatmentTypes)
    currentTreatment = treatmentTypes(i);

    medianPNR = cellfun(@(X) median(X),peakToNoise(postSurgery & vocalization & treatment==currentTreatment));

    boxplot(medianPNR,Positions=currentTreatment);
    scatter(currentTreatment*ones(size(medianPNR)),medianPNR);
end
hold off;
linkaxes(ax(1:2),'y');