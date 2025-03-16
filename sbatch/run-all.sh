#!/bin/sh
set -e
set -u

export PROJECT_DIR=/mnt/lustre/mathdugre/fast-interpolate
SIF_DIR=/mnt/lustre/mathdugre/containers
export TEMPLATEFLOW_DIR=$HOME/.cache/templateflow

# Datatset preparation
cat << EOF
########################
# Datatset preparation #
########################
EOF
export DATA_DIR=${PROJECT_DIR}/datasets/ds004513
DATALAD_URL="https://github.com/OpenNeuroDatasets/ds004513.git"
echo "datalad install -gr -J\$(nproc) --source ${DATALAD_URL} ${DATA_DIR}"
## Convert symlink to hardlink to prevent issue with preprocessing
echo "find ${DATA_DIR} -type l -exec bash -c 'ln -f \$(readlink -m \$0) \$0' {} \;"

# Write subjects to file
find ${DATA_DIR} -maxdepth 1 -name "sub-*" -exec basename {} \;| sed -e "s/^sub-//" > subject_ids.txt
NUM_SUBJECTS=$(wc -l < subject_ids.txt)

#########################
# ANTs Brain Extraction #
#########################
export SIF_IMG=${SIF_DIR}/ants-paper-base.simg
job1=$(sbatch --parsable --array=1-${NUM_SUBJECTS} ./sbatch/antsBrainExtraction.sbatch)

#####################
# ANTs Registration #
#####################
export APPTAINERENV_ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=1  # Default value for pipelines
export FIXED_IMG=/templateflow/tpl-MNI152NLin2009cAsym/tpl-MNI152NLin2009cAsym_res-01_desc-brain_T1w.nii.gz

export SIF_IMG=${SIF_DIR}/ants-vprec-no_metric.simg

# Binary64
export EXPERIMENT_NAME="binary64"
export APPTAINERENV_VFC_BACKENDS="libinterflop_ieee.so"
export THRESHOLD="1e-6"
sbatch --dependency=afterok:$job1 --array=1-${NUM_SUBJECTS} ./sbatch/antsRegistration.sbatch

# Space search
for precision in {23..1}; do
    for range in {8..7}; do
        # EXP=$(python3 -c "import math; print(math.floor(math.log10(2)*$precision) - 1)")
        # export THRESHOLD="1e-${EXP}"
        export THRESHOLD="1e-6"

        export EXPERIMENT_NAME="r${range}-p${precision}"
        export APPTAINERENV_VFC_BACKENDS="libinterflop_vprec.so --range-binary32=$range --precision-binary32=$precision --range-binary64=$range --precision-binary64=$precision"
        # sbatch --job-name=${EXPERIMENT_NAME} --dependency=afterok:$job1 --array=1-${NUM_SUBJECTS} ./sbatch/antsRegistration.sbatch
        sbatch --job-name=${EXPERIMENT_NAME} --dependency=afterok:$job1 --array=1-${NUM_SUBJECTS} ./sbatch/antsRegistration-001.sbatch
        sbatch --job-name=${EXPERIMENT_NAME} --dependency=afterok:$job1 --array=1-${NUM_SUBJECTS} ./sbatch/antsRegistration-011.sbatch
    done
done
