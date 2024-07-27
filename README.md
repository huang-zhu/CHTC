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

First, we have to clone this repository into our ``$HOME`` directory and replace my username with yours.

```
mkdir -p ${HOME}/benchmarks/
git clone https://github.com/huang-zhu/CHTC -b benchmarks ${HOME}/benchmarks/
sed -i s/'huangzhu'/`whoami`/g ${HOME}/benchmarks/executable.sh

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

The following files will be included and are required to run GROMACS on HTC:
- ``README.md``: Contains this same info. You can ignore/delete it.
- ``executable.sh`` Script that will run on the assigned node. When a job is submitted, Condor basically runs ``sbatch executable.sh`` on the node (with input arguments/variables if provided).
- ``jobs_multi.txt`` File that contains the input arguments for running multi process jobs. This is like running ``sbatch executable.sh [VAR1]``, ``sbatch executable.sh [VAR2]``, etc... for however many variables you have.
- ``submit_multi.sub`` File that contains Condor requirements. This is analogous to the ``#SBATCH`` directives on Slurm. The ``_multi`` version reads in the rows in a helper file (``jobs_multi.txt`` in this case) as input arguments to ``executable.sh``.
- ``submit_single.sub`` File that contains Condor requirements. This is analogous to the ``#SBATCH`` directives on Slurm. The ``_single`` doesn't read input arguments and only queues one process in one cluster.

I strongly encourage you to take a look at these files and try to understand them. I tried to have the executable script well-commented for readibility, but feel free to reach out if you still have questions after reading through it.

The ``gromacs/`` directory contains five sub-directories, each containing the TPR files for benchmarking, and has to be moved to ``${STAGING}/benchmarks/``.

```
mkdir -p ${STAGING}/benchmarks/
mv ${HOME}/benchmarks/gromacs/ ${STAGING}/benchmarks/
```

We are now ready to run the benchmarks from our ``${HOME}/benchmarks/`` directory. 

## Single Cluster - Single Process Job

Since the great majority of the time we will be running Multi Process Jobs, we will take this moment to run the Single Process Job benchmark in interactive mode to illustrate how we would go about debugging code on HTC. This is extremely important because porting code written on your workstation or on SWARM (Slurm) is a tedious process since we are moving over to Condor with the mobile filesystem. 

We will start by running an interactive session from the ``${HOME}/benchmarks/`` directory. The ``-i`` on the ``condor_submit`` command below refers to "interactive".
```
cd ${HOME}/benchmarks/
condor_submit -i submit_single.sub
```
<p align="center">
  <img width="600" src=https://github.com/user-attachments/assets/2f59b3e8-b78c-4d79-a185-bbb39980cfff>
</p>

You should see something like the screenshot above. The "mobile filesystem" can be seen from ``slot3/dir_1890475`` which will be different for every Cluster/Process. We can also see from the hostname that we were assigned the ``vetsigian0001`` server. 

Right now, we are inside the Docker container image. The image was built with all software compiled into ``/usr/local/``, so we can take a look at what's available. By echoing the ``$PATH``, we can see that the binaries have been exported so we can just call on them (*i.e.*, ``gmx --version``, ``gmx_mpi --version``, ``plumed help``, ``packmol --version``, ``acpype --version``, ``wham``, ``wham-2d``, etc...). Notice that both thread-MPI and MPI versions of GROMACS are available without sourcing one or the other.
<p align="center">
  <img width="600" src=https://github.com/user-attachments/assets/b5fe53f7-1021-45cf-bcdc-2886e7e64176>
</p>

We will now open up the ``executable.sh`` file on our computers and run line by line as if you were typing it in. This way, we can identify specific lines that are triggering errors (if any). 

In the ``INITIALIZING JOB`` section we define the basic things needed (arguments, paths, and binaries). The way I define the binaries allows me to quickly switch between versions. Defining paths like this simplifies a lot of the code for tansferrability across multiple/different clusters. You can run this whole block of code, or line by line to see what some of the ``DEFINE ARGUMENTS`` line do (might be handy to know). 

After initializing the job, we move on to the ``MAIN SCRIPT`` section. We will copy the benchmarking TPR files to our ``${WORKING_DIR}``. Directly copying files from ``${STAGING}`` into a job is *not* the most preferred way. Best practices consist of going into ``${STAGING}``, copying the files into a tarball (with a name unique to the Process you are running, *i.e.*, ``inputs_rep_0.tar``, ``inputs_rep_1.tar``, etc...), transferring the tarball to the job, removing the tarball from ``${STAGING}``, and then untarring to run the rest of the script. Since this is a very light and simple tutorial, I'm just copying the files, but don't do this for real workflows. A metafile (``results.csv``) that will contain the performance results of the benchmarked systems is then generated. We also define the output name for this metafile that contains unique information from this run 

We then go into every benchmark directory using a for loop, and in each of these directories, we run the ``benchmark.tpr`` file for a short time (20,000 ps). The performance of the benchmark in ``ns/day`` and ``hr/ns`` are extracted from the LOG file and then printed into the metafile. After running all the benchmarks in the for loop, we go back into the ``${SCRATCH}`` directory and rename the metafile with the new name.

After running the main script, we move on to the ``FINALIZING JOB`` section. Here, we copy the outputs back into ``${STAGING}`` and we purge the ``${SCRATCH}}`` directory. We do this clean-up process because it's best practice to delete whatever we copied into the node, that way, we are not filling up the node's local disk (although Condor does periodic purges). In addition, files (not directories) that remain in ``${SCRATCH}`` are transferred back into your ``${HOME}`` directory from where you submitted the job, which can lead to clutter and even accidental overwrites of files depending on how you write your scripts. After, purging you can just close the job by exiting. We can then check if the metafile exists and look at the performance recorded on the node. Remember that the name of the file will be different for you.
```
exit
ls ${STAGING}/benchmarks/
cat ${STAGING}/benchmarks/gromacs_chtc_1xNVIDIA_GeForce_RTX_2080_Ti_2024-07-26.csv
```
<p align="center">
  <img width="800" src=https://github.com/user-attachments/assets/eb7ff0a9-c503-4474-847c-664aeca50cb0>
</p>




## Single Cluster - Multi Process Job

