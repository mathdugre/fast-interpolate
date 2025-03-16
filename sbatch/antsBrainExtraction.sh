#!/bin/sh
TMPLT="/opt/templates/OASIS"

antsBrainExtraction.sh \
    -d 3 \
    -a /data/sub-${SUBJECT_ID}/ses-open/anat/sub-${SUBJECT_ID}_ses-open_T1w.nii.gz \
    -e ${TMPLT}/T_template0.nii.gz \
    -m ${TMPLT}/T_template0_BrainCerebellumProbabilityMask.nii.gz \
    -o /data/derivatives/flint/antsBrainExtraction/sub-${SUBJECT_ID}/
