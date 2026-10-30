% Identify a speaker using the WAV files in speaker_recordings/speaker_<name>.
fs = 16000;
phrase = 'This is my voice for identification.';
folder = fileparts(mfilename('fullpath'));
addpath(folder);
speakers = dir(fullfile(folder, 'speaker_recordings', 'speaker_*'));
speakers = speakers([speakers.isdir]);
if isempty(speakers)
    errordlg('No speakers enrolled. Run train_my_voice.m first.', 'Speaker identification');
    return;
end

names = cell(1, numel(speakers));
features = zeros(27, 5, numel(speakers));
try
    for speakerNumber = 1:numel(speakers)
        name = strrep(speakers(speakerNumber).name(9:end), '_', ' ');
        if isempty(strtrim(name))
            error('speaker:Name', 'Each speaker folder must include a name after speaker_.');
        end
        name(1) = upper(name(1));
        names{speakerNumber} = name;
        for example = 1:5
            filename = fullfile(speakers(speakerNumber).folder, speakers(speakerNumber).name, ...
                sprintf('sample_%03d.wav', example));
            [sample, rate] = audioread(filename);
            features(:, example, speakerNumber) = sound_pattern(sample, rate);
        end
    end
catch problem
    errordlg(problem.message, 'Cannot load speaker recordings');
    return;
end

x = record_voice(fs, phrase, 'Live speaker identification');
if isempty(x)
    return;
end

try
    [pattern, filteredSound, details] = sound_pattern(x, fs);
catch problem
    errordlg(problem.message, 'Speaker identification');
    return;
end
% Use within-speaker variation; between-speaker differences carry identity.
centroids = median(features, 2);
residuals = reshape(features-centroids, 27, []);
scale = max(1.4826*median(abs(residuals), 2), [0.5*ones(26, 1); 0.1]);
scores = zeros(1, numel(speakers));
speakerMeans = zeros(13, numel(speakers));
for speakerNumber = 1:numel(speakers)
    centroid = centroids(:, 1, speakerNumber);
    speakerMeans(:, speakerNumber) = mean(features(1:13, :, speakerNumber), 2);
    difference = (pattern-centroid)./scale;
    scores(speakerNumber) = 0.75*mean(difference(1:26).^2)+0.25*difference(27)^2;
    enrollmentDifference = (features(:, :, speakerNumber)-centroid)./scale;
    enrollmentDistances = 0.75*mean(enrollmentDifference(1:26, :).^2, 1)+ ...
        0.25*enrollmentDifference(27, :).^2;
    if any(enrollmentDistances > 4)
        fprintf('Check %s enrollment sample(s) %s: inconsistent with the other recordings. Consider re-enrolling.\n', ...
            names{speakerNumber}, mat2str(find(enrollmentDistances > 4)));
    end
end
[ordered, positions] = sort(scores);
result.name = names{positions(1)};
result.names = names;
result.scores = scores;
result.margin = NaN;
if numel(speakers) > 1
    result.margin = (ordered(2)-ordered(1))/max(ordered(2), eps);
end
% These are practical rejection limits, not calibrated probabilities.
result.uncertain = result.margin < 0.20 || ordered(1) > 4;
result.phrase = phrase;
result.pitch_hz = details.pitch_hz;
if result.uncertain
    result.name = 'Uncertain';
    message = 'No reliable match. Please repeat the phrase clearly.';
    plotTitle = 'Uncertain match';
elseif isscalar(speakers)
    message = sprintf('Voice matches enrollment: %s\nOnly one speaker enrolled; no comparison with other people.', result.name);
    plotTitle = ['Enrollment match: ' result.name];
else
    message = sprintf('Identified speaker: %s', result.name);
    plotTitle = message;
end
fprintf('%s\n', message);
fprintf('Estimated voiced pitch: %.1f Hz\n', details.pitch_hz);
for speakerNumber = 1:numel(names)
    fprintf('  %s: %.4f\n', names{speakerNumber}, scores(speakerNumber));
end
msgbox(message, 'Speaker identification result');
drawnow;

if isvector(x)
    x = x(:);
else
    x = mean(x, 2);
end
time = (0:length(x)-1)'/fs;
signalFigure = figure('Name', 'Speaker identification', 'Color', 'w', 'WindowStyle', 'docked');
subplot(4,1,1); plot(time, x); grid on;
title('Recorded speech'); xlabel('Time (s)'); ylabel('Amplitude');
subplot(4,1,2);
plot(details.fft_frequency, 20*log10(max(details.fft_input, 1e-12)), ...
    details.fft_frequency, 20*log10(max(details.fft_filtered, 1e-12)));
grid on; xlim([0 fs/2]);
title('Full-record FFT before and after filtering'); xlabel('Frequency (Hz)'); ylabel('Magnitude (dB)');
legend('Before filtering', 'After filtering', 'Location', 'best');
subplot(4,1,3); imagesc(details.cepstra); axis xy;
title('MFCCs of selected speech frames'); xlabel('Selected speech frame'); ylabel('Coefficient');
colorbar('Color', 'k');
subplot(4,1,4); bar(scores); grid on;
set(gca, 'XTick', 1:numel(names), 'XTickLabel', names, 'TickLabelInterpreter', 'none');
title(plotTitle, 'Interpreter', 'none'); ylabel('Distance (lower is closer)');
set(findall(gcf, 'Type', 'axes'), 'Color', 'w', 'XColor', 'k', 'YColor', 'k');
set(findall(gcf, 'Type', 'text'), 'Color', 'k');
set(findall(gcf, 'Type', 'legend'), 'Color', 'w', 'TextColor', 'k');

coefficients = 1:13;
colors = lines(numel(speakers));
meanDifferences = pattern(1:13)-speakerMeans;
meanFigure = figure('Name', 'Speaker mean comparison', 'Color', 'w', 'WindowStyle', 'docked');
subplot(2,1,1);
plot(coefficients, pattern(1:13), '-ko', 'LineWidth', 2); hold on;
for speakerNumber = 1:numel(speakers)
    plot(coefficients, speakerMeans(:, speakerNumber), '-o', ...
        'Color', colors(speakerNumber, :), 'LineWidth', 1.2);
end
grid on; xlim([1 13]); xticks(coefficients);
title('Current voice and enrolled speaker means'); xlabel('MFCC coefficient'); ylabel('Mean MFCC value');
legend([{'Current voice'} names], 'Interpreter', 'none', 'Location', 'best');
subplot(2,1,2);
bars = bar(coefficients, meanDifferences, 'grouped');
for speakerNumber = 1:numel(speakers)
    bars(speakerNumber).FaceColor = colors(speakerNumber, :);
end
grid on; xticks(coefficients); yline(0, 'k-');
title('Current mean minus each enrolled speaker mean'); xlabel('MFCC coefficient'); ylabel('Signed difference');
legend(bars, names, 'Interpreter', 'none', 'Location', 'best');
set(findall(gcf, 'Type', 'axes'), 'Color', 'w', 'XColor', 'k', 'YColor', 'k');
set(findall(gcf, 'Type', 'text'), 'Color', 'k');
set(findall(gcf, 'Type', 'legend'), 'Color', 'w', 'TextColor', 'k');

drawnow;
exportgraphics(signalFigure, fullfile(folder, 'test_signal.png'), 'Resolution', 150);
exportgraphics(meanFigure, fullfile(folder, 'test_comparison.png'), 'Resolution', 150);
fprintf('Saved latest test figures: test_signal.png and test_comparison.png\n');
