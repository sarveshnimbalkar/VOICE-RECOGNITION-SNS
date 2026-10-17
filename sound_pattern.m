function [pattern, filteredSound] = sound_pattern(x, fs)
% Turn a sound into 24 numbers that describe its frequency content.
% This is a basic word fingerprint, not a speech-to-text neural network.

x = mean(x, 2);                    % Convert stereo to one channel
sampleCount = length(x);
fftSize = 2^nextpow2(sampleCount);  % Convenient size for the Fourier transform
frequency = (0:fftSize-1)' * fs / fftSize;

% Keep 200 to 4000 Hz, plus the matching negative-frequency part.
% This reduces low hum and high-frequency noise; it cannot remove all noise.
spectrum = fft(x, fftSize);
keep = (frequency >= 200 & frequency <= 4000) | ...
       (frequency >= fs-4000 & frequency <= fs-200);
spectrum(~keep) = 0;
filteredSound = real(ifft(spectrum));
filteredSound = filteredSound(1:sampleCount);

% Estimate background frequency power from the first quiet 0.25 seconds.
noise = x(1:round(0.25*fs));
noisePower = abs(fft(noise, fftSize)).^2 / length(noise);
soundPower = abs(spectrum).^2 / sampleCount;

% Divide the useful range into 24 bands and measure power in each band.
edges = linspace(200, 4000, 25);
pattern = zeros(24, 1);
for band = 1:24
    bins = frequency >= edges(band) & frequency < edges(band+1);
    speechPower = mean(soundPower(bins)) - mean(noisePower(bins));
    pattern(band) = log(max(speechPower, 1e-10));
end

% Remove the average level and scale the pattern for fair comparison.
pattern = pattern - mean(pattern);
pattern = pattern / max(sqrt(sum(pattern.^2)), eps);
end
