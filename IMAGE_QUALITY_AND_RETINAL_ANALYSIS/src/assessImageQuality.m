function quality = assessImageQuality(img)

if isempty(img)
    error("Input image is empty.");
end

if size(img,3) == 3
    gray = rgb2gray(img);
else
    gray = img;
end

gray = im2double(gray);

% Sharpness
lap = imfilter(gray,[0 1 0;1 -4 1;0 1 0],"replicate");
sharpness = var(lap(:));

% Brightness
brightness = mean(gray(:));

% Contrast
contrast = std(gray(:));

% Field of View
mask = gray > 0.05;
fovCoverage = sum(mask(:)) / numel(mask);

% Normalize quality components
sharpScore = min(sharpness/0.003,1);

brightScore = max(0, ...
    1 - abs(brightness-0.5)/0.5);

contrastScore = min(contrast/0.12,1);

fovScore = min(fovCoverage/0.75,1);

% Overall score
qualityScore = 0.30*sharpScore + ...
               0.25*brightScore + ...
               0.20*contrastScore + ...
               0.25*fovScore;

% Decision
if qualityScore < 0.35 || ...
        fovCoverage < 0.40 || ...
        sharpness < 0.0005

    decision = "Ungradeable";

    reasons = strings(0);

    if sharpness < 0.0005
        reasons(end+1) = "Poor focus";
    end

    if brightness < 0.15
        reasons(end+1) = "Image too dark";
    elseif brightness > 0.85
        reasons(end+1) = "Image too bright";
    end

    if contrast < 0.03
        reasons(end+1) = "Very low contrast";
    end

    if fovCoverage < 0.40
        reasons(end+1) = "Insufficient field of view";
    end

    if isempty(reasons)
        reasons = "Overall image quality too low";
    end

    feedback = "RECAPTURE REQUIRED: " + ...
        strjoin(reasons,", ");

elseif qualityScore < 0.70

    decision = "Borderline";

    feedback = ...
        "Enhancement recommended before DR analysis.";

else

    decision = "Good";

    feedback = ...
        "Image acceptable for automated DR screening.";

end

quality = struct;

quality.sharpness = sharpness;
quality.brightness = brightness;
quality.contrast = contrast;
quality.fovCoverage = fovCoverage;
quality.qualityScore = qualityScore;
quality.decision = decision;
quality.feedback = feedback;

end