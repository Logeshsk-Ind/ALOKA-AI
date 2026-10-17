clc; clear;

projectPath = fileparts(fileparts(fileparts(mfilename("fullpath"))));

aptosPath = fullfile(projectPath, ...
    "data","raw","aptos","colored_images");

files = dir(fullfile(aptosPath,"**","*.png"));

rng(1);

indices = randperm(numel(files),min(20,numel(files)));

fprintf("\n====================================\n");
fprintf("IMAGE QUALITY PIPELINE TEST\n");
fprintf("====================================\n");

for i = 1:numel(indices)

    file = files(indices(i));

    imagePath = fullfile(file.folder,file.name);

    img = imread(imagePath);

    quality = assessImageQuality(img);

    fprintf("\nImage: %s\n",file.name);
    fprintf("Sharpness: %.6f\n",quality.sharpness);
    fprintf("Brightness: %.3f\n",quality.brightness);
    fprintf("Contrast: %.3f\n",quality.contrast);
    fprintf("FOV: %.3f\n",quality.fovCoverage);
    fprintf("Score: %.3f\n",quality.qualityScore);
    fprintf("Decision: %s\n",quality.decision);
    fprintf("Action: %s\n",quality.feedback);

end

fprintf("\n====================================\n");
fprintf("QUALITY TEST COMPLETED\n");
fprintf("====================================\n");