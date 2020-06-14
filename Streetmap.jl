using OpenStreetMapX, LightGraphs, GraphPlot, GraphRecipes
using CSV, DataFrames
using Agents, AgentsPlots
using Statistics

function create_node_map()
    #get map data and intersections
    aachen_map = get_map_data("SourceData\\map.osm", use_cache=false, only_intersections=true)
    aachen_graph = aachen_map.g

    #lat long of Aachen as reference frame
    LLA_ref = LLA(50.77664, 6.08342, 0.0)
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
    aachen_graph = aachen_graph, LLA_Dict_longs, LLA_Dict_lats

    return aachen_graph
end

function create_demography_map()
    #wrote changes to csv so we dont have to do basic cleaning again and again
    #read the data
    #rawdata = CSV.read("SourceData\\zensus3.csv")
    #drop irrelevant columns and redundant rows
    #select!(rawdata,Not(16))
    #rawdata = rawdata[rawdata.Einwohner.!=-1,:]
    #CSV.write("SourceData\\zensus.csv",rawdata)

    rawdata = CSV.read("SourceData\\zensus.csv")
    #make sure properties are symbols
    colsymbols = propertynames(rawdata)
    rename!(rawdata,colsymbols)
    @time plot(rawdata.X,rawdata.Y)
    return rawdata
end

function fill_map(model)
    #TODO improve working_grid cell selection we also get edge cases, leads to some empty grid cells
    #TODO pass coordinates to agent space for good visualization later
    #TODO optimize for loop so we dont use those weird nested for loops

    #create the nodemap and rawdata demography map and set the bounds for it
    nodes,long,lat=create_node_map()
    topleft = (maximum(lat),minimum(long))
    bottomright = (minimum(lat),maximum(long))
    rawdata = create_demography_map()

    #get the grid data within the boundaries of the node map
    working_grid = rawdata[(rawdata.X .> topleft[2]) .& (rawdata.X .< bottomright[2]) .& (rawdata.Y .< topleft[1]) .& (rawdata.Y .> bottomright[1]),:]
    working_grid = groupby(working_grid,:DE_Gitter_ETRS89_LAEA_1km_ID_1k; sort=true)

    #divide the population by this to avoid computing me to death
    #should scale nicely with graph size to keep agent number in check
    correction_factor = nv(nodes)

    #set up the variables and iterate over the groups to fill the node map
    inhabitants = women = age = below18 = over65 = 0

    DemoAgent(id;women,age) = DemoAgent(id,women,age)
    space = GraphSpace(nodes)
    model = ABM(DemoAgent,space)

    for group in working_grid

        #get the bounds and skip if the cell is empty
        top = maximum(group[:Y])
        bottom = minimum(group[:Y])
        left = minimum(group[:X])
        right = maximum(group[:X])
        top-bottom == 0 && right-left == 0 && continue
        print(group)

        #get the number of inhabitants, women, old people etc for the current grid
        inhabitants = Int(round(mean(group.Einwohner)/(correction_factor/1000)))
        women = get_amount(inhabitants,group.Frauen_A)
        age = Int(round(mean(group.Alter_D)))
        below18 = get_amount(inhabitants,group.unter18_A)
        over65 = get_amount(inhabitants,group.ab65_A)
        #print("We have $(inhabitants) inhabitants with $(women) women, $(age) mean age and $(over65) old people \n")

        possible_nodes_long = findall(y -> isbetween(left,y,right), long)
        possible_nodes_lat = findall(x -> isbetween(bottom, x, top), lat)
        #get index of nodes to create a base of nodes we can later add our agents to
        possible_nodes = (intersect(possible_nodes_lat,possible_nodes_long))

        #fill array with default agents of respective amount of agents with young/old age and gender
        agent_properties = Vector{agent_tuple}(undef,inhabitants)
        for x in 1:inhabitants
            agent_properties[Int(x)] = agent_tuple(false,age)
        end
        for w in women
            agent_properties[rand(1:inhabitants)].women = true
        end
        for y in below18
            agent_properties[rand(1:inhabitants)].age = rand(1:17)
        end
        for o in over65
            temp_arr = findall(x -> x.age == age, agent_properties)
            agent_properties[rand(temp_arr)].age = rand(66:100)
        end

        for agent in agent_properties
            add_agent!(rand(possible_nodes), model, agent.women, agent.age)
        end
    end

    return model
    #plot to test if model is properly initialized, seems okay
    plotargs = (linealpha = 0.4, x=long, y=lat, nodesize=0.001)
    agent_number(x) = cgrad(:inferno)[length(x)]
    agent_size(x) = length(x)
    model.space.
    graphplot(model.space.graph, markersize=2, x=long, y=lat, linealpha = 0.9)
    @time plotabm(model; ac = agent_number, as=agent_size, plotargs...)

end

#helper functions
function get_amount(inhabitants,input)
    return round(mean((inhabitants*input)/100))
end

isbetween(a, x, b) = a <= x <= b || b <= x <= a

mutable struct DemoAgent <: AbstractAgent
    id::Int
    pos::Int
    women::Bool
    age::Int8
end


mutable struct agent_tuple
    women::Bool
    age::Int16
end
