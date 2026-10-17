function result = runM2TrainingSilent(imageDir,labelDir,modelPath)

if nargin < 3
    error('imageDir, labelDir and modelPath are required.');
end

if ~isfolder(imageDir)
    error('Image directory not found.');
end

if ~isfolder(labelDir)
    error('Label directory not found.');
end

imageFiles = [dir(fullfile(imageDir,'*.png')); ...
    dir(fullfile(imageDir,'*.jpg')); ...
    dir(fullfile(imageDir,'*.jpeg'))];

if isempty(imageFiles)
    error('No training images found.');
end

imds = imageDatastore(imageDir);

classNames = ["background","lesion"];
labelIDs = [0 1];

pxds = pixelLabelDatastore(labelDir,classNames,labelIDs);

trainingData = combine(imds,pxds);

inputSize = [224 224 3];

numClasses = 2;

lgraph = unetLayers(inputSize,numClasses);

options = trainingOptions('adam', ...
    'InitialLearnRate',1e-3, ...
    'MaxEpochs',30, ...
    'MiniBatchSize',4, ...
    'Shuffle','every-epoch', ...
    'Verbose',false, ...
    'Plots','none');

net = trainNetwork(trainingData,lgraph,options);

save(modelPath,'net','-v7.3');

result = struct();
result.ModelPath = modelPath;
result.Images = numel(imageFiles);
result.Status = 'TRAINING_COMPLETE';

end
