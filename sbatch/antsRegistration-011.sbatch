#!/bin/bash
#SBATCH --job-name=antsRegistration-011
#SBATCH --time=UNLIMITED
#SBATCH --mem=16G
#SBATCH --cpus-per-task=4
#SBATCH -o log-011/%x-%A-%a.out

set -u
set -e

SUBJECT_ID=$(sed -n ${SLURM_ARRAY_TASK_ID}p < subject_ids.txt)
INPUT_IMG=${DATA_DIR}/derivatives/flint/antsBrainExtraction/sub-${SUBJECT_ID}/BrainExtractionBrain.nii.gz
OUTPUT_DIR=${DATA_DIR}/derivatives/flint/antsRegistration-011/${EXPERIMENT_NAME}/sub-${SUBJECT_ID}

OUTPUT_FILE=${OUTPUT_DIR}/syn/transformed.nii.gz
if [ -e ${OUTPUT_FILE} ]; then
    echo "Registration already completed for sub-${SUBJECT_ID}"
    rm log/${SLURM_JOB_NAME}-${SLURM_ARRAY_JOB_ID}-${SLURM_ARRAY_TASK_ID}.out
    exit 0
fi

# Use SLURM environment variables to set the number of threads
APPTAINERENV_ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=${SLURM_CPUS_PER_TASK}

VFC_BACKENDS=${APPTAINERENV_VFC_BACKENDS}

echo "
##########################
# Experiment information #
##########################

EXPERIMENT_NAME: $EXPERIMENT_NAME
VFC_BACKENDS: $VFC_BACKENDS
THRESHOLD: $THRESHOLD

SIF_IMG: $SIF_IMG

SUBJECT_ID: $SUBJECT_ID
INPUT_IMG: $INPUT_IMG
OUTPUT_DIR: $OUTPUT_DIR

FIXED_IMG: $FIXED_IMG
DATA_DIR: $DATA_DIR
TEMPLATEFLOW_DIR: $TEMPLATEFLOW_DIR
ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS: $APPTAINERENV_ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS
##########################
"
export APPTAINERENV_VFC_BACKENDS="libinterflop_ieee.so"
mkdir -p ${OUTPUT_DIR}/rigid
apptainer exec --cleanenv \
    -B ${DATA_DIR}:${DATA_DIR} \
    -B ${OUTPUT_DIR}:${OUTPUT_DIR} \
    -B ${TEMPLATEFLOW_DIR}:/templateflow \
    ${SIF_IMG} antsRegistration \
    --verbose 1 \
    --dimensionality 3 \
    --collapse-output-transforms 0 \
    --use-histogram-matching 0 \
    --winsorize-image-intensities [0.005,0.995] \
    --interpolation Linear \
    --random-seed 1 \
    --write-interval-volumes 1 \
    --output [${OUTPUT_DIR}/rigid/,${OUTPUT_DIR}/rigid/Warped.nii.gz,${OUTPUT_DIR}/rigid/InverseWarped.nii.gz] \
    --initial-moving-transform [${FIXED_IMG},${INPUT_IMG},1] \
    --transform Rigid[0.1] \
    --metric MI[${FIXED_IMG},${INPUT_IMG},0.5,32,Regular,0.25] \
    --metric MeanSquares[${FIXED_IMG},${INPUT_IMG},0.5,4,Regular,0.25] \
    --convergence [1000x500x250x100,${THRESHOLD},10] \
    --shrink-factors 8x4x2x1 \
    --smoothing-sigmas 3x2x1x0vox

export APPTAINERENV_VFC_BACKENDS=${VFC_BACKENDS}
INPUT_IMG=${OUTPUT_DIR}/rigid/Warped.nii.gz
apptainer exec --cleanenv \
    -B ${DATA_DIR}:${DATA_DIR} \
    -B ${OUTPUT_DIR}:${OUTPUT_DIR} \
    -B ${TEMPLATEFLOW_DIR}:/templateflow \
    ${SIF_IMG} antsRegistration \
    --verbose 1 \
    --dimensionality 3 \
    --collapse-output-transforms 0 \
    --use-histogram-matching 0 \
    --winsorize-image-intensities [0.005,0.995] \
    --interpolation Linear \
    --random-seed 1 \
    --write-interval-volumes 1 \
    --output [${OUTPUT_DIR}/affine/,${OUTPUT_DIR}/affine/Warped.nii.gz,${OUTPUT_DIR}/affine/InverseWarped.nii.gz] \
    --transform Affine[0.1] \
    --metric MI[${FIXED_IMG},${INPUT_IMG},1,32,Regular,0.25] \
    --convergence [1000x500x250x100,${THRESHOLD},10] \
    --shrink-factors 8x4x2x1 \
    --smoothing-sigmas 3x2x1x0vox

export APPTAINERENV_VFC_BACKENDS=${VFC_BACKENDS}
mkdir -p ${OUTPUT_DIR}/syn
INPUT_IMG=${OUTPUT_DIR}/affine/Warped.nii.gz
apptainer exec --cleanenv \
    -B ${DATA_DIR}:${DATA_DIR} \
    -B ${OUTPUT_DIR}:${OUTPUT_DIR} \
    -B ${TEMPLATEFLOW_DIR}:/templateflow \
    ${SIF_IMG} antsRegistration \
    --verbose 1 \
    --dimensionality 3 \
    --collapse-output-transforms 0 \
    --use-histogram-matching 0 \
    --winsorize-image-intensities [0.005,0.995] \
    --interpolation Linear \
    --random-seed 1 \
    --write-interval-volumes 1 \
    --output [${OUTPUT_DIR}/syn/,${OUTPUT_DIR}/syn/Warped.nii.gz,${OUTPUT_DIR}/syn/InverseWarped.nii.gz] \
    --transform SyN[ 0.1,3,0 ] \
    --metric CC[${FIXED_IMG},${INPUT_IMG},0.5,4] \
    --metric MI[${FIXED_IMG},${INPUT_IMG},0.5,32,Regular,0.25] \
    --convergence [100x70x50x20,${THRESHOLD},10] \
    --shrink-factors 8x4x2x1 \
    --smoothing-sigmas 3x2x1x0vox
