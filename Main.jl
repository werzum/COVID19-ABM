using Agents, Random, DataFrames, LightGraphs
using CSV
using Plots

#TODO add arrays to keep track of the schools, homes, workplaces, so that we can set custom infection rates and so forth for them.
#TODO map is unweighted so far, could add wheights but then have to
#TODO could clear the warnings about changed uses of filter, csv read and filter

include("SpatialSetup.jl") #exports setup
#include("agent_functions.jl") #exports agent_step
include("Visualization.jl")# exports draw_route(model,lat,long) and draw_map(model,lat,long)
#include("model_initiation.jl") #exports model_initiation

#agent and params setup
mutable struct DemoAgent <: AbstractAgent
    id::Int
    pos::Int
    health_status::Symbol #reflects the SIR extended states (Susceptible, Exposed, Infected, InfectedWitoutSymptpms, NotQuarantined, Quarantined, Dead, Immune)
    women::Bool
    age::Int8
    wealth::Int16
    household::Int32
    workplace::Int32
    socialgroup::Int32
    distantgroup::Int32
    workplaceroute::Vector{LightGraphs.SimpleGraphs.SimpleEdge{Int64}}
    socialroute::Vector{LightGraphs.SimpleGraphs.SimpleEdge{Int64}}
    distantroute::Vector{LightGraphs.SimpleGraphs.SimpleEdge{Int64}}
end
parameters = Dict(
            :beta_det=> 1,
            :beta_undet=> 3,
            :infection_period=> 10,
            :reinfection_probability=> 0.01,
            :detection_time=> 6,
            :death_rate=> 0.02)

#initialize the model and generate the map - takes about 115s
@time model,lat,long,social_groups,distant_groups = setup(parameters)

#step the model X times - each step takes about Xs

#Plot map
draw_map(model,lat,long)
