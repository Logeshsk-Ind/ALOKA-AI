clc; clear; close all;

%% PATHS

scriptFolder = fileparts(mfilename("fullpath"));
projectPath = char(java.io.File( ...
    fullfile(scriptFolder,"..","..")).getCanonicalPath());

modelPath = fullfile(projectPath,"models","fastDRModel_baseline.mat");
dataPath = fullfile(projectPath,"data","raw","aptos","colored_images");
reportFolder = fullfile(projectPath,"results","reports");

if ~isfolder(reportFolder)
    mkdir(reportFolder);
end

%% LOAD MODEL

load(modelPath,"trainedNet");

%% SELECT IMAGE

[fileName,filePath] = uigetfile( ...
    {"*.png;*.jpg","Fundus Images"}, ...
    "Select Fundus Image",dataPath);

if isequal(fileName,0)
    error("No image selected.");
end

imgPath = fullfile(filePath,fileName);
img = imread(imgPath);
img = imresize(img,[224 224]);

%% IMAGE QUALITY

gray = im2double(rgb2gray(img));

sharpness = var(imfilter(gray, ...
    fspecial("laplacian",0.2),"replicate"),0,"all");

brightness = mean(gray(:));
contrastValue = std(gray(:));
fov = nnz(gray > 0.05) / numel(gray);

qualityScore = 0.35*min(sharpness/0.002,1) + ...
               0.25*(1-min(abs(brightness-0.5)/0.5,1)) + ...
               0.20*min(contrastValue/0.2,1) + ...
               0.20*min(fov/0.5,1);

if qualityScore >= 0.70
    qualityDecision = "Good";
elseif qualityScore >= 0.45
    qualityDecision = "Borderline";
else
    qualityDecision = "Ungradeable";
end

%% CLASSIFICATION

[predictedLabel,scores] = classify(trainedNet,img);

confidence = max(scores)*100;

%% REFERABLE DR

if ismember(string(predictedLabel), ...
        ["Moderate","Severe","Proliferate_DR"])

    referral = "REFERABLE DR";
    recommendation = "Refer to ophthalmologist";

else

    referral = "NON-REFERABLE DR";
    recommendation = "Routine screening";

end

%% GRAD-CAM

map = gradCAM(trainedNet,img,predictedLabel);
map = imresize(map,[224 224]);

%% CREATE REPORT

figure("Position",[100 100 1200 650]);

subplot(2,3,[1 4]);
imshow(img);
title("Fundus Image");

subplot(2,3,[2 5]);
imshow(img);
hold on
h = imagesc(map);
colormap jet
set(h,"AlphaData",0.5);
title("Grad-CAM Explanation");
hold off

subplot(2,3,[3 6]);
axis off

reportText = {
    "DIABETIC RETINOPATHY SCREENING REPORT"
    " "
    "Prediction: " + string(predictedLabel)
    sprintf("Confidence: %.2f %%",confidence)
    " "
    sprintf("Image Quality Score: %.3f",qualityScore)
    "Image Quality: " + qualityDecision
    " "
    "Screening Result: " + referral
    " "
    "Recommendation:"
    recommendation
    " "
    "XAI Evidence:"
    "Highlighted regions influenced the AI prediction."
    };

text(0,0.95,reportText, ...
    "FontSize",13, ...
    "VerticalAlignment","top");

%% SAVE REPORT

[~,name,~] = fileparts(fileName);

timestamp = datestr(now,"yyyymmdd_HHMMSS");

reportPath = fullfile(reportFolder, ...
    name + "_DR_Report_" + timestamp + ".png");

exportgraphics(gcf,reportPath,"Resolution",300);

fprintf("\n====================================\n");
fprintf("DR SCREENING REPORT GENERATED\n");
fprintf("====================================\n");

fprintf("Prediction: %s\n",string(predictedLabel));
fprintf("Confidence: %.2f %%\n",confidence);
fprintf("Quality: %s\n",qualityDecision);
fprintf("Screening: %s\n",referral);
fprintf("Recommendation: %s\n",recommendation);

fprintf("\nReport saved:\n%s\n",reportPath);