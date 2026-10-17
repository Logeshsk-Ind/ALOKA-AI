function result = runRetinalStructureAnalysis()

clc;

fprintf('\n');
fprintf('============================================================\n');
fprintf('        ALOKA-AI RETINAL STRUCTURE ANALYSIS\n');
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

R = I(:,:,1);
G = I(:,:,2);
B = I(:,:,3);

gray = rgb2gray(I);

fprintf('Image loaded successfully.\n');

%% Vessel analysis

Gf = im2double(G);

background = imgaussfilt(Gf,7);

vesselResponse = background - Gf;

vesselResponse = mat2gray(vesselResponse);

vesselThreshold = graythresh(vesselResponse);

vesselMask = vesselResponse > vesselThreshold * 0.85;

vesselMask = bwareaopen(vesselMask,20);

%% Optic disc localization

Rdouble = im2double(R);

discResponse = imgaussfilt(Rdouble,12);

[~,linearIndex] = max(discResponse(:));

[discY,discX] = ind2sub(size(discResponse),linearIndex);

%% Fovea estimate

[h,w] = size(gray);

foveaX = round(0.68*w);
foveaY = round(0.55*h);

%% Visualization

figure('Name','ALOKA-AI Retinal Structure Analysis');

imshow(I);
hold on;

plot(discX,discY,'r+','MarkerSize',18,'LineWidth',2);

plot(foveaX,foveaY,'b+','MarkerSize',18,'LineWidth',2);

contour(vesselMask,[0.5 0.5],'g','LineWidth',0.5);

title('Retinal Structure Analysis');

legend('Optic Disc','Fovea Estimate','Vessel Map');

hold off;

result = struct;

result.ImagePath = imageFile;
result.VesselMask = vesselMask;
result.OpticDiscX = discX;
result.OpticDiscY = discY;
result.FoveaX = foveaX;
result.FoveaY = foveaY;

result.VesselCoveragePercent = ...
    100 * nnz(vesselMask) / numel(vesselMask);

result.Status = 'Prototype structural analysis';

resultDir = fullfile(projectRoot,...
    'IMAGE_QUALITY_AND_RETINAL_ANALYSIS',...
    'results',...
    'RetinalStructure');

if ~exist(resultDir,'dir')
    mkdir(resultDir);
end

imwrite(uint8(vesselMask)*255,...
    fullfile(resultDir,'vessel_mask.png'));

save(fullfile(resultDir,'RetinalStructure_Result.mat'),'result');

fprintf('\nOptic Disc           : (%d,%d)\n',discX,discY);
fprintf('Fovea Estimate       : (%d,%d)\n',foveaX,foveaY);
fprintf('Vessel Coverage      : %.2f %%\n',result.VesselCoveragePercent);

fprintf('\nResult saved:\n');
fprintf('%s\n',fullfile(resultDir,'RetinalStructure_Result.mat'));

fprintf('\nNOTE: Vessel/disc/fovea detection here is a prototype.\n');
fprintf('Benchmark validation is required before clinical claims.\n');

fprintf('============================================================\n');

end