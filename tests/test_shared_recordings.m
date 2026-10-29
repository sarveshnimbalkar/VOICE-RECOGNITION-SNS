function test_shared_recordings
% Simulate separate collaborators exchanging named speaker folders.
firstClone = tempname;
secondClone = tempname;
mkdir(firstClone); mkdir(secondClone);
cleanup = onCleanup(@() remove_clones(firstClone, secondClone));
assert(strcmp(speaker_folder_name(' Arnav Deshpande '), 'speaker_arnav_deshpande'));
assert(strcmp(speaker_folder_name('Alice / Smith'), 'speaker_alice_smith'));
assert_error(@() speaker_folder_name('...'), 'speaker:Name');
assert_error(@() speaker_folder_name(''), 'speaker:Name');

write_enrollment(firstClone, 'Alice Smith', 1);
write_enrollment(secondClone, 'Bob Jones', 2);
firstProfiles = sync_speakers(firstClone);
secondProfiles = sync_speakers(secondClone);
assert(isscalar(firstProfiles) && strcmp(firstProfiles.name, 'Alice Smith'));
assert(isscalar(secondProfiles) && strcmp(secondProfiles.name, 'Bob Jones'));
copyfile(fullfile(secondClone, 'speaker_recordings', 'speaker_bob_jones'), ...
    fullfile(firstClone, 'speaker_recordings', 'speaker_bob_jones'));
profiles = sync_speakers(firstClone);
assert(isequal({profiles.name}, {'Alice Smith', 'Bob Jones'}));
assert(isequal(profiles(1).features, firstProfiles.features));
for speaker = 1:2
    result = identify_speaker(test_voice(speaker, 99), 16000, profiles);
    assert(strcmp(result.name, profiles(speaker).name) && ~result.uncertain);
end

% The shared files, not an outdated MAT cache, define the next identification run.
profiles(1).name = 'Stale cache';
save(fullfile(firstClone, 'speaker_profiles.mat'), 'profiles');
profiles = sync_speakers(firstClone);
assert(strcmp(profiles(1).name, 'Alice Smith'));
metadataFile = fullfile(firstClone, 'speaker_recordings', 'speaker_bob_jones', 'speaker.json');
originalMetadata = fileread(metadataFile);
writelines('{broken json', metadataFile);
assert_error(@() sync_speakers(firstClone), 'speaker:Metadata');
cache = load(fullfile(firstClone, 'speaker_profiles.mat'), 'profiles');
assert(isequal(cache.profiles, profiles), 'A failed sync must retain the last good cache.');
writelines(originalMetadata, metadataFile);
sampleFile = fullfile(firstClone, 'speaker_recordings', 'speaker_bob_jones', 'sample_005.wav');
delete(sampleFile);
assert_error(@() sync_speakers(firstClone), 'speaker:Samples');
audiowrite(sampleFile, test_voice(2, 5), 8000);
assert_error(@() sync_speakers(firstClone), 'speaker:Samples');
audiowrite(sampleFile, test_voice(2, 5), 16000);
metadata = jsondecode(originalMetadata); metadata.phrase = 'A different phrase';
writelines(jsonencode(metadata), metadataFile);
assert_error(@() sync_speakers(firstClone), 'speaker:Metadata');
writelines(originalMetadata, metadataFile);
profiles = sync_speakers(firstClone);
assert(numel(profiles)==2);
rmdir(fullfile(firstClone, 'speaker_recordings', 'speaker_bob_jones'), 's');
profiles = sync_speakers(firstClone);
assert(isscalar(profiles) && strcmp(profiles.name, 'Alice Smith'));
fprintf('PASS: named folders, two-clone sharing, combined identification, cache rebuilding, and invalid shared samples.\n');
end

function write_enrollment(folder, name, speaker)
recordingFolder = fullfile(folder, 'speaker_recordings', speaker_folder_name(name));
mkdir(recordingFolder);
for example = 1:5
    audiowrite(fullfile(recordingFolder, sprintf('sample_%03d.wav', example)), test_voice(speaker, example), 16000);
end
metadata = struct('name', name, 'phrase', 'This is my voice for identification.', ...
    'sample_rate', 16000, 'feature_version', 1);
writelines(jsonencode(metadata), fullfile(recordingFolder, 'speaker.json'), 'Encoding', 'UTF-8');
end

function x = test_voice(speaker, seed)
rng(seed);
fs = 16000; t = (0:2*fs-1)'/fs;
f0 = 120+90*speaker;
voice = 0.15*sin(2*pi*f0*t)+0.07*sin(2*pi*(3*f0+15)*t);
voice = voice.*(0.6+0.4*sin(2*pi*2*t).^2);
x = [zeros(fs/2,1); voice; zeros(fs/4,1)];
x = x+0.0001*randn(size(x));
end

function assert_error(action, identifier)
try
    action();
catch problem
    assert(strcmp(problem.identifier, identifier), 'Unexpected error: %s', problem.identifier);
    return;
end
error('Expected error %s was not raised.', identifier);
end

function remove_clones(firstClone, secondClone)
rmdir(firstClone, 's');
rmdir(secondClone, 's');
end
