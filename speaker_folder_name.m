function folderName = speaker_folder_name(name)
% Convert a display name to a lowercase speaker folder without path separators.
if ~ischar(name) || isempty(strtrim(name)) || any(double(name) < 32)
    error('speaker:Name', 'Enter a nonempty speaker name without control characters.');
end
slug = lower(strtrim(name));
slug(~isstrprop(slug, 'alphanum')) = '_';
slug = regexprep(slug, '_+', '_');
slug = regexprep(slug, '^_|_$', '');
if isempty(slug)
    error('speaker:Name', 'Include at least one letter or number in the speaker name.');
end
folderName = ['speaker_' slug];
end
