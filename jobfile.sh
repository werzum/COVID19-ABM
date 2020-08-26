#!/bin/bash -l
#SBATCH --nodes=2
#SBATCH --ntasks=4
#SBATCH --ntasks-per-node=2
#SBATCH --time=00:10:00
#SBATCH --output=myoutput.log
#SBATCH --job-name=julia_abm_testrun_1

source $HOME/julia-v1.5.0/julia-environment
cd abm_folder
julia main.jl
