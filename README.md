# Basic Voice Command Recognition in MATLAB

A beginner project that recognizes **START, STOP and LIGHTS** from short audio recordings, with a simple frequency filter to reduce some background noise.

## Run the demonstration

1. Download or clone this repository.
2. Open its folder in MATLAB and make it the Current Folder.
3. Open **RUN_DEMO.m** and click **Run**.

No extra MATLAB toolboxes are required. The demo uses supplied synthetic speech, so you do not need to speak. Change `testWord = 'start'` to `'stop'` or `'lights'` to try the other commands.

The output is a recognized command and three plots: noisy input, filtered sound, and matching scores. A smaller matching score means a closer match.

## Use your voice

1. Open **TRAIN_MY_VOICE.m** and click Run.
2. Record three examples of each prompted command. Stay quiet until SPEAK NOW.
3. In **RUN_DEMO.m**, change `useMicrophone = false` to `useMicrophone = true`.
4. Run it and speak one of the trained commands when prompted.

Keep microphone placement and speaking style similar to training. The recordings stay in `my_recordings/`, which Git ignores. Training again overwrites those nine recordings.

## Only three code files

| File | Purpose |
|---|---|
| `RUN_DEMO.m` | Load or record audio, compare words and display results |
| `sound_pattern.m` | Basic frequency filtering and a 24-number sound fingerprint |
| `TRAIN_MY_VOICE.m` | Record your nine training examples |

Read **[EXPLANATION.md](EXPLANATION.md)** for a simple walkthrough.

## What was simplified?

This version removes MFCC, Gammatone, PCEN, dynamic time warping, the adaptive controller and the multiple processing modes. It uses a frequency filter and direct comparison of average frequency patterns. The previous advanced version remains in Git history.

The simpler method is less flexible with new speakers, changing noise and speaking speed. It is suitable for learning and a small personalized demonstration, rather than general speech transcription. It identifies the command, not the speaker. It does not control applications yet; a separate action layer could connect recognized commands to software.

## Checks and limits

An independent numerical check matched the supplied START, STOP and LIGHTS test clips with added 10 dB hum/noise. Static syntax checks passed. **The files have not been run in MATLAB here**, because MATLAB was unavailable. Run the demo on your MATLAB installation before presenting it. Synthetic examples do not establish accuracy on human speakers.

The first 0.25 seconds must contain background noise only. Filtering reduces noise outside 200-4000 Hz; noise inside that range remains. The noise estimate is also subtracted from the fingerprint's band powers, not reconstructed as a separately denoised audio waveform. Unknown words may still be incorrectly accepted. Thresholds are initial demonstration settings.
