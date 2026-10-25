function test_speaker_identification(outputFolder)
% Synthetic checks validate the pipeline, not recognition accuracy on people.
folder = fileparts(fileparts(mfilename('fullpath')));
addpath(folder);
fs = 16000;
phrase = 'This is my voice for identification.';
profiles = struct('name', {}, 'features', {}, 'phrase', {}, 'feature_version', {});
for speaker = 1:2
    features = zeros(26, 5);
    for example = 1:5
        x = synthetic_voice(speaker, example, fs);
        features(:, example) = sound_pattern(x, fs);
    end
    profiles(speaker) = struct('name', sprintf('Synthetic speaker %d', speaker), ...
        'features', features, 'phrase', phrase, 'feature_version', 1);
end
for speaker = 1:2
    x = synthetic_voice(speaker, 99, fs);
    result = identify_speaker(x, fs, profiles);
    assert(strcmp(result.name, profiles(speaker).name));
    assert(~result.uncertain);
    [pattern, filteredSound, details] = sound_pattern(x, fs);
    assert(isequal(size(pattern), [26 1]) && all(isfinite(pattern)));
    assert(length(filteredSound) == length(x) && details.speech_seconds >= 0.5);
    scaled = sound_pattern(x*0.4, fs);
    assert(max(abs(pattern-scaled)) < 1e-6, 'Features should resist global gain changes.');
    stereo = sound_pattern([x x], fs);
    row = sound_pattern(x', fs);
    assert(max(abs(pattern-stereo)) < 1e-10 && max(abs(pattern-row)) < 1e-10);
end
x = synthetic_voice(1, 99, fs);
assert_error(@() sound_pattern(zeros(fs, 1), fs), 'speaker:NoSpeech');
assert_error(@() sound_pattern(0.002*ones(fs, 1), fs), 'speaker:NoSpeech');
rng(100); stationaryNoise = randn(3*fs, 1)*0.005;
assert_error(@() sound_pattern(stationaryNoise, fs), 'speaker:NoSpeech');
assert_error(@() sound_pattern(x(1:100), fs), 'speaker:ShortAudio');
assert_error(@() sound_pattern(x, 8000), 'speaker:SampleRate');
badAudio = x; badAudio(1) = NaN;
assert_error(@() sound_pattern(badAudio, fs), 'speaker:InvalidAudio');
assert_error(@() identify_speaker(x, fs, profiles(1)), 'speaker:Enrollment');
badProfiles = profiles; badProfiles(1).features(1) = Inf;
assert_error(@() identify_speaker(x, fs, badProfiles), 'speaker:Profiles');
badProfiles = profiles; badProfiles(1).feature_version = 0;
assert_error(@() identify_speaker(x, fs, badProfiles), 'speaker:Profiles');
badProfiles = profiles; badProfiles(2).phrase = 'Another phrase';
assert_error(@() identify_speaker(x, fs, badProfiles), 'speaker:Profiles');
badProfiles = profiles; badProfiles(2).name = upper(profiles(1).name);
assert_error(@() identify_speaker(x, fs, badProfiles), 'speaker:Profiles');
tied = profiles; tied(2).features = tied(1).features;
result = identify_speaker(x, fs, tied);
assert(result.uncertain && abs(result.margin) < eps);

% Exercise imported WAV input without enrolling test fixtures as real people.
filename = [tempname '.wav'];
cleanup = onCleanup(@() delete(filename));
audiowrite(filename, x, fs);
[imported, rate] = audioread(filename);
result = identify_speaker(imported, rate, profiles);
assert(strcmp(result.name, profiles(1).name));
if nargin > 0
    if ~exist(outputFolder, 'dir')
        mkdir(outputFolder);
    end
    [~, ~, details] = sound_pattern(imported, rate);
    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [50 50 1100 850]);
    subplot(3,1,1); plot((0:length(imported)-1)/rate, imported); grid on;
    title('Synthetic speech-like test signal (not a human recording)');
    xlabel('Time (s)'); ylabel('Amplitude');
    subplot(3,1,2); imagesc(details.cepstra); axis xy;
    title('MFCCs of selected frames'); xlabel('Selected speech frame'); ylabel('Coefficient');
    colorbar('Color', 'k');
    subplot(3,1,3); bar(result.scores); grid on;
    set(gca, 'XTick', 1:2, 'XTickLabel', result.names);
    title(['Synthetic pipeline check: ' result.name]); ylabel('Distance (lower is closer)');
    set(findall(fig, 'Type', 'axes'), 'Color', 'w', 'XColor', 'k', 'YColor', 'k');
    set(findall(fig, 'Type', 'text'), 'Color', 'k');
    exportgraphics(fig, fullfile(outputFolder, 'speaker_validation.png'), 'Resolution', 150);
    close(fig);
end
fprintf('PASS: held-out synthetic identities, gain, channels, WAV input, ambiguity, and invalid-input checks.\n');
end

function x = synthetic_voice(speaker, seed, fs)
rng(seed);
t = (0:3*fs-1)'/fs;
f0 = (105+75*speaker)*(1+0.01*sin(2*pi*2*t));
phase = cumsum(f0)*2*pi/fs;
formants = [450 1300 2450] + (speaker-1)*[250 700 550];
voice = zeros(size(t));
for harmonic = 1:65
    frequency = harmonic*mean(f0);
    envelope = sum(exp(-0.5*((frequency-formants)./[100 140 200]).^2));
    voice = voice + envelope/harmonic*sin(harmonic*phase+0.01*randn);
end
voice = voice/max(abs(voice));
syllables = max(0, sin(2*pi*1.3*t)).^0.5;
voice = 0.25*voice.*syllables;
x = [zeros(round(0.5*fs), 1); voice; zeros(round(0.2*fs), 1)];
x = x + 0.0001*randn(size(x));
end

function assert_error(action, identifier)
try
    action();
catch problem
    assert(strcmp(problem.identifier, identifier), ...
        'Expected %s, received %s.', identifier, problem.identifier);
    return;
end
error('Expected error %s was not raised.', identifier);
end
