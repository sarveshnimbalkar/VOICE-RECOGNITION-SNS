function result = speech_model(action, fileName, featureType)
% SPEECH_MODEL  Simple offline speech-command recognition and DSP plots.
% speech_model('demo')       : supplied synthetic speech; no microphone needed
% speech_model('train')      : record your own START, STOP and LIGHTS templates
% speech_model('live')       : record and recognize one command
% speech_model('file','my.wav') : recognize a 16 kHz WAV with 0.35 s noise lead-in
% speech_model('selftest')   : check reconstruction, gain bounds and DTW
% speech_model('demo','','gammatone') : compare Gammatone-PCEN with MFCC
% Base MATLAB functions only. No Audio/Signal Processing/DL Toolbox required.
% A command recognizer, not arbitrary sentence transcription or speaker ID.

if nargin < 1, action = 'demo'; end
if nargin < 2, fileName = ''; end
if nargin < 3, featureType = 'mfcc'; end
assert(any(strcmp(featureType, {'mfcc','gammatone'})), 'Use mfcc or gammatone.');
c.fs = 16000; c.L = 400; c.H = 160; c.N = 512;
c.calibration = 0.25; c.floor = 0.25; c.kind = featureType;
c.root = fileparts(mfilename('fullpath'));
c.out = fullfile(c.root, 'results');
if ~exist(c.out,'dir'), mkdir(c.out); end
result = [];
switch lower(action)
    case 'demo'
        % The supplied voice is synthesized, not a human evaluation dataset.
        rng(7); labels = {'start','stop','lights'};
        clips = {}; names = {};
        for k = 1:numel(labels)
            for r = 1:3
                p = fullfile(c.root,'demo_audio',sprintf('train_%s_%d.wav',labels{k},r));
                clips{end+1} = readClip(p,c); %#ok<AGROW>
                names{end+1} = labels{k}; %#ok<AGROW>
            end
        end
        model = fitTemplates(clips,names,c);
        save(fullfile(c.out,['demo_model_' c.kind '.mat']),'model');
        truth = {}; condition = {}; prediction = {}; distance = []; snrs = [];
        for k = 1:numel(labels)
            clean = readClip(fullfile(c.root,'demo_audio',['test_' labels{k} '.wav']),c);
            t = (0:numel(clean)-1)'/c.fs;
            v = 0.7*sin(2*pi*120*t) + 0.3*randn(size(t));
            % Whole-file SNR convention, including silence. Same gain both paths.
            v = v*sqrt(sum(clean.^2)/(sum(v.^2)*10^(10/10)));
            noisy = clean+v;
            if max(abs(noisy)) > 0.98
                a = 0.98/max(abs(noisy)); clean = a*clean; noisy = a*noisy;
            end
            modes = {'raw','fixed','adaptive'};
            for q = 1:numel(modes)
                z = classify(noisy,model,c,modes{q});
                truth{end+1,1} = labels{k}; %#ok<AGROW>
                condition{end+1,1} = modes{q}; %#ok<AGROW>
                prediction{end+1,1} = z.label; %#ok<AGROW>
                distance(end+1,1) = z.distance; %#ok<AGROW>
                snrs(end+1,1) = 10*log10(sum(clean.^2)/(sum((z.audio-clean).^2)+eps)); %#ok<AGROW>
                if k == 1 && q == 3
                    showResult(noisy,z,c);
                    audiowrite(fullfile(c.out,'demo_clean.wav'),clean,c.fs);
                    audiowrite(fullfile(c.out,'demo_noisy.wav'),noisy,c.fs);
                    audiowrite(fullfile(c.out,'demo_processed.wav'),z.audio,c.fs);
                    result = z;
                end
            end
        end
        T = table(truth,condition,prediction,distance,snrs, ...
            'VariableNames',{'Expected','Mode','Predicted','DTW_distance','Output_SNR_dB'});
        disp(T); writetable(T,fullfile(c.out,['demo_scores_' c.kind '.csv']));
        % Negative tests: count these separately from spoken command trials.
        silent = classify(zeros(c.fs,1),model,c,'adaptive');
        noise = classify(0.02*randn(2*c.fs,1),model,c,'adaptive');
        fprintf('Silence: %s | Stationary noise: %s\n',silent.label,noise.label);
        fprintf('Demo uses one synthetic voice; these scores are NOT human accuracy.\n');
        fprintf('Plots, audio and CSV saved in: %s\n',c.out);
    case 'train'
        labels = {'start','stop','lights'}; clips = {}; names = {};
        for k = 1:numel(labels)
            for r = 1:3
                clips{end+1} = recordClip(sprintf('%s (example %d/3)',upper(labels{k}),r),c); %#ok<AGROW>
                names{end+1} = labels{k}; %#ok<AGROW>
            end
        end
        model = fitTemplates(clips,names,c);
        save(fullfile(c.root,['my_voice_' c.kind '.mat']),'model');
        fprintf('Saved your voice templates. Next: speech_model(''live'')\n');
    case {'live','file'}
        p = fullfile(c.root,['my_voice_' c.kind '.mat']);
        assert(exist(p,'file')==2,'First run speech_model(''train'') using the same feature type.');
        data = load(p,'model');
        if strcmpi(action,'live')
            x = recordClip('one command: START, STOP or LIGHTS',c);
        else
            assert(~isempty(fileName),'Supply the path to a WAV file.');
            x = readClip(fileName,c);
        end
        result = classify(x,data.model,c,'adaptive');
        showResult(x,result,c);
        audiowrite(fullfile(c.out,'latest_processed.wav'),result.audio,c.fs);
        save(fullfile(c.out,'latest_result.mat'),'result');
        fprintf('Decision: %s | DTW distance: %.3f | gap: %.3f\n', ...
            upper(result.label),result.distance,result.margin);
    case 'selftest'
        rng(42); x = randn(17321,1)*0.1;
        [X,w,n] = analysisSTFT(x,c);
        y = synthesisSTFT(X,w,n,c);
        err = max(abs(x-y)); assert(err < 1e-10,'Overlap-add reconstruction failed.');
        [y,d] = enhance(x,c,'adaptive');
        assert(numel(y)==numel(x) && all(isfinite(y)));
        assert(all(d.gain(:)>=c.floor-1e-12) && all(d.gain(:)<=1+1e-12));
        assert(all(d.mix>=0) && all(d.mix<=0.8+1e-12));
        a = randn(13,24); assert(dtwCost(a,a)<1e-12);
        [~,s] = enhance(zeros(c.fs,1),c,'adaptive'); assert(~any(s.active));
        fprintf('PASS: identity error %.3g; lengths; finite values; bounded gains; DTW; silence.\n',err);
        result = struct('identity_error',err,'passed',true);
    otherwise
        error('Use demo, train, live, file or selftest.');
end
end

function x = readClip(p,c)
[x,fs] = audioread(p);
assert(fs==c.fs,'Use a 16000 Hz WAV. Properly resample it; do not just change its rate label.');
x = mean(x,2); x = checkClip(x,c);
end

function x = checkClip(x,c)
x = double(x(:));
assert(all(isfinite(x)) && numel(x)>=0.5*c.fs && numel(x)<=10*c.fs, ...
    'Audio must be finite and between 0.5 and 10 seconds.');
assert(mean(abs(x)>=0.999)<0.01,'Recording is clipped. Reduce microphone gain and repeat.');
% Deliberately do not normalize silence or quiet recordings to full volume.
end

function x = recordClip(prompt,c)
fprintf('\nPrepare to say %s.\n',prompt); input('Press Enter when ready.','s');
r = audiorecorder(c.fs,16,1); record(r);
fprintf('Stay quiet for calibration...\n'); pause(0.5);
fprintf('SPEAK NOW.\n'); pause(2.0); stop(r);
x = checkClip(getaudiodata(r),c);
end

function [X,w,n] = analysisSTFT(x,c)
% Hamming window has nonzero ends. Explicit normalization recovers boundaries.
n = numel(x); w = 0.54-0.46*cos(2*pi*(0:c.L-1)'/(c.L-1));
M = max(1,ceil((n-c.L)/c.H)+1);
x = [x; zeros((M-1)*c.H+c.L-n,1)];
X = zeros(c.N,M);
for m = 1:M
    ix = (m-1)*c.H+(1:c.L);
    X(:,m) = fft(x(ix).*w,c.N);
end
end

function y = synthesisSTFT(X,w,n,c)
M = size(X,2); y = zeros((M-1)*c.H+c.L,1); weight = y;
for m = 1:M
    ix = (m-1)*c.H+(1:c.L); frame = real(ifft(X(:,m)));
    y(ix) = y(ix)+frame(1:c.L).*w;
    weight(ix) = weight(ix)+w.^2;
end
y = y./max(weight,eps); y = y(1:n);
end

function [y,d] = enhance(x,c,mode)
% Contract: first 0.25 seconds contain only room noise. Required for all clips.
% Subtract calibration DC, not the full-record mean (which can leak speech).
x = x-mean(x(1:round(c.calibration*c.fs)));
[X,w,n] = analysisSTFT(x,c); P = abs(X).^2; M = size(P,2);
cal = max(1,floor((c.calibration*c.fs-c.L)/c.H)+1);
noise = mean(P(:,1:cal),2)+1e-12;
E = sum(P,1)/(c.N*sum(w.^2));
noiseE = max(mean(E(1:cal)),1e-10);
% Simple energy gate; it can mistake impulsive noise or other voices for speech.
active = E>max([3*noiseE,0.015*max(E),1e-8]); active(1:cal)=false;
if sum(active)<8, active(:)=false; end
gain = ones(size(P)); mix = zeros(1,M); previous = ones(c.N,1);
for m = 1:M
    if m>cal && ~active(m)
        noise = 0.95*noise+0.05*P(:,m);
    end
    g = max(c.floor,1-noise./(P(:,m)+1e-12));
    % Symmetric spectrum is retained, so inverse FFT produces real audio.
    g = 0.7*previous+0.3*g; previous=g; gain(:,m)=g;
    proxy = 10*log10(max(sum(P(:,m))/sum(noise)-1,1e-3));
    if strcmp(mode,'raw'), target=0;
    elseif strcmp(mode,'fixed'), target=0.5;
    else, target=min(0.8,max(0,(18-proxy)/20)); end
    if m==1, mix(m)=target; else, mix(m)=0.8*mix(m-1)+0.2*target; end
end
% Mixing aligned STFTs is equivalent to aligned waveform blending with
% window-weighted local strengths. Phase is preserved, with no delay mismatch.
Y = X.*(1-bsxfun(@times,1-gain,mix));
y = synthesisSTFT(Y,w,n,c);
d = struct('X',X,'Y',Y,'gain',gain,'mix',mix,'active',active, ...
    'energy',E,'noiseEnergy',noiseE,'time',((0:M-1)*c.H+c.L/2)/c.fs);
end

function F = features(y,d,c)
% Retain the contiguous detected word plus 30 ms of context on each side.
idx = find(d.active);
if isempty(idx), F=[]; return; end
first = max(1,idx(1)-3); last = min(size(d.X,2),idx(end)+3);
y = filter([1 -0.97],1,y); % pre-emphasis: H(z)=1-0.97 z^-1
[X,~,~] = analysisSTFT(y,c); P = abs(X(1:c.N/2+1,first:last)).^2/c.N;
B = auditoryBank(c); E = B*P;
if strcmp(c.kind,'mfcc')
    A = log(E+1e-10);
else
    % Fixed PCEN parameters: no neural training or learnable filters claimed.
    smoothed = E(:,1); A = zeros(size(E));
    for m = 1:size(E,2)
        smoothed = 0.975*smoothed+0.025*E(:,m);
        A(:,m) = (E(:,m)./(1e-6+smoothed).^0.98+2).^0.5-sqrt(2);
    end
end
% Explicit orthonormal DCT-II; exclude coefficient 0 (overall level).
K = size(B,1); D = sqrt(2/K)*cos(pi*(1:13)'*((0:K-1)+0.5)/K);
F = D*A;
end

function B = auditoryBank(c)
K = 26; f = (0:c.N/2)*c.fs/c.N;
if strcmp(c.kind,'mfcc')
    low=2595*log10(1+80/700); high=2595*log10(1+7600/700);
    points=700*(10.^(linspace(low,high,K+2)/2595)-1);
    B=zeros(K,numel(f));
    for k=1:K
        B(k,:)=max(0,min((f-points(k))/(points(k+1)-points(k)), ...
            (points(k+2)-f)/(points(k+2)-points(k+1))));
        B(k,:)=B(k,:)/max(sum(B(k,:)),eps);
    end
else
    % Actual finite, causal order-4 Gammatone impulse responses on ERB scale.
    erb=linspace(21.4*log10(1+0.00437*100),21.4*log10(1+0.00437*7000),K);
    centers=(10.^(erb/21.4)-1)/0.00437; t=(0:c.N-1)'/c.fs;
    B=zeros(K,numel(f));
    for k=1:K
        b=1.019*24.7*(1+0.00437*centers(k));
        h=t.^3.*exp(-2*pi*b*t).*cos(2*pi*centers(k)*t);
        h=h/max(abs(h)); % avoid tiny t^3 scales before response normalization
        H=abs(fft(h,c.N)).^2; row=H(1:c.N/2+1)';
        B(k,:)=row/max(sum(row),eps);
    end
end
end

function model = fitTemplates(clips,names,c)
% One 15 dB noisy training copy per template teaches the feature scale about
% residual noise. Only enrollment clips are augmented; test clips are unseen.
originalCount=numel(clips);
for k=1:originalCount
    x=clips{k}; t=(0:numel(x)-1)'/c.fs;
    v=0.7*sin(2*pi*120*t)+0.3*randn(size(t));
    v=v*sqrt(sum(x.^2)/(sum(v.^2)*10^(15/10)+eps));
    clips{end+1}=x+v; names{end+1}=names{k};
end
F=cell(size(clips));
for k=1:numel(clips)
    [y,d]=enhance(clips{k},c,'adaptive'); F{k}=features(y,d,c);
    assert(~isempty(F{k}),'No speech in training clip %d. Check calibration and speak again.',k);
end
allFrames=cat(2,F{:}); model.mu=mean(allFrames,2);
model.sigma=max(std(allFrames,0,2),0.05); model.labels=unique(names,'stable');
for k=1:numel(F)
    F{k}=bsxfun(@rdivide,bsxfun(@minus,F{k},model.mu),model.sigma);
end
model.F=F; model.names=names; model.kind=c.kind;
% Leave-one-template-out distance scale. A heuristic, not a calibrated probability.
within=[];
for k=1:numel(F)
    ds=[];
    for j=1:numel(F)
        if j~=k && strcmp(names{j},names{k}), ds(end+1)=dtwCost(F{k},F{j}); end %#ok<AGROW>
    end
    if ~isempty(ds), within(end+1)=min(ds); end %#ok<AGROW>
end
model.threshold=max(0.6,1.8*max(within)); model.minGap=0.04;
end

function z = classify(x,model,c,mode)
tic; x=checkClip(x,c); [y,d]=enhance(x,c,mode); F=features(y,d,c);
z=struct('label','no speech','distance',Inf,'margin',0,'scores', ...
    inf(numel(model.labels),1),'labels',{model.labels},'audio',y,'dsp',d);
if ~isempty(F)
    F=bsxfun(@rdivide,bsxfun(@minus,F,model.mu),model.sigma);
    for k=1:numel(model.F)
        j=find(strcmp(model.labels,model.names{k}));
        z.scores(j)=min(z.scores(j),dtwCost(F,model.F{k}));
    end
    [v,ix]=sort(z.scores); z.distance=v(1);
    z.margin=(v(2)-v(1))/max(v(2),eps);
    if v(1)>model.threshold || z.margin<model.minGap
        z.label='please repeat';
    else, z.label=model.labels{ix(1)}; end
end
z.seconds=toc;
end

function value = dtwCost(A,B)
% Dynamic programming aligns frames said at different speaking speeds.
na=size(A,2); nb=size(B,2); C=inf(na+1,nb+1); C(1,1)=0;
steps=zeros(na+1,nb+1);
for i=1:na
    for j=1:nb
        local=mean((A(:,i)-B(:,j)).^2);
        [previous,k]=min([C(i,j+1),C(i+1,j),C(i,j)]);
        lengths=[steps(i,j+1),steps(i+1,j),steps(i,j)];
        C(i+1,j+1)=local+previous; steps(i+1,j+1)=lengths(k)+1;
    end
end
value=C(end,end)/max(steps(end,end),1);
end

function showResult(x,z,c)
t=(0:numel(x)-1)/c.fs; d=z.dsp; f=(0:c.N/2)*c.fs/c.N;
h=figure('Name','Speech signals and adaptive system','Color','w','Position',[80 80 1100 800]);
subplot(3,2,1); plot(t,x); grid on; title('Input waveform'); xlabel('Time (s)'); ylabel('Amplitude');
subplot(3,2,2); plot(t,z.audio); grid on; title(['Output: ' upper(z.label)]); xlabel('Time (s)'); ylabel('Amplitude');
reference=max(abs(d.X(:)).^2)+eps;
subplot(3,2,3); imagesc(d.time,f,10*log10(abs(d.X(1:c.N/2+1,:)).^2/reference+1e-10));
axis xy; caxis([-80 0]); colorbar; title('Input STFT (common dB reference)'); xlabel('Time (s)'); ylabel('Hz');
subplot(3,2,4); imagesc(d.time,f,10*log10(abs(d.Y(1:c.N/2+1,:)).^2/reference+1e-10));
axis xy; caxis([-80 0]); colorbar; title('Output STFT (common dB reference)'); xlabel('Time (s)'); ylabel('Hz');
subplot(3,2,5); plot(d.time,d.mix,'LineWidth',1.4); hold on; stairs(d.time,double(d.active),'--');
ylim([-0.05 1.1]); grid on; legend('Processing strength','Speech evidence'); xlabel('Time (s)'); title('Adaptive controller');
teo=[0; x(2:end-1).^2-x(1:end-2).*x(3:end); 0];
subplot(3,2,6); plot(t,teo); grid on; title('Teager energy: diagnostic, not denoised audio'); xlabel('Time (s)'); ylabel('Energy operator');
saveas(h,fullfile(c.out,'signal_dashboard.png'));
h=figure('Name','Feature extraction and recognition','Color','w','Position',[110 110 1100 750]);
subplot(2,2,1); B=auditoryBank(c); plot(f,B'); grid on; xlabel('Hz'); ylabel('Weight'); title([c.kind ' analysis filterbank']);
subplot(2,2,2); imagesc(d.time,f,d.gain(1:c.N/2+1,:)); axis xy; caxis([0 1]); colorbar;
title('Time-varying suppression gain'); xlabel('Time (s)'); ylabel('Hz');
F=features(z.audio,d,c); subplot(2,2,3);
if isempty(F), text(0.1,0.5,'No speech features'); axis off;
else, imagesc(F); axis xy; colorbar; xlabel('Selected frame'); ylabel('Coefficient'); title('Cepstral features'); end
subplot(2,2,4); values=z.scores; values(~isfinite(values))=0;
bar(values); set(gca,'XTick',1:numel(z.labels),'XTickLabel',z.labels); ylabel('DTW cost (lower is better)');
title(sprintf('Decision: %s | %.3f s processing',upper(z.label),z.seconds)); grid on;
saveas(h,fullfile(c.out,'recognition_dashboard.png'));
end
