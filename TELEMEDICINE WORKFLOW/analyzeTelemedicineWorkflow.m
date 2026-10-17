clc;
clear;

fprintf("====================================\n");
fprintf("MEMBER 5 - TELEMEDICINE ANALYSIS\n");
fprintf("====================================\n\n");

%% Locate project directory
scriptPath = fileparts(mfilename("fullpath"));
projectPath = fileparts(scriptPath);

%% Locate Simulink model
modelPath = fullfile(projectPath, ...
    "models", "telemedicineWorkflow.slx");

fprintf("Searching for model...\n");
fprintf("Model path:\n%s\n\n", modelPath);

%% Check model
if ~isfile(modelPath)
    error("Telemedicine model not found:\n%s", modelPath);
end

fprintf("Model found successfully.\n");

%% Load model
[~, modelName, ~] = fileparts(modelPath);

fprintf("Opening model: %s\n\n", modelName);

load_system(modelPath);

%% Display simulation settings
fprintf("====================================\n");
fprintf("SIMULATION SETTINGS\n");
fprintf("====================================\n");

stopTime = get_param(modelName,"StopTime");

fprintf("Simulation stop time : %s seconds\n", stopTime);

%% Check workflow blocks
fprintf("\n====================================\n");
fprintf("WORKFLOW BLOCK CHECK\n");
fprintf("====================================\n");

blockNames = {
    "Patient Arrivals"
    "Registration Queue"
    "Image Processing"
    "Network Queue"
    "Ophthalmologist Review"
    "Screening Report"
    };

for i = 1:numel(blockNames)

    blockPath = modelName + "/" + blockNames{i};

    if ~isempty(find_system(modelName, ...
            "SearchDepth",1, ...
            "Name",blockNames{i}))

        fprintf("✓ %-25s FOUND\n",blockNames{i});

    else

        fprintf("✗ %-25s NOT FOUND\n",blockNames{i});

    end

end

%% Run simulation
fprintf("\n====================================\n");
fprintf("RUNNING TELEMEDICINE SIMULATION\n");
fprintf("====================================\n\n");

try

    simOut = sim(modelName);

    fprintf("Simulation completed successfully.\n");

catch ME

    fprintf("Simulation error:\n");
    fprintf("%s\n",ME.message);

    close_system(modelName,0);

    return;

end

%% Check simulation output
fprintf("\n====================================\n");
fprintf("SIMULATION OUTPUT\n");
fprintf("====================================\n");

if isprop(simOut,"ErrorMessage")

    if isempty(simOut.ErrorMessage)
        fprintf("Simulation errors : NONE\n");
    else
        fprintf("Simulation errors : DETECTED\n");
        fprintf("%s\n",simOut.ErrorMessage);
    end

end

%% Time vector
try

    tout = simOut.tout;

    fprintf("Simulation time : %.2f seconds\n",tout(end));
    fprintf("Recorded points : %d\n",numel(tout));

catch

    fprintf("Time vector unavailable.\n");

end

%% Workflow interpretation
fprintf("\n====================================\n");
fprintf("TELEMEDICINE WORKFLOW ANALYSIS\n");
fprintf("====================================\n");

fprintf("\nPatient Arrival:\n");
fprintf("Patients enter the telemedicine system every 1 second.\n");

fprintf("\nRegistration:\n");
fprintf("FIFO registration queue with capacity of 500 patients.\n");

fprintf("\nAI Image Processing:\n");
fprintf("One processing server with approximately 2-second service time.\n");

fprintf("\nNetwork:\n");
fprintf("FIFO network queue with capacity of 1000 patients.\n");

fprintf("\nOphthalmologist Review:\n");
fprintf("One reviewer with approximately 30-second review time.\n");

fprintf("\nScreening Report:\n");
fprintf("Completed cases leave the workflow after screening/report generation.\n");

%% Capacity analysis
fprintf("\n====================================\n");
fprintf("CAPACITY ANALYSIS\n");
fprintf("====================================\n");

arrivalRate = 1/1;
aiServiceRate = 1/2;
doctorServiceRate = 1/30;

fprintf("Patient arrival rate       : %.2f patients/sec\n",arrivalRate);
fprintf("AI processing rate         : %.2f patients/sec\n",aiServiceRate);
fprintf("Ophthalmologist rate       : %.4f patients/sec\n",doctorServiceRate);

fprintf("\nApproximate hourly rates:\n");

fprintf("Arrival workload            : %.0f patients/hour\n", ...
    arrivalRate*3600);

fprintf("AI processing capacity      : %.0f patients/hour\n", ...
    aiServiceRate*3600);

fprintf("Ophthalmologist capacity   : %.0f patients/hour\n", ...
    doctorServiceRate*3600);

%% Bottleneck identification
fprintf("\n====================================\n");
fprintf("BOTTLENECK ANALYSIS\n");
fprintf("====================================\n");

fprintf("Primary bottleneck : Ophthalmologist Review\n");

fprintf("Reason:\n");
fprintf("One ophthalmologist processes approximately one patient every 30 seconds.\n");

fprintf("This corresponds to approximately 120 patients/hour.\n");

fprintf("\nAI processing capacity is approximately 1800 patients/hour,\n");
fprintf("so the AI stage is substantially faster than manual review.\n");

%% Telemedicine interpretation
fprintf("\n====================================\n");
fprintf("SYSTEM INTERPRETATION\n");
fprintf("====================================\n");

fprintf("The simulation represents the following workflow:\n\n");

fprintf("Patient\n");
fprintf("   ↓\n");
fprintf("Registration Queue\n");
fprintf("   ↓\n");
fprintf("AI Image Processing\n");
fprintf("   ↓\n");
fprintf("Network Queue\n");
fprintf("   ↓\n");
fprintf("Ophthalmologist Review\n");
fprintf("   ↓\n");
fprintf("Screening Report\n");

fprintf("\nThe model demonstrates how automated AI screening can\n");
fprintf("process images before limited ophthalmologist review.\n");

%% Save analysis
resultsPath = fullfile(projectPath,"results");

if ~isfolder(resultsPath)
    mkdir(resultsPath);
end

reportFile = fullfile(resultsPath, ...
    "telemedicineWorkflowAnalysis.txt");

fid = fopen(reportFile,"w");

if fid ~= -1

    fprintf(fid,"MEMBER 5 - TELEMEDICINE WORKFLOW ANALYSIS\n");
    fprintf(fid,"=========================================\n\n");

    fprintf(fid,"Simulation time: %s seconds\n",stopTime);

    fprintf(fid,"Patient arrival rate: %.2f patients/sec\n",arrivalRate);
    fprintf(fid,"AI processing rate: %.2f patients/sec\n",aiServiceRate);
    fprintf(fid,"Ophthalmologist rate: %.4f patients/sec\n",doctorServiceRate);

    fprintf(fid,"\nPrimary bottleneck: Ophthalmologist Review\n");

    fprintf(fid,"\nWorkflow:\n");
    fprintf(fid,"Patient Arrival -> Registration -> AI Processing -> ");
    fprintf(fid,"Network -> Ophthalmologist -> Screening Report\n");

    fclose(fid);

    fprintf("\nAnalysis report saved:\n");
    fprintf("%s\n",reportFile);

else

    fprintf("\nWarning: Could not save analysis report.\n");

end

%% Save model
save_system(modelName,modelPath);

close_system(modelName,0);

fprintf("\n====================================\n");
fprintf("MEMBER 5 ANALYSIS COMPLETE\n");
fprintf("====================================\n");