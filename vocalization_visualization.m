function vocalization_visualization()


[vocs,baselineIdx,f,filepath,ops] = analyze_vocalization('/Users/OZeliger/Desktop/Vocalizations/Recordings/T0000009.wav');

wellFit = false(size(vocs));
vocalization = wellFit;
for i = 1:length(vocs)
    wellFit(i) = strcmp(vocs(i).ManualCuration,'Well-fit');
    vocalization(i) = wellFit(i) || strcmp(vocs(i).ManualCuration,'Poorly-fit') || strcmp(vocs(i).ManualCuration,'Vocalization');
end

% get summary statistics per vocalization
peakIntensity = nan(length(vocalization));
meanIntensity = peakIntensity;
meanSNR = peakIntensity;
for i = 1:length(vocs)
    % vocalization loudness
    power = vocs(i).TotalPower(vocs(i).VocalizationOn);
    peakIntensity(i) = max(power);
    meanIntensity(i) = mean(power);

    % hoarseness
    meanSNR(i) = mean(vocs(i).PeakToNoiseRatio(vocs(i).VocalizationOn));
end



subplot(1,2,1);hold on;histogram(peakIntensity(vocalization),10);title('Peak intensity');
subplot(1,2,2);hold on;histogram(meanSNR(vocalization),50);title('peak-to-noise ratio');




end