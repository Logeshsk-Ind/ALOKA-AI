clc; clear; close all;

%% PATHS

scriptFolder = fileparts(mfilename("fullpath"));
projectPath = char(java.io.File( ...
    fullfile(scriptFolder,"..","..")).getCanonicalPath());

modelPath = fullfile(projectPath,"models","fastDRModel_baseline.mat");

outputFolder = fullfile(projectPath,"results","gradcam");

if ~isfolder(outputFolder)
    mkdir(outputFolder);
end

%% LOAD MODEL

if ~isfile(modelPath)
    error("Trained model not found.");
end

load(modelPath,"trainedNet");

fprintf("Model loaded successfully\n");

%% SELECT IMAGE

dataPath = fullfile(projectPath, ...
    "data","raw","aptos","colored_images");

[fileName,filePath] = uigetfile( ...
    {"*.png;*.jpg;*.jpeg","Image Files"}, ...
    "Select Fundus Image",dataPath);

if isequal(fileName,0)
    error("No image selected.");
end

imagePath = fullfile(filePath,fileName);

%% READ IMAGE

img = imread(imagePath);

if isempty(img)
    error("Image is empty.");
end

img = imresize(img,[224 224]);

%% PREDICTION

[predictedLabel,scores] = classify(trainedNet,img);

confidence = max(scores) * 100;

fprintf("\nPrediction: %s\n",string(predictedLabel));
fprintf("Confidence: %.2f %%\n",confidence);

%% GRAD-CAM

map = gradCAM(trainedNet,img,predictedLabel);

map = imresize(map,[224 224]);

%% DISPLAY

figure;

subplot(1,3,1)
imshow(img)
title("Original Fundus Image")

subplot(1,3,2)
imshow(map,[])
title("Grad-CAM Attention")

subplot(1,3,3)
imshow(img)
hold on

h = imagesc(map);
colormap jet
set(h,"AlphaData",0.5)

title(sprintf("%s | %.1f%%", ...
    string(predictedLabel),confidence))

hold off

%% SAVE

[~,name,~] = fileparts(fileName);

timestamp = datestr(now,"yyyymmdd_HHMMSS");

outputPath = fullfile(outputFolder, ...
    name + "_GradCAM_" + timestamp + ".png");

exportgraphics(gcf,outputPath,"Resolution",300);

fprintf("\nGrad-CAM saved successfully\n");
fprintf("%s\n",outputPath);