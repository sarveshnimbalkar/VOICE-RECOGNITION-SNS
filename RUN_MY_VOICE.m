% Record three examples each of START, STOP and LIGHTS, then try a new command.
% Keep quiet until SPEAK NOW appears for every recording.
speech_model('train');
result = speech_model('live');
% After this first run, use speech_model('live') to test more commands.
