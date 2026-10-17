function results = trainM2LesionSegmentation

clc
close all
rng(42)

fprintf('\n');
fprintf('====================================================\n');
fprintf(' ALOKA-AI M2 QUICK LESION TRAINING\n');
fprintf(' ONLY HARD EXUDATES + SOFT EXUDATES\n');
fprintf('====================================================\n\n');

%% ===================================================
% PATHS
% ====================================================

projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));

dataRoot = ...
    'C:\Users\LOGESH\OneDrive\Documents\DR_XAI _project\data\raw\Lesion';

imageRoot = ...
    fullfile(dataRoot,'Segmentation','Original_Images','Training Set');

maskRoot = ...
    fullfile(dataRoot,'Segmentation', ...
    'Segmentation_Groundtruths','Training Set');

modelRoot = ...
    fullfile(projectRoot, ...
    'IMAGE_QUALITY_AND_RETINAL_ANALYSIS','models');

resultRoot = ...
    fullfile(projectRoot, ...
    'IMAGE_QUALITY_AND_RETINAL_ANALYSIS', ...
    'results','M2_Lesion_Training_Quick');

patchRoot = fullfile(resultRoot,'M2_Patches');

if ~exist(modelRoot,'dir')
    mkdir(modelRoot)
end

if ~exist(resultRoot,'dir')
    mkdir(resultRoot)
end

if ~exist(patchRoot,'dir')
    mkdir(patchRoot)
end

%% ===================================================
% QUICK TRAINING SETTINGS
% ====================================================

inputSize = [256 256 3];

patchSize = 256;

positivePatchesPerImage = 3;
negativePatchesPerImage = 1;

lesionNames = {'Hard Exudates','Soft Exudates'};
lesionCodes = {'EX','SE'};

classes = ["background","lesion"];

maxEpochs = 15;
miniBatchSize = 8;
initialLearnRate = 1e-4;

validationFrequency = 50;

validationPatience = 4;

results = struct;

%% ===================================================
% TRAIN ONLY EX + SE
% ====================================================

for lesionIndex = 1:numel(lesionNames)

    lesionName = lesionNames{lesionIndex};
    lesionCode = lesionCodes{lesionIndex};

    fprintf('\n');
    fprintf('====================================================\n');
    fprintf(' QUICK TRAINING: %s (%s)\n',lesionName,lesionCode);
    fprintf('====================================================\n');

    %% ------------------------------------------------
    % MASK FOLDER
    % -------------------------------------------------

    lesionFolder = fullfile(maskRoot,lesionName);

    if ~exist(lesionFolder,'dir')

        warning('Mask folder not found: %s',lesionFolder);

        continue

    end

    %% ------------------------------------------------
    % FIND IMAGES
    % -------------------------------------------------

    imageFiles = dir(fullfile(imageRoot,'*.jpg'));

    tifFiles = dir(fullfile(lesionFolder,'*.tif'));
    pngFiles = dir(fullfile(lesionFolder,'*.png'));

    maskFiles = [tifFiles; pngFiles];

    imageIDs = zeros(numel(imageFiles),1);
    maskIDs = zeros(numel(maskFiles),1);

    %% ------------------------------------------------
    % EXTRACT IMAGE IDs
    % -------------------------------------------------

    for k = 1:numel(imageFiles)

        token = regexp( ...
            imageFiles(k).name, ...
            'IDRiD_(\d+)', ...
            'tokens','once');

        if ~isempty(token)

            imageIDs(k) = str2double(token{1});

        end

    end

    %% ------------------------------------------------
    % EXTRACT MASK IDs
    % -------------------------------------------------

    for k = 1:numel(maskFiles)

        token = regexp( ...
            maskFiles(k).name, ...
            'IDRiD_(\d+)', ...
            'tokens','once');

        if ~isempty(token)

            maskIDs(k) = str2double(token{1});

        end

    end

    %% ------------------------------------------------
    % MATCH IMAGE + MASK
    % -------------------------------------------------

    [commonIDs,ia,ib] = intersect( ...
        imageIDs,maskIDs);

    imageFiles = imageFiles(ia);
    maskFiles = maskFiles(ib);

    [commonIDs,order] = sort(commonIDs);

    imageFiles = imageFiles(order);
    maskFiles = maskFiles(order);

    n = numel(commonIDs);

    fprintf('Matched labelled images : %d\n',n);

    if n < 2

        warning( ...
            'Not enough labelled images for %s.', ...
            lesionName);

        continue

    end

    %% ------------------------------------------------
    % PATH ARRAYS
    % -------------------------------------------------

    imagePaths = ...
        fullfile({imageFiles.folder}, ...
        {imageFiles.name});

    maskPaths = ...
        fullfile({maskFiles.folder}, ...
        {maskFiles.name});

    imagePaths = imagePaths(:);
    maskPaths = maskPaths(:);

    %% ------------------------------------------------
    % TRAIN / VALIDATION SPLIT
    % -------------------------------------------------

    indices = randperm(n);

    nValidation = max(1,round(0.20*n));

    if nValidation >= n

        nValidation = n - 1;

    end

    validationIndices = ...
        indices(1:nValidation);

    trainingIndices = ...
        indices(nValidation+1:end);

    trainImages = ...
        imagePaths(trainingIndices);

    trainMasks = ...
        maskPaths(trainingIndices);

    valImages = ...
        imagePaths(validationIndices);

    valMasks = ...
        maskPaths(validationIndices);

    fprintf('Training images   : %d\n', ...
        numel(trainImages));

    fprintf('Validation images : %d\n', ...
        numel(valImages));

    %% =================================================
    % PATCH DIRECTORY
    % =================================================

    lesionPatchRoot = ...
        fullfile(patchRoot,lesionCode);

    if exist(lesionPatchRoot,'dir')

        fprintf('Removing old quick patches...\n');

        rmdir(lesionPatchRoot,'s');

    end

    trainImagePatchRoot = ...
        fullfile(lesionPatchRoot,'train_images');

    trainMaskPatchRoot = ...
        fullfile(lesionPatchRoot,'train_masks');

    mkdir(trainImagePatchRoot);
    mkdir(trainMaskPatchRoot);

    %% =================================================
    % CREATE QUICK TRAINING PATCHES
    % =================================================

    fprintf('\n');
    fprintf('Creating QUICK training patches...\n');

    [numPositivePatches,numNegativePatches] = ...
        localCreateTrainingPatches( ...
        trainImages, ...
        trainMasks, ...
        trainImagePatchRoot, ...
        trainMaskPatchRoot, ...
        patchSize, ...
        positivePatchesPerImage, ...
        negativePatchesPerImage);

    fprintf('\nPositive patches : %d\n', ...
        numPositivePatches);

    fprintf('Negative patches : %d\n', ...
        numNegativePatches);

    if numPositivePatches < 1

        warning( ...
            'No positive patches generated for %s.', ...
            lesionName);

        continue

    end

    %% =================================================
    % VALIDATION PATCHES
    % =================================================

    valPatchRoot = ...
        fullfile(lesionPatchRoot,'validation');

    if exist(valPatchRoot,'dir')

        rmdir(valPatchRoot,'s');

    end

    valImagePatchRoot = ...
        fullfile(valPatchRoot,'images');

    valMaskPatchRoot = ...
        fullfile(valPatchRoot,'masks');

    mkdir(valImagePatchRoot);
    mkdir(valMaskPatchRoot);

    fprintf('\n');
    fprintf('Creating validation tiles...\n');

    numValidationTiles = ...
        localCreateValidationTiles( ...
        valImages, ...
        valMasks, ...
        valImagePatchRoot, ...
        valMaskPatchRoot, ...
        patchSize);

    fprintf('Validation tiles : %d\n', ...
        numValidationTiles);

    %% =================================================
    % DATASTORES
    % =================================================

    trainImds = ...
        imageDatastore(trainImagePatchRoot);

    trainPxds = ...
        pixelLabelDatastore( ...
        trainMaskPatchRoot, ...
        classes, ...
        [0 255]);

    valImds = ...
        imageDatastore(valImagePatchRoot);

    valPxds = ...
        pixelLabelDatastore( ...
        valMaskPatchRoot, ...
        classes, ...
        [0 255]);

    trainData = ...
        combine(trainImds,trainPxds);

    valData = ...
        combine(valImds,valPxds);

    trainData = ...
        transform( ...
        trainData, ...
        @localPrepareTrainingData);

    valData = ...
        transform( ...
        valData, ...
        @localPrepareValidationData);

    %% =================================================
    % CREATE SMALL U-NET
    % =================================================

    fprintf('\n');
    fprintf('Creating FAST U-Net...\n');

    net = unet( ...
        inputSize, ...
        numel(classes), ...
        EncoderDepth=2);

    fprintf('Fast U-Net created.\n');

    %% =================================================
    % TRAINING OPTIONS
    % =================================================

    options = trainingOptions( ...
        'adam', ...
        InitialLearnRate=initialLearnRate, ...
        MaxEpochs=maxEpochs, ...
        MiniBatchSize=miniBatchSize, ...
        Shuffle='every-epoch', ...
        ValidationData=valData, ...
        ValidationFrequency=validationFrequency, ...
        ValidationPatience=validationPatience, ...
        L2Regularization=1e-4, ...
        GradientThreshold=1, ...
        GradientThresholdMethod='l2norm', ...
        ExecutionEnvironment='auto', ...
        Verbose=true, ...
        Plots='none');

    %% =================================================
    % START TRAINING
    % =================================================

    fprintf('\n');
    fprintf('====================================================\n');
    fprintf(' STARTING QUICK %s TRAINING\n',lesionName);
    fprintf('====================================================\n');

    fprintf('Input size       : %dx%d\n', ...
        inputSize(1),inputSize(2));

    fprintf('Positive patches : %d/image\n', ...
        positivePatchesPerImage);

    fprintf('Negative patches : %d/image\n', ...
        negativePatchesPerImage);

    fprintf('Epochs           : %d\n', ...
        maxEpochs);

    fprintf('Batch size       : %d\n', ...
        miniBatchSize);

    fprintf('Learning rate    : %.1e\n', ...
        initialLearnRate);

    fprintf('\n');

    trainingStart = tic;

    try

        [net,info] = trainnet( ...
            trainData, ...
            net, ...
            "crossentropy", ...
            options);

    catch ME

        fprintf('\n');
        fprintf('TRAINING FAILED: %s\n', ...
            lesionName);

        fprintf('%s\n',ME.message);

        warning( ...
            'Skipping %s because training failed.', ...
            lesionName);

        continue

    end

    trainingTime = toc(trainingStart);

    fprintf('\n');
    fprintf('Training completed for %s\n', ...
        lesionName);

    fprintf('Training time: %.2f minutes\n', ...
        trainingTime/60);

    %% =================================================
    % SAVE MODEL IMMEDIATELY
    % =================================================

    modelFile = ...
        fullfile( ...
        modelRoot, ...
        ['M2_' lesionCode '_U-Net.mat']);

    save( ...
        modelFile, ...
        'net', ...
        'info', ...
        'classes', ...
        'commonIDs', ...
        'trainingIndices', ...
        'validationIndices', ...
        'positivePatchesPerImage', ...
        'negativePatchesPerImage', ...
        'inputSize', ...
        'maxEpochs', ...
        'miniBatchSize', ...
        'initialLearnRate', ...
        'trainingTime', ...
        '-v7.3');

    fprintf('\n');
    fprintf('MODEL SAVED:\n');
    fprintf('%s\n',modelFile);

    %% =================================================
    % QUICK VALIDATION
    % =================================================

    fprintf('\n');
    fprintf('Running quick validation...\n');

    metrics = ...
        localEvaluateQuick( ...
        net, ...
        valImages, ...
        valMasks, ...
        patchSize, ...
        lesionCode, ...
        resultRoot);

    %% =================================================
    % STORE RESULTS
    % =================================================

    metrics.Lesion = lesionName;
    metrics.Code = lesionCode;

    metrics.TotalMatchedImages = n;

    metrics.TrainingImages = ...
        numel(trainingIndices);

    metrics.ValidationImages = ...
        numel(validationIndices);

    metrics.PositivePatches = ...
        numPositivePatches;

    metrics.NegativePatches = ...
        numNegativePatches;

    metrics.TrainingTimeMinutes = ...
        trainingTime/60;

    metrics.InputSize = inputSize;
    metrics.Epochs = maxEpochs;
    metrics.BatchSize = miniBatchSize;

    results.(lesionCode) = metrics;

    %% =================================================
    % PRINT METRICS
    % =================================================

    fprintf('\n');
    fprintf('====================================================\n');
    fprintf('%s QUICK VALIDATION RESULTS\n', ...
        lesionName);
    fprintf('====================================================\n');

    fprintf('Dice        : %.4f\n', ...
        metrics.Dice);

    fprintf('IoU         : %.4f\n', ...
        metrics.IoU);

    fprintf('Sensitivity : %.4f\n', ...
        metrics.Sensitivity);

    fprintf('Specificity : %.4f\n', ...
        metrics.Specificity);

    fprintf('Precision   : %.4f\n', ...
        metrics.Precision);

    fprintf('F1          : %.4f\n', ...
        metrics.F1);

    fprintf('Training    : %.2f minutes\n', ...
        metrics.TrainingTimeMinutes);

end

%% ===================================================
% SAVE FINAL RESULTS
% ====================================================

save( ...
    fullfile( ...
    resultRoot, ...
    'M2_QuickTrainingResults.mat'), ...
    'results', ...
    '-v7.3');

localReport( ...
    results, ...
    fullfile( ...
    resultRoot, ...
    'M2_QuickTrainingReport.txt'));

fprintf('\n');
fprintf('====================================================\n');
fprintf(' M2 QUICK TRAINING COMPLETE\n');
fprintf('====================================================\n');

fprintf('\nCompleted lesions:\n');
fprintf('  [KEEP] Microaneurysms - existing model\n');
fprintf('  [KEEP] Haemorrhages   - existing model\n');
fprintf('  [DONE] Hard Exudates  - quick model\n');
fprintf('  [DONE] Soft Exudates  - quick model\n');

end


%% ===================================================
% CREATE TRAINING PATCHES
% ====================================================

function [numPositive,numNegative] = ...
    localCreateTrainingPatches( ...
    imagePaths, ...
    maskPaths, ...
    imageOut, ...
    maskOut, ...
    patchSize, ...
    numPositivePerImage, ...
    numNegativePerImage)

numPositive = 0;
numNegative = 0;

for k = 1:numel(imagePaths)

    fprintf('Patch generation %d/%d\n', ...
        k,numel(imagePaths));

    I = imread(imagePaths{k});
    M = imread(maskPaths{k});

    if size(I,3) == 1
        I = repmat(I,1,1,3);
    end

    if size(M,3) > 1
        M = M(:,:,1);
    end

    M = M > 0;

    [h,w,~] = size(I);

    positivePixels = find(M);

    %% ------------------------------------------------
    % POSITIVE PATCHES
    % -------------------------------------------------

    if ~isempty(positivePixels)

        [pr,pc] = ...
            ind2sub([h w],positivePixels);

        for p = 1:numPositivePerImage

            found = false;

            for attempt = 1:30

                q = randi(numel(pr));

                centerRow = pr(q);
                centerCol = pc(q);

                [Ipatch,Mpatch] = ...
                    localExtractPatch( ...
                    I,M, ...
                    centerRow, ...
                    centerCol, ...
                    patchSize);

                if nnz(Mpatch) >= 2

                    found = true;
                    break

                end

            end

            if found

                numPositive = ...
                    numPositive + 1;

                baseName = sprintf( ...
                    'ID_%04d_POS_%03d', ...
                    k,p);

                imwrite( ...
                    Ipatch, ...
                    fullfile( ...
                    imageOut, ...
                    [baseName '.png']));

                imwrite( ...
                    uint8(Mpatch)*255, ...
                    fullfile( ...
                    maskOut, ...
                    [baseName '.png']));

            end

        end

    end

    %% ------------------------------------------------
    % NEGATIVE PATCHES
    % -------------------------------------------------

    for p = 1:numNegativePerImage

        found = false;

        for attempt = 1:50

            centerRow = randi(h);
            centerCol = randi(w);

            [Ipatch,Mpatch] = ...
                localExtractPatch( ...
                I,M, ...
                centerRow, ...
                centerCol, ...
                patchSize);

            if nnz(Mpatch) == 0

                found = true;
                break

            end

        end

        if found

            numNegative = ...
                numNegative + 1;

            baseName = sprintf( ...
                'ID_%04d_NEG_%03d', ...
                k,p);

            imwrite( ...
                Ipatch, ...
                fullfile( ...
                imageOut, ...
                [baseName '.png']));

            imwrite( ...
                uint8(Mpatch)*255, ...
                fullfile( ...
                maskOut, ...
                [baseName '.png']));

        end

    end

end

end


%% ===================================================
% EXTRACT PATCH
% ====================================================

function [Ipatch,Mpatch] = ...
    localExtractPatch( ...
    I,M, ...
    centerRow, ...
    centerCol, ...
    patchSize)

[h,w,~] = size(I);

halfPatch = floor(patchSize/2);

r1 = centerRow-halfPatch+1;
c1 = centerCol-halfPatch+1;

r2 = r1+patchSize-1;
c2 = c1+patchSize-1;

padTop = max(1-r1,0);
padLeft = max(1-c1,0);

padBottom = max(r2-h,0);
padRight = max(c2-w,0);

if padTop > 0 || ...
        padLeft > 0 || ...
        padBottom > 0 || ...
        padRight > 0

    I = padarray( ...
        I,[padTop padLeft],0,'pre');

    I = padarray( ...
        I,[padBottom padRight],0,'post');

    M = padarray( ...
        M,[padTop padLeft],false,'pre');

    M = padarray( ...
        M,[padBottom padRight],false,'post');

    r1 = r1+padTop;
    r2 = r2+padTop;

    c1 = c1+padLeft;
    c2 = c2+padLeft;

end

Ipatch = ...
    I(r1:r2,c1:c2,:);

Mpatch = ...
    M(r1:r2,c1:c2);

end


%% ===================================================
% TRAINING DATA PREPARATION
% ====================================================

function data = ...
    localPrepareTrainingData(data)

I = data{1};
C = data{2};

if size(I,3) == 1
    I = repmat(I,1,1,3);
end

if size(C,3) > 1
    C = C(:,:,1);
end

I = im2single(I);

I = min(max(I,0),1);

if rand > 0.5

    I = fliplr(I);
    C = fliplr(C);

end

if rand > 0.5

    I = flipud(I);
    C = flipud(C);

end

if rand > 0.5

    angleIndex = randi([0 3]);

    I = rot90(I,angleIndex);
    C = rot90(C,angleIndex);

end

if rand > 0.5

    factor = ...
        0.90 + 0.20*rand;

    I = I .* factor;

end

I = min(max(I,0),1);

data = {I,C};

end


%% ===================================================
% VALIDATION DATA
% ====================================================

function data = ...
    localPrepareValidationData(data)

I = data{1};
C = data{2};

if size(I,3) == 1

    I = repmat(I,1,1,3);

end

if size(C,3) > 1

    C = C(:,:,1);

end

I = im2single(I);

I = min(max(I,0),1);

data = {I,C};

end


%% ===================================================
% VALIDATION TILES
% ====================================================

function numTiles = ...
    localCreateValidationTiles( ...
    imagePaths, ...
    maskPaths, ...
    imageOut, ...
    maskOut, ...
    patchSize)

numTiles = 0;

for k = 1:numel(imagePaths)

    I = imread(imagePaths{k});
    M = imread(maskPaths{k});

    if size(I,3) == 1

        I = repmat(I,1,1,3);

    end

    if size(M,3) > 1

        M = M(:,:,1);

    end

    M = M > 0;

    [h,w,~] = size(I);

    tileIndex = 0;

    for r = 1:patchSize:h

        for c = 1:patchSize:w

            tileIndex = tileIndex + 1;

            r2 = min( ...
                r+patchSize-1, ...
                h);

            c2 = min( ...
                c+patchSize-1, ...
                w);

            Icrop = ...
                I(r:r2,c:c2,:);

            Mcrop = ...
                M(r:r2,c:c2);

            [cropH,cropW,~] = ...
                size(Icrop);

            Ipatch = ...
                zeros( ...
                patchSize, ...
                patchSize, ...
                3, ...
                'like',Icrop);

            Mpatch = ...
                false( ...
                patchSize, ...
                patchSize);

            Ipatch(1:cropH,1:cropW,:) = ...
                Icrop;

            Mpatch(1:cropH,1:cropW) = ...
                Mcrop;

            baseName = sprintf( ...
                'ID_%04d_TILE_%04d', ...
                k,tileIndex);

            imwrite( ...
                Ipatch, ...
                fullfile( ...
                imageOut, ...
                [baseName '.png']));

            imwrite( ...
                uint8(Mpatch)*255, ...
                fullfile( ...
                maskOut, ...
                [baseName '.png']));

            numTiles = ...
                numTiles + 1;

        end

    end

end

end


%% ===================================================
% QUICK VALIDATION
% ====================================================

function metrics = ...
    localEvaluateQuick( ...
    net, ...
    imagePaths, ...
    maskPaths, ...
    patchSize, ...
    code, ...
    resultRoot)

TP = 0;
TN = 0;
FP = 0;
FN = 0;

for k = 1:numel(imagePaths)

    fprintf( ...
        'Quick validation %s %d/%d\n', ...
        code,k,numel(imagePaths));

    I = imread(imagePaths{k});
    GT = imread(maskPaths{k});

    if size(I,3) == 1

        I = repmat(I,1,1,3);

    end

    if size(GT,3) > 1

        GT = GT(:,:,1);

    end

    GT = GT > 0;

    [h,w,~] = size(I);

    predictionFull = ...
        false(h,w);

    for r = 1:patchSize:h

        for c = 1:patchSize:w

            r2 = min( ...
                r+patchSize-1,h);

            c2 = min( ...
                c+patchSize-1,w);

            Icrop = ...
                I(r:r2,c:c2,:);

            [cropH,cropW,~] = ...
                size(Icrop);

            Ipatch = ...
                zeros( ...
                patchSize, ...
                patchSize, ...
                3, ...
                'like',Icrop);

            Ipatch(1:cropH,1:cropW,:) = ...
                Icrop;

            Ipatch = ...
                im2single(Ipatch);

            Ipatch = ...
                min(max(Ipatch,0),1);

            predictedLabels = ...
                semanticseg(Ipatch,net);

            predictedPatch = ...
                predictedLabels == ...
                categorical("lesion");

            predictionFull( ...
                r:r2,c:c2) = ...
                predictedPatch( ...
                1:cropH,1:cropW);

        end

    end

    TP = TP + nnz( ...
        predictionFull & GT);

    TN = TN + nnz( ...
        ~predictionFull & ~GT);

    FP = FP + nnz( ...
        predictionFull & ~GT);

    FN = FN + nnz( ...
        ~predictionFull & GT);

    if k <= 3

        fig = figure( ...
            'Visible','off');

        imshow(I);
        hold on;

        if any(predictionFull(:))

            contour( ...
                predictionFull, ...
                [0.5 0.5], ...
                'LineWidth',1);

        end

        title([code ' Quick Prediction']);

        saveas( ...
            fig, ...
            fullfile( ...
            resultRoot, ...
            [code '_QuickPrediction_' ...
            num2str(k) '.png']));

        close(fig);

    end

end

%% ---------------------------------------------------
% METRICS
% ----------------------------------------------------

Dice = ...
    (2*TP) / ...
    (2*TP+FP+FN+eps);

IoU = ...
    TP / ...
    (TP+FP+FN+eps);

Sensitivity = ...
    TP / ...
    (TP+FN+eps);

Specificity = ...
    TN / ...
    (TN+FP+eps);

Precision = ...
    TP / ...
    (TP+FP+eps);

F1 = ...
    2*Precision*Sensitivity / ...
    (Precision+Sensitivity+eps);

metrics = struct;

metrics.TP = TP;
metrics.TN = TN;
metrics.FP = FP;
metrics.FN = FN;

metrics.Dice = Dice;
metrics.IoU = IoU;
metrics.Sensitivity = Sensitivity;
metrics.Specificity = Specificity;
metrics.Precision = Precision;
metrics.F1 = F1;

end


%% ===================================================
% REPORT
% ====================================================

function localReport(results,fileName)

fid = fopen(fileName,'w');

if fid == -1

    warning( ...
        'Unable to create report: %s', ...
        fileName);

    return

end

fprintf( ...
    fid, ...
    'ALOKA-AI M2 QUICK LESION SEGMENTATION\n');

fprintf( ...
    fid, ...
    '=====================================\n\n');

codes = fieldnames(results);

for k = 1:numel(codes)

    r = results.(codes{k});

    fprintf( ...
        fid, ...
        '%s (%s)\n', ...
        r.Lesion, ...
        r.Code);

    fprintf( ...
        fid, ...
        'Matched images  : %d\n', ...
        r.TotalMatchedImages);

    fprintf( ...
        fid, ...
        'Training images : %d\n', ...
        r.TrainingImages);

    fprintf( ...
        fid, ...
        'Validation      : %d\n', ...
        r.ValidationImages);

    fprintf( ...
        fid, ...
        'Positive patches: %d\n', ...
        r.PositivePatches);

    fprintf( ...
        fid, ...
        'Negative patches: %d\n', ...
        r.NegativePatches);

    fprintf( ...
        fid, ...
        'Input size      : %d x %d\n', ...
        r.InputSize(1), ...
        r.InputSize(2));

    fprintf( ...
        fid, ...
        'Epochs          : %d\n', ...
        r.Epochs);

    fprintf( ...
        fid, ...
        'Batch size      : %d\n', ...
        r.BatchSize);

    fprintf( ...
        fid, ...
        'Training time   : %.2f minutes\n', ...
        r.TrainingTimeMinutes);

    fprintf( ...
        fid, ...
        'Dice            : %.6f\n', ...
        r.Dice);

    fprintf( ...
        fid, ...
        'IoU             : %.6f\n', ...
        r.IoU);

    fprintf( ...
        fid, ...
        'Sensitivity     : %.6f\n', ...
        r.Sensitivity);

    fprintf( ...
        fid, ...
        'Specificity     : %.6f\n', ...
        r.Specificity);

    fprintf( ...
        fid, ...
        'Precision       : %.6f\n', ...
        r.Precision);

    fprintf( ...
        fid, ...
        'F1              : %.6f\n\n', ...
        r.F1);

end

fprintf( ...
    fid, ...
    'This is a quick-training configuration.\n');

fprintf( ...
    fid, ...
    'Microaneurysms and Haemorrhages were not retrained.\n');

fprintf( ...
    fid, ...
    'Hard Exudates and Soft Exudates were trained using reduced patches and epochs.\n');

fclose(fid);

end