function profiles = sync_speakers(folder)
% Rebuild the local feature cache from shared WAV recordings and speaker metadata.
if nargin == 0
    folder = fileparts(mfilename('fullpath'));
end
phrase = 'This is my voice for identification.';
profiles = struct('name', {}, 'features', {}, 'phrase', {}, 'feature_version', {});
recordingRoot = fullfile(folder, 'speaker_recordings');
speakers = dir(fullfile(recordingRoot, 'speaker_*'));
speakers = speakers([speakers.isdir]);
for k = 1:numel(speakers)
    recordingFolder = fullfile(recordingRoot, speakers(k).name);
    metadataFile = fullfile(recordingFolder, 'speaker.json');
    if ~isfile(metadataFile)
        error('speaker:Metadata', 'Missing speaker.json in %s. Use named enrollment folders from train_my_voice.m.', speakers(k).name);
    end
    try
        metadata = jsondecode(fileread(metadataFile));
    catch
        error('speaker:Metadata', 'Invalid speaker.json in %s.', speakers(k).name);
    end
    required = {'name', 'phrase', 'sample_rate', 'feature_version'};
    if ~isstruct(metadata) || ~isscalar(metadata) || ~all(isfield(metadata, required)) || ...
            ~ischar(metadata.name) || ~ischar(metadata.phrase) || ...
            ~strcmp(metadata.phrase, phrase) || ~isequal(metadata.sample_rate, 16000) || ...
            ~isequal(metadata.feature_version, 1)
        error('speaker:Metadata', 'Incompatible speaker metadata in %s.', speakers(k).name);
    end
    if ~strcmp(speaker_folder_name(metadata.name), speakers(k).name)
        error('speaker:Metadata', 'The folder %s does not match its speaker name.', speakers(k).name);
    end
    if any(strcmpi({profiles.name}, metadata.name))
        error('speaker:Metadata', 'Duplicate speaker name: %s.', metadata.name);
    end
    features = zeros(26, 5);
    for example = 1:5
        filename = fullfile(recordingFolder, sprintf('sample_%03d.wav', example));
        if ~isfile(filename)
            error('speaker:Samples', 'Missing sample_%03d.wav for %s. Pull all five enrollment samples.', example, metadata.name);
        end
        try
            [x, fs] = audioread(filename);
            features(:, example) = sound_pattern(x, fs);
        catch problem
            error('speaker:Samples', 'Cannot use %s: %s', filename, problem.message);
        end
    end
    profiles(k) = struct('name', metadata.name, 'features', features, ...
        'phrase', metadata.phrase, 'feature_version', metadata.feature_version);
end
% Save only after every shared profile has been validated successfully.
save(fullfile(folder, 'speaker_profiles.mat'), 'profiles');
end
