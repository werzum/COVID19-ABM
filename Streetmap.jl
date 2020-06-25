using OpenStreetMapX, LightGraphs, GraphPlot, GraphRecipes
using CSV, DataFrames
using Agents, AgentsPlots
using Statistics
using Distributed
using DataFramesMeta
using Luxor
using StatsBase
using Random
using StatsBase
using Distributions, StatsPlots

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
        agent_properties[Int(x)] = agent_tuple(false,age,wealth,0)
    end

    [agent.women = true for agent in agent_properties[1:women]]
    shuffle!(agent_properties)
    [agent.age = rand(1:17) for agent_properties[1:young]]
    [agent.age = rand(66:110) for agent_properties[young+1:(young+1+over65)]]

    #@simd
    #auch möglich: Maschinencode anschauen mit
    #TODO komische Verteilung: falsch gezogene Werte werden an max/min Position gesetzt?

    #shuffle the agent_properties, sample #inhabitants, map it to the desired rang and assign those to the agent properties
    wealth_distribution = BetaPrime(2.29201,108.029)
    sample = rand(wealth_distribution,inhabitants)
    #modify the sample so that its mean equals kaufkraft
    multiplier = kaufkraft/mean(sample)
    sample .* multiplier
    #and assign the wealth to inhabitants
    [agent.wealth = sample[i] for i in 1:inhabitants]
    #println("ranges are $rich for rich, $(rich+middle) for middle and $(length(agent_properties))")

    #Adding households to the map
    #avg household size is 2, so
    nodecount = Int(round(inhabitants/2))
    nodes = sample(possible_nodes,nodecount)
    nodesbefore = nv(model.space.graph)
    add_households(nodes,model,lat,long)
    #now pair agents and households within newly added nodes
    noderange = [nodesbefore:nv(model.space.graph)-2;]
    #hh distribution from paper, fitted Categorical to it
    household_distribution = Categorical([0.41889017788089716, 0.337949535962877, 0.11898201856148492, 0.09058391337973705, 0.03359435421500387])
    #sample = rand(household_distribution,inhabitants)
    #for all newly added nodes, add #hh agents to it
    #agent_index = noderange(or something)
    for (index,value) in enumerate(noderange)
        #for node in noderange
        #hhhere = rand(hhdistr)
        #for i in 1:hhhere
        #agent_properties[agent_index+i]
        #global agent_index+hhere
        #sooooo ungefähr. Problem von Zukunftscarlo
        agent_properties[index*2].household = value
        agent_properties[index*2-1].household = value
    end

    filter!(e->e.household ≠ 0,agent_properties)

    new_nodes = [Int[] for i in 1:length(nodes)]
    model.space.agent_positions = vcat(model.space.agent_positions,new_nodes)

    for agent in agent_properties
        add_agent!(agent.household, model, agent.women, agent.age, agent.wealth, agent.household)
    end
    return
end

#helper functions
function add_households(nodes,model,lat,long)
    #println("possible nodes are $possible_nodes with $inhabitants inhabitants")
    randfloat = rand(0.0000:0.00001:0.0004)
    graph = model.space.graph
    nodecount = nv(graph)
    #first add the vertices to the graph
    add_vertices!(graph,length(nodes))
    #then generate an edge and locate them to their parent node
    for (index,value) in enumerate(nodes)
        neighbors = node_neighbors(value,model)
        coordinates = (lat[value]-0.0002+randfloat,long[value]-0.0002+randfloat)
        #superhacky stuff that works like 1000%
        add_edge!(graph, value, (nodecount+index))
        push!(lat,coordinates[1])
        push!(long,coordinates[2])
    end
end

function get_additional_nodes(group,correction_factor)
    #to keep the count consistent we have to pass the same checks as above
    #TODO make those checks better or maybe put them in a function we can reuse
    nrow(group) < 2 && return 0
    #get the bounds and skip if the cell is empty
    top = maximum(group[:Y])
    bottom = minimum(group[:Y])
    left = minimum(group[:X])
    right = maximum(group[:X])
    top-bottom == 0 && right-left == 0 && return 0
    possible_nodes_long = findall(y -> isbetween(left,y,right), long)
    possible_nodes_lat = findall(x -> isbetween(bottom, x, top), lat)
    #get index of nodes to create a base of nodes we can later add our agents to
    #and skip if there are no nodes within this space
    possible_nodes = (intersect(possible_nodes_lat,possible_nodes_long))
    length(possible_nodes) == 0 && return 0

    #thats what we do: compute the nodes we add
    inhabitants = Int(round(mean(group.Einwohner)/(correction_factor/1000)))
    nodecount = Int(round(inhabitants/2))
    return nodecount
end

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
    household::Int16
end

mutable struct agent_tuple
    women::Bool
    age::Int16
    wealth::Int16
    household::Int16
end

function setup(model)
    #TODO improve working_grid cell selection we also get edge cases, leads to some empty grid cells
    #TODO optimize for loop so we dont use those weird nested for loops
    #TODO maybe add a normal-distribution for wealth instead of the bins
    #TODO also add household distribution since even 2 are not realistic

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
    #get the future amount of nodes so we can properly allocate the graph space
    #=nodes_with_households = nv(nodes)
    for group in working_grid
        global nodes_with_households = nodes_with_households+get_additional_nodes(group,correction_factor)
    end
    println("we have $(nodes_with_households) households instead of just $correction_factor")=#

    #set up the variables and iterate over the groups to fill the node map
    inhabitants = women = age = below18 = over65 = wealth = 0

    DemoAgent(id;women,age) = DemoAgent(id,women,age)
    space = GraphSpace(nodes)
    model = ABM(DemoAgent,space)

    @time @inbounds Thread.@threads for group in working_grid
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
        #ncolor[i]=cgrad(:inferno)[mean(b)/10]
        length(a)==0 ? ncolor[i]=cgrad(:inferno)[1] : ncolor[i]=cgrad(:inferno)[mean(b)/10]
        length(a)==0 ? nodesizevec[i] = 2 : nodesizevec[i] = 3
    end
    gplot(nodes, long, lat, nodefillc=ncolor, nodesize=nodesizevec)

end
