function result = runRetinalAnalysisWorkflow(imagePath)

if nargin < 1 || isempty(imagePath)
    root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    files = dir(fullfile(root,'data','test','*.png'));
    if isempty(files)
        files = dir(fullfile(root,'data','test','*.jpg'));
    end
    if isempty(files)
        error('No test image found.');
    end
    imagePath = fullfile(files(1).folder,files(1).name);
end

root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
baseDir = fullfile(root,'IMAGE_QUALITY_AND_RETINAL_ANALYSIS');
modelPath = fullfile(baseDir,'models','IDRiD_LesionUNet_v2.mat');
resultDir = fullfile(baseDir,'results');

if ~exist(resultDir,'dir')
    mkdir(resultDir);
end

I = imread(imagePath);

if size(I,3) == 1
    I = repmat(I,[1 1 3]);
end

I = im2uint8(I);

[h,w,~] = size(I);

R = double(I(:,:,1));
G = double(I(:,:,2));
B = double(I(:,:,3));

gray = rgb2gray(I);
grayD = double(gray);

retinalMask = G > 15 & G > 0.45*R & G > 0.45*B;
retinalMask = imfill(retinalMask,'holes');
retinalMask = imopen(retinalMask,strel('disk',3));
retinalMask = imclose(retinalMask,strel('disk',7));
retinalMask = bwareaopen(retinalMask,200);

if nnz(retinalMask) < 0.15*numel(retinalMask)
    retinalMask = gray > 8;
    retinalMask = imfill(retinalMask,'holes');
    retinalMask = bwareaopen(retinalMask,200);
end

retinalFieldPixels = nnz(retinalMask);
retinalCoverage = 100*retinalFieldPixels/numel(retinalMask);

edges = edge(gray,'Canny');
structuralEdges = edges & retinalMask;
structuralEdgePixels = nnz(structuralEdges);

green = im2single(I(:,:,2));
enhancedGreen = adapthisteq(green,'NumTiles',[8 8],'ClipLimit',0.01);

vesselResponse = imbothat(enhancedGreen,strel('disk',5));
vesselResponse = mat2gray(vesselResponse);

vesselThreshold = graythresh(vesselResponse);
vesselMask = vesselResponse > max(0.08,vesselThreshold);
vesselMask = vesselMask & retinalMask;
vesselMask = bwareaopen(vesselMask,4);
vesselMask = imclose(vesselMask,strel('disk',1));

vesselPixels = nnz(vesselMask);
vesselCoverage = 100*vesselPixels/max(retinalFieldPixels,1);

brightMap = mat2gray(imgaussfilt(grayD,7));

discCandidate = brightMap > 0.88;
discCandidate = discCandidate & retinalMask;
discCandidate = bwareaopen(discCandidate,50);

discStats = regionprops(discCandidate,'Area','Centroid','EquivDiameter','Circularity');

discFound = false;
discCentroid = [NaN NaN];
discDiameter = NaN;

if ~isempty(discStats)

    areas = [discStats.Area];
    circularity = [discStats.Circularity];

    valid = areas > 120 & areas < 0.12*retinalFieldPixels & circularity > 0.35;

    if any(valid)

        candidates = find(valid);

        scores = zeros(size(candidates));

        for k = 1:numel(candidates)

            c = discStats(candidates(k)).Centroid;

            edgeDistance = min([c(1),c(2),w-c(1),h-c(2)]);

            scores(k) = 0.5*areas(candidates(k)) + ...
                        100*circularity(candidates(k)) + ...
                        20*edgeDistance;

        end

        [~,p] = max(scores);

        idx = candidates(p);

        discFound = true;
        discCentroid = discStats(idx).Centroid;
        discDiameter = discStats(idx).EquivDiameter;

    end
end

darkMap = mat2gray(imgaussfilt(255-grayD,8));
darkMap(~retinalMask) = 0;

foveaFound = false;
foveaCentroid = [NaN NaN];
foveaConfidence = 0;
foveaDistanceFromDisc = NaN;

if discFound

    [X,Y] = meshgrid(1:w,1:h);

    dx = X-discCentroid(1);
    dy = Y-discCentroid(2);

    distance = sqrt(dx.^2 + dy.^2);

    targetDistance = 2.6*discDiameter;

    distanceScore = exp(-((distance-targetDistance)/(0.75*discDiameter)).^2);

    verticalScore = exp(-(abs(dy)/(0.85*discDiameter)).^2);

    discSide = sign(discCentroid(1)-w/2);

    if discSide > 0
        temporalMask = X < discCentroid(1);
    else
        temporalMask = X > discCentroid(1);
    end

    if discCentroid(1) > 0.70*w
        temporalMask = X < discCentroid(1);
    elseif discCentroid(1) < 0.30*w
        temporalMask = X > discCentroid(1);
    end

    validFoveaRegion = retinalMask & temporalMask;

    minDistance = 1.4*discDiameter;
    maxDistance = 4.0*discDiameter;

    validFoveaRegion = validFoveaRegion & ...
        distance >= minDistance & ...
        distance <= maxDistance;

    borderX = round(0.08*w);
    borderY = round(0.08*h);

    validFoveaRegion(1:borderY,:) = false;
    validFoveaRegion(end-borderY+1:end,:) = false;
    validFoveaRegion(:,1:borderX) = false;
    validFoveaRegion(:,end-borderX+1:end) = false;

    localDark = mat2gray(imgaussfilt(255-grayD,12));

    localMean = imgaussfilt(grayD,15);
    localContrast = mat2gray(localMean-grayD);

    foveaScore = 0.50*localDark + ...
                 0.30*localContrast + ...
                 0.20*distanceScore;

    foveaScore = foveaScore .* verticalScore;
    foveaScore(~validFoveaRegion) = 0;

    foveaScore = imgaussfilt(foveaScore,3);

    [peakValue,peakIndex] = max(foveaScore(:));

    [fy,fx] = ind2sub([h w],peakIndex);

    foveaDistanceFromDisc = sqrt( ...
        (fx-discCentroid(1))^2 + ...
        (fy-discCentroid(2))^2);

    distanceAgreement = exp(-abs(foveaDistanceFromDisc-targetDistance)/(discDiameter));

    foveaConfidence = 100*(0.7*peakValue + 0.3*distanceAgreement);

    if peakValue > 0.30 && ...
       foveaDistanceFromDisc >= minDistance && ...
       foveaDistanceFromDisc <= maxDistance

        foveaFound = true;
        foveaCentroid = [fx fy];

    end

end

S = load(modelPath);

if ~isfield(S,'trainedUNet')
    error('trainedUNet not found in model file.');
end

net = S.trainedUNet;

if isfield(S,'classNames')
    classNames = string(S.classNames);
else
    classNames = ["background","lesion"];
end

inputSize = S.imageSize;

Xinput = imresize(I,inputSize(1:2));
Xsingle = im2single(Xinput);

dlX = dlarray(Xsingle,'SSC');

Y = predict(net,dlX);

if iscell(Y)
    Y = Y{1};
end

Y = extractdata(Y);
Y = squeeze(Y);

numClasses = numel(classNames);

if ndims(Y) == 2
    error('Unexpected segmentation output.');
end

dims = size(Y);
classDim = find(dims == numClasses,1,'last');

if isempty(classDim)
    error('Segmentation class dimension not found.');
end

if classDim ~= 3

    order = 1:ndims(Y);
    order([3 classDim]) = order([classDim 3]);
    Y = permute(Y,order);

end

if ndims(Y) == 4
    Y = Y(:,:,:,1);
end

Y = double(Y);

if max(Y(:)) > 1 || min(Y(:)) < 0

    Y = exp(Y-max(Y,[],3));
    Y = Y./sum(Y,3);

end

lesionClassIndex = [];

for k = 1:numel(classNames)

    name = lower(strtrim(string(classNames(k))));

    if contains(name,"lesion") || contains(name,"micro") || contains(name,"dr")
        lesionClassIndex = k;
        break
    end

end

if isempty(lesionClassIndex)
    lesionClassIndex = min(2,numClasses);
end

lesionProbability = Y(:,:,lesionClassIndex);

lesionProbability = imresize(lesionProbability,[h w],'bilinear');
lesionProbability(~retinalMask) = 0;

rawLesionMask = lesionProbability >= 0.50;

thresholds = [0.50 0.60 0.70 0.80 0.90];
ratios = zeros(size(thresholds));

for k = 1:numel(thresholds)

    tempMask = lesionProbability >= thresholds(k);
    tempMask = tempMask & retinalMask;

    ratios(k) = 100*nnz(tempMask)/max(retinalFieldPixels,1);

end

selectedThreshold = 0.80;

if ratios(4) > 15
    selectedThreshold = 0.90;
elseif ratios(3) > 15
    selectedThreshold = 0.80;
elseif ratios(2) > 20
    selectedThreshold = 0.70;
end

lesionMask = lesionProbability >= selectedThreshold;
lesionMask = lesionMask & retinalMask;

lesionMask = bwareaopen(lesionMask,3);
lesionMask = imopen(lesionMask,strel('disk',1));

lesionPixels = nnz(lesionMask);
lesionRatio = 100*lesionPixels/max(retinalFieldPixels,1);

if lesionRatio < 1
    lesionAssessment = 'Low';
elseif lesionRatio < 5
    lesionAssessment = 'Moderate';
else
    lesionAssessment = 'High';
end

components = bwconncomp(lesionMask);

smallLesions = false(h,w);

if components.NumObjects > 0

    areas = cellfun(@numel,components.PixelIdxList);

    for k = 1:numel(areas)

        if areas(k) >= 3 && areas(k) <= 80
            smallLesions(components.PixelIdxList{k}) = true;
        end

    end

else

    areas = [];

end

microCandidatePixels = nnz(smallLesions);
microaneurysmCandidate = microCandidatePixels >= 3;

brightLesionCandidate = lesionMask & enhancedGreen > 0.68;
brightLesionCandidate = bwareaopen(brightLesionCandidate,3);

exudatePixels = nnz(brightLesionCandidate);
exudateCandidate = exudatePixels >= 3;

darkLesionCandidate = lesionMask & enhancedGreen < 0.42;
darkLesionCandidate = bwareaopen(darkLesionCandidate,3);

hemorrhagePixels = nnz(darkLesionCandidate);
hemorrhageCandidate = hemorrhagePixels >= 3;

vesselSkeleton = bwmorph(vesselMask,'skel',Inf);
branchPoints = bwmorph(vesselSkeleton,'branchpoints');

vesselEndpoints = bwmorph(vesselSkeleton,'endpoints');

branchCount = nnz(branchPoints);
endpointCount = nnz(vesselEndpoints);

vesselLength = nnz(vesselSkeleton);

if vesselLength > 0
    branchDensity = branchCount/vesselLength;
else
    branchDensity = 0;
end

if discFound

    [VX,VY] = meshgrid(1:w,1:h);

    discDistanceMap = sqrt( ...
        (VX-discCentroid(1)).^2 + ...
        (VY-discCentroid(2)).^2);

    peripapillaryRegion = retinalMask & ...
        discDistanceMap <= 2.2*discDiameter;

    peripapillaryVessels = vesselSkeleton & peripapillaryRegion;

    peripapillaryLength = nnz(peripapillaryVessels);

    peripapillaryArea = nnz(peripapillaryRegion);

    peripapillaryDensity = peripapillaryLength/max(peripapillaryArea,1);

else

    peripapillaryLength = 0;
    peripapillaryDensity = 0;
    peripapillaryRegion = false(h,w);

end

fineVesselResponse = imbothat(enhancedGreen,strel('disk',2));
fineVesselResponse = mat2gray(fineVesselResponse);

fineVesselMask = fineVesselResponse > 0.55;
fineVesselMask = fineVesselMask & retinalMask;
fineVesselMask = bwareaopen(fineVesselMask,3);

fineVesselPixels = nnz(fineVesselMask);

if vesselPixels > 0
    fineVesselFraction = fineVesselPixels/vesselPixels;
else
    fineVesselFraction = 0;
end

tortuosityProxy = branchDensity;

nvScore = 0;

if peripapillaryDensity > 0.010
    nvScore = nvScore + 25;
end

if fineVesselFraction > 0.20
    nvScore = nvScore + 25;
end

if tortuosityProxy > 0.004
    nvScore = nvScore + 20;
end

if branchCount >= 15
    nvScore = nvScore + 15;
end

if endpointCount >= 20
    nvScore = nvScore + 15;
end

nvScore = min(nvScore,100);

neovascularizationCandidate = nvScore >= 65;

if nvScore >= 65
    neovascularizationEvidence = 'Possible candidate evidence';
elseif nvScore >= 40
    neovascularizationEvidence = 'Indeterminate candidate evidence';
else
    neovascularizationEvidence = 'No strong candidate evidence';
end

nvCandidateMask = false(h,w);

if discFound

    nvCandidateMask = vesselSkeleton & peripapillaryRegion;

    if nnz(nvCandidateMask) < 20
        nvCandidateMask = fineVesselMask & peripapillaryRegion;
    end

else

    nvCandidateMask = fineVesselMask;

end

if microaneurysmCandidate
    microEvidence = 'Candidate evidence present';
else
    microEvidence = 'No candidate evidence';
end

if exudateCandidate
    exudateEvidence = 'Candidate evidence present';
else
    exudateEvidence = 'No candidate evidence';
end

if hemorrhageCandidate
    hemorrhageEvidence = 'Candidate evidence present';
else
    hemorrhageEvidence = 'No candidate evidence';
end

lesionOverlay = I;

lesionOverlay(:,:,1) = uint8(min(255,double(lesionOverlay(:,:,1)) + 160*double(lesionMask)));
lesionOverlay(:,:,2) = uint8(double(lesionOverlay(:,:,2)).*(1-0.45*double(lesionMask)));
lesionOverlay(:,:,3) = uint8(double(lesionOverlay(:,:,3)).*(1-0.45*double(lesionMask)));

structureOverlay = I;

structureOverlay(:,:,1) = uint8(min(255,double(structureOverlay(:,:,1)) + 100*double(structuralEdges)));
structureOverlay(:,:,2) = uint8(double(structureOverlay(:,:,2)).*(1-0.30*double(structuralEdges)));

vesselOverlay = I;

vesselOverlay(:,:,1) = uint8(double(vesselOverlay(:,:,1)).*(1-0.35*double(vesselMask)));
vesselOverlay(:,:,2) = uint8(min(255,double(vesselOverlay(:,:,2)) + 120*double(vesselMask)));

nvOverlay = I;

nvOverlay(:,:,1) = uint8(min(255,double(nvOverlay(:,:,1)) + 170*double(nvCandidateMask)));
nvOverlay(:,:,2) = uint8(double(nvOverlay(:,:,2)).*(1-0.45*double(nvCandidateMask)));
nvOverlay(:,:,3) = uint8(double(nvOverlay(:,:,3)).*(1-0.45*double(nvCandidateMask)));

discFoveaOverlay = I;

if discFound
    discFoveaOverlay = insertShape( ...
        discFoveaOverlay, ...
        'circle', ...
        [discCentroid discDiameter/2], ...
        'Color','white', ...
        'LineWidth',3);
end

if foveaFound
    discFoveaOverlay = insertMarker( ...
        discFoveaOverlay, ...
        foveaCentroid, ...
        'x', ...
        'Color','white', ...
        'Size',12);
end

imwrite(uint8(retinalMask)*255,fullfile(resultDir,'retinal_field_mask.png'));
imwrite(uint8(structuralEdges)*255,fullfile(resultDir,'retinal_structure_edges.png'));
imwrite(uint8(vesselMask)*255,fullfile(resultDir,'vessel_mask.png'));
imwrite(vesselOverlay,fullfile(resultDir,'vessel_analysis_overlay.png'));

imwrite(uint8(lesionProbability*255), ...
    fullfile(resultDir,'lesion_probability_map.png'));

imwrite(uint8(rawLesionMask)*255, ...
    fullfile(resultDir,'lesion_raw_mask.png'));

imwrite(uint8(lesionMask)*255, ...
    fullfile(resultDir,'lesion_mask.png'));

imwrite(lesionOverlay, ...
    fullfile(resultDir,'retinal_lesion_overlay.png'));

imwrite(structureOverlay, ...
    fullfile(resultDir,'retinal_structure_overlay.png'));

imwrite(discFoveaOverlay, ...
    fullfile(resultDir,'optic_disc_fovea_overlay.png'));

imwrite(uint8(nvCandidateMask)*255, ...
    fullfile(resultDir,'neovascularization_candidate_mask.png'));

imwrite(nvOverlay, ...
    fullfile(resultDir,'neovascularization_candidate_overlay.png'));

result.ImagePath = imagePath;
result.ModelPath = modelPath;
result.ImageSize = size(I);

result.RetinalFieldPixels = retinalFieldPixels;
result.RetinalCoveragePercent = retinalCoverage;

result.StructuralEdgePixels = structuralEdgePixels;

result.VesselPixels = vesselPixels;
result.VesselCoveragePercent = vesselCoverage;

result.OpticDiscDetected = discFound;
result.OpticDiscCentroid = discCentroid;
result.OpticDiscDiameter = discDiameter;

result.FoveaDetected = foveaFound;
result.FoveaCentroid = foveaCentroid;
result.FoveaConfidencePercent = foveaConfidence;
result.FoveaDistanceFromDisc = foveaDistanceFromDisc;

result.ClassNames = classNames;
result.LesionClassIndex = lesionClassIndex;
result.LesionClassName = classNames(lesionClassIndex);

result.LesionThreshold = selectedThreshold;
result.LesionPixels = lesionPixels;
result.LesionRatioPercent = lesionRatio;
result.RawLesionRatioPercent = 100*nnz(rawLesionMask)/max(retinalFieldPixels,1);
result.LesionAssessment = lesionAssessment;

result.MicroaneurysmCandidate = microaneurysmCandidate;
result.MicroaneurysmEvidence = microEvidence;

result.ExudateCandidate = exudateCandidate;
result.ExudateEvidence = exudateEvidence;

result.HemorrhageCandidate = hemorrhageCandidate;
result.HemorrhageEvidence = ...
    ternary(hemorrhageCandidate,'Candidate evidence present','No candidate evidence');

result.NeovascularizationCandidate = neovascularizationCandidate;
result.NeovascularizationEvidence = neovascularizationEvidence;
result.NeovascularizationScore = nvScore;
result.NeovascularizationBranchPoints = branchCount;
result.NeovascularizationEndpoints = endpointCount;
result.NeovascularizationFineVesselFraction = fineVesselFraction;
result.NeovascularizationPeripapillaryDensity = peripapillaryDensity;

result.ModelStatus = 'Loaded and inference completed';

result.EvidenceStatus = ...
    'Prototype computer-vision evidence; lesion subtype and neovascularization findings require clinical validation';

save(fullfile(resultDir,'retinalAnalysisResult.mat'),'result');

fid = fopen(fullfile(resultDir,'retinal_analysis_report.txt'),'w');

fprintf(fid,'ALOKA-AI RETINAL STRUCTURE AND LESION ANALYSIS\n');
fprintf(fid,'===============================================\n\n');

fprintf(fid,'Image: %s\n',imagePath);
fprintf(fid,'Image Size: %d x %d x %d\n',size(I,1),size(I,2),size(I,3));

fprintf(fid,'\nRETINAL FIELD\n');
fprintf(fid,'Retinal Field Pixels: %d\n',retinalFieldPixels);
fprintf(fid,'Retinal Coverage: %.2f %%\n',retinalCoverage);

fprintf(fid,'\nRETINAL STRUCTURE\n');
fprintf(fid,'Structural Edge Pixels: %d\n',structuralEdgePixels);
fprintf(fid,'Vessel Pixels: %d\n',vesselPixels);
fprintf(fid,'Vessel Coverage: %.2f %%\n',vesselCoverage);

fprintf(fid,'Optic Disc Detected: %s\n',mat2str(discFound));
fprintf(fid,'Optic Disc Centroid: [%.2f %.2f]\n',discCentroid);
fprintf(fid,'Optic Disc Diameter: %.2f\n',discDiameter);

fprintf(fid,'Fovea Detected: %s\n',mat2str(foveaFound));
fprintf(fid,'Fovea Centroid: [%.2f %.2f]\n',foveaCentroid);
fprintf(fid,'Fovea Confidence: %.2f %%\n',foveaConfidence);
fprintf(fid,'Fovea Distance From Disc: %.2f pixels\n',foveaDistanceFromDisc);

fprintf(fid,'\nLESION MODEL\n');
fprintf(fid,'Class Names: %s\n',strjoin(classNames,', '));
fprintf(fid,'Lesion Class: %s\n',classNames(lesionClassIndex));
fprintf(fid,'Lesion Class Index: %d\n',lesionClassIndex);
fprintf(fid,'Selected Threshold: %.2f\n',selectedThreshold);
fprintf(fid,'Raw Lesion Ratio: %.2f %%\n',result.RawLesionRatioPercent);
fprintf(fid,'Filtered Lesion Ratio: %.2f %%\n',lesionRatio);
fprintf(fid,'Lesion Assessment: %s\n',lesionAssessment);

fprintf(fid,'\nLESION EVIDENCE\n');
fprintf(fid,'Microaneurysm Candidate: %s\n',mat2str(microaneurysmCandidate));
fprintf(fid,'Microaneurysm Evidence: %s\n',microEvidence);
fprintf(fid,'Exudate Candidate: %s\n',mat2str(exudateCandidate));
fprintf(fid,'Exudate Evidence: %s\n',exudateEvidence);
fprintf(fid,'Hemorrhage Candidate: %s\n',mat2str(hemorrhageCandidate));
fprintf(fid,'Hemorrhage Evidence: %s\n',result.HemorrhageEvidence);

fprintf(fid,'\nNEOVASCULARIZATION EVIDENCE\n');
fprintf(fid,'Candidate: %s\n',mat2str(neovascularizationCandidate));
fprintf(fid,'Evidence: %s\n',neovascularizationEvidence);
fprintf(fid,'Evidence Score: %.2f / 100\n',nvScore);
fprintf(fid,'Branch Points: %d\n',branchCount);
fprintf(fid,'Endpoints: %d\n',endpointCount);
fprintf(fid,'Fine Vessel Fraction: %.4f\n',fineVesselFraction);
fprintf(fid,'Peripapillary Vessel Density: %.6f\n',peripapillaryDensity);

fprintf(fid,'\nMODEL STATUS\n');
fprintf(fid,'Model Status: Loaded and inference completed\n');

fprintf(fid,'\nVALIDATION STATUS\n');
fprintf(fid,'This is a prototype computer-vision workflow.\n');
fprintf(fid,'Clinical validation requires expert-annotated reference data and independent testing.\n');

fclose(fid);

fprintf('\n============================================================\n');
fprintf('             ALOKA-AI RETINAL ANALYSIS\n');
fprintf('============================================================\n');
fprintf('Retinal Coverage       : %.2f %%\n',retinalCoverage);
fprintf('Structural Edges       : %d\n',structuralEdgePixels);
fprintf('Vessel Coverage        : %.2f %%\n',vesselCoverage);
fprintf('Optic Disc             : %s\n',mat2str(discFound));
fprintf('Fovea                  : %s\n',mat2str(foveaFound));
fprintf('Fovea Confidence       : %.2f %%\n',foveaConfidence);
fprintf('Fovea Distance         : %.2f pixels\n',foveaDistanceFromDisc);
fprintf('Lesion Class           : %s\n',classNames(lesionClassIndex));
fprintf('Lesion Threshold       : %.2f\n',selectedThreshold);
fprintf('Raw Lesion Ratio       : %.2f %%\n',result.RawLesionRatioPercent);
fprintf('Filtered Lesion Ratio  : %.2f %%\n',lesionRatio);
fprintf('Lesion Assessment      : %s\n',lesionAssessment);
fprintf('Microaneurysm Evidence : %s\n',microEvidence);
fprintf('Exudate Evidence       : %s\n',exudateEvidence);
fprintf('Hemorrhage Evidence    : %s\n',result.HemorrhageEvidence);
fprintf('NV Evidence            : %s\n',neovascularizationEvidence);
fprintf('NV Score               : %.2f / 100\n',nvScore);
fprintf('NV Branch Points       : %d\n',branchCount);
fprintf('NV Endpoints            : %d\n',endpointCount);
fprintf('Model Status           : Loaded and inference completed\n');
fprintf('============================================================\n');

end

function out = ternary(condition,a,b)

if condition
    out = a;
else
    out = b;
end

end