% set up directory paths
% TODO: add ops.gainAdj and ops.clip
homebase = fileparts(which("batch_vocalization_analysis.m"));
ratLogPath = fullfile(homebase,"Vocalization_recording_data.xlsx");
ratInfo = readtable(ratLogPath);
%ratInfo = removevars(ratInfo,'SCARSCORE');

resultsPath = fullfile(homebase,"_results");
results = dir(fullfile(resultsPath,"*.mat"));

recDirPath = fullfile(homebase,"Recordings");

% analysis options
ops.window = .01;
ops.overlap = .8;
ops.freqs = [];
ops.freqRange = [300 125000];
ops.fitFormants = true;
ops.nFormants = 2;
ops.minVocalizationLength = 0.1;
ops.chunkLength = 0.01;
ops.formantColors = {'red',[1 .5 0],'yellow','green','blue',[1 0 1]};
ops.manuallyPickBaseline = true;
ops.fitGaussian = true;
ops.nPeaks = 10;
ops.hoarseCutoff = 200;

% iterate over every rat
for i = 1:height(ratInfo)
    %try
        for rec = 1:2
            if rec==1
                recordingID = ratInfo.REC1NAME(i);
                age = ratInfo.AGEREC1(i);
                postSurgery = false;
                gain = ratInfo.Gain1(i);
            elseif rec==2
                recordingID = ratInfo.REC2NAME(i);
                age = ratInfo.AGEREC2(i);
                postSurgery = true;
                gain = ratInfo.Gain2(i);
            end
            cageNum = ratInfo.CAGENUMBER(i);
            mark = logical(ratInfo.MARK(i));
            treatment = ratInfo.TREATMENT_(i);
            controlGel = ratInfo.EmptyGel(i);
            decorinGel = ratInfo.DcnGel(i);
            try
                recordingID = recordingID{:};
            catch
            end

            ops.clip = ratInfo.Gain2(i) ~= ratInfo.Gain1(i);

            resName = [recordingID(1:end-4) '_results'];
            if ~isempty(recordingID) && all(~isnan(recordingID)) && ...
                    exist(fullfile(recDirPath,recordingID),'file') && ...% only analyze recordings that exist...
                    ~any(cell2mat(regexp({results.name},[resName '*']))==1) % don't redo already analyzed ones
                
                conv = load(fullfile(homebase,'Gain calibration',sprintf('Gain%dCalibration.mat',gain)));
                ops.gainAdj = conv.conversion;

                [vocs,baselineIdx,frequencies,filepath,ops] = analyze_vocalization(fullfile(recDirPath,recordingID),ops);
                save(fullfile(resultsPath,resName),...
                    'vocs','baselineIdx','frequencies','filepath','ops','gain',...
                    'recordingID','age','postSurgery','controlGel','decorinGel','cageNum','mark','treatment');
            end
        end
    %catch
    %end
end





