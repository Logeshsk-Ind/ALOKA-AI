clc;
clear;

fprintf("\n====================================\n");
fprintf("MEMBER 6 - MODEL VALIDATION\n");
fprintf("====================================\n");

%% Paths

projectRoot = "D:\mem 1,2\Member1_Member2_Delivery";

comparisonFile = fullfile( ...
    projectRoot,"results","modelComparison.mat");

member6Folder = fullfile( ...
    projectRoot,"Member6_Delivery");

validationFolder = fullfile( ...
    member6Folder,"validation");

if ~isfolder(validationFolder)
    mkdir(validationFolder);
end

%% Check source file

if ~isfile(comparisonFile)
    error("modelComparison.mat was not found:\n%s", ...
        comparisonFile);
end

fprintf("\nLoading:\n%s\n",comparisonFile);

S = load(comparisonFile);

%% Check required variables

if ~isfield(S,"trueLabels")
    error("trueLabels was not found in modelComparison.mat.");
end

if ~isfield(S,"baselinePred")
    error("baselinePred was not found in modelComparison.mat.");
end

trueLabels = S.trueLabels;
predictedLabels = S.baselinePred;

%% Check sample counts

fprintf("\n====================================\n");
fprintf("VALIDATION DATA\n");
fprintf("====================================\n");

fprintf("Ground-truth samples : %d\n",numel(trueLabels));
fprintf("Predicted samples    : %d\n",numel(predictedLabels));

if numel(trueLabels) ~= numel(predictedLabels)
    error("Ground-truth and prediction counts do not match.");
end

%% Convert to categorical

trueLabels = categorical(trueLabels);
predictedLabels = categorical(predictedLabels);

%% Determine common class order

classNames = categories(trueLabels);

fprintf("\nClasses detected:\n");

for i = 1:numel(classNames)
    fprintf("  %s\n",classNames{i});
end

%% Confusion matrix

fprintf("\n====================================\n");
fprintf("CONFUSION MATRIX\n");
fprintf("====================================\n");

classOrder = categorical(classNames);

confMatrix = confusionmat( ...
    trueLabels, ...
    predictedLabels, ...
    "Order",classOrder);

disp(confMatrix);

%% Overall accuracy

totalSamples = sum(confMatrix(:));

correctPredictions = sum(diag(confMatrix));

accuracy = correctPredictions / totalSamples;

fprintf("\nOverall Accuracy : %.2f %%\n", ...
    accuracy * 100);

%% Per-class metrics

numClasses = size(confMatrix,1);

sensitivity = NaN(numClasses,1);
specificity = NaN(numClasses,1);
precision = NaN(numClasses,1);
f1Score = NaN(numClasses,1);

for i = 1:numClasses

    TP = confMatrix(i,i);

    FN = sum(confMatrix(i,:)) - TP;

    FP = sum(confMatrix(:,i)) - TP;

    TN = totalSamples - TP - FN - FP;

    % Sensitivity / Recall

    if (TP + FN) > 0
        sensitivity(i) = TP / (TP + FN);
    end

    % Specificity

    if (TN + FP) > 0
        specificity(i) = TN / (TN + FP);
    end

    % Precision

    if (TP + FP) > 0
        precision(i) = TP / (TP + FP);
    end

    % F1 score

    if (precision(i) + sensitivity(i)) > 0
        f1Score(i) = ...
            2 * precision(i) * sensitivity(i) / ...
            (precision(i) + sensitivity(i));
    end

end

%% Display per-class metrics

fprintf("\n====================================\n");
fprintf("PER-CLASS VALIDATION METRICS\n");
fprintf("====================================\n\n");

fprintf("%-20s %12s %12s %12s %12s\n", ...
    "Class", ...
    "Sensitivity", ...
    "Specificity", ...
    "Precision", ...
    "F1-score");

fprintf("--------------------------------------------------------------------------\n");

for i = 1:numClasses

    fprintf("%-20s %11.2f%% %11.2f%% %11.2f%% %11.2f%%\n", ...
        classNames{i}, ...
        sensitivity(i)*100, ...
        specificity(i)*100, ...
        precision(i)*100, ...
        f1Score(i)*100);

end

%% Macro averages

macroSensitivity = mean(sensitivity,"omitnan");

macroSpecificity = mean(specificity,"omitnan");

macroPrecision = mean(precision,"omitnan");

macroF1 = mean(f1Score,"omitnan");

fprintf("\n====================================\n");
fprintf("MACRO AVERAGES\n");
fprintf("====================================\n");

fprintf("Sensitivity : %.2f %%\n", ...
    macroSensitivity*100);

fprintf("Specificity : %.2f %%\n", ...
    macroSpecificity*100);

fprintf("Precision   : %.2f %%\n", ...
    macroPrecision*100);

fprintf("F1-score    : %.2f %%\n", ...
    macroF1*100);

%% Create validation table

validationTable = table( ...
    string(classNames(:)), ...
    sensitivity*100, ...
    specificity*100, ...
    precision*100, ...
    f1Score*100, ...
    'VariableNames', ...
    {'Class','Sensitivity','Specificity','Precision','F1Score'});

%% Save MAT file

matOutput = fullfile( ...
    validationFolder, ...
    "member6ValidationResults.mat");

save(matOutput, ...
    "confMatrix", ...
    "accuracy", ...
    "validationTable", ...
    "sensitivity", ...
    "specificity", ...
    "precision", ...
    "f1Score", ...
    "macroSensitivity", ...
    "macroSpecificity", ...
    "macroPrecision", ...
    "macroF1", ...
    "classNames", ...
    "totalSamples");

%% Save CSV

csvOutput = fullfile( ...
    validationFolder, ...
    "member6ValidationMetrics.csv");

writetable(validationTable,csvOutput);

%% Save text report

reportOutput = fullfile( ...
    validationFolder, ...
    "member6ValidationReport.txt");

fid = fopen(reportOutput,"w");

if fid == -1
    error("Could not create validation report.");
end

fprintf(fid,"====================================\n");
fprintf(fid,"MEMBER 6 - MODEL VALIDATION REPORT\n");
fprintf(fid,"====================================\n\n");

fprintf(fid,"Source file:\n%s\n\n",comparisonFile);

fprintf(fid,"Validation samples : %d\n",totalSamples);

fprintf(fid,"Overall accuracy   : %.2f %%\n\n", ...
    accuracy*100);

fprintf(fid,"CONFUSION MATRIX\n");
fprintf(fid,"------------------------------------\n");

for i = 1:numClasses

    fprintf(fid,"%s : ",classNames{i});

    for j = 1:numClasses
        fprintf(fid,"%d ",confMatrix(i,j));
    end

    fprintf(fid,"\n");

end

fprintf(fid,"\nPER-CLASS METRICS\n");
fprintf(fid,"------------------------------------\n");

for i = 1:numClasses

    fprintf(fid,"\n%s\n",classNames{i});

    fprintf(fid,"Sensitivity : %.2f %%\n", ...
        sensitivity(i)*100);

    fprintf(fid,"Specificity : %.2f %%\n", ...
        specificity(i)*100);

    fprintf(fid,"Precision   : %.2f %%\n", ...
        precision(i)*100);

    fprintf(fid,"F1-score    : %.2f %%\n", ...
        f1Score(i)*100);

end

fprintf(fid,"\nMACRO AVERAGES\n");
fprintf(fid,"------------------------------------\n");

fprintf(fid,"Sensitivity : %.2f %%\n", ...
    macroSensitivity*100);

fprintf(fid,"Specificity : %.2f %%\n", ...
    macroSpecificity*100);

fprintf(fid,"Precision   : %.2f %%\n", ...
    macroPrecision*100);

fprintf(fid,"F1-score    : %.2f %%\n", ...
    macroF1*100);

fprintf(fid,"\n====================================\n");
fprintf(fid,"VALIDATION COMPLETE\n");
fprintf(fid,"====================================\n");

fclose(fid);

%% Final message

fprintf("\n====================================\n");
fprintf("MEMBER 6 VALIDATION COMPLETE\n");
fprintf("====================================\n");

fprintf("\nSamples       : %d\n",totalSamples);
fprintf("Accuracy      : %.2f %%\n",accuracy*100);
fprintf("Macro F1      : %.2f %%\n",macroF1*100);

fprintf("\nFiles created:\n");
fprintf("1. %s\n",matOutput);
fprintf("2. %s\n",csvOutput);
fprintf("3. %s\n",reportOutput);

fprintf("\n====================================\n");