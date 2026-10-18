# Simple project explanation

## What are we making?

A small MATLAB program that recognizes three spoken commands: **START, STOP and LIGHTS**. It reduces some background noise and shows the recognized word with graphs.

Example: you say START with a fan running. The program removes some low-frequency hum, compares your sound with saved examples, and displays START if that is the closest clear match.

## The whole idea

**Get sound -> reduce some noise -> make a sound pattern -> compare with examples -> display a word.**

## 1. Get a recording

The demonstration uses supplied WAV files. It adds hum and random noise so you can see what filtering does. For a live demonstration, the microphone records your voice instead.

`fs = 16000` means that one second of audio is represented by 16,000 sample values. `x` is the list of those values.

## 2. Reduce some background noise

`fft` shows how much of each frequency is present. The code keeps frequencies from 200 to 4000 Hz and removes frequencies outside that range. This can reduce low hum and high-frequency noise, although it also removes some useful speech information.

The FFT of real audio contains matching positive and negative frequency parts, so the code keeps both. `ifft` converts the remaining frequencies back into a sound waveform.

This is a basic frequency filter. It cannot separate every kind of noise from speech, especially another person talking in the same frequency range. Abrupt frequency cutoffs can also cause ringing.

## 3. Make a frequency fingerprint

Split the 200-4000 Hz range into 24 equal bands. Measure the average sound power in each band. This gives 24 numbers describing the overall frequency pattern of the word.

During the first quiet 0.25 seconds, the recording contains background noise. The code estimates its power in the same bands and subtracts that estimate from the fingerprint values. This affects recognition features; the plotted output waveform comes from the frequency filter.

`log` compresses large differences in power. Subtracting the pattern's mean and dividing by its size make comparison less sensitive to overall volume. These operations do not teach the model a language.

## 4. Compare with known words

We store three examples each of START, STOP and LIGHTS. For each saved example:

```matlab
difference = sum((pattern - savedPattern).^2);
```

In plain language: subtract the two lists of 24 numbers, square each difference, and add them. A smaller result means the patterns are closer. The program keeps the best example for each word.

A whole-word average loses the order of speech sounds. Two words with similar overall frequency content can therefore be confused. This is the main tradeoff for keeping the code short and easy to understand.

## 5. Choose a result

The word with the smallest score is the candidate. If its score is too high, or too close to the runner-up, the program says PLEASE REPEAT.

A separate volume check compares the full recording with the initial background interval. If there is not enough extra energy, it says NO SPEECH DETECTED. This is a simple energy check, not a reliable speech detector for every environment. Sudden noise can trigger it, and quiet speech can be missed.

The thresholds in the code are starting values for a demonstration. They are not confidence percentages and need separate development recordings to tune.

## What the graphs show

1. **Original sound:** the noisy recording.
2. **Filtered sound:** the result after removing frequencies outside the selected range.
3. **Matching scores:** how different the input is from each command. Smaller is better.

## How to present it

First run RUN_DEMO.m without a microphone. Change `testWord` to try each of the three words. Explain the two waveforms and the three matching scores.

For a personal live demonstration, train beforehand with TRAIN_MY_VOICE.m. Then set `useMicrophone = true` in RUN_DEMO.m. Stay quiet until SPEAK NOW appears, then say one command. Use the same microphone and a similar speaking distance.

## What we can honestly claim

“We made a basic MATLAB program that recognizes three trained commands. It uses frequency filtering to reduce some noise and compares simple frequency patterns to identify the word.”

It is not unrestricted speech-to-text, speaker identification, or a system that automatically understands every voice. The simple code does not operate other applications yet. That would need extra code mapping an accepted command to an application action.

## How we checked it

The simplified numerical method matched three supplied synthetic test words with added hum/noise. This is a small demonstration, not a human-speaker accuracy result. Example microphone runs in MATLAB R2026a produced STOP and LIGHTS outputs; screenshots are included in the README. These examples do not establish accuracy on unseen recordings or speakers.
