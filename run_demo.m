% Identify an enrolled speaker from a new recording of the enrollment phrase.
fs = 16000;
folder = fileparts(mfilename('fullpath'));
addpath(folder);
try
    profiles = sync_speakers(folder);
catch problem
    if startsWith(problem.identifier, 'speaker:')
        errordlg(problem.message, 'Speaker identification');
        return;
    end
    rethrow(problem);
end
if numel(profiles) < 2
    errordlg('Enroll or pull recordings for at least two different people first.', 'Speaker identification');
    return;
end
inputMode = questdlg('Choose an input for speaker identification.', ...
    'Speaker identification', 'Microphone', 'WAV file', 'Cancel', 'Microphone');
if isempty(inputMode) || strcmp(inputMode, 'Cancel')
    return;
end
if strcmp(inputMode, 'Microphone')
    x = record_voice(fs, profiles(1).phrase, 'Speaker identification');
    if isempty(x)
        disp('Identification cancelled.');
        return;
    end
else
    [filename, pathname] = uigetfile('*.wav', 'Select a new 16000 Hz recording of the enrollment phrase');
    if isequal(filename, 0)
        return;
    end
    [x, fs] = audioread(fullfile(pathname, filename));
end

try
    [result, filteredSound, details] = identify_speaker(x, fs, profiles);
catch problem
    if startsWith(problem.identifier, 'speaker:')
        errordlg(problem.message, 'Speaker identification');
        return;
    end
    rethrow(problem);
end
if result.uncertain
    message = sprintf('Uncertain match. Please repeat.\nClosest enrolled speaker: %s', result.name);
    plotTitle = ['Uncertain match: ' result.name];
else
    message = sprintf('Identified speaker: %s\n\nClosest match among enrolled speakers.', result.name);
    plotTitle = ['Identified speaker: ' result.name];
end
fprintf('%s\n', message);
for k = 1:numel(result.names)
    fprintf('  %s: %.4f\n', result.names{k}, result.scores(k));
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
subplot(3,1,3); bar(result.scores); grid on;
set(gca, 'XTick', 1:numel(result.names), 'XTickLabel', result.names, 'TickLabelInterpreter', 'none');
title(plotTitle, 'Interpreter', 'none'); ylabel('Distance (lower is closer)');
set(findall(gcf, 'Type', 'axes'), 'Color', 'w', 'XColor', 'k', 'YColor', 'k');
set(findall(gcf, 'Type', 'text'), 'Color', 'k');
