function result = runALOKAPipeline(imagePath)

root = fileparts(fileparts(mfilename('fullpath')));

if nargin < 1 || isempty(imagePath)
    files = dir(fullfile(root,'data','test','*.png'));
    if isempty(files)
        files = dir(fullfile(root,'data','test','*.jpg'));
    end
    if isempty(files)
        error('No test image found.');
    end
    imagePath = fullfile(files(1).folder,files(1).name);
end

if ~isfile(imagePath)
    error('Image not found: %s',imagePath);
end

modelDir = fullfile(root,'IMAGE_QUALITY_AND_RETINAL_ANALYSIS','models');

addpath(genpath(root));

resultDir = fullfile(root,...
    'IMAGE_QUALITY_AND_RETINAL_ANALYSIS',...
    'results',...
    'ALOKA_AI_Screening',...
    datestr(now,'yyyymmdd_HHMMSS'));

if ~exist(resultDir,'dir')
    mkdir(resultDir);
end

I = imread(imagePath);

if size(I,3) == 1
    I = repmat(I,[1 1 3]);
end

if size(I,3) > 3
    I = I(:,:,1:3);
end

I = im2uint8(I);


result = struct;
result.ImagePath = imagePath;
result.Timestamp = datestr(now);

quality = runImageQualityWorkflow(imagePath);
result.ImageQuality = quality;

if ~quality.Gradable
    result.Status = 'RECAPTURE_REQUIRED';
    result.Screening = 'NOT_PERFORMED';
    result.Recommendation = quality.Recommendation;
    result.OutputDirectory = resultDir;

    save(fullfile(resultDir,'ALOKA_AI_Result.mat'),'result');
    writeReport(result,resultDir);

    return
end

m2Names = {'MA','HE','EX','SE'};

m2Files = {...
    'M2_MA_U-Net.mat',...
    'M2_HE_U-Net.mat',...
    'M2_EX_U-Net.mat',...
    'M2_SE_U-Net.mat'};

m2 = struct;

for k = 1:4

    modelPath = fullfile(modelDir,m2Files{k});

    [probability,mask] = runIDRiDLesionInference(...
        imagePath,modelPath,0.20);

    maskOriginal = imresize(...
        mask,[size(I,1) size(I,2)],'nearest');

    probabilityOriginal = imresize(...
        probability,[size(I,1) size(I,2)]);

    m2.(m2Names{k}).ModelPath = modelPath;
    m2.(m2Names{k}).Probability = probability;
    m2.(m2Names{k}).Mask = mask;
    m2.(m2Names{k}).MaskOriginal = maskOriginal;
    m2.(m2Names{k}).PositivePixels = nnz(maskOriginal);
    m2.(m2Names{k}).PositivePercent = ...
        100*nnz(maskOriginal)/numel(maskOriginal);
    m2.(m2Names{k}).MeanProbability = ...
        mean(probabilityOriginal(:));

    imwrite(...
        uint8(maskOriginal)*255,...
        fullfile(resultDir,...
        [m2Names{k} '_mask.png']));
end

result.LesionSegmentation = m2;

m3Path = fullfile(modelDir,'M3_DR_Classifier.mat');

S = load(m3Path);
vars = fieldnames(S);

net = [];

for k = 1:numel(vars)

    if isa(S.(vars{k}),'SeriesNetwork') || ...
       isa(S.(vars{k}),'DAGNetwork') || ...
       isa(S.(vars{k}),'dlnetwork')

        net = S.(vars{k});
        break
    end
end

if isempty(net)
    error('No supported M3 network found.');
end

classes = {...
    'No_DR',...
    'Mild',...
    'Moderate',...
    'Severe',...
    'Proliferative_DR'};

if isa(net,'SeriesNetwork') || isa(net,'DAGNetwork')
    inputSize = net.Layers(1).InputSize;
else
    inputSize = [224 224 3];
end

X = imresize(I,inputSize(1:2));
X = im2single(X);

scores = predict(net,X);

scores = gather(extractdata(scores));
scores = squeeze(scores);
scores = double(scores(:));

if numel(scores) ~= 5
    error('M3 returned %d scores instead of 5.',numel(scores));
end

if any(scores < 0) || abs(sum(scores)-1) > 0.05
    scores = scores - max(scores);
    scores = exp(scores);
    scores = scores/sum(scores);
else
    scores = scores/sum(scores);
end

[confidence,classIndex] = max(scores);

severity = classIndex-1;
referable = severity >= 2;

result.DRClassification.ModelPath = m3Path;
result.DRClassification.Class = classes{classIndex};
result.DRClassification.ClassIndex = classIndex;
result.DRClassification.Severity = severity;
result.DRClassification.Confidence = confidence;
result.DRClassification.Scores = scores;
result.DRClassification.Classes = classes;
result.DRClassification.Referable = referable;

targetLayer = 'res5b_relu';

attentionMap = [];
xaiMethod = 'Unavailable';

try

    if isa(net,'SeriesNetwork')

        dlX = dlarray(X,'SSCB');

        if canUseGPU
            dlX = gpuArray(dlX);
        end

        [~,gradients] = dlfeval(...
            @classificationInputGradient,...
            net,dlX,classIndex);

        gradients = gather(extractdata(gradients));

        attentionMap = mean(abs(gradients),3);
        attentionMap = squeeze(attentionMap);
        attentionMap = mat2gray(attentionMap);

        xaiMethod = 'Gradient Saliency';

    elseif isa(net,'DAGNetwork')

        dlX = dlarray(X,'SSCB');

        if canUseGPU
            dlX = gpuArray(dlX);
        end

        [~,gradients] = dlfeval(...
            @classificationInputGradient,...
            net,dlX,classIndex);

        gradients = gather(extractdata(gradients));

        attentionMap = mean(abs(gradients),3);
        attentionMap = squeeze(attentionMap);
        attentionMap = mat2gray(attentionMap);

        xaiMethod = 'Gradient Saliency';

    elseif isa(net,'dlnetwork')

        dlX = dlarray(X,'SSCB');

        if canUseGPU
            dlX = gpuArray(dlX);
        end

        [~,gradients] = dlfeval(...
            @classificationInputGradient,...
            net,dlX,classIndex);

        gradients = gather(extractdata(gradients));

        attentionMap = mean(abs(gradients),3);
        attentionMap = squeeze(attentionMap);
        attentionMap = mat2gray(attentionMap);

        xaiMethod = 'Gradient Saliency';

    end

catch
    attentionMap = [];
end

if ~isempty(attentionMap)

    attentionMap = imresize(...
        attentionMap,[size(I,1) size(I,2)]);

    attentionMap = mat2gray(attentionMap);

    result.XAI.Method = xaiMethod;
    result.XAI.TargetLayer = targetLayer;
    result.XAI.AttentionMap = attentionMap;

    heat = ind2rgb(...
        uint8(attentionMap*255),...
        jet(256));

    baseImage = im2double(I);

    overlay = ...
        0.55*baseImage + ...
        0.45*heat;

    overlay = ...
        uint8(255*min(max(overlay,0),1));

    imwrite(...
        uint8(attentionMap*255),...
        fullfile(resultDir,...
        'XAI_Heatmap.png'));

    imwrite(...
        overlay,...
        fullfile(resultDir,...
        'XAI_Overlay.png'));

else

    result.XAI.Method = 'Unavailable';
    result.XAI.TargetLayer = targetLayer;
    result.XAI.AttentionMap = [];

end

structure = analyzeRetinalStructure(I);

result.RetinalStructure = structure;

imwrite(...
    uint8(structure.VesselMask)*255,...
    fullfile(resultDir,'vessel_mask.png'));

m5Path = fullfile(...
    root,...
    'TELEMEDICINE_WORKFLOW',...
    'models',...
    'telemedicineWorkflow.slx');

result.Telemedicine.ModelPath = m5Path;
result.Telemedicine.Available = isfile(m5Path);

if result.Telemedicine.Available
    result.Telemedicine.Status = ...
        'Simulink telemedicine workflow available';
else
    result.Telemedicine.Status = ...
        'Telemedicine model unavailable';
end

if referable

    result.Status = 'COMPLETE';
    result.Screening = 'REFERABLE DR';
    result.Recommendation = ...
        'Refer to ophthalmologist for further evaluation.';

else

    result.Status = 'COMPLETE';
    result.Screening = 'NON-REFERABLE DR';
    result.Recommendation = ...
        'Routine diabetic eye screening follow-up recommended.';

end

result.OutputDirectory = resultDir;

save(...
    fullfile(resultDir,'ALOKA_AI_Result.mat'),...
    'result');

writeReport(result,resultDir);

fprintf('\n');
fprintf('============================================\n');
fprintf('       ALOKA-AI SCREENING COMPLETE\n');
fprintf('============================================\n');
fprintf('Image          : %s\n',imagePath);
fprintf('Quality        : %s\n',quality.Quality);
fprintf('Quality Score  : %.2f %%\n',quality.QualityScore);
fprintf('DR Class       : %s\n',classes{classIndex});
fprintf('Confidence     : %.2f %%\n',confidence*100);
fprintf('Screening      : %s\n',result.Screening);
fprintf('XAI Method     : %s\n',result.XAI.Method);
fprintf('XAI Layer      : %s\n',result.XAI.TargetLayer);
fprintf('M5 Available   : %s\n',mat2str(result.Telemedicine.Available));
fprintf('Output         : %s\n',resultDir);
fprintf('============================================\n');

end

function [loss,gradients] = classificationInputGradient(net,X,classIndex)

if isa(net,'dlnetwork')
    scores = forward(net,X);
else
    scores = predict(net,extractdata(X));
    scores = dlarray(scores);
end

scores = squeeze(scores);

loss = scores(classIndex);

gradients = dlgradient(loss,X);

end

function structure = analyzeRetinalStructure(I)

G = I(:,:,2);

background = imgaussfilt(double(G),12);

vesselResponse = mat2gray(...
    background-double(G));

threshold = graythresh(vesselResponse)*0.85;

vesselMask = vesselResponse > threshold;

vesselMask = bwareaopen(vesselMask,20);

vesselMask = imclose(...
    vesselMask,...
    strel('disk',2));

R = imgaussfilt(double(I(:,:,1)),15);

[~,idx] = max(R(:));

[yDisc,xDisc] = ind2sub(size(R),idx);

[h,w,~] = size(I);

xFovea = round(0.68*w);
yFovea = round(0.55*h);

structure.VesselMask = vesselMask;

structure.VesselCoveragePercent = ...
    100*nnz(vesselMask)/numel(vesselMask);

structure.OpticDisc.X = xDisc;
structure.OpticDisc.Y = yDisc;

structure.Fovea.X = xFovea;
structure.Fovea.Y = yFovea;

structure.Method = ...
    'Prototype retinal structure analysis';

end

function writeReport(result,resultDir)

fid = fopen(...
    fullfile(resultDir,...
    'ALOKA_AI_Screening_Report.txt'),'w');

fprintf(fid,...
    'ALOKA-AI DIABETIC RETINOPATHY SCREENING REPORT\n');

fprintf(fid,...
    '==============================================\n\n');

fprintf(fid,'Image: %s\n',result.ImagePath);
fprintf(fid,'Timestamp: %s\n\n',result.Timestamp);

fprintf(fid,'IMAGE QUALITY\n');
fprintf(fid,'-------------\n');
fprintf(fid,'Quality: %s\n',result.ImageQuality.Quality);
fprintf(fid,'Quality Score: %.2f %%\n',...
    result.ImageQuality.QualityScore);
fprintf(fid,'Gradable: %s\n',...
    mat2str(result.ImageQuality.Gradable));
fprintf(fid,'Quality Findings: %s\n\n',...
    result.ImageQuality.QualityReasons);

if isfield(result,'DRClassification')

    fprintf(fid,'DR CLASSIFICATION\n');
    fprintf(fid,'-----------------\n');

    fprintf(fid,'Class: %s\n',...
        result.DRClassification.Class);

    fprintf(fid,'Confidence: %.2f %%\n',...
        result.DRClassification.Confidence*100);

    fprintf(fid,'Severity: %d\n',...
        result.DRClassification.Severity);

    fprintf(fid,'Referable: %s\n\n',...
        mat2str(result.DRClassification.Referable));

    fprintf(fid,'CLASS PROBABILITIES\n');
    fprintf(fid,'-------------------\n');

    for k = 1:numel(result.DRClassification.Classes)

        fprintf(fid,...
            '%s: %.2f %%\n',...
            result.DRClassification.Classes{k},...
            result.DRClassification.Scores(k)*100);

    end

    fprintf(fid,'\n');

    fprintf(fid,'LESION SEGMENTATION\n');
    fprintf(fid,'-------------------\n');

    names = fieldnames(result.LesionSegmentation);

    for k = 1:numel(names)

        x = result.LesionSegmentation.(names{k});

        fprintf(fid,...
            '%s: %.4f %% positive area\n',...
            names{k},...
            x.PositivePercent);

    end

    fprintf(fid,'\n');

    fprintf(fid,'EXPLAINABILITY\n');
    fprintf(fid,'--------------\n');

    fprintf(fid,...
        'Method: %s\n',...
        result.XAI.Method);

    fprintf(fid,...
        'Target Layer: %s\n\n',...
        result.XAI.TargetLayer);

    fprintf(fid,'RETINAL STRUCTURE\n');
    fprintf(fid,'-----------------\n');

    fprintf(fid,...
        'Vessel Coverage: %.4f %%\n',...
        result.RetinalStructure.VesselCoveragePercent);

    fprintf(fid,...
        'Optic Disc: (%d,%d)\n',...
        result.RetinalStructure.OpticDisc.X,...
        result.RetinalStructure.OpticDisc.Y);

    fprintf(fid,...
        'Fovea Estimate: (%d,%d)\n\n',...
        result.RetinalStructure.Fovea.X,...
        result.RetinalStructure.Fovea.Y);

end

fprintf(fid,'SCREENING RESULT\n');
fprintf(fid,'----------------\n');

fprintf(fid,...
    'Status: %s\n',...
    result.Status);

fprintf(fid,...
    'Screening: %s\n',...
    result.Screening);

fprintf(fid,...
    'Recommendation: %s\n\n',...
    result.Recommendation);

fprintf(fid,'TELEMEDICINE\n');
fprintf(fid,'------------\n');

fprintf(fid,...
    'Available: %s\n',...
    mat2str(result.Telemedicine.Available));

fprintf(fid,...
    'Status: %s\n',...
    result.Telemedicine.Status);

fclose(fid);

end