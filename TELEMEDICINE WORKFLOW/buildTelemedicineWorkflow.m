%% =========================================================
% MEMBER 5 - TELEMEDICINE WORKFLOW
% SimEvents R2026a
% =========================================================

clc;
clear;
close all;

fprintf("\n====================================\n");
fprintf("MEMBER 5 - TELEMEDICINE WORKFLOW\n");
fprintf("====================================\n");

%% PROJECT PATH

scriptFolder = fileparts(mfilename("fullpath"));
member5Folder = fileparts(scriptFolder);

modelsFolder = fullfile(member5Folder,"models");

if ~isfolder(modelsFolder)
    mkdir(modelsFolder);
end

modelName = "telemedicineWorkflow";

modelFile = fullfile(modelsFolder, ...
    modelName + ".slx");

%% CLOSE OLD MODEL

if bdIsLoaded(modelName)
    close_system(modelName,0);
end

%% DELETE OLD MODEL

if isfile(modelFile)
    delete(modelFile);
end

%% LOAD SIMEVENTS LIBRARY

fprintf("\nLoading SimEvents library...\n");

simevents;

fprintf("SimEvents library opened.\n");

%% CURRENT R2026a SIMEVENTS BLOCK PATHS

generatorPath = "sldelib/Entity Generator";
queuePath     = "sldelib/Entity Queue";
serverPath    = "sldelib/Entity Server";
terminatorPath = "sldelib/Entity Terminator";

%% VERIFY BLOCKS

fprintf("\nChecking SimEvents blocks...\n");

if isempty(find_system("sldelib", ...
        "SearchDepth",1, ...
        "Name","Entity Generator"))

    error("Entity Generator not found.");

end

if isempty(find_system("sldelib", ...
        "SearchDepth",1, ...
        "Name","Entity Queue"))

    error("Entity Queue not found.");

end

if isempty(find_system("sldelib", ...
        "SearchDepth",1, ...
        "Name","Entity Server"))

    error("Entity Server not found.");

end

if isempty(find_system("sldelib", ...
        "SearchDepth",1, ...
        "Name","Entity Terminator"))

    error("Entity Terminator not found.");

end

fprintf("Entity Generator      : FOUND\n");
fprintf("Entity Queue          : FOUND\n");
fprintf("Entity Server         : FOUND\n");
fprintf("Entity Terminator     : FOUND\n");

%% CREATE MODEL

fprintf("\nCreating Simulink model...\n");

new_system(modelName);
open_system(modelName);

%% ADD PATIENT ARRIVAL GENERATOR

fprintf("Adding Patient Arrivals...\n");

add_block( ...
    generatorPath, ...
    modelName + "/Patient Arrivals", ...
    "Position",[50 150 180 210]);

%% ADD REGISTRATION QUEUE

fprintf("Adding Registration Queue...\n");

add_block( ...
    queuePath, ...
    modelName + "/Registration Queue", ...
    "Position",[240 150 390 210]);

%% ADD IMAGE PROCESSING SERVER

fprintf("Adding Image Processing Server...\n");

add_block( ...
    serverPath, ...
    modelName + "/Image Processing", ...
    "Position",[450 150 610 210]);

%% ADD NETWORK QUEUE

fprintf("Adding Network Queue...\n");

add_block( ...
    queuePath, ...
    modelName + "/Network Queue", ...
    "Position",[670 150 820 210]);

%% ADD OPHTHALMOLOGIST SERVER

fprintf("Adding Ophthalmologist Review...\n");

add_block( ...
    serverPath, ...
    modelName + "/Ophthalmologist Review", ...
    "Position",[880 150 1050 210]);

%% ADD SCREENING REPORT TERMINATOR

fprintf("Adding Screening Report...\n");

add_block( ...
    terminatorPath, ...
    modelName + "/Screening Report", ...
    "Position",[1110 150 1260 210]);

%% CONNECT BLOCKS

fprintf("\nConnecting workflow...\n");

add_line( ...
    modelName, ...
    "Patient Arrivals/1", ...
    "Registration Queue/1", ...
    "autorouting","on");

add_line( ...
    modelName, ...
    "Registration Queue/1", ...
    "Image Processing/1", ...
    "autorouting","on");

add_line( ...
    modelName, ...
    "Image Processing/1", ...
    "Network Queue/1", ...
    "autorouting","on");

add_line( ...
    modelName, ...
    "Network Queue/1", ...
    "Ophthalmologist Review/1", ...
    "autorouting","on");

add_line( ...
    modelName, ...
    "Ophthalmologist Review/1", ...
    "Screening Report/1", ...
    "autorouting","on");

fprintf("Workflow connections created.\n");

%% ADD WORKFLOW ANNOTATION

annotationText = [ ...
    "RURAL INDIA TELEMEDICINE SCREENING WORKFLOW" newline newline ...
    "Patient Arrivals" newline ...
    "        ↓" newline ...
    "Registration Queue" newline ...
    "        ↓" newline ...
    "AI Image Processing" newline ...
    "        ↓" newline ...
    "Network Queue" newline ...
    "        ↓" newline ...
    "Ophthalmologist Review" newline ...
    "        ↓" newline ...
    "Screening Report"];

add_block( ...
    "simulink/Signal Routing/Goto", ...
    modelName + "/WorkflowInfo", ...
    "Position",[500 300 620 330]);

%% SAVE MODEL

fprintf("\nSaving model...\n");

save_system(modelName,modelFile);

%% FINAL OUTPUT

fprintf("\n====================================\n");
fprintf("MODEL CREATION COMPLETE\n");
fprintf("====================================\n");

fprintf("\nModel saved at:\n");
fprintf("%s\n",modelFile);

fprintf("\nWorkflow:\n");
fprintf("Patient Arrivals\n");
fprintf("      ↓\n");
fprintf("Registration Queue\n");
fprintf("      ↓\n");
fprintf("Image Processing\n");
fprintf("      ↓\n");
fprintf("Network Queue\n");
fprintf("      ↓\n");
fprintf("Ophthalmologist Review\n");
fprintf("      ↓\n");
fprintf("Screening Report\n");

fprintf("\n====================================\n");
fprintf("MEMBER 5 STEP 1 COMPLETE\n");
fprintf("====================================\n");