% Identify a speaker using the WAV files in speaker_recordings/speaker_<name>.
fs = 16000;
phrase = 'This is my voice for identification.';
folder = fileparts(mfilename('fullpath'));
addpath(folder);
speakers = dir(fullfile(folder, 'speaker_recordings', 'speaker_*'));
speakers = speakers([speakers.isdir]);
if numel(speakers) < 2
    errordlg('Enroll or pull recordings for at least two people first.', 'Speaker identification');
    return;
end

names = cell(1, numel(speakers));
features = zeros(26, 5, numel(speakers));
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

inputMode = questdlg('Choose an input for speaker identification.', ...
    'Speaker identification', 'Microphone', 'WAV file', 'Cancel', 'Microphone');
if isempty(inputMode) || strcmp(inputMode, 'Cancel')
    return;
end
if strcmp(inputMode, 'Microphone')
    x = record_voice(fs, phrase, 'Speaker identification');
    if isempty(x)
        return;
    end
else
    [filename, pathname] = uigetfile('*.wav', 'Select a new 16000 Hz recording of the same phrase');
    if isequal(filename, 0)
        return;
    end
    [x, fs] = audioread(fullfile(pathname, filename));
end

try
    [pattern, filteredSound, details] = sound_pattern(x, fs);
catch problem
    errordlg(problem.message, 'Speaker identification');
    return;
end
scale = max(std(reshape(features, 26, []), 0, 2), 0.5);
scores = zeros(1, numel(speakers));
for speakerNumber = 1:numel(speakers)
    centroid = mean(features(:, :, speakerNumber), 2);
    scores(speakerNumber) = mean(((pattern-centroid)./scale).^2);
end
[ordered, positions] = sort(scores);
result.name = names{positions(1)};
result.names = names;
result.scores = scores;
result.margin = (ordered(2)-ordered(1))/max(ordered(2), eps);
result.uncertain = result.margin < 0.10;
result.phrase = phrase;
if result.uncertain
    message = sprintf('Uncertain match. Please repeat.\nClosest enrolled speaker: %s', result.name);
    plotTitle = ['Uncertain match: ' result.name];
else
    message = sprintf('Identified speaker: %s', result.name);
    plotTitle = message;
end
fprintf('%s\n', message);
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
figure('Name', 'Speaker identification', 'Color', 'w');
subplot(3,1,1); plot(time, x); grid on;
title('Recorded speech'); xlabel('Time (s)'); ylabel('Amplitude');
subplot(3,1,2); imagesc(details.cepstra); axis xy;
title('MFCCs of selected speech frames'); xlabel('Selected speech frame'); ylabel('Coefficient');
colorbar('Color', 'k');
subplot(3,1,3); bar(scores); grid on;
set(gca, 'XTick', 1:numel(names), 'XTickLabel', names, 'TickLabelInterpreter', 'none');
title(plotTitle, 'Interpreter', 'none'); ylabel('Distance (lower is closer)');
set(findall(gcf, 'Type', 'axes'), 'Color', 'w', 'XColor', 'k', 'YColor', 'k');
set(findall(gcf, 'Type', 'text'), 'Color', 'k');
