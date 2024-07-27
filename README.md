# CHTC: Benchmarks

To run these benchmarks, you need access to the /staging directory. If you don't have access, please reach out to CHTC and ask for it.
We will run GROMACS 2021.5 benchmarks on HTC in two ways:

(1) Single Cluster - Single Process Job:
- A single job (Process) is submitted to a single node (Cluster), running a single instance of the executable script. Will show up as ``JOBID 000.0``.

(2) Single Cluster - Multi Process Job:
- Multiple "sub-jobs" (Process) are submitted to multiple nodes (Cluster). Condor considers multiple nodes a Cluster, while jobs that are running on the Cluster (on different nodes) are different Processes. Will show up as ``JOBID 000.0``, ``JOBID 000.1``, etc... for however many Processes you requested.

We will be using a Docker container to run GROMACS on HTC. You can alternatively use Singularity, but I don't have experience with running Singularity on HTC. The container we'll be using is the ``huangzhu/chtc:1.0`` image from my hub (https://hub.docker.com/r/huangzhu). You can find the contained software by following the link and clicking on ``huangzhu/chtc``.

TPR files were taken from:

- https://hpc.fau.de/2022/02/10/gromacs-performance-on-different-gpu-types --- 20k (fast output), 32k, and 80k systems
- https://www.hecbiosim.ac.uk/access-hpc/benchmarks --- 19k and 70k systems

## Set up files

First, we have to clone this repository into our ``$HOME`` directory.

```
mkdir -p ${HOME}/benchmarks/
git clone https://github.com/huang-zhu/CHTC -b benchmarks ${HOME}/benchmarks/

### EXPECTED OUTPUT:
# git clone https://github.com/huang-zhu/CHTC -b benchmarks ${HOME}/benchmarks
# Cloning into '/home/huangzhu/benchmarks'...
# remote: Enumerating objects: 31, done.
# remote: Counting objects: 100% (31/31), done.
# remote: Compressing objects: 100% (23/23), done.
# remote: Total 31 (delta 6), reused 0 (delta 0), pack-reused 0
# Receiving objects: 100% (31/31), 4.73 MiB | 9.83 MiB/s, done.
# Resolving deltas: 100% (6/6), done.
```

The following additional files will be included:
- ``README.md``: Contains this same info. You can ignore/delete it.
- ``executable.sh`` Script that will run on the assigned node. When a job is submitted, Condor basically runs ``sbatch executable.sh`` on the node (with input arguments/variables if provided).
- ``jobs_multi.txt`` File that contains the input arguments for running multi process jobs. This is like running ``sbatch executable.sh [VAR1]``, ``sbatch executable.sh [VAR2]``, etc... for however many variables you have.
- ``submit_multi.sub`` File that contains Condor requirements. This is analogous to the ``#SBATCH`` directives on Slurm. The ``_multi`` version reads in the rows in a helper file (``jobs_multi.txt`` in this case) as input arguments to ``executable.sh``.
- ``submit_single.sub`` File that contains Condor requirements. This is analogous to the ``#SBATCH`` directives on Slurm. The ``_single`` doesn't read input arguments and only queues one process in one cluster.

These files have to be placed in our HTC ``$STAGING`` directory. 

```
mkdir -p ${STAGING}/benchmarks/
mv ${HOME}/benchmarks/gromacs/ ${STAGING}/benchmarks/
```

We are now ready to run the benchmarks from our ``${HOME}/benchmarks/`` directory.

## Single Cluster - Single Process Job



## Single Cluster - Multi Process Job

