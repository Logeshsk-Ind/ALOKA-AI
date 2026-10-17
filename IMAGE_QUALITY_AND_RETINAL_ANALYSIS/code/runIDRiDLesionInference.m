function [probability,mask] = runIDRiDLesionInference(imagePath,modelPath,threshold)

if nargin < 3
    threshold = 0.20;
end

if ~isfile(imagePath)
    error("Image not found: %s",imagePath);
end

if ~isfile(modelPath)
    error("Model not found: %s",modelPath);
end

S = load(modelPath);

if isfield(S,"trainedUNet")
    net = S.trainedUNet;
elseif isfield(S,"net")
    net = S.net;
else
    names = fieldnames(S);
    found = false;

    for k = 1:numel(names)
        if isa(S.(names{k}),"dlnetwork")
            net = S.(names{k});
            found = true;
            break;
        end
    end

    if ~found
        error("No trained network found in model file.");
    end
end

I = imread(imagePath);

if ndims(I) == 2
    I = repmat(I,1,1,3);
end

if size(I,3) > 3
    I = I(:,:,1:3);
end

I = imresize(I,[224 224]);
I = im2single(I);

Y = predict(net,I);

if isa(Y,"dlarray")
    Y = extractdata(Y);
end

Y = gather(Y);

if ndims(Y) == 4
    Y = Y(:,:,:,1);
end

if ndims(Y) == 3 && size(Y,3) >= 2
    probability = Y(:,:,2);
else
    probability = Y;
end

probability = single(probability);

probability(probability < 0) = 0;
probability(probability > 1) = 1;

mask = probability >= threshold;

mask = logical(mask);

end