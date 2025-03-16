#!/bin/sh
OMP_NUM_THREADS=1

source /fsl_env.sh
mkdir -p /data/derivatives/flint/fsl-fast/sub-${SUBJECT_ID}
fast \
    -o /data/derivatives/flint/fsl-fast/sub-${SUBJECT_ID}/BrainExtractionBrain \
    /data/derivatives/flint/antsBrainExtraction/sub-${SUBJECT_ID}/BrainExtractionBrain.nii.gz
