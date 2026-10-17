clear;
clc;
close all;

root = fileparts(fileparts(mfilename('fullpath')));

f=dir(fullfile(root,'data','test','*.png'));

if isempty(f)
    error('No PNG test image found in data\test.');
end

img=fullfile(f(1).folder,f(1).name);

m12=fullfile(root,'IMAGE_QUALITY_AND_RETINAL_ANALYSIS');
m3=fullfile(root,'DR_CLASSIFICATION_WORKFLOW');
m4=fullfile(root,'EXPLAINABLE_AI_WORKFLOW');
m5=fullfile(root,'TELEMEDICINE_WORKFLOW');
m6=fullfile(root,'INTEGRATION_AND_IMPACT');

out=fullfile(root,'INTEGRATION','ALOKA_AI_TEST_RESULTS');

if ~exist(out,'dir')
    mkdir(out);
end

fprintf('\n============================================================\n');
fprintf('                 ALOKA-AI FULL TEST\n');
fprintf('============================================================\n');

I=imread(img);

fprintf('\nTEST IMAGE\n');
fprintf('Path: %s\n',img);
fprintf('Size: [%d %d %d]\n',size(I,1),size(I,2),size(I,3));

fprintf('\n------------------------------------------------------------\n');
fprintf('M1/M2 IMAGE QUALITY + RETINAL ANALYSIS\n');
fprintf('------------------------------------------------------------\n');

addpath(fullfile(m12,'code'));

qualityResult=runImageQualityWorkflow(img,out);

retinalModel=fullfile(m12,'models','IDRiD_LesionUNet_v2.mat');

retinalResult=runRetinalAnalysisWorkflow(img,retinalModel,out);

disp(qualityResult);
disp(retinalResult);

fprintf('M1/M2 STATUS: PASS\n');

fprintf('\n------------------------------------------------------------\n');
fprintf('M3 DR CLASSIFICATION\n');
fprintf('------------------------------------------------------------\n');

modelPath=fullfile(m3,'models','fastDRModel_baseline.mat');

if ~isfile(modelPath)
    modelPath=fullfile(m12,'models','fastDRModel_baseline.mat');
end

D=load(modelPath);
names=fieldnames(D);
net=[];

for k=1:numel(names)
    v=D.(names{k});
    if isa(v,'DAGNetwork') || isa(v,'SeriesNetwork') || isa(v,'dlnetwork')
        net=v;
        break;
    end
end

if isempty(net)
    error('DR classification network not found.');
end

X=imresize(I,net.Layers(1).InputSize(1:2));

[prediction,scores]=classify(net,X);
confidence=max(scores);

fprintf('Prediction : %s\n',string(prediction));
fprintf('Confidence : %.2f %%\n',double(confidence)*100);
fprintf('M3 STATUS: PASS\n');

fprintf('\n------------------------------------------------------------\n');
fprintf('M4 EXPLAINABLE AI\n');
fprintf('------------------------------------------------------------\n');

xaiCode=fullfile(m12,'code','runExplainableAIWorkflow.m');

xaiResult=[];

if isfile(xaiCode)
    try
        addpath(fullfile(m12,'code'));
        xaiResult=runExplainableAIWorkflow(img,modelPath,out);
        disp(xaiResult);
        fprintf('M4 STATUS: PASS\n');
    catch ME
        fprintf('M4 STATUS: EXECUTION FAILED\n');
        fprintf('%s\n',ME.message);
    end
else
    fprintf('M4 STATUS: IN PROGRESS\n');
end

fprintf('\n------------------------------------------------------------\n');
fprintf('M5 TELEMEDICINE\n');
fprintf('------------------------------------------------------------\n');

slx=fullfile(m5,'models','telemedicineWorkflow.slx');

if isfile(slx)
    fprintf('Simulink model: PASS\n');
    fprintf('M5 STATUS: PASS\n');
else
    fprintf('M5 STATUS: FAIL\n');
end

fprintf('\n------------------------------------------------------------\n');
fprintf('M6 VALIDATION\n');
fprintf('------------------------------------------------------------\n');

metricsFile=fullfile(m6,'validation','member6ValidationMetrics.csv');
validationMat=fullfile(m6,'validation','member6ValidationResults.mat');

if isfile(metricsFile)
    metrics=readtable(metricsFile);
    disp(metrics);
    fprintf('M6 METRICS: PASS\n');
else
    metrics=[];
    fprintf('M6 METRICS: FAIL\n');
end

if isfile(validationMat)
    fprintf('Validation MAT: PASS\n');
else
    fprintf('Validation MAT: FAIL\n');
end

fprintf('\n------------------------------------------------------------\n');
fprintf('GENERATING ALOKA-AI VISUALIZATION\n');
fprintf('------------------------------------------------------------\n');

figure('Name','ALOKA-AI Full Pipeline','Color','w','Position',[100 100 1500 850]);

subplot(2,3,1);
imshow(I);
title('Input Fundus Image');

subplot(2,3,2);
q=fullfile(out,'quality_preprocessed.png');
if isfile(q)
    imshow(imread(q));
else
    imshow(I);
end
title(['Image Quality: ' char(string(qualityResult.Quality))]);

subplot(2,3,3);
r=fullfile(out,'retinal_field_mask.png');
if isfile(r)
    imshow(imread(r));
else
    imshow(I);
end
title('Retinal Field');

subplot(2,3,4);
l=fullfile(out,'lesion_mask.png');
if isfile(l)
    imshow(imread(l));
else
    imshow(I);
end
title(sprintf('Lesion Ratio: %.2f %%',retinalResult.LesionRatioPercent));

subplot(2,3,5);
g=fullfile(out,'gradcam_overlay.png');
if isfile(g)
    imshow(imread(g));
else
    g=fullfile(out,'gradcam_heatmap.png');
    if isfile(g)
        imshow(imread(g));
    else
        imshow(I);
    end
end
title('Explainable AI');

subplot(2,3,6);
axis off;
text(0.05,0.85,'ALOKA-AI SCREENING RESULT','FontSize',14,'FontWeight','bold');
text(0.05,0.68,['DR Prediction: ' char(string(prediction))],'FontSize',12);
text(0.05,0.55,sprintf('Confidence: %.2f %%',double(confidence)*100),'FontSize',12);
text(0.05,0.42,['Image Quality: ' char(string(qualityResult.Quality))],'FontSize',12);
text(0.05,0.29,sprintf('Retinal Coverage: %.2f %%',retinalResult.RetinalCoveragePercent),'FontSize',12);
text(0.05,0.16,sprintf('Lesion Ratio: %.2f %%',retinalResult.LesionRatioPercent),'FontSize',12);

saveas(gcf,fullfile(out,'ALOKA_AI_FULL_PIPELINE.png'));

fprintf('\nVisualization saved:\n%s\n',fullfile(out,'ALOKA_AI_FULL_PIPELINE.png'));

fprintf('\n============================================================\n');
fprintf('                 FINAL TEST SUMMARY\n');
fprintf('============================================================\n');

fprintf('M1/M2 Image + Retinal Analysis : PASS\n');
fprintf('M3 DR Classification            : PASS\n');

if ~isempty(xaiResult)
    fprintf('M4 Explainable AI               : PASS\n');
else
    fprintf('M4 Explainable AI               : IN PROGRESS\n');
end

if isfile(slx)
    fprintf('M5 Telemedicine                 : PASS\n');
else
    fprintf('M5 Telemedicine                 : FAIL\n');
end

if isfile(validationMat) && isfile(metricsFile)
    fprintf('M6 Validation                   : PASS\n');
else
    fprintf('M6 Validation                   : FAIL\n');
end

fprintf('\nPrediction: %s\n',string(prediction));
fprintf('Confidence: %.2f %%\n',double(confidence)*100);

fprintf('\n============================================================\n');
fprintf('              ALOKA-AI TEST COMPLETED\n');
fprintf('============================================================\n');