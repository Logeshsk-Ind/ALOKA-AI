ALOKA_AI — Explainable AI for Diabetic Retinopathy Screening

ALOKA_AI is a MATLAB-based project focused on AI-assisted diabetic retinopathy (DR) screening using retinal fundus images. It aims to support early identification of potential retinal abnormalities through image analysis, deep learning, and explainable AI.

Overview

Diabetic retinopathy is a diabetes-related eye disease that can lead to vision loss if not detected and managed early. Access to retinal screening can be limited in rural and underserved communities.

ALOKA_AI aims to support retinal image assessment through an integrated workflow for patient information, image quality assessment, AI-assisted analysis, visualization, and screening report generation.

Project focus: Explainable AI for Diabetic Retinopathy Screening in Rural India.

SIH problem statement: SIH26038  
Team: GoldOops  
Primary development environment: MATLAB

Key Features

- Screening dashboard: A user interface for managing the screening workflow.
- Patient workflow: Organizes patient information and screening steps.
- Retinal image analysis: Supports the retinal image assessment workflow.
- Image quality assessment: Intended to help identify images that may be unsuitable for analysis.
- AI-assisted classification: Designed for diabetic retinopathy grading, subject to the integrated model's capabilities.
- Explainable AI: Grad-CAM visualization is intended to help users inspect image regions influencing a model prediction.
  Screening reports: Supports the planned presentation of screening findings.
- Modular architecture: Separates classification, explainability, image analysis, integration, validation, and telemedicine workflows.

Technology Stack

- MATLAB
- Image Processing
- Computer Vision
- Deep Learning
- Explainable AI and Grad-CAM
- Simulink/SimEvents for relevant workflow simulations

*The availability of each capability depends on the corresponding implementation, MATLAB release, toolboxes, and model files included in the repository.*

Project Structure

```text
ALOKA-AI/
├── App/
├── BACKEND/
├── IMAGE_QUALITY_AND_RETINAL_ANALYSIS/
├── INTEGRATION_AND_IMPACT/
├── TELEMEDICINE_WORKFLOW/
├── models/
├── README.md
└── .gitignore
```

*Update this structure to match the actual files and folders in the repository.*

Getting Started

Prerequisites

- MATLAB with a release compatible with the project code.
- Required MATLAB toolboxes, depending on the modules being used.
- Any model weights, sample images, and supporting assets required by the implementation.

Installation

1. Clone or download this repository.
2. Open MATLAB.
3. Navigate to the project directory.
4. Review the available source files and project instructions.
5. Install or enable the required MATLAB toolboxes.
6. Run the application entry point if its dependencies are available.

Run the Application
If `APP/ ALOKA_AI.m` is the verified application entry point, open it in MATLAB and run the appropriate startup command for its class definition.
The exact launch command and dependency setup should be documented after confirming the current source code and project configuration.

Explainable AI and Responsible Use
AI-generated screening outputs are intended to support research and screening workflows, not replace professional ophthalmic diagnosis.
Model performance, generalization, and clinical suitability must be evaluated using appropriate datasets and validation procedures before real-world deployment. Grad-CAM visualizations are explanatory aids and do not independently establish diagnostic correctness.

Validation
Validation should document the dataset, train/validation/test split, preprocessing, classification metrics, model limitations, and reproducibility details.
Only report measured results that have been verified experimentally.

Current Status
This project is under development. The user interface and individual workflow components should be assessed separately from the completeness and clinical validity of the underlying AI models.

Future Scope
- Improve and validate the retinal image classification pipeline.
- Strengthen explainability and image quality assessment.
- Expand testing across representative retinal datasets.
- Improve report generation and usability.
- Explore rural screening and telemedicine workflow integration.

Team and Acknowledgements
Team: GoldOops
Developed as an engineering project focused on accessible, explainable AI-assisted retinal screening.

Disclaimer
ALOKA_AI is a research and engineering project. It is not a substitute for examination by a qualified eye-care professional. Do not use unvalidated outputs to make clinical decisions.
