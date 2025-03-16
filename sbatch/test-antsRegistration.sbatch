#!/bin/bash
#SBATCH --job-name=antsRegistration-test
#SBATCH --time=UNLIMITED
#SBATCH --mem=0
#SBATCH --cpus-per-task=64
#SBATCH -o log-tests/%x-%A-%a.out

set -u
set -e

TEMPLATEFLOW_DIR=$HOME/.cache/templateflow

PROJECT_DIR=/mnt/lustre/mathdugre/fast-interpolate
DATA_DIR=${PROJECT_DIR}/datasets/ds004513

SUBJECT_ID=$(sed -n 1p < subject_ids.txt)
INPUT_IMG=${DATA_DIR}/derivatives/flint/fsl-fast/sub-${SUBJECT_ID}/BrainExtractionBrain_seg.nii.gz
OUTPUT_DIR=${PROJECT_DIR}/test-antsRegistration/out
mkdir -p ${OUTPUT_DIR}

FIXED_IMG=/templateflow/tpl-MNI152NLin2009cAsym/tpl-MNI152NLin2009cAsym_res-01_desc-brain_T1w.nii.gz
export APPTAINERENV_ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=64

SIF_IMG=/mnt/lustre/mathdugre/containers/ants-vprec-no_metric.simg
 
THRESHOLD="1e-6"

echo "
##########################
# Experiment information #
##########################

HOSTNAME: $(hostname)

EXPERIMENT_NAME: TEST
SIF_IMG: $SIF_IMG

THRESHOLD: $THRESHOLD

SUBJECT_ID: $SUBJECT_ID
INPUT_IMG: $INPUT_IMG
OUTPUT_DIR: $OUTPUT_DIR

FIXED_IMG: $FIXED_IMG
DATA_DIR: $DATA_DIR
TEMPLATEFLOW_DIR: $TEMPLATEFLOW_DIR
ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS: $APPTAINERENV_ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS
##########################
"

#    --write-interval-volumes 1 \
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
    --output [${OUTPUT_DIR}/,${OUTPUT_DIR}/Warped.nii.gz,${OUTPUT_DIR}/InverseWarped.nii.gz] \
    --initial-moving-transform [${FIXED_IMG},${INPUT_IMG},1] \
    --transform Rigid[0.1] \
    --metric MI[${FIXED_IMG},${INPUT_IMG},1,32,Regular,0.25] \
    --convergence [1000x500x250x100,${THRESHOLD},10] \
    --shrink-factors 8x4x2x1 \
    --smoothing-sigmas 3x2x1x0vox \
    --transform Affine[0.1] \
    --metric MI[${FIXED_IMG},${INPUT_IMG},1,32,Regular,0.25] \
    --convergence [1000x500x250x100,${THRESHOLD},10] \
    --shrink-factors 8x4x2x1 \
    --smoothing-sigmas 3x2x1x0vox \
    --transform SyN[ 0.1,3,0 ] \
    --metric CC[${FIXED_IMG},${INPUT_IMG},1,4] \
    --convergence [100x70x50x20,${THRESHOLD},10] \
    --shrink-factors 8x4x2x1 \
    --smoothing-sigmas 3x2x1x0vox

