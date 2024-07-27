#!/bin/bash
 
###############################################################################################
### SCRIPT INFORMATION
###############################################################################################
# PURPOSE:
# Benchmark several GROMACS systems on HTC.

# INPUTS:
# - None. Arguments are hard-coded for paths, files and benchmark settings.

# OUTPUTS:
# - Results CSV for the requested HTC Cluster in /staging/user/benchmarks.

# ALGORITHM:
# - Records information about the HTC cluster.
# - Defines array with number of cores to test. For the intended purposes, only 1 core used.
# - Transfers benchmarking files to scratch directory and sets up file system.
# - Loops through benchmarks in short runs.
# - Performance results are saved in metadata file.
# - Metadata file is transferred back to outputs directory.
# - Scratch directory is purged.

# NOTES:
# 20240726
#   - CHZ: Created by CHZ. 
###############################################################################################

###############################################################################################
### INITIALIZING JOB
###############################################################################################
### DEFINE ARGUMENTS 
NODE=`hostname`
NODE=${NODE%%.*}
GPU_NAME=$(nvidia-smi --query-gpu=gpu_name --format=csv | tail -n 1)
GPU_NAME=${GPU_NAME// /_}
HOST_NAME=`hostname`
HOST_NAME=($HOST_NAME)
HOST_NAME=${HOST_NAME#*.}
HOST_NAME=${HOST_NAME%'.wisc.edu'*}
HOST_NAME=${HOST_NAME//./_}
DATE=$(date +%F)
NUM_GPUS=1
NUM_CORES_ARRAY=(1)

### DEFINE TRANSFER PATHS
SCRATCH=${_CONDOR_SCRATCH_DIR}
SOURCE_PATH=/staging/huangzhu
MAIN_DIR=benchmarks
BENCHMARK_DIR=gromacs
OUTPUTS_DIR=${SOURCE_PATH}/${MAIN_DIR}

### DEFINE WORKING PATHS
WORKING_DIR=${MAIN_DIR}/"$HOST_NAME"/"$NUM_GPUS"x"$GPU_NAME"/"$DATE"_"$NODE"

### DEFINE BINARIES
GMX="$(type -P gmx)"
###############################################################################################

###############################################################################################
### MAIN SCRIPT 
###############################################################################################
### TRANSFER FILES
cd ${SCRATCH}
mkdir -p ${WORKING_DIR}
cp -rv ${SOURCE_PATH}/${MAIN_DIR}/${BENCHMARK_DIR}/* ${WORKING_DIR}

### CREATE CSV FOR BENCHMARK DATA
METAFILE_RESULTS=${SCRATCH}/${WORKING_DIR}/results.csv
METAFILE_RESULTS_OUTPUT="$BENCHMARK_DIR"_"$HOST_NAME"_"$NUM_GPUS"x"$GPU_NAME"_"$DATE".csv
if [ ! -f ${METAFILE_RESULTS} ]; then
    > ${METAFILE_RESULTS}
    printf "%-10s %-10s %-10s %-10s %-10s %-10s %-30s %-10s %-10s\n" "TEST" "NUM_MPI" "NUM_OMP" "ns/day" "hours/ns" "NGPUS" "GPU" "HOST" "NODE" >> ${METAFILE_RESULTS}
    # echo "TEST", "NUM_MPI", "NUM_OMP", "ns/day", "hours/ns", "NGPUS", "GPU", "HOST", "NODE" >> ${METAFILE_RESULTS}
fi

### LOOP THROUGH BENCHMARK TESTS & NUMBER OF CORES
for TEST_DIR in ${WORKING_DIR}/*/; do
    TEST=$(basename "$TEST_DIR")
    echo -e "================================================================="
    echo -e "=== BENCHMARKING: $TEST                                          "
    echo -e "=================================================================\n"
    cd ${SCRATCH}/${WORKING_DIR}/$TEST
    for NUM_CORES in ${NUM_CORES_ARRAY[@]}; do
        ### DEFINE MPI RANKS AND OMP THREADS TO USE
        NUM_MPI=1
        NUM_OMP=$(($NUM_CORES / $NUM_MPI))
        export OMP_NUM_THREADS=$NUM_OMP

        ### RUN GROMACS
        ${GMX} mdrun -v -deffnm benchmark \
                        -ntmpi $NUM_MPI \
                        -ntomp $OMP_NUM_THREADS \
                        -nb gpu \
                        -bonded cpu \
                        -update gpu \
                        -nsteps 20000 
        
        ### EXTRACT PERFORMANCE IN (ns/day) AND (hours/ns)
        P1=$(grep "Performance: " benchmark.log | awk '{print $2}')
        P2=$(grep "Performance: " benchmark.log | awk '{print $3}')

        ### OUTPUT DATA TO METAFILE
        printf "%-10s %-10s %-10s %-10s %-10s %-10s %-30s %-10s %-10s\n" "$TEST" "$NUM_MPI" "$NUM_OMP" "$P1" "$P2" "$NUM_GPUS" "$GPU_NAME" "$HOST_NAME" "$NODE" >> ${METAFILE_RESULTS}
        # echo "$TEST", "$NUM_MPI", "$NUM_OMP", "$P1", "$P2", "$NUM_GPUS", "$GPU_NAME", "$HOST_NAME", "$NODE" >> ${METAFILE_RESULTS}
    done
done

cd ${SCRATCH}
cp -rv ${METAFILE_RESULTS} ${METAFILE_RESULTS_OUTPUT}
###############################################################################################

###############################################################################################
### FINALIZING JOB
###############################################################################################
### TRANSFER FILES
cp -rv ${METAFILE_RESULTS_OUTPUT} ${OUTPUTS_DIR}

### CLEAN-UP
rm -r ${SCRATCH}/*
###############################################################################################



