function result = testALOKABackend(imagePath)

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

result = alokaBackend(imagePath);

fprintf('\n');
fprintf('============================================================\n');
fprintf('ALOKA-AI BACKEND TEST\n');
fprintf('============================================================\n');
fprintf('Image       : %s\n',imagePath);
fprintf('Status      : %s\n',result.Status);

if isfield(result,'M1')
    fprintf('M1 Quality  : %s\n',result.M1.Quality);
    fprintf('M1 Score    : %.2f %%\n',result.M1.QualityScore);
end

if isfield(result,'M3') && ~isempty(result.M3)

    fprintf('M3 Grade    : %s\n',result.M3.Grade);
    fprintf('M3 Conf.    : %.2f %%\n',result.M3.Confidence);
    fprintf('Screening   : %s\n',result.M3.Screening);

end

if isfield(result,'M4') && ~isempty(result.M4)
    fprintf('M4 XAI      : %s\n',result.M4.Method);
end

if isfield(result,'M5')
    fprintf('M5 Status   : %s\n',result.M5.Status);
end

if isfield(result,'M6') && ~isempty(result.M6)
    fprintf('M6 Status   : %s\n',result.M6.Status);
end

fprintf('============================================================\n');

end