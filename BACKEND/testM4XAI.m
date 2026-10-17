function result = testM4XAI(imagePath)

if nargin < 1 || isempty(imagePath)

    files = dir(fullfile(fullfile(fileparts(fileparts(mfilename('fullpath'))),'data','test'),'*.png'));

    if isempty(files)
        files = dir(fullfile(fullfile(fileparts(fileparts(mfilename('fullpath'))),'data','test'),'*.jpg'));
    end

    if isempty(files)
        error('No test image found.');
    end

    imagePath = fullfile(files(1).folder,files(1).name);
end

m3 = backendM3Severity(imagePath);

result = backendM4XAI(imagePath,m3);

fprintf('\n');
fprintf('============================================\n');
fprintf('M4 XAI TEST\n');
fprintf('============================================\n');
fprintf('Image       : %s\n',imagePath);
fprintf('Prediction  : %s\n',m3.Grade);
fprintf('Method      : %s\n',result.Method);
fprintf('Layer       : %s\n',result.Layer);
fprintf('Available   : %s\n',mat2str(result.Available));

if ~isempty(result.AttentionMapPath)
    fprintf('Attention   : %s\n',result.AttentionMapPath);
end

if ~isempty(result.OverlayPath)
    fprintf('Overlay     : %s\n',result.OverlayPath);
end

fprintf('============================================\n');

end