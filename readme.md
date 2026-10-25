# Speaker Identification Using MFCC Features in MATLAB

An academic signals and systems mini-project that identifies **which enrolled person is speaking**. Each speaker supplies five recordings of a common phrase. The system extracts mel-frequency cepstral coefficients (MFCCs), builds a spectral profile for each person, and compares a new recording with the enrolled profiles.

## Objective and Scope

The project implements a **text-dependent, closed-set speaker identification** baseline: every participant repeats the same phrase, and the system selects the closest enrolled speaker. Enrollment accepts any display name and supports adding people without editing the source code.

The output is a person's enrolled name, such as **Identified speaker: Arnav**. The common phrase keeps the spoken content approximately consistent so that profiles can be compared under similar conditions. The system does not transcribe speech, verify a claimed identity, or reliably detect an unregistered speaker.

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

## Signals and Systems Interpretation

The microphone converts acoustic pressure into an electrical signal, and the audio interface samples and quantizes it. The program then transforms that discrete-time waveform into a compact feature vector and uses the vector to select an enrolled speaker.

| Stage | Signals and systems concept | Role in this project |
|---|---|---|
| Audio acquisition | Sampling and quantization | Represent speech as a discrete-time signal at 16 kHz |
| Frequency selection | DFT, frequency response, and convolution | Retain the selected frequency band |
| Frame selection | Local mean-square power and thresholding | Exclude low-energy background intervals |
| Pre-emphasis | First-order FIR filtering | Reduce the dominance of low-frequency components |
| Windowed FFT | Short-time analysis and spectral leakage | Estimate changing speech spectra over short intervals |
| Mel filter bank | Weighted spectral power measurements | Summarize the spectral envelope in 26 bands |
| Logarithm and DCT | Nonlinear compression and transform-domain representation | Form 13 cepstral features per selected frame |
| Statistical pooling and matching | Feature statistics and minimum-distance classification | Compare a new recording with named speaker profiles |

### 1. Speech as a source–filter system

Over a short interval, speech can be approximated as an excitation signal passing through the vocal tract:

$$x[n] \approx (e*h_v)[n]+v[n]$$

Here, $e[n]$ represents vocal excitation, $h_v[n]$ represents the vocal tract's impulse response for that interval, $v[n]$ represents recording noise, and $*$ denotes convolution. The corresponding frequency-domain approximation is:

$$X(e^{j\omega}) \approx E(e^{j\omega})H_v(e^{j\omega})+V(e^{j\omega})$$

Vocal tract resonances shape the spectral envelope. Differences between speakers can therefore appear in features describing that envelope. Articulation also changes the envelope, which is why this baseline asks everyone to repeat the same phrase. Speech is not globally time invariant; the short-interval approximation motivates framing. The [MathWorks speaker identification example](https://www.mathworks.com/help/audio/ug/speaker-identification-using-pitch-and-mfcc.html) discusses this source–filter interpretation.

The implementation does not explicitly estimate $e[n]$, $h_v[n]$, formant frequencies, or pitch. It uses MFCC statistics as a practical spectral representation.

### 2. Sampling and quantization

The sampled signal is $x[n]=x_a(nT_s)$, with $f_s=1/T_s=16000$ Hz and $T_s=62.5$ microseconds. The Nyquist frequency is 8 kHz. Frequencies above that limit must be controlled by the recording system's anti-aliasing filter; a later digital filter cannot undo aliasing that has already occurred.

Live recording uses 16-bit quantization. The program accepts 16 kHz audio files and rejects other sample rates rather than silently changing their interpretation. Stereo channels are averaged, and the finite recording's sample mean is removed to reduce DC offset.

**Implementation:** `record_voice.m` and `sound_pattern.m`.

### 3. Frequency-domain filtering

The program zero-pads the full recording to a power-of-two transform length $N$ and computes its DFT. A real, symmetric frequency mask retains 80–7600 Hz and the corresponding negative-frequency bins:

$$Y[k]=H[k]X[k],\qquad y[n]=\operatorname{IDFT}_N\{Y[k]\}$$

The retained negative-frequency bins preserve conjugate symmetry, so the inverse transform remains real apart from numerical round-off. By the DFT convolution property, multiplication by $H[k]$ corresponds to **circular convolution** with $h_N[n]=\operatorname{IDFT}_N\{H[k]\}$ at that transform length. The output is then truncated to the original recording length.

This is finite-record, offline spectral filtering. Its abrupt cutoff may introduce ringing and boundary effects; it is not a designed causal streaming band-pass filter. It suppresses out-of-band components but cannot separate a speaker from noise or another voice occupying the retained band.

**Implementation:** `sound_pattern.m`.

### 4. Short-time power and speech frame selection

Speech changes over time, so the filtered signal is divided into frames of $L=400$ samples (25 ms), with hop size $R=160$ samples (10 ms). Adjacent frames overlap by 240 samples, or 60%. Their local mean-square power is:

$$P_m=\frac{1}{L}\sum_{r=0}^{L-1}y^2[mR+r]$$

The first 0.25 seconds provide the background-power estimate $P_b$. A frame is selected when:

$$P_m>\max\left(4P_b,\;0.01\max_j P_j,\;10^{-8}\right)$$

The recording must contribute at least 0.5 seconds measured as the number of selected frames multiplied by the hop duration. This is an approximate activity-duration measure because frames overlap.

Power thresholding prevents quiet intervals from dominating the feature statistics. It is an energy gate, not proof that a frame contains speech: sudden noise may also pass the threshold. The initial interval must contain background only.

**Implementation:** `sound_pattern.m`.

### 5. Pre-emphasis, windowing, and the short-time spectrum

Before feature extraction, the filtered waveform passes through a first-order FIR pre-emphasis filter:

$$u[n]=y[n]-0.97y[n-1],\qquad H_p(z)=1-0.97z^{-1}$$

Its impulse response is $h_p[n]=\delta[n]-0.97\delta[n-1]$. This linear time-invariant operation attenuates slowly varying components relative to higher frequencies. It changes spectral balance; it does not identify a person by itself.

Each selected frame is multiplied by a Hamming window:

$$w[r]=0.54-0.46\cos\left(\frac{2\pi r}{L-1}\right),\qquad 0\le r<L$$

The tapered edges reduce spectral leakage relative to abrupt rectangular truncation, at the cost of a wider main lobe. A 512-point FFT then estimates the windowed frame spectrum:

$$U_m[k]=\sum_{r=0}^{L-1}u[mR+r]w[r]e^{-j2\pi kr/512}$$

The FFT bin spacing is $16000/512=31.25$ Hz. Zero-padding from 400 to 512 samples produces a denser frequency grid; it does not increase the underlying resolving power set by frame duration and window shape. The implementation uses $|U_m[k]|^2/512$ as its power-spectrum values and retains the nonnegative-frequency bins for feature extraction.

**Implementation:** `sound_pattern.m`.

### 6. Mel bands, logarithmic compression, and MFCCs

The positive-frequency power spectrum is summarized using 26 triangular filters spaced on the mel scale between 80 and 7600 Hz:

$$\operatorname{mel}(f)=2595\log_{10}\left(1+\frac{f}{700}\right)$$

For triangular weight function $B_b[k]$, the band measurement and compressed value are:

$$E_b[m]=\sum_k B_b[k]\frac{|U_m[k]|^2}{512},\qquad \ell_b[m]=\ln\left(\max(E_b[m],10^{-12})\right)$$

The bands summarize spectral shape with finer spacing at lower frequencies. The logarithm compresses the dynamic range. Ignoring additive noise, the logarithm of a source–filter spectral product becomes a sum; this motivates cepstral descriptions but does not perfectly separate speaker identity from phonetic content or the recording channel.

A discrete cosine transform maps the 26 log-band values to cepstral coefficients:

$$c_q[m]=\sqrt{\frac{2}{26}}\sum_{b=0}^{25}\ell_b[m]\cos\left[\frac{\pi q(b+1/2)}{26}\right],\qquad q=1,\ldots,13$$

The code retains coefficients 1–13 and omits coefficient zero. Omitting the constant component reduces sensitivity to a uniform change in log-band level, such as recording gain when flooring and frame selection do not change. MFCCs still vary with the phrase, microphone, and environment. The [MATLAB MFCC documentation](https://www.mathworks.com/help/audio/ref/mfcc.html) provides additional background; this project implements its filter bank and transform directly and does not call the toolbox `mfcc` function.

**Implementation:** `sound_pattern.m`.

### 7. Speaker profiles from feature statistics

For each utterance, the temporal mean and sample standard deviation of each retained coefficient are concatenated:

$$\mathbf{p}=[\mu_1,\ldots,\mu_{13},\sigma_1,\ldots,\sigma_{13}]^T$$

The result is a 26-dimensional descriptor. Means summarize typical cepstral shape, while standard deviations summarize its variation across selected frames. This statistical pooling converts a variable-length recording into a fixed-length vector, while discarding the detailed order of its sounds.

Enrollment stores five utterance descriptors for each person. Their average defines that speaker's centroid $\mathbf{c}_s$. The standard deviation of each coordinate across **all enrollment descriptors** provides its scale, with a minimum value of 0.5 to prevent small enrollment variation from creating excessively large weights. Test recordings are not used to estimate these scales.

**Implementation:** `train_my_voice.m`, `sound_pattern.m`, and `identify_speaker.m`.

### 8. Minimum-distance speaker identification

For test descriptor $\mathbf{p}$, speaker centroid $\mathbf{c}_s$, and coordinate scales $a_b$, the matching score is:

$$d_s=\frac{1}{26}\sum_{b=1}^{26}\left(\frac{p_b-c_{s,b}}{a_b}\right)^2$$

The identified name is attached to the centroid with the smallest distance. Scaling prevents coordinates with larger numerical variation from automatically dominating the comparison.

Let $d_1$ and $d_2$ be the smallest two scores. The relative separation is:

$$g=\frac{d_2-d_1}{\max(d_2,\varepsilon)}$$

If $g<0.10$, the interface reports **Uncertain match** and asks the user to repeat. Otherwise, it displays the selected name. The margin is a heuristic separation measure, not a calibrated probability or an absolute identity test. An unregistered person's voice can still be closest to an enrolled profile.

Filtering and transforms produce the features; the final minimum-distance decision assigns the speaker label. The complete pipeline is **not** an LTI system: logarithms, data-dependent frame selection, statistical normalization, and classification introduce nonlinear or adaptive operations.

**Implementation:** `identify_speaker.m` and `run_demo.m`.

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

The `demo_audio/` and `my_recordings/` directories and older result images are legacy assets, not the speaker enrollment dataset. They have no verified multi-speaker labels and are not loaded by this system. Enroll each participant afresh using `train_my_voice.m`.

## Limitations

- MFCC statistics also reflect the phrase, microphone, noise, and room acoustics. This baseline assumes the same phrase and similar conditions for enrollment and testing.
- Averaging features loses temporal detail and limits discrimination between similar voices.
- The energy gate does not establish that a signal is human speech; sudden noise can pass it.
- The system selects among enrolled people and has no calibrated absolute rejection threshold for unregistered speakers.
- It does not include replay detection or spoofing resistance and is not intended as an authentication mechanism.
- Speaker names, recordings, and feature templates remain local and are excluded from version control.
