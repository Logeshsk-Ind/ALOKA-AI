function result = runM1ImageQuality()

clc;

fprintf('\n');
fprintf('============================================================\n');
fprintf('             ALOKA-AI M1 IMAGE QUALITY\n');
fprintf('============================================================\n');

projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));

imageFile = fullfile(projectRoot,'data','test','test_image.png');

if ~isfile(imageFile)
    error('Test image not found: %s',imageFile);
end

I = imread(imageFile);

if size(I,3) == 1
    I = repmat(I,[1 1 3]);
end

I = im2uint8(I);

gray = rgb2gray(I);

meanIntensity = mean(gray(:));
contrastValue = std(double(gray(:)));

lap = imfilter(double(gray),fspecial('laplacian',0.2),'replicate');
sharpnessValue = var(lap(:));

darkRatio = nnz(gray < 30) / numel(gray);
brightRatio = nnz(gray > 245) / numel(gray);

illuminationScore = 100 - abs(meanIntensity - 120) * 0.55;
illuminationScore = max(0,min(100,illuminationScore));

contrastScore = min(100,contrastValue * 2);

sharpnessScore = min(100,sharpnessValue / 30);

darkPenalty = min(30,darkRatio * 100);
brightPenalty = min(30,brightRatio * 100);

fieldMask = gray > 10;
fieldCoverage = 100 * nnz(fieldMask) / numel(fieldMask);

fieldScore = min(100,max(0,(fieldCoverage - 15) * 2));

qualityScore = ...
    0.30 * illuminationScore + ...
    0.25 * contrastScore + ...
    0.25 * sharpnessScore + ...
    0.20 * fieldScore;

qualityScore = qualityScore - darkPenalty * 0.20;
qualityScore = qualityScore - brightPenalty * 0.20;

qualityScore = max(0,min(100,qualityScore));

if qualityScore >= 70 && fieldCoverage >= 20
    quality = 'Good';
    gradable = true;
    recapture = false;
    recommendation = 'Image acceptable for DR screening.';
    enhancement = 'CLAHE + illumination normalization + denoising';
elseif qualityScore >= 45 && fieldCoverage >= 15
    quality = 'Borderline';
    gradable = true;
    recapture = false;
    recommendation = 'Image usable after enhancement; review image quality.';
    enhancement = 'CLAHE + illumination normalization + denoising';
else
    quality = 'Ungradable';
    gradable = false;
    recapture = true;
    recommendation = 'Recapture required with better focus, illumination and retinal field.';
    enhancement = 'Strong enhancement attempted; recapture recommended';
end

lab = rgb2lab(I);

L = lab(:,:,1) / 100;

L2 = adapthisteq(L,'NumTiles',[8 8],'ClipLimit',0.01);

lab(:,:,1) = L2 * 100;

enhanced = lab2rgb(lab);
enhanced = im2uint8(enhanced);

enhanced = imgaussfilt(enhanced,0.5);

result = struct;

result.ImagePath = imageFile;
result.ImageSize = size(I);
result.MeanIntensity = meanIntensity;
result.Contrast = contrastValue;
result.Sharpness = sharpnessValue;
result.DarkPixelRatio = darkRatio;
result.BrightPixelRatio = brightRatio;
result.RetinalFieldCoveragePercent = fieldCoverage;
result.QualityScore = qualityScore;
result.Quality = quality;
result.Gradable = gradable;
result.RecaptureRequired = recapture;
result.Recommendation = recommendation;
result.Enhancement = enhancement;

fprintf('Image                 : %s\n',imageFile);
fprintf('Mean Intensity        : %.4f\n',meanIntensity);
fprintf('Contrast              : %.4f\n',contrastValue);
fprintf('Sharpness             : %.4f\n',sharpnessValue);
fprintf('Retinal Field         : %.2f %%\n',fieldCoverage);
fprintf('Quality Score         : %.2f %%\n',qualityScore);
fprintf('Quality               : %s\n',quality);
fprintf('Gradable              : %s\n',string(gradable));
fprintf('Recapture Required    : %s\n',string(recapture));
fprintf('Recommendation        : %s\n',recommendation);
fprintf('Enhancement           : %s\n',enhancement);

resultDir = fullfile(projectRoot,...
    'IMAGE_QUALITY_AND_RETINAL_ANALYSIS',...
    'results',...
    'M1_ImageQuality');

if ~exist(resultDir,'dir')
    mkdir(resultDir);
end

imwrite(enhanced,fullfile(resultDir,'enhanced_test_image.png'));

save(fullfile(resultDir,'M1_ImageQuality_Result.mat'),'result');

fprintf('------------------------------------------------------------\n');
fprintf('Enhanced image saved:\n');
fprintf('%s\n',fullfile(resultDir,'enhanced_test_image.png'));
fprintf('Result saved:\n');
fprintf('%s\n',fullfile(resultDir,'M1_ImageQuality_Result.mat'));
fprintf('============================================================\n');

end