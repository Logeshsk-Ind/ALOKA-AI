function result = runImageQualityWorkflow(imagePath)

if nargin < 1 || isempty(imagePath)
    root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    testDir = fullfile(root,'data','test');
    files = dir(fullfile(testDir,'*.png'));
    if isempty(files)
        files = dir(fullfile(testDir,'*.jpg'));
    end
    if isempty(files)
        error('No test image found.');
    end
    imagePath = fullfile(files(1).folder,files(1).name);
end

root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
resultDir = fullfile(root,'IMAGE_QUALITY_AND_RETINAL_ANALYSIS','results');
if ~exist(resultDir,'dir')
    mkdir(resultDir);
end

I = imread(imagePath);

if size(I,3) == 1
    I = repmat(I,[1 1 3]);
end

I = im2uint8(I);
G = rgb2gray(I);

meanIntensity = mean(double(G(:)));
contrastValue = std(double(G(:)));
grad = imgradient(G);
sharpnessValue = var(double(grad(:)));
HSV = rgb2hsv(I);
saturationValue = mean(HSV(:,:,2),'all');

darkPixelRatio = mean(G(:) < 20);
brightPixelRatio = mean(G(:) > 245);

R = I(:,:,1);
Gch = I(:,:,2);
B = I(:,:,3);

retinalMask = (double(Gch) > 25) & ...
             (double(Gch) > 0.55*double(R)) & ...
             (double(Gch) > 0.55*double(B));

retinalMask = imfill(retinalMask,'holes');
retinalMask = bwareaopen(retinalMask,100);
retinalMask = imclose(retinalMask,strel('disk',5));

fieldCoverage = nnz(retinalMask)/numel(retinalMask)*100;

claheImage = adapthisteq(G,'NumTiles',[8 8],'ClipLimit',0.01);

background = imgaussfilt(double(G),25);
normalized = mat2gray(double(G)./(background+1));
normalized = im2uint8(normalized);

denoised = imgaussfilt(I,0.6);

focusScore = min(sharpnessValue/500,1);
contrastScore = min(contrastValue/50,1);
illuminationScore = 1-min(abs(meanIntensity-110)/110,1);
fovScore = min(fieldCoverage/50,1);

qualityScore = 100*(0.35*focusScore + ...
                    0.25*contrastScore + ...
                    0.20*illuminationScore + ...
                    0.20*fovScore);

qualityScore = max(0,min(100,qualityScore));

qualityReasons = {};

if sharpnessValue < 100
    qualityReasons{end+1} = 'Low focus';
end

if contrastValue < 15
    qualityReasons{end+1} = 'Low contrast';
end

if meanIntensity < 30 || meanIntensity > 220
    qualityReasons{end+1} = 'Poor illumination';
end

if fieldCoverage < 30
    qualityReasons{end+1} = 'Insufficient retinal field';
end

if darkPixelRatio > 0.35
    qualityReasons{end+1} = 'Excessive dark pixels';
end

if isempty(qualityReasons) && qualityScore >= 60
    quality = 'Good';
    gradable = true;
    recapture = false;
    recommendation = 'Image acceptable for DR screening.';
elseif qualityScore >= 40
    quality = 'Borderline';
    gradable = true;
    recapture = false;
    recommendation = 'Proceed with caution; image quality is borderline.';
else
    quality = 'Ungradable';
    gradable = false;
    recapture = true;
    recommendation = 'Recapture fundus image before screening.';
end

if ~isempty(qualityReasons)
    reasonText = strjoin(qualityReasons,'; ');
else
    reasonText = 'No major quality issue detected.';
end

imwrite(claheImage,fullfile(resultDir,'clahe_retinal_image.png'));
imwrite(normalized,fullfile(resultDir,'illumination_normalized.png'));
imwrite(denoised,fullfile(resultDir,'denoised_fundus_image.png'));
imwrite(uint8(retinalMask)*255,fullfile(resultDir,'retinal_field_quality_mask.png'));

result.ImagePath = imagePath;
result.ImageSize = size(I);
result.MeanIntensity = meanIntensity;
result.Contrast = contrastValue;
result.Sharpness = sharpnessValue;
result.Saturation = saturationValue;
result.DarkPixelRatio = darkPixelRatio;
result.BrightPixelRatio = brightPixelRatio;
result.RetinalFieldCoveragePercent = fieldCoverage;
result.QualityScore = qualityScore;
result.Quality = quality;
result.Gradable = gradable;
result.RecaptureRequired = recapture;
result.Recommendation = recommendation;
result.QualityReasons = reasonText;
result.Enhancement = 'CLAHE + illumination normalization + denoising';

save(fullfile(resultDir,'imageQualityResult.mat'),'result');

fid = fopen(fullfile(resultDir,'image_quality_report.txt'),'w');

fprintf(fid,'ALOKA-AI IMAGE QUALITY ASSESSMENT\n');
fprintf(fid,'=================================\n\n');
fprintf(fid,'Image: %s\n',imagePath);
fprintf(fid,'Image Size: %d x %d x %d\n',size(I,1),size(I,2),size(I,3));
fprintf(fid,'Mean Intensity: %.4f\n',meanIntensity);
fprintf(fid,'Contrast: %.4f\n',contrastValue);
fprintf(fid,'Sharpness: %.4f\n',sharpnessValue);
fprintf(fid,'Saturation: %.4f\n',saturationValue);
fprintf(fid,'Dark Pixel Ratio: %.4f\n',darkPixelRatio);
fprintf(fid,'Bright Pixel Ratio: %.4f\n',brightPixelRatio);
fprintf(fid,'Retinal Field Coverage: %.2f %%\n',fieldCoverage);
fprintf(fid,'Quality Score: %.2f %%\n',qualityScore);
fprintf(fid,'Quality: %s\n',quality);
fprintf(fid,'Gradable: %s\n',mat2str(gradable));
fprintf(fid,'Recapture Required: %s\n',mat2str(recapture));
fprintf(fid,'Recommendation: %s\n',recommendation);
fprintf(fid,'Quality Findings: %s\n',reasonText);
fprintf(fid,'Enhancement: CLAHE + illumination normalization + denoising\n');

fclose(fid);

fprintf('\n============================================================\n');
fprintf('             ALOKA-AI IMAGE QUALITY\n');
fprintf('============================================================\n');
fprintf('Image                 : %s\n',imagePath);
fprintf('Mean Intensity        : %.4f\n',meanIntensity);
fprintf('Contrast              : %.4f\n',contrastValue);
fprintf('Sharpness             : %.4f\n',sharpnessValue);
fprintf('Retinal Field         : %.2f %%\n',fieldCoverage);
fprintf('Quality Score         : %.2f %%\n',qualityScore);
fprintf('Quality               : %s\n',quality);
fprintf('Gradable              : %s\n',mat2str(gradable));
fprintf('Recapture Required    : %s\n',mat2str(recapture));
fprintf('Recommendation        : %s\n',recommendation);
fprintf('Enhancement           : CLAHE + normalization + denoising\n');
fprintf('============================================================\n');

end