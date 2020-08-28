#!/bin/bash -l
#SBATCH --nodes=1
#SBATCH --ntasks=8
#SBATCH --ntasks-per-node=8
#SBATCH --time=10:10:00
#SBATCH --output=myoutput.log
#SBATCH --job-name=julia_abm_testrun_1

source $HOME/julia-1.5.0/julia-environment/julia-environment
cd ~/Julia
~/julia-1.5.0/bin/julia --trace-compile=precompiled_functions.jl Main.jl
