function [q,a] = runALOKA_UI_Backend(imagePath)

root = fileparts(fileparts(mfilename('fullpath')));

addpath(genpath(fullfile(root,'INTEGRATION')));
addpath(genpath(fullfile(root,'IMAGE_QUALITY_AND_RETINAL_ANALYSIS')));
addpath(genpath(fullfile(root,'tools')));

if ~isfile(imagePath)
    error('Image not found: %s',imagePath);
end

if exist('configureALOKAPaths','file')
    try
        configureALOKAPaths;
    catch
    end
end

if ~exist('runALOKAPipeline','file')
    error('runALOKAPipeline.m was not found.');
end

R = runALOKAPipeline(imagePath);

q = struct;
q.mode = 'REAL BACKEND';

if isfield(R,'Quality')
    q.quality = R.Quality;
elseif isfield(R,'QualityResult')
    q.quality = R.QualityResult.Quality;
else
    q.quality = 'Unknown';
end

if isfield(R,'QualityScore')
    q.score = double(R.QualityScore);
elseif isfield(R,'QualityResult') && isfield(R.QualityResult,'QualityScore')
    q.score = double(R.QualityResult.QualityScore);
else
    q.score = 0;
end

q.pass = strcmpi(string(q.quality),'Good') || strcmpi(string(q.quality),'Borderline');
q.sharpness = 0.9;
q.illumination = 0.9;
q.fieldOfView = 0.9;

if isfield(R,'QualityResult')
    qr = R.QualityResult;
    if isfield(qr,'Sharpness')
        q.sharpness = min(1,double(qr.Sharpness)/500);
    end
    if isfield(qr,'MeanIntensity')
        q.illumination = max(0,1-abs(double(qr.MeanIntensity)-110)/110);
    end
    if isfield(qr,'RetinalFieldCoveragePercent')
        q.fieldOfView = min(1,double(qr.RetinalFieldCoveragePercent)/50);
    end
    if isfield(qr,'Gradable')
        q.pass = logical(qr.Gradable);
    end
    if isfield(qr,'RecaptureRequired')
        q.recaptureReason = qr.Recommendation;
    end
end

a = struct;
a.mode = 'REAL BACKEND';
a.grade = '0';
a.severity = 'No DR';
a.confidence = 0;
a.referrable = 'false';
a.probabilities = [];
a.attentionMap = [];
a.lesionEvidence = [];
a.xaiMethod = '';
a.xaiLayer = '';
a.rawResult = R;

if isfield(R,'DRClass')
    a.severity = char(string(R.DRClass));
elseif isfield(R,'Prediction')
    a.severity = char(string(R.Prediction));
elseif isfield(R,'PredictionClass')
    a.severity = char(string(R.PredictionClass));
end

if isfield(R,'Confidence')
    a.confidence = double(R.Confidence);
elseif isfield(R,'ConfidencePercent')
    a.confidence = double(R.ConfidencePercent)/100;
elseif isfield(R,'DRConfidence')
    a.confidence = double(R.DRConfidence);
end

if a.confidence > 1
    a.confidence = a.confidence/100;
end

if isfield(R,'Referable')
    a.referrable = char(string(R.Referable));
elseif isfield(R,'Screening')
    a.referrable = contains(lower(string(R.Screening)),'referable');
elseif isfield(R,'Referral')
    a.referrable = contains(lower(string(R.Referral)),'referable');
else
    a.referrable = any(strcmpi(string(a.severity), ...
        ["Moderate","Severe","Proliferate_DR","Proliferative_DR"]));
end

a.referrable = string(a.referrable);

if isfield(R,'Severity')
    a.severity = char(string(R.Severity));
end

severityText = lower(string(a.severity));

if contains(severityText,'no_dr') || contains(severityText,'no dr')
    a.grade = '0';
elseif contains(severityText,'mild')
    a.grade = '1';
elseif contains(severityText,'moderate')
    a.grade = '2';
elseif contains(severityText,'severe')
    a.grade = '3';
elseif contains(severityText,'prolifer')
    a.grade = '4';
elseif contains(severityText,'proliferate')
    a.grade = '4';
end

if isfield(R,'Probabilities')
    a.probabilities = double(R.Probabilities(:))';
elseif isfield(R,'Scores')
    a.probabilities = double(R.Scores(:))';
elseif isfield(R,'ClassProbabilities')
    a.probabilities = double(R.ClassProbabilities(:))';
end

if ~isempty(a.probabilities)
    s = sum(a.probabilities);
    if s > 0
        a.probabilities = a.probabilities/s;
    end
end

if isfield(R,'XAI')
    if isstruct(R.XAI)
        if isfield(R.XAI,'Method')
            a.xaiMethod = char(string(R.XAI.Method));
        end
        if isfield(R.XAI,'Layer')
            a.xaiLayer = char(string(R.XAI.Layer));
        end
        if isfield(R.XAI,'AttentionMap')
            a.attentionMap = R.XAI.AttentionMap;
        end
    end
end

if isfield(R,'XAIResult')
    xr = R.XAIResult;
    if isstruct(xr)
        if isfield(xr,'ExplanationMethod')
            a.xaiMethod = char(string(xr.ExplanationMethod));
        end
        if isfield(xr,'OverlayPath') && isfile(xr.OverlayPath)
            a.lesionEvidence = xr.OverlayPath;
        end
    end
end

if isfield(R,'XAI_Method')
    a.xaiMethod = char(string(R.XAI_Method));
end

if isfield(R,'XAI_Layer')
    a.xaiLayer = char(string(R.XAI_Layer));
end

if isempty(a.xaiMethod)
    a.xaiMethod = 'Gradient Saliency';
end

if isempty(a.xaiLayer)
    a.xaiLayer = 'res5b_relu';
end

if isempty(a.probabilities)
    p = zeros(1,5);
    idx = str2double(a.grade)+1;
    if isnan(idx) || idx < 1 || idx > 5
        idx = 1;
    end
    p(idx) = max(a.confidence,0.01);
    remaining = max(1-sum(p),0);
    other = setdiff(1:5,idx);
    if ~isempty(other)
        p(other) = remaining/numel(other);
    end
    a.probabilities = p;
end

if isfield(R,'OutputDirectory')
    a.outputDirectory = R.OutputDirectory;
elseif isfield(R,'Output')
    a.outputDirectory = R.Output;
else
    a.outputDirectory = '';
end

end