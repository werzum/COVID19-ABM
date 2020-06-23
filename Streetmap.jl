using OpenStreetMapX, LightGraphs, GraphPlot, GraphRecipes
using CSV, DataFrames
using Agents, AgentsPlots
using Statistics
using Distributed
using DataFramesMeta
using Luxor
using StatsBase
using Random

function create_node_map()
    #get map data and intersections
    aachen_map = get_map_data("SourceData\\aachen_bigger.osm", use_cache=false, only_intersections=true)
    aachen_graph = aachen_map.g
    bounds = aachen_map.bounds

    #lat long of Aachen as reference frame
    LLA_ref = LLA((bounds.min_y+bounds.max_y)/2, (bounds.min_x+bounds.max_x)/2, 0.0)
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
    #graphplot(aachen_graph, markersize=2, x=LLA_Dict_longs, y=LLA_Dict_lats)
    #show the map to prove how cool and orderly it is
    #gplot(aachen_graph, LLA_Dict_longs, LLA_Dict_lats)

    #savegraph("Graphics\\aachen_graph.lgz", aachen_graph)
    aachen_graph = aachen_graph, LLA_Dict_longs, LLA_Dict_lats, bounds

    return aachen_graph
end

function create_demography_map()

    rawdata = CSV.read("SourceData\\zensus.csv")

    #make sure properties are symbols
    colsymbols = propertynames(rawdata)
    rename!(rawdata,colsymbols)

    #@time plot(rawdata.X,rawdata.Y)
    return rawdata
end

function fill_map(model,group,long, lat, correction_factor)
    nrow(group) < 2 && return
    #get the bounds and skip if the cell is empty
    top = maximum(group[:Y])
    bottom = minimum(group[:Y])
    left = minimum(group[:X])
    right = maximum(group[:X])
    top-bottom == 0 && right-left == 0 && return

    possible_nodes_long = findall(y -> isbetween(left,y,right), long)
    possible_nodes_lat = findall(x -> isbetween(bottom, x, top), lat)
    #get index of nodes to create a base of nodes we can later add our agents to
    #and skip if there are no nodes within this space
    possible_nodes = (intersect(possible_nodes_lat,possible_nodes_long))
    length(possible_nodes) == 0 && return

    #get the number of inhabitants, women, old people etc for the current grid
    inhabitants = Int(round(mean(group.Einwohner)/(correction_factor/1000)))
    women = get_amount(inhabitants,group.Frauen_A)
    age = Int(round(mean(group.Alter_D)))
    below18 = get_amount(inhabitants,group.unter18_A)
    over65 = get_amount(inhabitants,group.ab65_A)
    rich = Int(get_amount(inhabitants,20))
    middle = poor = Int(get_amount(inhabitants,40))
    kaufkraft = mean(group.kaufkraft)

    #println("We have $(inhabitants) inhabitants with $(women) women, $(age) mean age, $(over65) old people and $rich rich, $poor poor persons \n")

    #fill array with default agents of respective amount of agents with young/old age and gender
    agent_properties = Vector{agent_tuple}(undef,inhabitants)
    for x in 1:inhabitants
        agent_properties[Int(x)] = agent_tuple(false,age,wealth)
    end
    for w in 1:women
        agent_properties[rand(1:inhabitants)].women = true
    end
    for y in 1:below18
        agent_properties[rand(1:inhabitants)].age = rand(1:17)
    end
    for o in 1:over65
        temp_arr = findall(x -> x.age == age, agent_properties)
        agent_properties[rand(temp_arr)].age = rand(66:100)
    end

    #shuffle the agent_properties and add wealth data
    shuffle!(agent_properties)
    [agent.wealth = kaufkraft+rand(0:1000) for agent in agent_properties[1:rich]]
    [agent.wealth = kaufkraft-100+rand(0:200) for agent in agent_properties[rich:(rich+middle)]]
    [agent.wealth = kaufkraft-150+rand(0:100) for agent in agent_properties[(rich+middle):end]]
    println("ranges are $rich for rich, $(rich+middle) for middle and $(length(agent_properties))")

    #make groups of 1-4, group by wealth, age?

    for agent in agent_properties
        add_agent!(rand(possible_nodes), model, agent.women, agent.age, agent.wealth)
    end
    return
end


#helper functions
function get_amount(inhabitants,input)
    return round((inhabitants*(mean(input)/100)))
end

isbetween(a, x, b) = a <= x <= b || b <= x <= a

mutable struct DemoAgent <: AbstractAgent
    id::Int
    pos::Int
    women::Bool
    age::Int8
    wealth::Int16
end

mutable struct agent_tuple
    women::Bool
    age::Int16
    wealth::Int16
end

function setup(model)
    #TODO improve working_grid cell selection we also get edge cases, leads to some empty grid cells
    #TODO optimize for loop so we dont use those weird nested for loops
    #TODO maybe add a normal-distribution for wealth instead of the bins

    #create the nodemap and rawdata demography map and set the bounds for it

    r1 = @spawn create_node_map()
    r2 = @spawn create_demography_map()

    nodes,long,lat,bounds = fetch(r1)
    rawdata = fetch(r2)

    #get the grid data within the boundaries of the node map
    working_grid = rawdata[(rawdata.X .> bounds.min_x) .& (rawdata.X .< bounds.max_x) .& (rawdata.Y .> bounds.min_y).& (rawdata.Y .< bounds.max_y),:]
    working_grid = groupby(working_grid,:DE_Gitter_ETRS89_LAEA_1km_ID_1k; sort=true)

    #divide the population by this to avoid computing me to death
    #should scale nicely with graph size to keep agent number in check
    correction_factor = nv(nodes)

    #set up the variables and iterate over the groups to fill the node map
    inhabitants = women = age = below18 = over65 = wealth = 0

    DemoAgent(id;women,age) = DemoAgent(id,women,age)
    space = GraphSpace(nodes)
    model = ABM(DemoAgent,space)

    @time @inbounds for group in working_grid
        fill_map(model,group,long,lat,correction_factor)
    end

    return model

    N = Agents.nodes(model)
    ncolor = Vector(undef, length(N))
    nodesizevec = Vector(undef, length(N))

    #color and size the nodes according to the population
    #could set size to population and color to other attributes (sickness, belief,...)
    for (i, n) in enumerate(N)
        a = get_node_agents(n, model)
        #set color for empty nodes and populated nodes
        b = [agent.wealth for agent in a]
        ncolor[i]=cgrad(:inferno)[mean(b)/10]
        length(a)==0 ? nodesizevec[i] = 1 : nodesizevec[i] = 3
    end
    gplot(nodes, long, lat, nodefillc=ncolor, nodesize=nodesizevec, edgestrokec=cgrad(:inferno)[100])

end
