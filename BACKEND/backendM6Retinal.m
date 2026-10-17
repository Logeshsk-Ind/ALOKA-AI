function result = backendM6Retinal(imagePath,m2)

I = imread(imagePath);

if ndims(I) == 2
    I = repmat(I,[1 1 3]);
end

if size(I,3) > 3
    I = I(:,:,1:3);
end

I = im2uint8(I);

R = I(:,:,1);
G = I(:,:,2);
B = I(:,:,3);

grayG = rgb2gray(I);

background = imgaussfilt(double(G),15);

vesselResponse = double(G)-background;

vesselResponse = mat2gray(vesselResponse);

threshold = graythresh(vesselResponse)*0.85;

vesselMask = vesselResponse > threshold;

vesselMask = bwareaopen(vesselMask,20);

vesselMask = imclose(vesselMask,strel('disk',1));

redResponse = imgaussfilt(double(R),15);

[~,idx] = max(redResponse(:));

[discY,discX] = ind2sub(size(redResponse),idx);

[h,w] = size(grayG);

foveaX = round(0.68*w);
foveaY = round(0.55*h);

result = struct();

result.ImagePath = imagePath;

result.VesselMask = vesselMask;
result.VesselPixelCount = nnz(vesselMask);
result.VesselPercent = 100*nnz(vesselMask)/numel(vesselMask);

result.OpticDiscX = discX;
result.OpticDiscY = discY;

result.FoveaX = foveaX;
result.FoveaY = foveaY;

result.MicroaneurysmMask = [];
result.HemorrhageMask = [];
result.ExudateMask = [];
result.SoftExudateMask = [];
result.NeovascularizationMask = [];

if isfield(m2,'MA') && m2.MA.available
    result.MicroaneurysmMask = m2.MA.mask;
end

if isfield(m2,'HE') && m2.HE.available
    result.HemorrhageMask = m2.HE.mask;
end

if isfield(m2,'EX') && m2.EX.available
    result.ExudateMask = m2.EX.mask;
end

if isfield(m2,'SE') && m2.SE.available
    result.SoftExudateMask = m2.SE.mask;
end

result.Status = 'AVAILABLE';

end