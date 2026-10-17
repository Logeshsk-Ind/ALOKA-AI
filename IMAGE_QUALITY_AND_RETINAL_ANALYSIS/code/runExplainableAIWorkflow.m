function result=runExplainableAIWorkflow(imgPath,modelPath,outDir)

root=fileparts(fileparts(fileparts(mfilename('fullpath'))));

if nargin<1 || isempty(imgPath)
    f=dir(fullfile(root,'data','test','*.png'));
    if isempty(f)
        error('Test image not found.')
    end
    imgPath=fullfile(f(1).folder,f(1).name);
end

if nargin<2 || isempty(modelPath)
    modelPath=fullfile(root,'DR_CLASSIFICATION_WORKFLOW','models','fastDRModel_baseline.mat');
end

if nargin<3 || isempty(outDir)
    outDir=fullfile(root,'EXPLAINABLE_AI_WORKFLOW','results');
end

if ~isfile(imgPath)
    error('Image file not found.')
end

if ~isfile(modelPath)
    error('Classification model not found.')
end

if ~exist(outDir,'dir')
    mkdir(outDir)
end

I=imread(imgPath);

if size(I,3)==1
    I=repmat(I,1,1,3);
end

D=load(modelPath);
names=fieldnames(D);
net=[];

for k=1:numel(names)
    v=D.(names{k});
    if isa(v,'DAGNetwork') || isa(v,'SeriesNetwork') || isa(v,'dlnetwork')
        net=v;
        break
    end
end

if isempty(net)
    error('Classification network not found in MAT file.')
end

inputSize=net.Layers(1).InputSize;

if numel(inputSize)>=2
    X=imresize(I,inputSize(1:2));
else
    X=imresize(I,[224 224]);
end

if isa(net,'dlnetwork')
    scores=extractdata(predict(net,dlarray(single(X),'SSCB')));
    scores=squeeze(scores);
    [confidence,idx]=max(scores);
    if isprop(net,'Classes')
        classes=net.Classes;
        prediction=classes(idx);
    else
        prediction="Class_"+string(idx);
    end
else
    [prediction,scores]=classify(net,X);
    confidence=max(scores);
end

G=im2gray(X);
G=im2single(G);

try
    layerNames=string({net.Layers.Name});
    targetLayer=layerNames(end-2);
catch
    targetLayer="";
end

gradcamAvailable=false;

if ~isa(net,'dlnetwork') && strlength(targetLayer)>0
    try
        scoreMap=gradCAM(net,X,prediction,'ReductionLayer',targetLayer);
        gradcamAvailable=true;
    catch
        try
            scoreMap=gradCAM(net,X,prediction);
            gradcamAvailable=true;
        catch
            scoreMap=[];
        end
    end
else
    scoreMap=[];
end

if ~gradcamAvailable
    [gx,gy]=gradient(G);
    edgeMap=sqrt(gx.^2+gy.^2);
    scoreMap=edgeMap;
    scoreMap=scoreMap-min(scoreMap(:));
    if max(scoreMap(:))>0
        scoreMap=scoreMap/max(scoreMap(:));
    end
end

scoreMap=imresize(scoreMap,[size(I,1) size(I,2)]);
scoreMap=max(0,min(1,scoreMap));

scoreMap=mat2gray(scoreMap); scoreMap=imresize(scoreMap,[size(I,1) size(I,2)]); cmap=hot(256); heatMap=ind2rgb(im2uint8(scoreMap),cmap); I=im2double(I); overlay=0.55*I+0.45*heatMap; overlay=im2uint8(min(max(overlay,0),1));
imwrite(overlay,fullfile(outDir,'gradcam_overlay.png'));

heatmap=uint8(scoreMap*255);
imwrite(heatmap,fullfile(outDir,'gradcam_heatmap.png'));

figure('Visible','off');
imshow(overlay);
title("Aloka-AI Explainable DR Screening");
exportgraphics(gca,fullfile(outDir,'explainable_ai_visualization.png'));
close;

reportFile=fullfile(outDir,'explainable_ai_report.txt');

fid=fopen(reportFile,'w');
fprintf(fid,'ALOKA-AI EXPLAINABLE AI REPORT\n');
fprintf(fid,'====================================\n');
fprintf(fid,'Image: %s\n',imgPath);
fprintf(fid,'Prediction: %s\n',string(prediction));
fprintf(fid,'Confidence: %.2f %%\n',double(confidence)*100);
fprintf(fid,'Explanation: Grad-CAM heatmap generated when supported by the classification network.\n');
fprintf(fid,'Fallback explanation: image-gradient saliency used when Grad-CAM was unavailable.\n');
fprintf(fid,'Interpretation: highlighted regions indicate image areas contributing to the visual explanation and are not a clinical diagnosis.\n');
fclose(fid);

result=struct;
result.ImagePath=imgPath;
result.ModelPath=modelPath;
result.Prediction=string(prediction);
result.ConfidencePercent=double(confidence)*100;
result.ExplanationMethod=string(ternary(gradcamAvailable,"Grad-CAM","Gradient Saliency"));
result.Status="Completed";
result.OverlayPath=fullfile(outDir,'gradcam_overlay.png');
result.HeatmapPath=fullfile(outDir,'gradcam_heatmap.png');
result.ReportPath=reportFile;

save(fullfile(outDir,'explainableAIResult.mat'),'result');

end

function y=ternary(c,a,b)
if c
    y=a;
else
    y=b;
end
end