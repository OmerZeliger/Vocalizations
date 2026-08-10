% set up directory paths
filepath = fileparts(which("_batch_vocalization_analysis.m"));
ratLogPath = fullfile(filepath,"Vocalization_recording_data.xlsx");
ratInfo = readtable(ratLogPath);

resultsPath = fullfile(filepath,"_results");
results = dir(fullfile(resultsPath,"*.mat"));

recDirPath = fullfile(filepath,"Recordings");

% analysis options
ops.window = .01;
ops.overlap = .8;
ops.freqs = [];
ops.freqRange = [1000 100000];
ops.fitFormants = false;
ops.nFormants = 2;
ops.minVocalizationLength = 0.2;
ops.chunkLength = 0.01;
ops.formantColors = {'red',[1 .5 0],'yellow','green','blue',[1 0 1]};
ops.manuallyPickBaseline = false;
ops.fitGaussian = false;
ops.nPeaks = 10;

% iterate over every rat
for i = 1:height(ratInfo)
    try
        for rec = 1:2
            if rec==1
                recordingID = ratInfo.REC1NAME(i);
                age = ratInfo.AGEREC1(i);
                scarScore = nan;
                postSurgery = false;
            elseif rec==2
                recordingID = ratInfo.REC2NAME(i);
                age = ratInfo.AGEREC2(i);
                scarScore = ratInfo.SCARSCORE(i);
                postSurgery = true;
            end
            cageNum = ratInfo.CAGENUMBER(i);
            mark = logical(ratInfo.MARK(i));
            treatment = logical(ratInfo.TREATMENT_(i));
            try
                recordingID = recordingID{:};
            catch
            end

            resName = [recordingID(1:end-4) '_results'];
            if ~isempty(recordingID) && all(~isnan(recordingID)) && ...
                    exist(fullfile(recDirPath,recordingID),'file') && ...% only analyze recordings that exist...
                    ~any(cell2mat(regexp({results.name},[resName '*']))==1) % don't redo already analyzed ones

                [vocs,baselineIdx,frequencies,filepath,ops] = analyze_vocalization(fullfile(recDirPath,recordingID),ops);
                save(fullfile(resultsPath,resName),...
                    'vocs','baselineIdx','frequencies','filepath','ops',...
                    'recordingID','age','scarScore','postSurgery','cageNum','mark','treatment');
            end
        end
    catch
    end
end





