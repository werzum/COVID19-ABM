module COVID_SIR

using Agents, Random, DataFrames, LightGraphs
using Distributions: Poisson, DiscreteNonParametric
using CSV
using Plots
using LinearAlgebra:diagind
using AgentsPlots
using Images

include("spatial_setup.jl") #exports getDensityData,generateDensity
include("agent_functions.jl") #exports agent_step
include("visualization.jl") #exports create_graph,create_gif
include("model_initiation.jl") #exports model_initiation

#generating the Map
rawdata = getDensityData()
fullmap = generateDensity(rawdata, 80000, 123123123)
sum(fullmap)
gr()
heatmap(fullmap)

#agent and params setup
mutable struct agent <: AbstractAgent
    id::Int
    pos::Tuple{Int,Int}
    days_infected::Int
    status::Symbol #1: S, 2: I, 3:R
end

params = Dict(
            :beta_det=> 1,
            :beta_undet=> 3,
            :infection_period=> 10,
            :reinfection_probability=> 0.01,
            :detection_time=> 6,
            :death_rate=> 0.02)

#initialize the model
model = model_initiation(densitymap = fullmap; params...)
#Plot of overall SIR count
create_gif()
#or make a GIF with 50 steps
create_gif()

end
