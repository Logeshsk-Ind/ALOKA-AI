function result = backendM2Lesions(imagePath)

root = fileparts(fileparts(mfilename('fullpath')));

modelDir = fullfile(root,'IMAGE_QUALITY_AND_RETINAL_ANALYSIS','models');

models = struct();

models.MA = fullfile(modelDir,'M2_MA_U-Net.mat');
models.HE = fullfile(modelDir,'M2_HE_U-Net.mat');
models.EX = fullfile(modelDir,'M2_EX_U-Net.mat');
models.SE = fullfile(modelDir,'M2_SE_U-Net.mat');

names = fieldnames(models);

result = struct();

for k = 1:numel(names)

    name = names{k};
    modelPath = models.(name);

    if ~isfile(modelPath)
        result.(name).available = false;
        result.(name).probability = [];
        result.(name).mask = [];
        result.(name).modelPath = modelPath;
        continue;
    end

    try
        [probability,mask] = runIDRiDLesionInference(imagePath,modelPath,0.20);

        result.(name).available = true;
        result.(name).probability = probability;
        result.(name).mask = mask;
        result.(name).modelPath = modelPath;
        result.(name).positivePixels = nnz(mask);
        result.(name).positivePercent = 100*nnz(mask)/numel(mask);

    catch ME
        result.(name).available = false;
        result.(name).probability = [];
        result.(name).mask = [];
        result.(name).modelPath = modelPath;
        result.(name).error = ME.message;
    end
end

end