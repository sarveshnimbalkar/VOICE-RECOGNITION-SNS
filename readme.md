# Speaker Identification Using MFCC Features in MATLAB

An academic signals and systems mini-project that identifies **which enrolled person is speaking**. Each speaker supplies five recordings of a common phrase. The system extracts mel-frequency cepstral coefficients (MFCCs), builds a spectral profile for each person, and compares a new recording with the enrolled profiles.

## Objective and Scope

The project implements a **text-dependent, closed-set speaker identification** baseline: every participant repeats the same phrase, and the system selects the closest enrolled speaker. Enrollment accepts any display name and supports adding people without editing the source code.

This version replaces the earlier START/STOP/LIGHTS command classifier. The output is a person's enrolled name. It does not transcribe speech, verify a claimed identity, or reliably detect an unregistered speaker.

## Requirements

- MATLAB with audio I/O, plotting, and standard numerical operations. Automated pipeline checks were run in MATLAB R2026a.
- No additional MATLAB toolboxes are required; the MFCC filter bank and cosine transform are implemented directly.
- A working microphone and microphone permission for live enrollment and identification.
- At least **two different people**, with five enrollment recordings each.

## Enrollment

1. Open the repository folder in MATLAB and make it the Current Folder.
2. Run `train_my_voice.m` and enter the first speaker's name.
3. For each of the five recordings, click **Record**, remain quiet during the initial interval, and read the displayed phrase after **SPEAK NOW**:

   > This is my voice for identification.

4. Repeat `train_my_voice.m` for each additional person using a different name.

Each recording includes 0.5 seconds of background followed by a four-second speaking interval. Use a natural, consistent voice and complete the phrase within the speaking interval. Enrollment requests another recording if it detects insufficient speech. Cancelling an incomplete enrollment retains the existing profiles.

Re-entering an existing name, ignoring letter case, offers to replace that person's enrollment. Names are stored as labels; recording folders use numeric identifiers, so display names do not become file paths.

## Identification

Run `run_demo.m` and choose an input:

| Input | Procedure |
|---|---|
| **Microphone** | Click Record and read the same phrase after the visible SPEAK NOW cue. |
| **WAV file** | Select a new 16 kHz recording of the same phrase, with at least 0.25 seconds of initial background audio. |

Use a fresh recording for testing rather than an enrollment file. The result appears in a **Speaker identification result** dialog and in the Command Window. The figure shows the input waveform, the selected speech frames' MFCCs, and a distance for each speaker. Smaller distances indicate closer matches.

If the two best scores are too similar, the interface displays **Uncertain match** and the closest enrolled name. This ambiguity check does not constitute unknown-speaker rejection. A person who was never enrolled may still receive an enrolled person's name.

## Signal Processing Method

1. **Preprocessing:** Convert multichannel audio to mono, remove the sample mean, and apply an FFT-domain mask retaining 80–7600 Hz and its negative-frequency counterpart.
2. **Frame selection:** Form 25 ms frames at 10 ms intervals. Select frames whose mean-square energy exceeds the maximum of four times the initial background power, 1% of the maximum frame power, and a small absolute floor. Require at least 0.5 seconds of selected frames.
3. **MFCC extraction:** Apply pre-emphasis with coefficient 0.97, a Hamming window, a 512-point FFT, 26 triangular mel filters, logarithmic compression, and a discrete cosine transform. Retain coefficients 1–13, excluding coefficient zero.
4. **Utterance representation:** Concatenate the temporal mean and standard deviation of the 13 coefficients to obtain a 26-dimensional descriptor.
5. **Enrollment:** Store five descriptors per person. Their mean defines the speaker centroid.
6. **Classification:** Compare the test descriptor with each centroid using mean squared distance after coordinate scaling learned only from enrollment descriptors. The scale floor is 0.5.

For test descriptor **p**, speaker centroid **c** and enrollment-derived scale **s**, the class distance is:

$$d(\mathbf{p},\mathbf{c})=\frac{1}{26}\sum_{b=1}^{26}\left(\frac{p_b-c_b}{s_b}\right)^2$$

The ambiguity margin is $(d_2-d_1)/\max(d_2,\varepsilon)$, where $d_1$ and $d_2$ are the smallest class distances. A margin below 0.10 produces the uncertain result. The threshold is an initial heuristic; distances and margins are not identity confidence probabilities.

MFCCs are also used in the [MathWorks speaker identification example](https://www.mathworks.com/help/audio/ug/speaker-identification-using-pitch-and-mfcc.html). This project uses its own mean/std descriptor and nearest-centroid implementation rather than that example's toolbox-based classifier.

## Validation and Example Figure

![MATLAB synthetic pipeline check showing a speech-like waveform, MFCCs, and distances to two synthetic profiles](docs/images/speaker_validation.png)

*Figure 1. MATLAB output for a generated speech-like signal and two synthetic profiles. This checks feature extraction, scoring, and plotting. It is not a human speaker identification result.*

Run the automated checks from the project folder:

```matlab
addpath('tests');
test_speaker_identification;
```

The checks cover synthetic profiles with separate test realizations, gain invariance, mono/row/stereo inputs, WAV import, silence, stationary noise, insufficient audio, unsupported sample rates, invalid profiles, and tied scores. To regenerate Figure 1:

```matlab
test_speaker_identification(fullfile(pwd, 'docs', 'images'));
```

**Human identification accuracy has not been measured.** Collect separate enrollment and test sessions from multiple people, keep the phrase and equipment consistent initially, and report a confusion matrix and per-speaker results before making accuracy claims. Test unregistered speakers separately if developing an unknown-speaker rejection rule.

## Repository Structure

| Path | Purpose |
|---|---|
| `train_my_voice.m` | Named speaker enrollment and local profile storage |
| `run_demo.m` | Live or file-based identification and result presentation |
| `record_voice.m` | Shared recording dialog with visible quiet/speak cues |
| `sound_pattern.m` | Speech frame selection and MFCC descriptor extraction |
| `identify_speaker.m` | Profile validation, normalized distances, and ambiguity handling |
| `tests/test_speaker_identification.m` | Automated synthetic and input-validation checks |
| `speaker_profiles.mat` | Local speaker names and feature templates; ignored by Git |
| `speaker_recordings/` | Local enrollment WAV files; ignored by Git |
| `docs/images/speaker_validation.png` | Synthetic pipeline validation figure |

The earlier `demo_audio/` command clips, `my_recordings/` command recordings, and command-result images are legacy artifacts. They have no verified multi-speaker labels and are not loaded by this system. New speaker enrollment is required.

## Limitations

- MFCC statistics also reflect the phrase, microphone, noise, and room acoustics. This baseline assumes the same phrase and similar conditions for enrollment and testing.
- Averaging features loses temporal detail and limits discrimination between similar voices.
- The energy gate does not establish that a signal is human speech; sudden noise can pass it.
- The system selects among enrolled people and has no calibrated absolute rejection threshold for unregistered speakers.
- It does not include replay detection or spoofing resistance and is not intended as an authentication mechanism.
- Speaker names, recordings, and feature templates remain local and are excluded from version control.
