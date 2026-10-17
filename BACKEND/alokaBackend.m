function result = alokaBackend(imagePath)

% ============================================================
% ALOKA-AI CENTRAL BACKEND
%
% Master project:
%     D:\ALOKA_AI_FINAL
%
% Models:
%     D:\ALOKA_AI_FINAL\models
%
% Pipeline:
%     M1 - Image Quality
%     M2 - Lesion Segmentation
%     M3 - DR Severity
%     M4 - Explainable AI
%     M5 - Telemedicine availability
%     M6 - Retinal Structure Analysis
% ============================================================

root = fileparts(fileparts(mfilename('fullpath')));

modelDir = fullfile(root,'models');

if nargin < 1 || isempty(imagePath)
    error('Image path required.');
end

if ~isfile(imagePath)
    error('Input image does not exist: %s',imagePath);
end

if ~isfolder(modelDir)
    error('Model directory not found: %s',modelDir);
end

addpath(genpath(root));

result = struct();

result.ImagePath = imagePath;

result.ProjectRoot = root;

result.ModelDirectory = modelDir;


%% ============================================================
% M1 - IMAGE QUALITY
% =============================================================

fprintf('\n');
fprintf('========================================\n');
fprintf(' M1 - IMAGE QUALITY\n');
fprintf('========================================\n');

try

    q = runImageQualityWorkflow(imagePath);

    result.M1 = q;

    fprintf('M1 completed successfully.\n');

catch ME

    result.M1 = struct( ...
        'Status',"ERROR", ...
        'Message',ME.message);

    fprintf('M1 ERROR: %s\n',ME.message);

end


%% ============================================================
% M2 - LESION SEGMENTATION
% =============================================================

fprintf('\n');
fprintf('========================================\n');
fprintf(' M2 - LESION SEGMENTATION\n');
fprintf('========================================\n');

models = {
    'MA','M2_MA_U-Net.mat'
    'HE','M2_HE_U-Net.mat'
    'EX','M2_EX_U-Net.mat'
    'SE','M2_SE_U-Net.mat'
};

result.M2 = struct();

for k = 1:size(models,1)

    lesionName = models{k,1};
    modelName = models{k,2};

    modelPath = fullfile( ...
        modelDir, ...
        modelName);

    fprintf('\n');
    fprintf('%s\n',lesionName);
    fprintf('Model: %s\n',modelPath);

    try

        if ~isfile(modelPath)

            error( ...
                'Model not found: %s', ...
                modelPath);

        end

        [p,m] = ...
            runIDRiDLesionInference( ...
            imagePath, ...
            modelPath, ...
            0.20);

        result.M2.(lesionName).Probability = p;

        result.M2.(lesionName).Mask = m;

        result.M2.(lesionName).Detected = ...
            any(m(:));

        result.M2.(lesionName).AreaPercent = ...
            100*nnz(m)/numel(m);

        result.M2.(lesionName).Model = ...
            modelPath;

        result.M2.(lesionName).Status = ...
            "OK";

        fprintf( ...
            '%s completed. Probability = %.4f\n', ...
            lesionName,p);

        fprintf( ...
            'Area = %.4f %%\n', ...
            result.M2.(lesionName).AreaPercent);

    catch ME

        result.M2.(lesionName).Probability = NaN;

        result.M2.(lesionName).Mask = [];

        result.M2.(lesionName).Detected = false;

        result.M2.(lesionName).AreaPercent = NaN;

        result.M2.(lesionName).Model = ...
            modelPath;

        result.M2.(lesionName).Status = ...
            "ERROR";

        result.M2.(lesionName).Message = ...
            ME.message;

        fprintf( ...
            '%s ERROR: %s\n', ...
            lesionName,ME.message);

    end

end


%% ============================================================
% M3 - DR SEVERITY CLASSIFICATION
% =============================================================

fprintf('\n');
fprintf('========================================\n');
fprintf(' M3 - DR SEVERITY\n');
fprintf('========================================\n');

m3Model = fullfile( ...
    modelDir, ...
    'M3_DR_Classifier.mat');

try

    if ~isfile(m3Model)

        error( ...
            'M3 model not found: %s', ...
            m3Model);

    end

    result.M3 = ...
        localM3( ...
        imagePath, ...
        m3Model);

    result.M3.Status = "OK";

    result.M3.Model = m3Model;

    fprintf( ...
        'M3 completed: %s\n', ...
        result.M3.Class);

    fprintf( ...
        'Confidence: %.2f %%\n', ...
        result.M3.Confidence);

catch ME

    result.M3 = struct( ...
        'Status',"ERROR", ...
        'Message',ME.message, ...
        'Model',m3Model);

    fprintf( ...
        'M3 ERROR: %s\n', ...
        ME.message);

end


%% ============================================================
% M4 - EXPLAINABLE AI
% =============================================================

fprintf('\n');
fprintf('========================================\n');
fprintf(' M4 - EXPLAINABLE AI\n');
fprintf('========================================\n');

try

    if ~isfile(m3Model)

        error( ...
            'M3 model required for XAI was not found: %s', ...
            m3Model);

    end

    result.M4 = ...
        localXAI( ...
        imagePath, ...
        m3Model);

    result.M4.Status = "OK";

    fprintf('M4 XAI completed successfully.\n');

catch ME

    result.M4 = struct( ...
        'Status',"ERROR", ...
        'Message',ME.message, ...
        'Model',m3Model);

    fprintf( ...
        'M4 ERROR: %s\n', ...
        ME.message);

end


%% ============================================================
% M5 - TELEMEDICINE
% =============================================================

fprintf('\n');
fprintf('========================================\n');
fprintf(' M5 - TELEMEDICINE\n');
fprintf('========================================\n');

telemedicineModel = fullfile( ...
    root, ...
    'TELEMEDICINE_WORKFLOW', ...
    'models', ...
    'telemedicineWorkflow.slx');

result.M5 = struct();

result.M5.Model = ...
    telemedicineModel;

result.M5.Available = ...
    isfile(telemedicineModel);

if result.M5.Available

    result.M5.Status = "AVAILABLE";

    fprintf( ...
        'Telemedicine model found:\n%s\n', ...
        telemedicineModel);

else

    result.M5.Status = "NOT_AVAILABLE";

    fprintf( ...
        'Telemedicine model not found.\n');

end


%% ============================================================
% M6 - RETINAL STRUCTURE ANALYSIS
% =============================================================

fprintf('\n');
fprintf('========================================\n');
fprintf(' M6 - RETINAL STRUCTURE ANALYSIS\n');
fprintf('========================================\n');

try

    result.M6 = ...
        localM6( ...
        imagePath, ...
        root);

    fprintf( ...
        'M6 completed successfully.\n');

catch ME

    result.M6 = struct( ...
        'Status',"ERROR", ...
        'Message',ME.message);

    fprintf( ...
        'M6 ERROR: %s\n', ...
        ME.message);

end


%% ============================================================
% FINAL SCREENING DECISION
% =============================================================

fprintf('\n');
fprintf('========================================\n');
fprintf(' FINAL ALOKA-AI SCREENING\n');
fprintf('========================================\n');

result.ReferableDR = false;

if isfield(result,'M3') && ...
        isfield(result.M3,'Referable')

    result.ReferableDR = ...
        result.M3.Referable;

end


%% ============================================================
% GRADABILITY
% =============================================================

if isfield(result,'M1') && ...
        isfield(result.M1,'Gradable')

    result.Gradable = ...
        result.M1.Gradable;

else

    result.Gradable = true;

end


%% ============================================================
% SCREENING MESSAGE
% =============================================================

if ~result.Gradable

    result.Screening = ...
        "IMAGE QUALITY INSUFFICIENT";

    result.Recommendation = ...
        "Acquire a better retinal image before screening.";

elseif result.ReferableDR

    result.Screening = ...
        "REFERABLE DR";

    result.Recommendation = ...
        "Refer to ophthalmologist.";

else

    result.Screening = ...
        "NON-REFERABLE DR";

    result.Recommendation = ...
        "Routine follow-up recommended.";

end


%% ============================================================
% SAVE FINAL RESULT
% =============================================================

integrationDir = ...
    fullfile(root,'INTEGRATION');

if ~exist(integrationDir,'dir')

    mkdir(integrationDir);

end

resultFile = ...
    fullfile( ...
    integrationDir, ...
    'ALOKA_FinalResult.mat');

save( ...
    resultFile, ...
    'result', ...
    '-v7.3');

result.ResultFile = resultFile;


%% ============================================================
% FINAL SUMMARY
% =============================================================

fprintf('\n');
fprintf('========================================\n');
fprintf(' ALOKA-AI BACKEND COMPLETE\n');
fprintf('========================================\n');

fprintf('Screening      : %s\n', ...
    result.Screening);

fprintf('Referable DR   : %d\n', ...
    result.ReferableDR);

fprintf('Gradable       : %d\n', ...
    result.Gradable);

fprintf('Result saved   :\n%s\n', ...
    resultFile);

fprintf('========================================\n\n');

end


%% ============================================================
% M3 LOCAL CLASSIFIER
% =============================================================

function r = localM3(imagePath,modelPath)

S = load(modelPath);

names = fieldnames(S);

net = [];

for k = 1:numel(names)

    v = S.(names{k});

    if isa(v,'dlnetwork') || ...
       isa(v,'SeriesNetwork') || ...
       isa(v,'DAGNetwork')

        net = v;

        break;

    end

end

if isempty(net)

    error('M3 network not found.');

end


%% ------------------------------------------------------------
% CLASS NAMES
% ------------------------------------------------------------

if isfield(S,'classNames')

    classes = string(S.classNames);

else

    classes = [
        "No_DR"
        "Mild"
        "Moderate"
        "Severe"
        "Proliferative_DR"
    ];

end


%% ------------------------------------------------------------
% IMAGE
% ------------------------------------------------------------

I = imread(imagePath);

if size(I,3) == 1

    I = repmat(I,[1 1 3]);

end

if size(I,3) > 3

    I = I(:,:,1:3);

end

I = im2single(I);


%% ------------------------------------------------------------
% INPUT SIZE
% ------------------------------------------------------------

if isa(net,'dlnetwork')

    inputSize = net.Layers(1).InputSize(1:2);

else

    inputSize = net.Layers(1).InputSize(1:2);

end

I = imresize(I,inputSize);


%% ------------------------------------------------------------
% PREDICTION
% ------------------------------------------------------------

if isa(net,'dlnetwork')

    X = dlarray(I,'SSCB');

    Y = predict(net,X);

    scores = extractdata(Y);

    scores = squeeze(scores);

else

    scores = predict(net,I);

end


%% ------------------------------------------------------------
% NORMALIZE OUTPUT
% ------------------------------------------------------------

scores = double(scores(:));

if numel(scores) ~= numel(classes)

    error( ...
        'M3 output/classes mismatch. Output = %d, Classes = %d.', ...
        numel(scores), ...
        numel(classes));

end


scores = scores - max(scores);

scores = exp(scores);

scores = ...
    scores ./ (sum(scores)+eps);


%% ------------------------------------------------------------
% FINAL CLASS
% ------------------------------------------------------------

[confidence,index] = ...
    max(scores);


r.Class = ...
    classes(index);

r.Confidence = ...
    confidence*100;

r.SeverityLevel = ...
    index-1;

r.Referable = ...
    any( ...
    r.Class == ...
    ["Moderate","Severe","Proliferative_DR"]);

r.Classes = classes;

r.Scores = scores;

end


%% ============================================================
% M4 LOCAL XAI
% =============================================================

function r = localXAI(imagePath,modelPath)

S = load(modelPath);

names = fieldnames(S);

net = [];

for k = 1:numel(names)

    v = S.(names{k});

    if isa(v,'dlnetwork')

        net = v;

        break;

    end

end

if isempty(net)

    error( ...
        'dlnetwork not found for XAI.');

end


%% ------------------------------------------------------------
% ORIGINAL IMAGE
% ------------------------------------------------------------

originalImage = ...
    imread(imagePath);

if size(originalImage,3) == 1

    originalImage = ...
        repmat(originalImage,[1 1 3]);

end

if size(originalImage,3) > 3

    originalImage = ...
        originalImage(:,:,1:3);

end

originalImage = ...
    im2single(originalImage);


originalSize = [
    size(originalImage,1)
    size(originalImage,2)
];


%% ------------------------------------------------------------
% NETWORK INPUT
% ------------------------------------------------------------

inputSize = ...
    net.Layers(1).InputSize(1:2);

networkImage = ...
    imresize( ...
    originalImage, ...
    inputSize);


%% ------------------------------------------------------------
% CLASS PREDICTION
% ------------------------------------------------------------

X = ...
    dlarray( ...
    networkImage, ...
    'SSCB');

Y = ...
    predict(net,X);

scores = ...
    extractdata(Y);

scores = ...
    squeeze(scores);

scores = ...
    double(scores(:));

scores = ...
    scores - max(scores);

scores = ...
    exp(scores);

scores = ...
    scores ./ ...
    (sum(scores)+eps);

[~,classIndex] = ...
    max(scores);


%% ------------------------------------------------------------
% GRAD-CAM
% ------------------------------------------------------------

map = [];

try

    map = ...
        gradCAM( ...
        net, ...
        networkImage, ...
        classIndex, ...
        'FeatureLayer',"res5b_relu");

catch

    dlX = ...
        dlarray( ...
        networkImage, ...
        'SSCB');

    g = ...
        dlfeval( ...
        @gradientMap, ...
        net, ...
        dlX, ...
        classIndex);

    g = ...
        abs(extractdata(g));

    g = ...
        squeeze(g);

    if ndims(g) == 3

        map = ...
            max(g,[],3);

    else

        map = g;

    end

end


%% ------------------------------------------------------------
% NORMALIZE MAP
% ------------------------------------------------------------

map = gather(map);

map = squeeze(map);

if ndims(map) > 2

    map = max(map,[],3);

end

map(~isfinite(map)) = 0;

if max(map(:)) > min(map(:))

    map = mat2gray(map);

else

    map = zeros(size(map));

end


map = ...
    imresize( ...
    map, ...
    originalSize, ...
    'bicubic');

map = ...
    max(0,min(1,map));


%% ------------------------------------------------------------
% HEATMAP
% ------------------------------------------------------------

heat = ...
    ind2rgb( ...
    uint8(map*255), ...
    jet(256));


overlay = ...
    0.60*originalImage + ...
    0.40*single(heat);

overlay = ...
    min(max(overlay,0),1);


%% ------------------------------------------------------------
% OUTPUT DIRECTORY
% ------------------------------------------------------------

projectRoot = ...
    fileparts(fileparts(modelPath));

outDir = ...
    fullfile( ...
    projectRoot, ...
    'results');

if ~exist(outDir,'dir')

    mkdir(outDir);

end


%% ------------------------------------------------------------
% SAVE XAI
% ------------------------------------------------------------

outFile = ...
    fullfile( ...
    outDir, ...
    'ALOKA_XAI_Heatmap.png');

imwrite( ...
    overlay, ...
    outFile);


rawFile = ...
    fullfile( ...
    outDir, ...
    'ALOKA_XAI_RawHeatmap.png');

imwrite( ...
    uint8(map*255), ...
    rawFile);


%% ------------------------------------------------------------
% RESULT
% ------------------------------------------------------------

r.Method = ...
    "Grad-CAM";

r.FeatureLayer = ...
    "res5b_relu";

r.ClassIndex = ...
    classIndex;

r.Map = ...
    map;

r.Image = ...
    overlay;

r.File = ...
    outFile;

r.RawMapFile = ...
    rawFile;

r.ClassScores = ...
    scores;

end


%% ============================================================
% GRADIENT MAP
% =============================================================

function g = gradientMap(net,X,classIndex)

Y = forward(net,X);

Y = Y(:);

score = Y(classIndex);

g = dlgradient( ...
    score, ...
    X);

end


%% ============================================================
% M6 RETINAL STRUCTURE ANALYSIS
% =============================================================

function r = localM6(imagePath,root)

I = imread(imagePath);

if size(I,3) == 1

    I = repmat(I,[1 1 3]);

end

if size(I,3) > 3

    I = I(:,:,1:3);

end

I = im2single(I);


%% ------------------------------------------------------------
% GREEN CHANNEL
% ------------------------------------------------------------

G = I(:,:,2);

R = I(:,:,1);


%% ------------------------------------------------------------
% VESSEL ENHANCEMENT
% ------------------------------------------------------------

background = ...
    imgaussfilt(G,25);

enhanced = ...
    mat2gray( ...
    G ./ ...
    (background+eps));


level = ...
    graythresh(enhanced)*0.85;


vesselMask = ...
    enhanced > level;


vesselMask = ...
    bwareaopen( ...
    vesselMask, ...
    30);


%% ------------------------------------------------------------
% PROTOTYPE OPTIC DISC LOCATION
% ------------------------------------------------------------

red = ...
    imgaussfilt(R,8);

[~,idx] = ...
    max(red(:));

[y,x] = ...
    ind2sub( ...
    size(red), ...
    idx);


%% ------------------------------------------------------------
% RESULT
% ------------------------------------------------------------

r.VesselMask = ...
    vesselMask;

r.VesselAreaPercent = ...
    100*nnz(vesselMask) / ...
    numel(vesselMask);

r.OpticDiscX = x;

r.OpticDiscY = y;

r.Status = ...
    "Prototype retinal structure analysis";


%% ------------------------------------------------------------
% SAVE M6 OUTPUT
% ------------------------------------------------------------

outDir = ...
    fullfile( ...
    root, ...
    'IMAGE_QUALITY_AND_RETINAL_ANALYSIS', ...
    'results');

if ~exist(outDir,'dir')

    mkdir(outDir);

end


vesselFile = ...
    fullfile( ...
    outDir, ...
    'ALOKA_VesselMask.png');


imwrite( ...
    uint8(vesselMask)*255, ...
    vesselFile);


r.VesselMaskFile = ...
    vesselFile;

end