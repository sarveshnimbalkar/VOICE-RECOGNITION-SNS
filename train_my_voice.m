% Enroll five utterances under a speaker's name; repeat for each person.
fs = 16000;
phrase = 'This is my voice for identification.';
folder = fileparts(mfilename('fullpath'));
addpath(folder);
answer = inputdlg('Speaker name:', 'Speaker enrollment', [1 50]);
if isempty(answer)
    return;
end
speakerName = strtrim(answer{1});
try
    recordingFolder = fullfile(folder, 'speaker_recordings', speaker_folder_name(speakerName));
catch problem
    errordlg(problem.message, 'Speaker enrollment');
    return;
end
if exist(recordingFolder, 'dir')
    metadataFile = fullfile(recordingFolder, 'speaker.json');
    if ~isfile(metadataFile)
        errordlg('This folder already exists without speaker metadata. Preserve it before enrolling.', 'Speaker enrollment');
        return;
    end
    try
        metadata = jsondecode(fileread(metadataFile));
    catch
        errordlg('This speaker folder has invalid metadata. Restore speaker.json before replacing it.', 'Speaker enrollment');
        return;
    end
    if ~isstruct(metadata) || ~isscalar(metadata) || ~isfield(metadata, 'name') || ...
            ~ischar(metadata.name) || ~strcmpi(metadata.name, speakerName)
        errordlg('Another name maps to this folder. Use a more distinct speaker name.', 'Speaker enrollment');
        return;
    end
    choice = questdlg(sprintf('Replace the existing enrollment for %s?', speakerName), ...
        'Speaker enrollment', 'Replace', 'Cancel', 'Cancel');
    if ~strcmp(choice, 'Replace')
        return;
    end
end

recordings = cell(1, 5);
example = 1;
while example <= 5
    x = record_voice(fs, phrase, sprintf('%s: enrollment %d of 5', speakerName, example));
    if isempty(x)
        disp('Enrollment cancelled. Existing recordings were retained.');
        return;
    end
    try
        sound_pattern(x, fs);
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

if ~exist(recordingFolder, 'dir')
    mkdir(recordingFolder);
end
for example = 1:5
    audiowrite(fullfile(recordingFolder, sprintf('sample_%03d.wav', example)), recordings{example}, fs);
end
metadata = struct('name', speakerName, 'phrase', phrase, ...
    'sample_rate', fs, 'feature_version', 1);
writelines(jsonencode(metadata), fullfile(recordingFolder, 'speaker.json'), 'Encoding', 'UTF-8');
profiles = sync_speakers(folder);
message = sprintf('Enrolled speaker: %s\nTotal speakers: %d\n\nEnroll at least two people, then run run_demo.m.', ...
    speakerName, numel(profiles));
fprintf('%s\n', message);
msgbox(message, 'Enrollment saved');
fprintf('Shared recordings: %s\nCommit and push this folder to share the enrollment.\n', recordingFolder);
