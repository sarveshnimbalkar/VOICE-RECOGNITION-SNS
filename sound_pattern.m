function [pattern, filteredSound, details] = sound_pattern(x, fs)
% Summarize speech with the mean and standard deviation of 13 MFCCs.

if fs ~= 16000
    error('speaker:SampleRate', 'Audio must be recorded at 16000 Hz.');
end
if ~isnumeric(x) || ~isreal(x) || isempty(x) || ~ismatrix(x) || any(~isfinite(x(:)))
    error('speaker:InvalidAudio', 'Audio must contain finite, real sample values.');
end
if isvector(x)
    x = x(:);
else
    x = mean(x, 2);
end
if length(x) < round(0.75*fs)
    error('speaker:ShortAudio', 'Record at least 0.75 seconds, including initial silence.');
end
x = double(x);
x = x - mean(x);

fftSize = 2^nextpow2(length(x));
frequency = (0:fftSize-1)' * fs / fftSize;
spectrum = fft(x, fftSize);
keep = (frequency >= 80 & frequency <= 7600) | ...
       (frequency >= fs-7600 & frequency <= fs-80);
spectrum(~keep) = 0;
filteredSound = real(ifft(spectrum));
filteredSound = filteredSound(1:length(x));

frameLength = round(0.025*fs);
hopLength = round(0.010*fs);
starts = 1:hopLength:(length(x)-frameLength+1);
indices = (0:frameLength-1)' + starts;
frames = filteredSound(indices);
energy = mean(frames.^2, 1);
% The first 0.25 s must contain background only, including in imported files.
background = filteredSound(1:round(0.25*fs));
threshold = max([4*mean(background.^2), 0.01*max(energy), 1e-8]);
speechFrames = energy > threshold;
if sum(speechFrames)*hopLength/fs < 0.5
    error('speaker:NoSpeech', 'Insufficient speech. Stay quiet first, then speak clearly for several seconds.');
end

emphasized = filter([1 -0.97], 1, filteredSound);
window = 0.54 - 0.46*cos(2*pi*(0:frameLength-1)'/(frameLength-1));
frames = emphasized(indices(:, speechFrames)) .* window;
frameFftSize = 512;
powerSpectrum = abs(fft(frames, frameFftSize)).^2 / frameFftSize;
powerSpectrum = powerSpectrum(1:frameFftSize/2+1, :);

melEdges = linspace(2595*log10(1+80/700), 2595*log10(1+7600/700), 28);
hzEdges = 700*(10.^(melEdges/2595)-1);
hz = (0:frameFftSize/2) * fs/frameFftSize;
filterBank = zeros(26, length(hz));
for band = 1:26
    rising = (hz-hzEdges(band))/(hzEdges(band+1)-hzEdges(band));
    falling = (hzEdges(band+2)-hz)/(hzEdges(band+2)-hzEdges(band+1));
    filterBank(band, :) = max(0, min(rising, falling));
end
logPower = log(max(filterBank*powerSpectrum, 1e-12));
% Exclude coefficient zero to reduce sensitivity to overall recording level.
dctBasis = sqrt(2/26)*cos(pi*(1:13)'*((0:25)+0.5)/26);
cepstra = dctBasis*logPower;
pattern = [mean(cepstra, 2); std(cepstra, 0, 2)];
details.cepstra = cepstra;
details.frame_times = (starts(speechFrames)-1+frameLength/2)/fs;
details.speech_seconds = sum(speechFrames)*hopLength/fs;
end
