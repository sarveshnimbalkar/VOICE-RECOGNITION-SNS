function x = record_voice(fs, phrase, titleText)
% Capture an utterance with visible quiet/speak cues; closing the window cancels.

x = [];
choice = questdlg(sprintf('Read this phrase when prompted:\n\n%s', phrase), ...
    titleText, 'Record', 'Cancel', 'Record');
if ~strcmp(choice, 'Record')
    return;
end
statusWindow = dialog('Name', titleText, 'Position', [300 300 540 200]);
statusText = uicontrol(statusWindow, 'Style', 'text', 'Position', [20 35 500 140], ...
    'FontSize', 15, 'String', 'Stay quiet...');
recorder = audiorecorder(fs, 16, 1);
cleanup = onCleanup(@() finish_recording(recorder, statusWindow));
drawnow;
record(recorder);
pause(0.5);
if ~isgraphics(statusWindow)
    return;
end
set(statusText, 'String', sprintf('SPEAK NOW\n\n%s\n\nRecording for 4 seconds...', phrase));
drawnow;
pause(4);
stop(recorder);
if isgraphics(statusWindow)
    x = getaudiodata(recorder);
end
end

function finish_recording(recorder, statusWindow)
if isrecording(recorder)
    stop(recorder);
end
if isgraphics(statusWindow)
    delete(statusWindow);
end
end
