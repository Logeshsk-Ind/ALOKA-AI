function result = backendM1Quality(imagePath)

if ~isfile(imagePath)
    error('Image not found.');
end

result = runImageQualityWorkflow(imagePath);

end