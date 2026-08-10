% set up directory paths
filepath = fileparts(which("smallifyResults.m"));

resultsPath = fullfile(filepath,"_results");
results = dir(fullfile(resultsPath,"*.mat"));

largeRecordings = results([results.bytes]./1e6 > 100);
newVocLength = 15;

for i = 1:length(largeRecordings)
    originalName = largeRecordings(i).name;
    originalResults = load(fullfile(resultsPath,originalName));
    load(fullfile(resultsPath,originalName));

    newNameBase = originalName(1:end-4);

    for j = 1:ceil(length(originalResults.vocs)/newVocLength)
        temp = min(newVocLength*j,length(originalResults.vocs));
        vocs = originalResults.vocs((newVocLength*(j-1))+1:temp);

        save(fullfile(resultsPath,[newNameBase '_part' num2str(j)]),...
            'vocs','baselineIdx','frequencies','filepath','ops',...
            'recordingID','age','scarScore','postSurgery','cageNum','mark','treatment');
    end

    movefile(fullfile(resultsPath,originalName),fullfile(resultsPath,['BIG_' originalName]));
end