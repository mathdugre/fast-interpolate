#!/bin/bash
#SBATCH -J antsBrainExtraction
#SBATCH --time=2:00:00
#SBATCH --cpus-per-task=1
#SBATCH --mem=8G
#SBATCH -o log/%x-%A-%a.out
set -e
set -u

SUBJECT_ID=$(sed -n ${SLURM_ARRAY_TASK_ID}p < subject_ids.txt)
echo "
SUBJECT_ID: ${SUBJECT_ID}
DATA_DIR: ${DATA_DIR}
"

OUTPUT_FILE=${DATA_DIR}/derivatives/flint/antsBrainExtraction/sub-${SUBJECT_ID}/BrainExtractionBrain.nii.gz
if [ -e ${OUTPUT_FILE} ]; then
    echo "Brain extracted image already exists. Exiting."
    rm log/${SLURM_JOB_NAME}-${SLURM_ARRAY_JOB_ID}-${SLURM_ARRAY_TASK_ID}.out
    exit 0
fi

APPTAINERENV_ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=${SLURM_CPUS_PER_TASK}
apptainer exec --cleanenv \
    -B ${DATA_DIR}:/data \
    --env SUBJECT_ID=${SUBJECT_ID} \
    ${SIF_IMG} \
    bash ./sbatch/antsBrainExtraction.sh