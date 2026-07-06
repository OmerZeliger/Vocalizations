filepath = fileparts(which("_analyze_processed_vocalizations.m"));
resultsPath = fullfile(filepath,"_results");

resultFiles = dir(fullfile(resultsPath,"*_results.mat"));

allData = struct([]);
for i = 1:length(resultFiles)
    dat = load(fullfile(resultsPath,resultFiles(i).name));
    
    % append experimental info to vocalizations
    temp = dat.vocs;
    [temp.Age] = deal(dat.age);
    [temp.RecordingID] = deal(dat.recordingID);
    [temp.ScarScore] = deal(dat.scarScore);
    [temp.Treatment] = deal(dat.treatment);
    [temp.PostSurgery] = deal(dat.postSurgery);

    % concatenate to table with all vocalizations
    allData = [allData temp];
end


