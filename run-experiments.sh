#!/bin/sh
set -e
set -u

NTHREAD=1
MAX_JOBS=8
PROJECT_DIR=/mnt/lustre/mathdugre/fast-interpolate
SIF_DIR=/mnt/lustre/mathdugre/containers

# Datatset preparation
cat << EOF
########################
# Datatset preparation #
########################
EOF
DATA_DIR=${PROJECT_DIR}/datasets/ds004513
DATALAD_URL="https://github.com/OpenNeuroDatasets/ds004513.git"
echo "datalad install -gr -J\$(nproc) --source ${DATALAD_URL} ${DATA_DIR}"
## Convert symlink to hardlink to prevent issue with preprocessing
echo "find ${DATA_DIR} -type l -exec bash -c 'ln -f \$(readlink -m \$0) \$0' {} \;"

# Write subjects to file
find ${DATA_DIR} -maxdepth 1 -name "sub-*" -exec basename {} \;| sed -e "s/^sub-//" > subject_ids.txt

cat << EOF

######################
# Launch Experiments #
######################
EOF
mkdir -p log

export NUM_SUBJECTS=$(wc -l < subject_ids.txt)
# export NUM_SUBJECTS=1
export START_REPETITIONS=1
export NUM_REPETITIONS=10
export EXPERIMENT_NAME="rand_nn"
export SIF_IMG_BASE=${SIF_DIR}/ants-debug.simg
export SIF_IMG_EXP=${SIF_DIR}/ants-rand-nn.simg

# Function to map the SLURM_ARRAY_TASK_ID to subject, repetition, and experiment
NUM_EXPERIMENTS=14
map_task_id() {
    local task_id=$1
    NTH_SUBJECT=$(( (task_id - 1) / (NUM_REPETITIONS * NUM_EXPERIMENTS) + 1 ))
    REPETITION_ID=$(( ( (task_id - 1) % (NUM_REPETITIONS * NUM_EXPERIMENTS) ) / NUM_EXPERIMENTS + START_REPETITIONS ))
    EXPERIMENT_ID=$(( (task_id - 1) % NUM_EXPERIMENTS + 1 ))
}

# Iterate over all tasks
TOTAL_TASKS=$((NUM_SUBJECTS * NUM_REPETITIONS * NUM_EXPERIMENTS))
for task_id in $(seq 1 $TOTAL_TASKS); do
    map_task_id $task_id

    SUBJECT_ID=$(sed -n ${NTH_SUBJECT}p < subject_ids.txt)

    FIXED_IMG=/templateflow/tpl-MNI152NLin2009cAsym/tpl-MNI152NLin2009cAsym_res-01_desc-brain_T1w.nii.gz
    MOVING_IMG=${DATA_DIR}/derivatives/fsl/fast/sub-${SUBJECT_ID}/ses-open/anat/BrainExtractionBrain_seg.nii.gz
    OUTPUT_DIR=${DATA_DIR}/derivatives/flint/ants/${EXPERIMENT_NAME}/sub-${SUBJECT_ID}/ses-open/anat

    # Determine the STAGE and input image for the current task
    case $EXPERIMENT_ID in
        1)  # .0
            STAGE="rigid"
            INPUT_IMG=$MOVING_IMG
            SIF_IMG=$SIF_IMG_BASE
            OUTPUT_PREFIX="0"
            ;;
        2) # .1
            STAGE="rigid"
            INPUT_IMG=$MOVING_IMG
            SIF_IMG=$SIF_IMG_EXP
            OUTPUT_PREFIX="1"
            ;;

        3) # 0.0
            STAGE="affine"
            INPUT_IMG=${OUTPUT_DIR}/0/${REPETITION_ID}_Rigid.nii.gz
            SIF_IMG=$SIF_IMG_BASE
            OUTPUT_PREFIX="00"
            ;;
        4) # 0.1
            STAGE="affine"
            INPUT_IMG=${OUTPUT_DIR}/0/${REPETITION_ID}_Rigid.nii.gz
            SIF_IMG=$SIF_IMG_EXP
            OUTPUT_PREFIX="01"
            ;;
        5) # 1.0
            STAGE="affine"
            INPUT_IMG=${OUTPUT_DIR}/1/${REPETITION_ID}_Rigid.nii.gz
            SIF_IMG=$SIF_IMG_BASE
            OUTPUT_PREFIX="10"
            ;;
        6) # 1.1
            STAGE="affine"
            INPUT_IMG=${OUTPUT_DIR}/1/${REPETITION_ID}_Rigid.nii.gz
            SIF_IMG=$SIF_IMG_EXP
            OUTPUT_PREFIX="11"
            ;;

        7) # 00.0
            STAGE="syn"
            INPUT_IMG=${OUTPUT_DIR}/00/${REPETITION_ID}_Affine.nii.gz
            SIF_IMG=$SIF_IMG_BASE
            OUTPUT_PREFIX="000"
            ;;
        8) # 00.1
            STAGE="syn"
            INPUT_IMG=${OUTPUT_DIR}/00/${REPETITION_ID}_Affine.nii.gz
            SIF_IMG=$SIF_IMG_EXP
            OUTPUT_PREFIX="001"
            ;;
        9) # 01.0
            STAGE="syn"
            INPUT_IMG=${OUTPUT_DIR}/01/${REPETITION_ID}_Affine.nii.gz
            SIF_IMG=$SIF_IMG_BASE
            OUTPUT_PREFIX="010"
            ;;
        10) # 01.1
            STAGE="syn"
            INPUT_IMG=${OUTPUT_DIR}/01/${REPETITION_ID}_Affine.nii.gz
            SIF_IMG=$SIF_IMG_EXP
            OUTPUT_PREFIX="011"
            ;;
        11) # 10.0
            STAGE="syn"
            INPUT_IMG=${OUTPUT_DIR}/10/${REPETITION_ID}_Affine.nii.gz
            SIF_IMG=$SIF_IMG_BASE
            OUTPUT_PREFIX="100"
            ;;
        12) # 10.1
            STAGE="syn"
            INPUT_IMG=${OUTPUT_DIR}/10/${REPETITION_ID}_Affine.nii.gz
            SIF_IMG=$SIF_IMG_EXP
            OUTPUT_PREFIX="101"
            ;;
        13) # 11.0
            STAGE="syn"
            INPUT_IMG=${OUTPUT_DIR}/11/${REPETITION_ID}_Affine.nii.gz
            SIF_IMG=$SIF_IMG_BASE
            OUTPUT_PREFIX="110"
            ;;
        14) # 11.1
            STAGE="syn"
            INPUT_IMG=${OUTPUT_DIR}/11/${REPETITION_ID}_Affine.nii.gz
            SIF_IMG=$SIF_IMG_EXP
            OUTPUT_PREFIX="111"
            ;;
    esac

    case $STAGE in
        rigid)
            OUTPUT_FILE=${OUTPUT_DIR}/${OUTPUT_PREFIX}/${REPETITION_ID}_Rigid.nii.gz
        ;;
        affine)
            OUTPUT_FILE=${OUTPUT_DIR}/${OUTPUT_PREFIX}/${REPETITION_ID}_Affine.nii.gz
        ;;
        syn)
            OUTPUT_FILE=${OUTPUT_DIR}/${OUTPUT_PREFIX}/${REPETITION_ID}_Warped.nii.gz
        ;;
    esac

    if [[ -f $INPUT_IMG && ! -e $OUTPUT_FILE ]]; then
        JOB_NAME=${EXPERIMENT_NAME}-${SUBJECT_ID}-${OUTPUT_PREFIX}-${REPETITION_ID}
        JOB_QUEUED=$(squeue -u $USER --name $JOB_NAME --noheader | wc -l)

        if [[ $JOB_QUEUED -eq 0 ]]; then
            # Submit the job or run the command
            sbatch \
                --job-name=$JOB_NAME \
                --output=log/$JOB_NAME.out \
                --error=log/$JOB_NAME.err \
                run-stage.sh \
                $SIF_IMG \
                $STAGE \
                $FIXED_IMG \
                $DATA_DIR \
                $INPUT_IMG \
                $OUTPUT_DIR \
                $OUTPUT_PREFIX \
                $SUBJECT_ID \
                $REPETITION_ID
        fi
    fi
done
