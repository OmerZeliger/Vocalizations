function calibrateAcrossGain()

% prep filepaths and constants
homebase = fileparts(which('calibrateAcrossGain'));
gainToTest = 10;

% load in highest gain
[baseGainWF,fs] = audioread(fullfile(homebase,sprintf('Gain%d.wav',10)));
[newGainWF,fs] = audioread(fullfile(homebase,sprintf('Gain%d.wav',gainToTest)));

% calculate conversion to make rms equal
conversion = rms(baseGainWF(2*fs:3*fs))/rms(newGainWF(2*fs:3*fs));

% save info
save(fullfile(homebase,sprintf('Gain%dCalibration',gainToTest)),"conversion");
end