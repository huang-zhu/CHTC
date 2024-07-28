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
- ``README.md`` Contains this same info. You can ignore/delete it.
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
  <img width="600" src=https://github.com/user-attachments/assets/f3bdb275-e126-4fed-88cd-f8ae5b5a731c>
</p>

You should see something like the screenshot above. The "mobile filesystem" can be seen from ``slot3/dir_2558735`` which will be different for every Cluster/Process. We can also see from the hostname that we were assigned the ``vetsigian0001`` server. 

Right now, we are inside the Docker container image. The image was built with all software compiled into ``/usr/local/``, so we can take a look at what's available. By echoing the ``$PATH``, we can see that the binaries have been exported so we can just call on them (*i.e.*, ``gmx --version``, ``gmx_mpi --version``, ``plumed help``, ``packmol``, ``acpype --version``, ``wham``, ``wham-2d``, etc...). Notice that both thread-MPI and MPI versions of GROMACS are available without sourcing one or the other.
<p align="center">
  <img width="600" src=https://github.com/user-attachments/assets/7048c5a0-da96-409a-8fe7-4216f0e2e369>
</p>

We will now open up the ``executable.sh`` file on our computers and run line by line as if you were typing it in. This way, we can identify specific lines that are triggering errors (if any). 

In the ``INITIALIZING JOB`` section we define the basic things needed (arguments, paths, and binaries). The way I define the binaries allows me to quickly switch between versions. Defining paths like this simplifies a lot of the code for tansferrability across multiple/different clusters. You can run this whole block of code, or line by line to see what some of the ``DEFINE ARGUMENTS`` line do (might be handy to know). 

After initializing the job, we move on to the ``MAIN SCRIPT`` section. We will copy the benchmarking TPR files to our ``${WORKING_DIR}``. Directly copying files from ``${STAGING}`` into a job is *not* the appropriate way for data transfer when using Condor. Best practices consist of going into ``${STAGING}``, copying the files into a tarball (with a name unique to the Process you are running, *i.e.*, ``inputs_rep_0.tar``, ``inputs_rep_1.tar``, etc...), transferring the tarball to the job, removing the tarball from ``${STAGING}``, and then untarring to run the rest of the script. Since this is a very light and simple tutorial, I'm just copying the files, but don't do this for real workflows. A metafile (``results.csv``) that will contain the performance results of the benchmarked systems is then generated. We also define the output name for this metafile that contains unique information from this run 

We then go into every benchmark directory using a for loop, and in each of these directories, we run the ``benchmark.tpr`` file for a short time (20,000 steps). The performance of the benchmark in ``ns/day`` and ``hr/ns`` is extracted from the LOG file and then printed into the metafile. After running all the benchmarks in the for loop, we go back into the ``${SCRATCH}`` directory and rename the metafile with the new name.

After running the main script, we move on to the ``FINALIZING JOB`` section. Here, we copy the outputs back into ``${STAGING}`` and we purge the ``${SCRATCH}}`` directory. We do this clean-up process because it's best practice to delete whatever we copied into the node, that way, we are not filling up the node's local disk (although Condor does periodic purges). In addition, files (not directories) that remain in ``${SCRATCH}`` are transferred back into your ``${HOME}`` directory from where you submitted the job, which can lead to clutter and even accidental overwrites of files depending on how you write your scripts. After purging you can just close the job by exiting. We can then check if the metafile exists and look at the performance recorded on the node. Remember that the name of the file will be different for you.
```
exit
ls ${STAGING}/benchmarks/
cat ${STAGING}/benchmarks/gromacs_chtc_1xNVIDIA_GeForce_RTX_2080_Ti_2024-07-26.csv
```
<p align="center">
  <img width="800" src=https://github.com/user-attachments/assets/42e864a2-e493-4caf-9b8a-60da55c3d1ca>
</p>

After running line by line, I like to comment out the purge line from the executable (``rm -r ${SCRATCH}/*``) and bash the script to replicate how Condor would run it when the job is submitted non-interactively. The commands would be the following, but I won't run them now (feel free to run them).
```
cd ${HOME}/benchmarks/
condor_submit -i submit_single.sub
### COMMENT OUT rm -r ${SCRATCH}/*
bash executable.sh
### CHECK IF OUTPUTS ARE CREATED.
###    IF CREATED, CONTINUE
###    IF NOT CREATED, DEBUG EXECUTABLE
rm -r ${SCRATCH}/*
```

## Single Cluster - Multi Process Job

We will now run the benchmarks using the multi process method. In this case, we will use a helper file (``jobs_multi.txt`` in this case) to run the ``executable.sh`` using different specifications for the compute capability. In the previous exercise, we defined ``(Capability > 6.0)`` which tells HTC to use any GPU. We would now like to run the benchmarks on specific GPUs by specififying compute capabilities (you can read more about this on CHTC's website). From the ``jobs_multi.txt`` we can see that we have four lines, each line containing a number for the compute capability requested. When we run the ``submit_multi.sub`` submit file, Condor will read each line as an argument, which are declared within the submit file. These arguments are then used throughout the rest of the submit file, hence we can change parameters from this file using the helper file.

```
cd ${HOME}/benchmarks/
condor_submit submit_multi.sub
```

<p align="center">
  <img width="600" src=https://github.com/user-attachments/assets/e438ab3c-edbf-4924-86fa-5a8746f50b02>
</p>

As seen from the screenshot above, the job is run in a single Cluster (``400278``), but with four Processes (``.0-.3``). These can take minutes or even hours to start depending on the queue.

Once all four jobs finish, you should see the metafile from each job inside your ``${STAGING}/benchmarks/`` directory. In my case, we can see that our previous 2080 Ti benchmark was overwritten since the job was submitted to the same server.

<p align="center">
  <img width="800" src=https://github.com/user-attachments/assets/0850aac8-554e-4736-bfc7-86cd31d3a5d2>
</p>

Just for reference, these are the results from my run:

<p align="center">
  <img width="800" src=https://github.com/user-attachments/assets/4aa3629f-a8df-4d70-b0f3-0d2c68c4b0c4>
</p>

Keep in mind that performance will be somewhat different all-around. This is due to the way that Condor is set up, specifically in terms of CPU binding. This means that the requested CPU cores may or may not be correctly pinned to maximize GROMACS performance (if you want to learn more, look into the GROMACS documentation or ask around in the group). In summary, the random assignment of CPU cores will greatly impact performance on a Proces-to-Process basis. This is something you have to consider when planning your jobs and developing workflows for HTC. Furthermore, we have to consider that HTC is best suited for high-throughput, particularly many short jobs that require few cores and that are strongly accelerated by GPUs. Running longer and/or more intensive jobs will suffer from performance degradation and wall clock times will significantly vary for each Process. This concludes the first tutorial, and you should now be able to begin writing code (or porting existing code) to run GROMACS in HTC. 








