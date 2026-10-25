% Enroll five utterances under a speaker's name; repeat for each person.
fs = 16000;
phrase = 'This is my voice for identification.';
folder = fileparts(mfilename('fullpath'));
addpath(folder);
profileFile = fullfile(folder, 'speaker_profiles.mat');
profiles = struct('name', {}, 'features', {}, 'phrase', {}, 'feature_version', {});
if exist(profileFile, 'file')
    saved = load(profileFile, 'profiles');
    if ~isfield(saved, 'profiles') || ~isstruct(saved.profiles) || ...
            ~all(isfield(saved.profiles, {'name', 'features', 'phrase', 'feature_version'}))
        error('speaker:Profiles', 'The speaker profile file is invalid. Restore it before enrolling.');
    end
    profiles = saved.profiles;
    for k = 1:numel(profiles)
        if ~isequal(profiles(k).feature_version, 1) || ~strcmp(profiles(k).phrase, phrase)
            error('speaker:Profiles', 'Existing profiles use another format or phrase. Back them up before starting a new enrollment.');
        end
    end
end
answer = inputdlg('Speaker name:', 'Speaker enrollment', [1 50]);
if isempty(answer)
    return;
end
speakerName = strtrim(answer{1});
if isempty(speakerName) || any(double(speakerName) < 32)
    errordlg('Enter a nonempty speaker name without control characters.', 'Speaker enrollment');
    return;
end
index = find(strcmpi({profiles.name}, speakerName), 1);
if isempty(index)
    index = numel(profiles)+1;
else
    choice = questdlg(sprintf('Replace the existing enrollment for %s?', speakerName), ...
        'Speaker enrollment', 'Replace', 'Cancel', 'Cancel');
    if ~strcmp(choice, 'Replace')
        return;
    end
end

features = zeros(26, 5);
recordings = cell(1, 5);
example = 1;
while example <= 5
    x = record_voice(fs, phrase, sprintf('%s: enrollment %d of 5', speakerName, example));
    if isempty(x)
        disp('Enrollment cancelled. Existing profiles were retained.');
        return;
    end
    try
        features(:, example) = sound_pattern(x, fs);
    catch problem
        if startsWith(problem.identifier, 'speaker:')
            uiwait(warndlg(problem.message, 'Please record again', 'modal'));
            continue;
        end
        rethrow(problem);
    end
    recordings{example} = x;
    example = example+1;
end

recordingFolder = fullfile(folder, 'speaker_recordings', sprintf('speaker_%03d', index));
if ~exist(recordingFolder, 'dir')
    mkdir(recordingFolder);
end
for example = 1:5
    audiowrite(fullfile(recordingFolder, sprintf('sample_%03d.wav', example)), recordings{example}, fs);
end
profiles(index) = struct('name', speakerName, 'features', features, ...
    'phrase', phrase, 'feature_version', 1);
save(profileFile, 'profiles');
message = sprintf('Enrolled speaker: %s\nTotal speakers: %d\n\nEnroll at least two people, then run run_demo.m.', ...
    speakerName, numel(profiles));
fprintf('%s\n', message);
msgbox(message, 'Enrollment saved');
