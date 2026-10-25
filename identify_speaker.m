function [result, filteredSound, details] = identify_speaker(x, fs, profiles)
% Compare an utterance with enrolled speaker centroids in scaled MFCC space.

if ~isstruct(profiles) || numel(profiles) < 2
    error('speaker:Enrollment', 'Enroll at least two different people using train_my_voice.m.');
end
required = {'name', 'features', 'phrase', 'feature_version'};
if ~all(isfield(profiles, required))
    error('speaker:Profiles', 'Invalid speaker profiles. Enroll the speakers again.');
end
names = cell(1, numel(profiles));
allFeatures = [];
for k = 1:numel(profiles)
    p = profiles(k);
    if ~ischar(p.name) || isempty(strtrim(p.name)) || ...
            ~ischar(p.phrase) || ~strcmp(p.phrase, profiles(1).phrase) || ...
            ~isequal(p.feature_version, 1) || ~isnumeric(p.features) || ...
            ~isreal(p.features) || size(p.features, 1) ~= 26 || ...
            size(p.features, 2) < 5 || any(~isfinite(p.features(:)))
        error('speaker:Profiles', 'Invalid or incompatible profile. Enroll every speaker again.');
    end
    names{k} = p.name;
    allFeatures = [allFeatures p.features]; %#ok<AGROW>
end
if numel(unique(lower(string(names)))) ~= numel(names)
    error('speaker:Profiles', 'Speaker names must be unique.');
end

[pattern, filteredSound, details] = sound_pattern(x, fs);
% Learn feature scales from enrollment only; the floor limits unstable weights.
scale = max(std(allFeatures, 0, 2), 0.5);
scores = zeros(1, numel(profiles));
for k = 1:numel(profiles)
    centroid = mean(profiles(k).features, 2);
    scores(k) = mean(((pattern-centroid)./scale).^2);
end
[ordered, positions] = sort(scores);
result.name = names{positions(1)};
result.names = names;
result.scores = scores;
result.margin = (ordered(2)-ordered(1))/max(ordered(2), eps);
result.uncertain = result.margin < 0.10;
result.phrase = profiles(1).phrase;
end
