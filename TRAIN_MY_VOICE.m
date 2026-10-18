% Record three reference utterances per command at 16 kHz.
fs = 16000;
words = {'start', 'stop', 'lights'};
folder = fullfile(fileparts(mfilename('fullpath')), 'my_recordings');
if ~exist(folder, 'dir')
    mkdir(folder);
end
disp('----------------- Training Mode -----------------');
for wordNumber = 1:3
    for example = 1:3
        fprintf('\nPrepare to say %s, example %d of 3.\n', words{wordNumber}, example);
        input('Press Enter when ready.', 's');
        recorder = audiorecorder(fs, 16, 1);
        record(recorder);
        disp('Stay quiet...'); pause(0.5);
        disp('SPEAK NOW'); pause(2);
        stop(recorder);
        recording = getaudiodata(recorder);
        name = sprintf('train_%s_%d.wav', words{wordNumber}, example);
        audiowrite(fullfile(folder, name), recording, fs);
    end
end

disp('----------------- Training Recordings Saved -----------------');
