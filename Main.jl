using Agents, Random, DataFrames, LightGraphs
using CSV
using Plots
using LinearAlgebra:diagind
using AgentsPlots
using Images

include("SpatialSetup.jl") #exports setup
#include("agent_functions.jl") #exports agent_step
include("Visualization.jl")# exports draw_route(model,lat,long) and draw_map(model,lat,long)
#include("model_initiation.jl") #exports model_initiation

#agent and params setup
mutable struct DemoAgent <: AbstractAgent
    id::Int
    pos::Int
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

#initialize the model and generate the map
@time model,lat,long = setup()

params = Dict(
            :beta_det=> 1,
            :beta_undet=> 3,
            :infection_period=> 10,
            :reinfection_probability=> 0.01,
            :detection_time=> 6,
            :death_rate=> 0.02)

#Plot map
draw_map(model,lat,long)
