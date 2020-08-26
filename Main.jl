using Distributed
using Agents, Random, DataFrames, LightGraphs, CSV, Plots
using Gadfly, Interact, Compose, Printf, Reactive

include("SpatialSetup.jl") #exports setup
#include("agent_functions.jl") #exports agent_step
include("Visualization.jl")# exports draw_route(model,lat,long) and draw_map(model,lat,long)
#include("model_initiation.jl") #exports model_initiation
include("UtilityFunctions.jl")# exports add_infected(number),reset_infected(model)
include("Validation.jl")#exports nothing so far
include("SteppingFunction.jl")#exports agent_week!

#agent and params setup
@everywhere mutable struct DemoAgent <: AbstractAgent
    id::Int
    pos::Int
    health_status::Symbol #reflects the SIR extended states (Susceptible, Exposed, Infected, InfectedWitoutSymptpms, NotQuarantined, Quarantined, Dead, Immune)
    days_infected::Int16
    attitude::Int16
    original_attitude::Int16
    fear::Float32
    behavior::Int16
    acquaintances_growth::Int32
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
            :exposed_period=>5,
            :infected_now=> 0,
            :infected_reported=>0,
            :norms_message=>0,
            :daily_cases=>0,
            :work_closes=>21,
            :work_opens=>70,
            :reinfection_probability=> 0.01,
            :detection_time=> 6,
            :death_rate=> 0.047,
            :days_passed => 0)

#initialize the model and generate the map - takes about 115s for 13.000 agents
model,lat,long, social_groups, distant_groups = setup(parameters)
#add workers and make the packages available for all of them
addprocs(7)

@everywhere using Agents, Random, DataFrames, LightGraphs, CSV, Plots
@everywhere using StatsBase, Distributions, Statistics,Distributed, GraphPlot, GraphRecipes, AgentsPlots, StatsPlots, Luxor, LightGraphs, OpenStreetMapX
include("UtilityFunctions.jl")# exports add_infected(number),reset_infected(model)
include("SteppingFunction.jl")#exports agent_week!
#make important data available as well - eval evaluates expression on global scope, everywhere makes it available for all workers, what does $do?
@everywhere mutable struct DemoAgent <: AbstractAgent
    id::Int
    pos::Int
    health_status::Symbol #reflects the SIR extended states (Susceptible, Exposed, Infected, InfectedWitoutSymptpms, NotQuarantined, Quarantined, Dead, Immune)
    days_infected::Int16
    attitude::Int16
    original_attitude::Int16
    fear::Float32
    behavior::Int16
    acquaintances_growth::Int32
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
@eval @everywhere model = $model
@eval @everywhere social_groups = $social_groups
@eval @everywhere distant_groups = $distant_groups
