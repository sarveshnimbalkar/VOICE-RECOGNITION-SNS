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
result = match_speakers(features, pattern);
result.names = names;
result.phrase = phrase;
result.pitch_hz = details.pitch_hz;
result.uncertain = ~result.accepted;
scores = result.scores;
speakerMeans = reshape(mean(features(1:13, :, :), 2), 13, []);
for speakerNumber = 1:numel(speakers)
    if ~isempty(result.bad_samples{speakerNumber})
        fprintf('Check %s enrollment sample(s) %s: inconsistent with this speaker.\n', ...
            names{speakerNumber}, mat2str(result.bad_samples{speakerNumber}));
    end
end
if ~result.accepted
    result.name = 'Unknown';
    message = sprintf('Unknown / rejected.\n%s\nRepeat the complete phrase in your normal voice.', result.reason);
    plotTitle = 'Unknown / rejected';
elseif isscalar(speakers)
    result.name = names{result.winner};
    message = sprintf('Voice matches enrollment: %s\nOnly one speaker enrolled; no comparison with other people.', result.name);
    plotTitle = ['Enrollment match: ' result.name];
else
    result.name = names{result.winner};
    message = sprintf('Identified speaker: %s', result.name);
    plotTitle = message;
end
fprintf('%s\n', message);
fprintf('Estimated voiced pitch: %.1f Hz\n', details.pitch_hz);
for speakerNumber = 1:numel(names)
    fprintf('  %s: distance %.4f / limit %.4f; matching samples %d of %d\n', ...
        names{speakerNumber}, scores(speakerNumber), result.limits(speakerNumber), ...
        result.support(speakerNumber), size(features, 2));
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
subplot(4,1,4); distanceBars = bar(scores); hold on;
limitMarkers = plot(1:numel(names), result.limits, 'ro', 'MarkerFaceColor', 'r');
grid on;
legend([distanceBars limitMarkers], 'Test distance', 'Enrollment distance limit', 'Location', 'best');
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

function result = match_speakers(features, pattern)
% Accept only a close, well-supported match; never fall back to another name.
exampleCount = size(features, 2);
speakerCount = size(features, 3);
centroids = median(features, 2);
residuals = reshape(features-centroids, 27, []);
scale = max(1.4826*median(abs(residuals), 2), [0.5*ones(26, 1); 0.1]);
result.scores = zeros(1, speakerCount);
result.limits = zeros(1, speakerCount);
result.mfcc_limits = zeros(1, speakerCount);
result.pitch_limits = zeros(1, speakerCount);
result.support = zeros(1, speakerCount);
result.profile_valid = false(1, speakerCount);
result.bad_samples = cell(1, speakerCount);
mfccDistances = zeros(1, speakerCount);
pitchDifferences = zeros(1, speakerCount);
for speakerNumber = 1:speakerCount
    samples = features(:, :, speakerNumber);
    centroid = centroids(:, 1, speakerNumber);
    difference = (pattern-centroid)./scale;
    result.scores(speakerNumber) = voice_distance(difference);
    mfccDistances(speakerNumber) = mean(difference(1:26).^2);
    pitchDifferences(speakerNumber) = abs(pattern(27)-centroid(27));

    % Each enrollment clip is scored against the other clips, not itself.
    genuine = zeros(3, exampleCount);
    for example = 1:exampleCount
        others = setdiff(1:exampleCount, example);
        reference = median(samples(:, others), 2);
        difference = (samples(:, example)-reference)./scale;
        genuine(:, example) = [voice_distance(difference); ...
            mean(difference(1:26).^2); abs(samples(27, example)-reference(27))];
    end
    middle = median(genuine, 2);
    bounds = min([2; 2; 0.2], max([0.25; 0.25; 0.1], ...
        middle+2*1.4826*median(abs(genuine-middle), 2)));
    result.limits(speakerNumber) = bounds(1);
    result.mfcc_limits(speakerNumber) = bounds(2);
    result.pitch_limits(speakerNumber) = bounds(3);

    pairs = (samples-reshape(samples, 27, 1, exampleCount))./scale;
    pairDistances = reshape(voice_distance(pairs), exampleCount, exampleCount);
    pairDistances = pairDistances(triu(true(exampleCount), 1));
    middle = median(pairDistances);
    templateLimit = min(3, max(0.5, middle+ ...
        2*1.4826*median(abs(pairDistances-middle))));
    templateDistances = voice_distance((samples-pattern)./scale);
    result.support(speakerNumber) = sum(templateDistances <= templateLimit);
    enrollmentDistances = voice_distance((samples-centroid)./scale);
    result.bad_samples{speakerNumber} = find(enrollmentDistances > bounds(1));
    result.profile_valid(speakerNumber) = sum(enrollmentDistances <= bounds(1)) >= 3;
end
[ordered, positions] = sort(result.scores);
result.winner = positions(1);
result.margin = NaN;
if speakerCount > 1
    result.margin = (ordered(2)-ordered(1))/max(ordered(2), eps);
end
winner = result.winner;
checks = [result.profile_valid(winner), ...
    result.scores(winner) <= result.limits(winner), ...
    mfccDistances(winner) <= result.mfcc_limits(winner), ...
    pitchDifferences(winner) <= result.pitch_limits(winner), ...
    result.support(winner) >= 3, ...
    speakerCount == 1 || result.margin >= 0.35];
result.accepted = all(checks);
reasons = {'Enrollment is inconsistent; re-enroll this speaker.', ...
    'Voice is too far from the enrollment profile.', ...
    'Voice spectrum does not match the enrollment.', ...
    'Voice pitch does not match the enrollment.', ...
    'Fewer than three enrollment samples support this match.', ...
    'The enrolled speakers are too similar for a reliable decision.'};
result.reason = 'Accepted';
if ~result.accepted
    result.reason = reasons{find(~checks, 1)};
end
end

function distance = voice_distance(difference)
distance = 0.75*mean(difference(1:26, :, :).^2, 1)+ ...
    0.25*difference(27, :, :).^2;
end
