#!/bin/bash
#SBATCH --job-name=ants_stage
#SBATCH --time=12:00:00
#SBATCH --mem=8G
#SBATCH --cpus-per-task=1

set -u
set -e

SIF_IMG=$1
STAGE=$2
FIXED_IMG=$3
DATA_DIR=$4
INPUT_IMG=$5
OUTPUT_DIR=$6
OUTPUT_PREFIX=$7
SUBJECT_ID=$8
REPETITION_ID=$9

PREVIOUS_PREFIX=${OUTPUT_PREFIX%?}

echo "---------------------
Experiment information

SIF_IMG: $SIF_IMG
EXPERIMENT_NAME: $EXPERIMENT_NAME
STAGE: $STAGE
SUBJECT_ID: $SUBJECT_ID
REPETITION_ID: $REPETITION_ID

FIXED_IMG: $FIXED_IMG
INPUT_IMG: $INPUT_IMG

DATA_DIR: $DATA_DIR
OUTPUT_DIR: $OUTPUT_DIR
OUTPUT_PREFIX: $OUTPUT_PREFIX
---------------------
"

antsRegistration () {
    local cmd=$@
    echo $cmd

    singularity exec --cleanenv \
        -B ${DATA_DIR}:${DATA_DIR} \
        -B $HOME/.cache/templateflow:/templateflow \
        ${SIF_IMG} antsRegistration \
        --verbose 1 \
        --dimensionality 3 \
        --collapse-output-transforms 1 \
        --use-histogram-matching 0 \
        --winsorize-image-intensities [0.005,0.995] \
        --interpolation Linear \
        $cmd
}
antsApplyTransforms () {
    local cmd=$@
    echo $cmd

    singularity exec --cleanenv \
        -B ${DATA_DIR}:${DATA_DIR} \
        -B $HOME/.cache/templateflow:/templateflow \
        ${SIF_IMG_BASE} antsApplyTransforms \
        -d 3 \
        --random-seed 123 \
        $cmd
}

mkdir -p ${OUTPUT_DIR}/${OUTPUT_PREFIX}

case $STAGE in
    rigid)
        antsRegistration \
            --output [${OUTPUT_DIR}/${OUTPUT_PREFIX}/${REPETITION_ID}_,${OUTPUT_DIR}/${OUTPUT_PREFIX}/${REPETITION_ID}_Rigid.nii.gz,${OUTPUT_DIR}/${OUTPUT_PREFIX}/${REPETITION_ID}_InverseRigid.nii.gz] \
            --initial-moving-transform [${FIXED_IMG},${INPUT_IMG},1] \
            --transform Rigid[0.1] \
            --metric MI[${FIXED_IMG},${INPUT_IMG},1,32,Regular,0.25] \
            --convergence [1000x500x250x100,1e-6,10] \
            --shrink-factors 8x4x2x1 \
            --smoothing-sigmas 3x2x1x0vox
        antsApplyTransforms \
            -i ${DATA_DIR}/derivatives/fsl/fast/sub-${SUBJECT_ID}/ses-open/anat/BrainExtractionBrain_seg.nii.gz \
            -o ${OUTPUT_DIR}/${OUTPUT_PREFIX}/${REPETITION_ID}_transformed.nii.gz \
            -t ${OUTPUT_DIR}/${OUTPUT_PREFIX}/${REPETITION_ID}_0GenericAffine.mat
        ;;
    affine)
        antsRegistration \
            --output [${OUTPUT_DIR}/${OUTPUT_PREFIX}/${REPETITION_ID}_,${OUTPUT_DIR}/${OUTPUT_PREFIX}/${REPETITION_ID}_Affine.nii.gz,${OUTPUT_DIR}/${OUTPUT_PREFIX}/${REPETITION_ID}_InverseAffine.nii.gz] \
            --initial-moving-transform [${FIXED_IMG},${INPUT_IMG},1] \
            --transform Affine[0.1] \
            --metric MI[${FIXED_IMG},${INPUT_IMG},1,32,Regular,0.25] \
            --convergence [1000x500x250x100,1e-6,10] \
            --shrink-factors 8x4x2x1 \
            --smoothing-sigmas 3x2x1x0vox
        antsApplyTransforms \
            -i ${OUTPUT_DIR}/${PREVIOUS_PREFIX}/${REPETITION_ID}_Rigid.nii.gz \
            -o ${OUTPUT_DIR}/${OUTPUT_PREFIX}/${REPETITION_ID}_transformed.nii.gz \
            -t ${OUTPUT_DIR}/${OUTPUT_PREFIX}/${REPETITION_ID}_0GenericAffine.mat
        ;;
    syn)
        antsRegistration \
            --output [${OUTPUT_DIR}/${OUTPUT_PREFIX}/${REPETITION_ID}_,${OUTPUT_DIR}/${OUTPUT_PREFIX}/${REPETITION_ID}_Warped.nii.gz,${OUTPUT_DIR}/${OUTPUT_PREFIX}/${REPETITION_ID}_InverseSyN.nii.gz] \
            --initial-moving-transform [${FIXED_IMG},${INPUT_IMG},1] \
            --transform SyN[ 0.1,3,0 ] \
            --metric CC[${FIXED_IMG},${INPUT_IMG},1,4] \
            --convergence [100x70x50x20,1e-6,10] \
            --shrink-factors 8x4x2x1 \
            --smoothing-sigmas 3x2x1x0vox
        antsApplyTransforms \
            -i ${OUTPUT_DIR}/${PREVIOUS_PREFIX}/${REPETITION_ID}_Affine.nii.gz \
            -o ${OUTPUT_DIR}/${OUTPUT_PREFIX}/${REPETITION_ID}_transformed.nii.gz \
            -t ${OUTPUT_DIR}/${OUTPUT_PREFIX}/${REPETITION_ID}_1Warp.nii.gz \
            -t ${OUTPUT_DIR}/${OUTPUT_PREFIX}/${REPETITION_ID}_0GenericAffine.mat
        ;;
esac

# Recursively call the next stages
# sh ./run-experiments.sh
