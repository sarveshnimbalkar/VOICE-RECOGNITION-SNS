function [pattern, filteredSound] = sound_pattern(x, fs)
% Return a normalized 24-band log-power descriptor and filtered audio.

x = mean(x, 2);
sampleCount = length(x);
fftSize = 2^nextpow2(sampleCount);
frequency = (0:fftSize-1)' * fs / fftSize;

% Retain conjugate frequency bands to preserve a real-valued waveform.
spectrum = fft(x, fftSize);
keep = (frequency >= 200 & frequency <= 4000) | ...
       (frequency >= fs-4000 & frequency <= fs-200);
spectrum(~keep) = 0;
filteredSound = real(ifft(spectrum));
filteredSound = filteredSound(1:sampleCount);

% Estimate background power from the initial quiet 0.25 s.
noise = x(1:round(0.25*fs));
noisePower = abs(fft(noise, fftSize)).^2 / length(noise);
soundPower = abs(spectrum).^2 / sampleCount;

edges = linspace(200, 4000, 25);
pattern = zeros(24, 1);
for band = 1:24
    bins = frequency >= edges(band) & frequency < edges(band+1);
    speechPower = mean(soundPower(bins)) - mean(noisePower(bins));
    pattern(band) = log(max(speechPower, 1e-10));
end

pattern = pattern - mean(pattern);
pattern = pattern / max(sqrt(sum(pattern.^2)), eps);
end
