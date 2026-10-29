% Save five enrollment recordings in speaker_recordings/speaker_<name>.
fs = 16000;
phrase = 'This is my voice for identification.';
folder = fileparts(mfilename('fullpath'));
addpath(folder);
answer = inputdlg('Speaker name:', 'Speaker enrollment', [1 50]);
if isempty(answer)
    return;
end
speakerName = strtrim(answer{1});
slug = lower(speakerName);
slug(~isstrprop(slug, 'alphanum')) = '_';
slug = regexprep(slug, '_+', '_');
slug = regexprep(slug, '^_|_$', '');
if isempty(slug) || any(double(speakerName) < 32)
    errordlg('Enter a speaker name containing letters or numbers.', 'Speaker enrollment');
    return;
end
recordingFolder = fullfile(folder, 'speaker_recordings', ['speaker_' slug]);
if exist(recordingFolder, 'dir')
    choice = questdlg(sprintf('Replace the five recordings in speaker_%s?', slug), ...
        'Speaker enrollment', 'Replace', 'Cancel', 'Cancel');
    if ~strcmp(choice, 'Replace')
        return;
    end
end

recordings = cell(1, 5);
example = 1;
while example <= 5
    x = record_voice(fs, phrase, sprintf('%s: recording %d of 5', speakerName, example));
    if isempty(x)
        return;
    end
    try
        sound_pattern(x, fs);
    catch problem
        uiwait(warndlg(problem.message, 'Please record again', 'modal'));
        continue;
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
message = sprintf('Saved five recordings for %s.\n\nCommit and push this speaker folder to share it.', speakerName);
fprintf('%s\nFolder: %s\n', message, recordingFolder);
msgbox(message, 'Enrollment saved');
