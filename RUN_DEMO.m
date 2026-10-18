% Recognize START, STOP, or LIGHTS using recorded or supplied audio.
useMicrophone = true;
testWord = 'start';
fs = 16000;
words = {'start', 'stop', 'lights'};
folder = fileparts(mfilename('fullpath'));
addpath(folder);

if useMicrophone
    trainingFolder = fullfile(folder, 'my_recordings');
    if ~exist(fullfile(trainingFolder, 'train_lights_3.wav'), 'file')
        error('First run TRAIN_MY_VOICE.m to record your examples.');
    end
    ready = questdlg('Click Record, stay quiet briefly, then speak when prompted.', ...
        'Voice command recognition', 'Record', 'Cancel', 'Record');
    if ~strcmp(ready, 'Record')
        disp('Recording cancelled.');
        return;
    end
    recorder = audiorecorder(fs, 16, 1);
    record(recorder);
    disp('Stay quiet...'); pause(0.5);
    disp('SPEAK NOW: START, STOP or LIGHTS'); pause(2);
    stop(recorder);
    x = getaudiodata(recorder);
else
    trainingFolder = fullfile(folder, 'demo_audio');
    [x, rate] = audioread(fullfile(trainingFolder, ['test_' testWord '.wav']));
    assert(rate == fs, 'Audio must be 16000 Hz.');
    rng(7);
    time = (0:length(x)-1)' / fs;
    noise = 0.7*sin(2*pi*120*time) + 0.3*randn(size(x));
    noise = noise * sqrt(sum(x.^2) / (10*sum(noise.^2)));
    x = x + noise;                  % 10 dB whole-recording SNR
end

% The first 0.25 s must contain background noise only.
noisePart = x(1:round(0.25*fs));
volume = sqrt(mean(x.^2));
noiseVolume = sqrt(mean(noisePart.^2));
if volume < 0.0001 || volume < 1.5*noiseVolume
    disp('NO SPEECH DETECTED. Try again.');
    msgbox('No speech detected. Run again and speak after SPEAK NOW.', ...
        'Recognition result', 'warn');
    drawnow;
    return;
end

[pattern, filteredSound] = sound_pattern(x, fs);

scores = zeros(1, 3);
for wordNumber = 1:3
    bestScore = inf;
    for example = 1:3
        name = sprintf('train_%s_%d.wav', words{wordNumber}, example);
        [sample, rate] = audioread(fullfile(trainingFolder, name));
        assert(rate == fs, 'Training audio must be 16000 Hz.');
        savedPattern = sound_pattern(sample, fs);
        difference = sum((pattern - savedPattern).^2);
        if difference < bestScore
            bestScore = difference;
        end
    end
    scores(wordNumber) = bestScore;
end

[bestScore, position] = min(scores);
sortedScores = sort(scores);
gap = (sortedScores(2)-bestScore) / max(sortedScores(2), eps);
if bestScore > 0.30 || gap < 0.15
    command = 'PLEASE REPEAT';
else
    command = upper(words{position});
end
fprintf('Recognized command: %s\n', command);
if strcmp(command, 'PLEASE REPEAT')
    resultMessage = 'Could not confidently recognize a command. Please repeat.';
else
    resultMessage = sprintf('Recognized command: %s', command);
end
msgbox(resultMessage, 'Recognition result');
drawnow;

time = (0:length(x)-1)' / fs;
figure('Name', 'Basic voice recognition', 'Color', 'w');
subplot(3,1,1); plot(time, x); grid on;
title('Original sound with background noise'); xlabel('Time (seconds)'); ylabel('Amplitude');
subplot(3,1,2); plot(time, filteredSound); grid on;
title('Sound after frequency filtering'); xlabel('Time (seconds)'); ylabel('Amplitude');
subplot(3,1,3); bar(scores); grid on;
set(gca, 'XTick', 1:3, 'XTickLabel', words);
title(['Result: ' command]); ylabel('Difference: smaller is better');
