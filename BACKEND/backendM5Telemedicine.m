function result = backendM5Telemedicine()

root = fileparts(fileparts(mfilename('fullpath')));;

modelPath = fullfile(root,...
    'TELEMEDICINE_WORKFLOW',...
    'models',...
    'telemedicineWorkflow.slx');

configPath = fullfile(root,...
    'TELEMEDICINE_WORKFLOW',...
    'scripts',...
    'configureDistrictSimulation.m');

result = struct();

result.ModelPath = modelPath;
result.ConfigurationPath = configPath;
result.Available = isfile(modelPath);
result.ConfigurationAvailable = isfile(configPath);

if result.Available
    result.Status = 'AVAILABLE';
else
    result.Status = 'NOT_AVAILABLE';
end

result.Mode = 'Telemedicine deployment simulation';

end