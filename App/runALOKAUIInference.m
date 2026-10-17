function result = runALOKAUIInference(imagePath)

if nargin < 1 || isempty(imagePath)
    error('Image path is required.');
end

if ~isfile(imagePath)
    error('Image not found: %s',imagePath);
end

root = fileparts(mfilename('fullpath'));

m2Dir = fullfile(root,'IMAGE_QUALITY_AND_RETINAL_ANALYSIS','models');
resultDir = fullfile(root,'IMAGE_QUALITY_AND_RETINAL_ANALYSIS','results','ALOKA_AI_Screening');

if ~exist(resultDir,'dir')
    mkdir(resultDir);
end

timestamp = datestr(now,'yyyymmdd_HHMMSS');
outDir = fullfile(resultDir,timestamp);

if ~exist(outDir,'dir')
    mkdir(outDir);
end

I = imread(imagePath);

if size(I,3) == 1
    I = repmat(I,[1 1 3]);
end

if size(I,3) > 3
    I = I(:,:,1:3);
end

I = im2uint8(I);

result = struct();

result.ImagePath = imagePath;
result.Timestamp = timestamp;

qualityResult = runImageQualityWorkflow(imagePath);

result.ImageQuality = qualityResult;

if isfield(qualityResult,'Gradable')
    if ~qualityResult.Gradable
        result.DRAnalysis = struct();
        result.DRAnalysis.Grade = 'Image_Ungradable';
        result.DRAnalysis.Severity = 'Ungradable';
        result.DRAnalysis.Confidence = 0;
        result.DRAnalysis.Referrable = false;
        result.DRAnalysis.Probabilities = zeros(1,5);

        result.XAI = struct();
        result.XAI.Method = 'Not generated';
        result.XAI.Layer = '';
        result.XAI.AttentionMap = [];

        result.M2 = struct();
        result.M6 = struct();
        result.M5 = struct();
        result.M5.Available = isfile(fullfile(root,'TELEMEDICINE_WORKFLOW','models','telemedicineWorkflow.slx'));

        save(fullfile(outDir,'ALOKA_AI_Result.mat'),'result');

        return;
    end
end

m3Path = fullfile(m2Dir,'M3_DR_Classifier.mat');

if ~isfile(m3Path)
    error('M3 model not found: %s',m3Path);
end

loaded = load(m3Path);

net = [];

names = fieldnames(loaded);

for k = 1:numel(names)
    v = loaded.(names{k});

    if isa(v,'dlnetwork')
        net = v;
        break;
    end
end

if isempty(net)
    for k = 1:numel(names)
        v = loaded.(names{k});

        if isa(v,'DAGNetwork') || isa(v,'SeriesNetwork')
            net = v;
            break;
        end
    end
end

if isempty(net)
    error('No supported M3 neural network found.');
end

inputSize = [224 224 3];

try
    if isa(net,'dlnetwork')
        if ~isempty(net.Layers)
            for k = 1:numel(net.Layers)
                layer = net.Layers(k);

                if isprop(layer,'InputSize')
                    s = layer.InputSize;

                    if numel(s) == 3
                        inputSize = s;
                        break;
                    end
                end
            end
        end
    else
        inputSize = net.Layers(1).InputSize;
    end
catch
end

X = imresize(I,inputSize(1:2));
X = im2single(X);

classNames = ["No_DR","Mild","Moderate","Severe","Proliferative_DR"];

scores = [];

try
    if isa(net,'dlnetwork')
        dlX = dlarray(X,'SSCB');
        Y = predict(net,dlX);

        if iscell(Y)
            Y = Y{1};
        end

        scores = extractdata(Y);
        scores = squeeze(scores);
    else
        scores = predict(net,X);
        scores = squeeze(scores);
    end
catch
    try
        scores = predict(net,X);
        scores = squeeze(scores);
    catch ME
        error('M3 inference failed: %s',ME.message);
    end
end

scores = double(scores);

if isempty(scores)
    error('M3 returned empty prediction scores.');
end

if isvector(scores)
    scores = scores(:);
end

if size(scores,1) ~= 5 && size(scores,2) == 5
    scores = scores';
end

if size(scores,1) > 5
    scores = scores(1:5,:);
end

if size(scores,1) < 5
    temp = zeros(5,1);
    temp(1:size(scores,1)) = scores(:);
    scores = temp;
end

scores = scores(:,1);

if any(~isfinite(scores))
    scores(~isfinite(scores)) = 0;
end

if any(scores < 0) || abs(sum(scores)-1) > 0.05
    scores = exp(scores-max(scores));
    scores = scores/sum(scores);
else
    scores = scores/sum(scores);
end

[confidence,predIndex] = max(scores);

predIndex = max(1,min(5,predIndex));

grade = char(classNames(predIndex));

severityNames = ["No DR","Mild NPDR","Moderate NPDR","Severe NPDR","Proliferative DR"];
severity = char(severityNames(predIndex));

referrable = predIndex >= 3;

result.DRAnalysis = struct();
result.DRAnalysis.Grade = grade;
result.DRAnalysis.Severity = severity;
result.DRAnalysis.Confidence = confidence*100;
result.DRAnalysis.Referrable = referrable;
result.DRAnalysis.Probabilities = scores(:)';
result.DRAnalysis.ClassNames = cellstr(classNames);

xai = struct();
xai.Method = 'Gradient-weighted Class Activation Mapping';
xai.Layer = 'res5b_relu';
xai.AttentionMap = [];

try
    if isa(net,'dlnetwork')
        try
            scoreMap = gradCAM(net,X,predIndex,'FeatureLayer','res5b_relu');
        catch
            scoreMap = gradCAM(net,dlarray(X,'SSCB'),predIndex,'FeatureLayer','res5b_relu');
        end

        scoreMap = extractdata(scoreMap);
        scoreMap = squeeze(scoreMap);

        if ~isempty(scoreMap)
            scoreMap = double(scoreMap);
            scoreMap = scoreMap-min(scoreMap(:));

            mx = max(scoreMap(:));

            if mx > 0
                scoreMap = scoreMap/mx;
            end

            scoreMap = imresize(scoreMap,size(I,[1 2]));

            xai.AttentionMap = scoreMap;
            xai.Method = 'Grad-CAM';
        end
    else
        try
            scoreMap = gradCAM(net,X,predIndex,'FeatureLayer','res5b_relu');

            scoreMap = squeeze(scoreMap);

            if ~isempty(scoreMap)
                scoreMap = double(scoreMap);
                scoreMap = scoreMap-min(scoreMap(:));

                mx = max(scoreMap(:));

                if mx > 0
                    scoreMap = scoreMap/mx;
                end

                scoreMap = imresize(scoreMap,size(I,[1 2]));

                xai.AttentionMap = scoreMap;
                xai.Method = 'Grad-CAM';
            end
        catch
        end
    end
catch
end

if isempty(xai.AttentionMap)
    xai.Method = 'Model-based visual explanation unavailable';
    xai.Layer = 'res5b_relu';
end

result.XAI = xai;

m2 = struct();

m2Names = {'MA','HE','EX','SE'};
m2Files = { ...
    'M2_MA_U-Net.mat', ...
    'M2_HE_U-Net.mat', ...
    'M2_EX_U-Net.mat', ...
    'M2_SE_U-Net.mat'};

for k = 1:numel(m2Names)

    modelPath = fullfile(m2Dir,m2Files{k});

    lesion = struct();
    lesion.Available = isfile(modelPath);
    lesion.Probability = 0;
    lesion.AreaPercent = 0;
    lesion.Mask = [];

    if lesion.Available
        try
            [probability,mask] = runIDRiDLesionInference(imagePath,modelPath,0.20);

            lesion.Probability = double(probability);
            lesion.Mask = mask;
            lesion.AreaPercent = 100*nnz(mask)/numel(mask);
        catch
            lesion.Available = false;
        end
    end

    m2.(m2Names{k}) = lesion;
end

result.M2 = m2;

m6 = struct();

gray = rgb2gray(I);
green = I(:,:,2);
red = I(:,:,1);

background = imgaussfilt(im2double(green),12);
vesselEnhanced = mat2gray(im2double(green)-background);

level = graythresh(vesselEnhanced)*0.85;

vesselMask = vesselEnhanced < level;

vesselMask = bwareaopen(vesselMask,20);
vesselMask = imclose(vesselMask,strel('disk',1));

m6.VesselMask = vesselMask;
m6.VesselAreaPercent = 100*nnz(vesselMask)/numel(vesselMask);

redDouble = im2double(red);
discResponse = imgaussfilt(redDouble,18);

[~,maxIndex] = max(discResponse(:));

[discY,discX] = ind2sub(size(discResponse),maxIndex);

m6.OpticDiscX = discX;
m6.OpticDiscY = discY;

[h,w] = size(gray);

foveaX = round(0.68*w);
foveaY = round(0.55*h);

m6.FoveaX = foveaX;
m6.FoveaY = foveaY;

m6.Available = true;
m6.Method = 'Retinal vessel, optic disc and fovea analysis';

result.M6 = m6;

telemedicineModel = fullfile(root,'TELEMEDICINE_WORKFLOW','models','telemedicineWorkflow.slx');

m5 = struct();
m5.Available = isfile(telemedicineModel);
m5.ModelPath = telemedicineModel;
m5.Status = 'Available';

if ~m5.Available
    m5.Status = 'Model not found';
end

result.M5 = m5;

try
    enhanced = imread(fullfile(root,'IMAGE_QUALITY_AND_RETINAL_ANALYSIS','results','clahe_retinal_image.png'));
catch
    enhanced = I;
end

imwrite(I,fullfile(outDir,'input_image.png'));
imwrite(enhanced,fullfile(outDir,'enhanced_retinal_image.png'));
imwrite(uint8(vesselMask)*255,fullfile(outDir,'retinal_vessel_mask.png'));

for k = 1:numel(m2Names)
    lesion = m2.(m2Names{k});

    if lesion.Available && ~isempty(lesion.Mask)
        imwrite(uint8(lesion.Mask)*255, ...
            fullfile(outDir,[m2Names{k} '_mask.png']));
    end
end

if ~isempty(xai.AttentionMap)

    attention = uint8(max(0,min(1,xai.AttentionMap))*255);

    imwrite(attention,fullfile(outDir,'xai_attention_map.png'));

    figure('Visible','off');

    imshow(I);
    hold on;

    imagesc(xai.AttentionMap);
    axis image off;
    colormap hot;
    alpha(0.45);

    title(sprintf('%s - %s',grade,xai.Method),'Interpreter','none');

    exportgraphics(gca,fullfile(outDir,'xai_visualization.png'),'Resolution',150);

    close(gcf);

else
    imwrite(I,fullfile(outDir,'xai_visualization.png'));
end

fid = fopen(fullfile(outDir,'screening_summary.txt'),'w');

fprintf(fid,'ALOKA-AI SCREENING RESULT\n');
fprintf(fid,'=========================\n\n');
fprintf(fid,'Image: %s\n\n',imagePath);

fprintf(fid,'IMAGE QUALITY\n');
fprintf(fid,'Quality: %s\n',qualityResult.Quality);
fprintf(fid,'Quality Score: %.2f %%\n',qualityResult.QualityScore);
fprintf(fid,'Gradable: %s\n\n',mat2str(qualityResult.Gradable));

fprintf(fid,'DR CLASSIFICATION\n');
fprintf(fid,'Class: %s\n',grade);
fprintf(fid,'Severity: %s\n',severity);
fprintf(fid,'Confidence: %.2f %%\n',confidence*100);
fprintf(fid,'Referable: %s\n\n',mat2str(referrable));

fprintf(fid,'XAI\n');
fprintf(fid,'Method: %s\n',xai.Method);
fprintf(fid,'Layer: %s\n\n',xai.Layer);

fprintf(fid,'LESION ANALYSIS\n');
fprintf(fid,'Microaneurysm area: %.4f %%\n',m2.MA.AreaPercent);
fprintf(fid,'Hemorrhage area: %.4f %%\n',m2.HE.AreaPercent);
fprintf(fid,'Exudate area: %.4f %%\n',m2.EX.AreaPercent);
fprintf(fid,'Soft exudate area: %.4f %%\n\n',m2.SE.AreaPercent);

fprintf(fid,'RETINAL STRUCTURE\n');
fprintf(fid,'Vessel area: %.4f %%\n',m6.VesselAreaPercent);
fprintf(fid,'Optic disc: (%d,%d)\n',m6.OpticDiscX,m6.OpticDiscY);
fprintf(fid,'Fovea estimate: (%d,%d)\n\n',m6.FoveaX,m6.FoveaY);

fprintf(fid,'TELEMEDICINE\n');
fprintf(fid,'M5 status: %s\n',m5.Status);

fclose(fid);

result.OutputDirectory = outDir;

save(fullfile(outDir,'ALOKA_AI_Result.mat'),'result');

fprintf('\n');
fprintf('============================================\n');
fprintf('       ALOKA-AI INFERENCE COMPLETE\n');
fprintf('============================================\n');
fprintf('DR Class       : %s\n',grade);
fprintf('Severity       : %s\n',severity);
fprintf('Confidence     : %.2f %%\n',confidence*100);

if referrable
    fprintf('Screening      : REFERABLE DR\n');
else
    fprintf('Screening      : NON-REFERABLE DR\n');
end

fprintf('XAI Method     : %s\n',xai.Method);
fprintf('XAI Layer      : %s\n',xai.Layer);
fprintf('M2 Available   : MA=%s HE=%s EX=%s SE=%s\n', ...
    mat2str(m2.MA.Available), ...
    mat2str(m2.HE.Available), ...
    mat2str(m2.EX.Available), ...
    mat2str(m2.SE.Available));

fprintf('M6 Available   : %s\n',mat2str(m6.Available));
fprintf('M5 Available   : %s\n',mat2str(m5.Available));
fprintf('Output         : %s\n',outDir);
fprintf('============================================\n');

end