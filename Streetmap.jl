using OpenStreetMapX
using Plots
using OpenStreetMapXPlot
using LightGraphs
using AgentsPlots
using GraphPlot

#get map data and intersections
aachen_map = get_map_data("SourceData\\map.osm", use_cache=false, only_intersections=true)
aachen_graph = aachen_map.g

#lat long of Aachen as reference frame
LLA_ref = LLA(50.77664, 6.08342, 0.0)
LLA_ref.lat
#conversion to lat long coordinates
LLA_Dict = OpenStreetMapX.LLA(aachen_map.nodes, LLA_ref)
#filter the LLA_Dict so we have only the nodes we have in the graph
LLA_Dict = filter(key -> haskey(aachen_map.v, key.first), LLA_Dict)

#sort the LLA_dict_values as in aachen_map.v so the graph has the right ordering of the nodes
LLA_Dict_values = Vector{LLA}(undef,length(LLA_Dict))
for (key,value) in aachen_map.v
    LLA_Dict_values[value] = LLA_Dict[key]
end

#and parse the lats longs into separate vectors
LLA_Dict_lats = zeros(Float64,0)
LLA_Dict_longs = zeros(Float64,0)
for (value) in LLA_Dict_values
    append!(LLA_Dict_lats, value.lat)
    append!(LLA_Dict_longs, value.lon)
end

aachen_graph = SimpleGraph(aachen_graph)
gplot(aachen_graph, LLA_Dict_lats, LLA_Dict_longs)

using Agents, AgentsPlots

mutable struct SchellingAgents <: AbstractAgent
    id::Int # The identifier number of the agent
    pos::Int # The x, y location of the agent on a 2D grid
    mood::Bool # whether the agent is happy in its node. (true = happy)
    group::Int # The group of the agent,  determines mood as it interacts with neighbors
end

space = GraphSpace(aachen_map.g)
model = ABM(SchellingAgents,space)

for x in 1:100
    agent = SchellingAgents(x+200, x, false, 1)
    add_agent!(agent, model)
end

plotargs = (node_size = 0.001, method = :spring, linealpha = 0.1)

agent_number(x) = cgrad(:inferno)[length(x)]
agent_size(x) = length(x)/10

plotabm(model; ac = agent_number, as=agent_size, plotargs...)
