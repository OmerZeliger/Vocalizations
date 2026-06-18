function vocalization_visualization()


[vocs,baselineTime,filepath,ops] = analyze_vocalization();

wellFit = false(size(vocs));
vocalization = wellFit;
for i = 1:length(vocs)
    wellFit(i) = strcmp(vocs(i).ManualCuration,'Well-fit');
    vocalization(i) = wellFit(i) || strcmp(vocs(i).ManualCuration,'Poorly-fit');
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



subplot(1,2,1);histogram(peakIntensity(vocalization),10);title('Peak intensity');
subplot(1,2,2);histogram(meanSNR(vocalization),50);title('peak-to-noise ratio');




end