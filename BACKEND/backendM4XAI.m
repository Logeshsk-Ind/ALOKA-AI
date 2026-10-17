function result = backendM4XAI(imagePath,m3)

root = fileparts(fileparts(mfilename('fullpath')));

modelPath = fullfile(root,'models','M3_DR_Classifier.mat');

outDir = fullfile(root,'results','ALOKA_AI_XAI');

if ~exist(outDir,'dir')
    mkdir(outDir);
end

if ~isfile(modelPath)
    error('M3 classifier model not found: %s',modelPath);
end

if ~isfile(imagePath)
    error('Input image not found: %s',imagePath);
end

S = load(modelPath);

net = [];

vars = fieldnames(S);

for k = 1:numel(vars)
    value = S.(vars{k});

    if isa(value,'dlnetwork') || isa(value,'SeriesNetwork') || isa(value,'DAGNetwork')
        net = value;
        break;
    end
end

if isempty(net)
    error('No supported neural network found in M3_DR_Classifier.mat.');
end

I = imread(imagePath);

if ndims(I) == 2
    I = repmat(I,[1 1 3]);
end

if size(I,3) > 3
    I = I(:,:,1:3);
end

original = I;

inputSize = [224 224 3];

try
    if isa(net,'dlnetwork')
        layers = net.Layers;
    else
        layers = net.Layers;
    end

    for k = 1:numel(layers)
        if isa(layers(k),'nnet.cnn.layer.ImageInputLayer')
            inputSize = layers(k).InputSize;
            break;
        end
    end
catch
end

X = im2single(imresize(I,inputSize(1:2)));

classIndex = 1;

if isfield(m3,'ModelClassNames')
    names = string(m3.ModelClassNames);
    idx = find(strcmpi(names,string(m3.Grade)),1);

    if ~isempty(idx)
        classIndex = idx;
    end
end

scoreMap = [];
method = 'Unavailable';
layerName = '';

if isa(net,'dlnetwork')

    try
        layers = net.Layers;

        candidateLayers = {};

        for k = 1:numel(layers)
            layer = layers(k);

            if isa(layer,'nnet.cnn.layer.ReLULayer') || ...
               isa(layer,'nnet.cnn.layer.Convolution2DLayer')

                candidateLayers{end+1} = layer.Name;
            end
        end

        for k = numel(candidateLayers):-1:1
            try
                map = gradCAM(net,X,classIndex,'FeatureLayer',candidateLayers{k});

                map = gather(extractdata(map));
                map = squeeze(map);

                if ~isempty(map) && any(isfinite(map(:)))
                    scoreMap = map;
                    layerName = candidateLayers{k};
                    method = 'Grad-CAM';
                    break;
                end
            catch
            end
        end
    catch
    end

elseif isa(net,'SeriesNetwork') || isa(net,'DAGNetwork')

    try
        predictedClass = m3.Grade;

        layers = net.Layers;
        candidateLayers = {};

        for k = 1:numel(layers)
            layer = layers(k);

            if isa(layer,'nnet.cnn.layer.ReLULayer') || ...
               isa(layer,'nnet.cnn.layer.Convolution2DLayer')

                candidateLayers{end+1} = layer.Name;
            end
        end

        for k = numel(candidateLayers):-1:1
            try
                map = gradCAM(net,X,predictedClass,'FeatureLayer',candidateLayers{k});

                map = gather(extractdata(map));
                map = squeeze(map);

                if ~isempty(map) && any(isfinite(map(:)))
                    scoreMap = map;
                    layerName = candidateLayers{k};
                    method = 'Grad-CAM';
                    break;
                end
            catch
            end
        end
    catch
    end
end

if isempty(scoreMap)
    try
        if isa(net,'dlnetwork')

            dlX = dlarray(X,'SSCB');

            Y = forward(net,dlX);
            Y = Y(:);

            classIndex = min(classIndex,numel(Y));

            score = Y(classIndex);

            grad = dlfeval(@inputGradient,net,dlX,score);

            grad = abs(gather(extractdata(grad)));
            grad = squeeze(grad);

            if ndims(grad) == 3
                scoreMap = max(grad,[],3);
            elseif ismatrix(grad)
                scoreMap = grad;
            end

            if ~isempty(scoreMap)
                scoreMap = mat2gray(scoreMap);
                method = 'Gradient Saliency';
                layerName = 'input';
            end
        end
    catch
    end
end

attentionPath = '';
overlayPath = '';
heatmapPath = '';

if ~isempty(scoreMap)

    scoreMap = imresize(scoreMap,[size(original,1) size(original,2)]);
    scoreMap = mat2gray(scoreMap);

    attentionPath = fullfile(outDir,'XAI_AttentionMap.png');
    heatmapPath = fullfile(outDir,'XAI_Heatmap.png');
    overlayPath = fullfile(outDir,'XAI_Overlay.png');

    imwrite(scoreMap,attentionPath);

    heat = ind2rgb(uint8(scoreMap*255),jet(256));

    imwrite(heat,heatmapPath);

    base = im2double(original);

    if size(base,3) == 1
        base = repmat(base,[1 1 3]);
    end

    overlay = 0.55*base + 0.45*heat;

    overlay = min(max(overlay,0),1);

    imwrite(im2uint8(overlay),overlayPath);

    figure('Visible','off');

    imshow(original);

    hold on;

    h = imagesc(scoreMap);

    colormap(jet(256));

    set(h,'AlphaData',0.45);

    axis image off;

    exportgraphics(gca,overlayPath,'Resolution',200);

    close(gcf);
end

result = struct();

result.Available = ~isempty(scoreMap);
result.Method = method;
result.Layer = layerName;
result.AttentionMap = scoreMap;
result.AttentionMapPath = attentionPath;
result.HeatmapPath = heatmapPath;
result.OverlayPath = overlayPath;
result.ModelPath = modelPath;
result.ClassIndex = classIndex;
result.PredictedClass = m3.Grade;
result.OutputDirectory = outDir;

end

function grad = inputGradient(net,dlX,score)

grad = dlgradient(score,dlX);

end