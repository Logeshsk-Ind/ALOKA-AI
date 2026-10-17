function R = runALOKAScreening(imagePath)

root = fileparts(fileparts(mfilename('fullpath'))); 
addpath(genpath(root));

R = alokaBackend(imagePath);

R.Diagnosis = R.M3.Class;
R.Confidence = R.M3.Confidence;
R.Referable = R.M3.Referable;
R.Quality = R.M1.Quality;
R.QualityScore = R.M1.QualityScore;
R.Gradable = R.M1.Gradable;

if R.Referable
    R.Screening = 'REFERABLE DR';
    R.Recommendation = 'Refer to ophthalmologist.';
else
    R.Screening = 'NON-REFERABLE DR';
    R.Recommendation = 'Routine follow-up recommended.';
end

end