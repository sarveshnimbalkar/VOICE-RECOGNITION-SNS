# Project explanation: Voice Recognition using Signals and Systems

## What does our project do?

Our project listens to a short command, reduces background noise, and identifies the command. It currently recognizes **START, STOP and LIGHTS**.

For example, you say START while a fan is running. The system records both your voice and the fan, estimates the background noise, reduces some of it, compares your speech with stored examples, and displays START.

Here, recognition means **what command was spoken**. It does not identify who is speaking or understand an unrestricted conversation.

## Why is this useful?

People can use voice commands as an alternative to clicking buttons or typing. A future integration could connect START to playing a video, STOP to pausing it, or LIGHTS to a connected device. The current model produces recognition decisions and signal outputs. It does **not** launch software, switch physical lights, or control appliances yet. Those actions need an additional software or hardware connection.

## What goes in and what comes out?

**Input:** one short spoken command recorded by a microphone or stored as a WAV file, with a brief background-only calibration interval.

**Outputs:** the recognized command, a processed audio signal, and graphs showing how the signal changed. If there is too little speech evidence, it reports `no speech`. If the match is weak or ambiguous, it reports `please repeat`.

## How it works, in everyday language

### 1. Listen to the room first

Before speaking, stay quiet during calibration. The system hears the room's fan, hum or other background sound. It uses the first 0.25 seconds to estimate that background noise. For microphone recording, it displays SPEAK NOW after approximately 0.5 seconds.

This is like learning what the room sounds like before trying to hear a person in it.

### 2. Break the recording into small pieces

Speech changes quickly. Instead of analyzing the entire recording at once, the model examines overlapping 25 millisecond pieces. It advances by 10 milliseconds each time.

At 16,000 samples per second, each piece contains 400 samples and each advance contains 160 samples.

### 3. See which frequencies are present

Each sound contains a mixture of frequencies. A Fourier transform separates the mixture into frequency components. Repeating this over the short pieces produces a spectrogram: a picture showing which frequencies occur at which times.

The Hamming window softens each piece's edges to reduce unwanted spectral leakage.

### 4. Reduce likely background noise

The system compares the current frequency content with the estimated background. It lowers components likely to be noise. It uses a nonzero minimum gain so it does not simply delete every weak component.

Noise reduction is imperfect because voice and noise can occupy the same frequencies.

### 5. Adjust the amount of processing

Strong processing can damage useful speech details. The model preserves an original-audio path and blends it with the processed path. Its simple controller generally uses more suppression when the estimated conditions are noisier.

This controller is a hand-written rule. It is not a trained neural network or a proven best setting for every room.

### 6. Rebuild the sound

The model converts the processed frequency components back into audio and joins the overlapping pieces. It corrects for the window overlap so the reconstructed waveform has the expected length and amplitude behavior.

### 7. Make a compact description of the word

The default feature extractor produces **MFCCs**. Think of these as a compact description of the sound's shape, rather than a saved list of every audio sample. They describe patterns related to speech resonances.

MFCC processing uses a hearing-inspired Mel filterbank, logarithms and a cosine transform. The model keeps 13 coefficients per selected frame.

An optional **Gammatone-PCEN** mode uses a different hearing-inspired filterbank and a normalization method that adapts to energy changes. Both versions use fixed mathematical parameters; neither is a learnable frontend.

### 8. Compare it with known examples

During enrollment, you record three examples each of START, STOP and LIGHTS. The system also makes a noisy training copy of each example, giving eighteen feature templates from nine recordings.

It compares a new word against those templates using **dynamic time warping (DTW)**. DTW allows the same word to be spoken a little faster or slower. Lower distance means a closer match.

### 9. Decide whether the match is strong enough

The system checks both the best match's distance and how clearly it beats the next-best command. It accepts a label when both tests pass, otherwise it asks for a repeat.

These thresholds are prototype settings, not percentages of confidence. Unknown words can still be mistaken for known commands.

## Where the code implements each stage

| MATLAB function | Responsibility |
|---|---|
| `speech_model` | Select demo, train, live, file or self-test mode |
| `readClip` / `checkClip` | Read audio and check sample rate, duration, finite values and clipping |
| `recordClip` | Record microphone audio with calibration instructions |
| `analysisSTFT` | Window overlapping frames and compute FFTs |
| `enhance` | Estimate noise, detect energy-based speech evidence, suppress noise and blend paths |
| `synthesisSTFT` | Inverse FFT and normalized overlap-add |
| `auditoryBank` | Build Mel or Gammatone frequency weights |
| `features` | Extract compact cepstral feature sequences |
| `fitTemplates` | Fit training normalization, templates and a provisional rejection threshold |
| `dtwCost` | Align and compare sequences of different durations |
| `classify` | Choose a command or return a rejection decision |
| `showResult` | Display and save signal and recognition plots |

All helper functions are in `speech_model.m` so the project is easy to move as one main code file.

## What do the graphs mean?

| Graph | Explanation |
|---|---|
| Input waveform | The recorded sound before enhancement |
| Output waveform | The sound after processing |
| Input/output spectrograms | Frequency content over time, displayed with a common scale |
| Adaptive strength | How much processing the controller applies |
| Speech evidence | Where the energy heuristic thinks the word is present |
| Teager energy | A diagnostic sensitive to local amplitude and frequency changes; not guaranteed noise removal |
| Analysis filterbank | Which frequency regions contribute to the features |
| Suppression gain | How strongly each frequency component is attenuated over time |
| Cepstral features | The compact sound pattern compared with templates |
| DTW bars | Distances to each command; smaller is better |

## Connection to Signals and Systems

- **Sampling:** converts microphone sound into discrete values at 16 kHz.
- **Windowing and STFT:** examine how frequency content changes with time.
- **Power spectra:** support background-noise estimation.
- **Filtering:** changes frequency components to reduce interference.
- **Impulse/frequency response:** explain the pre-emphasis filter and auditory analysis filters.
- **Inverse transforms and overlap-add:** reconstruct processed audio.
- **Adaptive systems:** change processing strength according to measured input conditions.

For example, the pre-emphasis filter has impulse response `h = [1, -0.97]` and transfer function `H(z) = 1 - 0.97*z^-1`. The entire recognizer is adaptive and nonlinear, so it should not be described as one linear time-invariant system.

## How to demonstrate it

### Demonstration without speaking

Open `RUN_DEMO.m` in MATLAB, set the repository folder as the Current Folder and click Run. It checks reconstruction, fits templates from supplied speech clips, adds noise to separate test clips and displays results.

The included voice is synthetic speech, supplied for a repeatable demonstration. It is not a human-speaker accuracy dataset.

### Demonstration using your voice

Before the presentation, run:

```matlab
speech_model('train');
```

Record the nine requested examples. Wait for SPEAK NOW each time. During the presentation, run:

```matlab
result = speech_model('live');
```

Say one of the trained commands when prompted. The saved model avoids repeating training for every trial. Keep microphone placement reasonably similar to enrollment.

## What has been tested?

The MATLAB files passed a static syntax check. An independent numerical implementation passed reconstruction, finite-output, signal-length, bounded-gain and DTW checks. It correctly recognized three held-out synthetic commands across three processing modes and two feature modes: eighteen condition/feature trials based on only three distinct test utterances. Tested silence and stationary noise returned `no speech`.

For those mixtures, adaptive processing increased whole-file signal-to-noise ratio from 10 dB to approximately 14.8-15.0 dB. All three processing modes recognized the commands after training augmentation, so this does not prove that adaptation improves recognition accuracy.

**MATLAB was not installed in the preparation environment. Native MATLAB execution and live microphone operation remain to be checked locally.** Details and limits are in `VERIFICATION.md`. Supplied files prefixed `reference_` are numerical reference outputs, not MATLAB screenshots or MATLAB execution results.

## Limitations and possible extensions

The current version recognizes isolated enrolled commands. It requires a brief background-only interval, and can fail with very quiet speech, sudden noise, another speaker, unknown words or substantially different microphones and rooms.

Useful extensions include more command recordings, independent human testing, a stronger speech detector and an action layer for a selected application. The source text's proposed fractional-transform neural architecture would require a separate training implementation and dataset; it is not implemented here.

## A short explanation for a presentation

“Our project recognizes spoken commands in noisy environments. It first estimates background noise, reduces some of that noise, and extracts a compact pattern from the speech. It compares the pattern with trained examples and displays the recognized command. The graphs show the original sound, processed sound and recognition results. A future action layer could use the recognized command to operate an application.”
