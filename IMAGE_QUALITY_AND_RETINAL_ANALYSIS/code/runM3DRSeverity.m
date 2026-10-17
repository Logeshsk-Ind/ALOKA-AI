function result = runM3DRSeverity()

clc;

fprintf('\n');
fprintf('============================================================\n');
fprintf('              ALOKA-AI M3 DR SEVERITY\n');
fprintf('============================================================\n');

projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));

imageFile = fullfile(projectRoot,'data','test','test_image.png');

modelDir = fullfile(projectRoot,...
    'IMAGE_QUALITY_AND_RETINAL_ANALYSIS',...
    'models');

if ~isfile(imageFile)
    error('Test image not found: %s',imageFile);
end

modelCandidates = {
    fullfile(modelDir,'M3_DR_Classifier.mat')
    fullfile(modelDir,'M3_DR_Severity.mat')
    fullfile(modelDir,'DR_Classifier.mat')
    };

modelFile = '';

for k = 1:numel(modelCandidates)
    if isfile(modelCandidates{k})
        modelFile = modelCandidates{k};
        break;
    end
end

if isempty(modelFile)

    files = dir(fullfile(modelDir,'*.mat'));

    for k = 1:numel(files)

        name = lower(files(k).name);

        if contains(name,'m3') || ...
                contains(name,'classifier') || ...
                contains(name,'severity')

            modelFile = fullfile(modelDir,files(k).name);
            break;
        end
    end
end

if isempty(modelFile)

    fprintf('\n');
    fprintf('M3 MODEL NOT FOUND\n');
    fprintf('------------------------------------------------------------\n');
    fprintf('Expected model directory:\n');
    fprintf('%s\n',modelDir);
    fprintf('\nTrain the M3 DR severity classifier first.\n');
    fprintf('============================================================\n');

    result = struct;
    result.Status = 'MODEL_NOT_FOUND';

    return;
end

fprintf('Model                 : %s\n',modelFile);

S = load(modelFile);

names = fieldnames(S);

net = [];

for k = 1:numel(names)

    candidate = S.(names{k});

    if isa(candidate,'dlnetwork') || ...
            isa(candidate,'SeriesNetwork') || ...
            isa(candidate,'DAGNetwork')

        net = candidate;
        break;
    end
end

if isempty(net)

    fprintf('\nNo supported neural network variable was found.\n');
    fprintf('Variables in MAT file:\n');

    for k = 1:numel(names)
        fprintf('  %s\n',names{k});
    end

    error('Unable to locate trained M3 network.');
end

I = imread(imageFile);

if size(I,3) == 1
    I = repmat(I,[1 1 3]);
end

I = im2single(I);

inputSize = [];

if isa(net,'dlnetwork')

    try
        inputSize = net.Layers(1).InputSize;
    catch
        inputSize = [224 224 3];
    end

else

    try
        inputSize = net.Layers(1).InputSize;
    catch
        inputSize = [224 224 3];
    end

end

if isempty(inputSize)
    inputSize = [224 224 3];
end

I = imresize(I,inputSize(1:2));

classNames = [
    "No_DR"
    "Mild"
    "Moderate"
    "Severe"
    "Proliferative_DR"
    ];

if isa(net,'dlnetwork')

    scores = predict(net,I);

    scores = gather(extractdata(scores));

else

    scores = predict(net,I);

end

scores = squeeze(scores);

if isrow(scores)
    scores = scores';
end

scores = double(scores);

if numel(scores) ~= 5

    error('M3 classifier returned %d outputs. Expected 5 DR classes.',numel(scores));

end

scores = scores(:);

if any(scores < 0) || abs(sum(scores)-1) > 0.05

    scores = softmax(scores);

else

    scores = scores / sum(scores);

end

[confidence,index] = max(scores);

severity = index - 1;

if severity >= 2
    screening = 'REFERABLE DR';
    recommendation = 'Refer to ophthalmologist.';
else
    screening = 'NON-REFERABLE DR';
    recommendation = 'Routine follow-up according to clinical protocol.';
end

result = struct;

result.ImagePath = imageFile;
result.ModelPath = modelFile;
result.PredictedClass = char(classNames(index));
result.SeverityLevel = severity;
result.Confidence = confidence;
result.ClassProbabilities = scores;
result.Screening = screening;
result.Recommendation = recommendation;

fprintf('\n');
fprintf('Prediction            : %s\n',classNames(index));
fprintf('Severity Level        : %d\n',severity);
fprintf('Confidence            : %.2f %%\n',confidence*100);
fprintf('Screening             : %s\n',screening);
fprintf('Recommendation        : %s\n',recommendation);

fprintf('\nClass probabilities:\n');

for k = 1:5
    fprintf('  %-20s %.2f %%\n',classNames(k),scores(k)*100);
end

resultDir = fullfile(projectRoot,...
    'IMAGE_QUALITY_AND_RETINAL_ANALYSIS',...
    'results',...
    'M3_DR_Severity');

if ~exist(resultDir,'dir')
    mkdir(resultDir);
end

save(fullfile(resultDir,'M3_DR_Result.mat'),'result');

fprintf('\nResult saved:\n');
fprintf('%s\n',fullfile(resultDir,'M3_DR_Result.mat'));

fprintf('============================================================\n');

end