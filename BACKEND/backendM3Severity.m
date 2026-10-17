function result = backendM3Severity(imagePath)

root = fileparts(fileparts(mfilename('fullpath')));;

modelPath = fullfile(root,...
    'IMAGE_QUALITY_AND_RETINAL_ANALYSIS',...
    'models',...
    'M3_DR_Classifier.mat');

if ~isfile(modelPath)
    error('M3 model not found: %s',modelPath);
end

S = load(modelPath);

net = [];

vars = fieldnames(S);

for k = 1:numel(vars)
    value = S.(vars{k});

    if isa(value,'dlnetwork') || ...
       isa(value,'SeriesNetwork') || ...
       isa(value,'DAGNetwork')

        net = value;
        break;
    end
end

if isempty(net)
    error('No supported M3 network found.');
end

I = imread(imagePath);

if ndims(I) == 2
    I = repmat(I,[1 1 3]);
end

if size(I,3) > 3
    I = I(:,:,1:3);
end

inputSize = [224 224 3];

try
    if isa(net,'dlnetwork')
        layers = net.Layers;

        for k = 1:numel(layers)
            if isa(layers(k),'nnet.cnn.layer.ImageInputLayer')
                inputSize = layers(k).InputSize;
                break;
            end
        end
    else
        inputSize = net.Layers(1).InputSize;
    end
catch
end

I = im2single(imresize(I,inputSize(1:2)));

if isa(net,'dlnetwork')

    try
        dlX = dlarray(I,'SSC');
        scores = predict(net,dlX);
    catch
        try
            dlX = dlarray(I,'SSCB');
            scores = predict(net,dlX);
        catch
            scores = predict(net,I);
        end
    end

else

    scores = predict(net,I);

end

scores = gather(extractdata(scores));
scores = squeeze(scores);

if isempty(scores)
    error('M3 returned empty prediction.');
end

scores = double(scores(:));

if any(~isfinite(scores))
    error('M3 returned invalid prediction values.');
end

if any(scores < 0) || sum(scores) <= 0 || abs(sum(scores)-1) > 0.05
    scores = exp(scores-max(scores));
    scores = scores/sum(scores);
else
    scores = scores/sum(scores);
end

canonical = {'No_DR','Mild','Moderate','Severe','Proliferative_DR'};

classNames = {};

try
    for k = 1:numel(net.Layers)
        layer = net.Layers(k);

        if isprop(layer,'Classes')
            c = layer.Classes;

            if ~isempty(c)
                if iscategorical(c)
                    classNames = cellstr(c);
                elseif isstring(c)
                    classNames = cellstr(c);
                elseif iscell(c)
                    classNames = c;
                end
            end
        end
    end
catch
end

if numel(classNames) ~= numel(scores)

    classNames = {'Mild','Moderate','No_DR','Proliferative_DR','Severe'};

end

classNames = normalizeNames(classNames);

if numel(classNames) ~= numel(scores)
    classNames = canonical(1:min(numel(canonical),numel(scores)));
end

[~,idx] = max(scores);

predicted = classNames{idx};

severityOrder = {'No_DR','Mild','Moderate','Severe','Proliferative_DR'};

severityIndex = find(strcmp(severityOrder,predicted),1)-1;

if isempty(severityIndex)
    severityIndex = 0;
end

canonicalProb = zeros(1,5);

for k = 1:numel(classNames)
    p = find(strcmp(canonical,classNames{k}),1);

    if ~isempty(p) && k <= numel(scores)
        canonicalProb(p) = scores(k);
    end
end

confidence = max(scores)*100;

referrable = severityIndex >= 2;

if referrable
    screening = 'REFERABLE DR';
else
    screening = 'NON-REFERABLE DR';
end

result = struct();

result.ModelPath = modelPath;
result.ModelClassNames = classNames;
result.RawProbabilities = scores;
result.Probabilities = canonicalProb;

result.Grade = predicted;
result.Severity = predicted;
result.Confidence = confidence;
result.Referrable = referrable;
result.Screening = screening;
result.SeverityIndex = severityIndex;

end

function names = normalizeNames(names)

for k = 1:numel(names)

    n = char(string(names{k}));

    n = strrep(n,' ','_');
    n = strrep(n,'-','_');

    low = lower(n);

    if contains(low,'no') && contains(low,'dr')
        names{k} = 'No_DR';
    elseif contains(low,'mild')
        names{k} = 'Mild';
    elseif contains(low,'moderate')
        names{k} = 'Moderate';
    elseif contains(low,'severe')
        names{k} = 'Severe';
    elseif contains(low,'prolifer')
        names{k} = 'Proliferative_DR';
    else
        names{k} = n;
    end
end

end