using Agents

mutable struct SchellingAgent <: AbstractAgent
    id::Int
    pos::Tuple{Int, Int}
    mood::Bool
    group::Int
end

space = Space((10,10), moore = true)

properties = Dict(:min_to_be_happy => 3)

schelling = ABM(SchellingAgent, space;
                scheduler = fastest, properties = properties)

function initialize(;numagents=320, griddims=(20,20), min_to_be_happy=3)
    space = Space(griddims, moore = true)
    properties = Dict(:min_to_be_happy => 3)
    model = ABM(SchellingAgent, space;properties=properties, scheduler = random_activation)

    for n in 1:numagents
        agent = SchellingAgent(n, (1,1), false, n < numagents/2 ? 1 : 2)
        add_agent_single!(agent, model)
    end
    return model
end

function agent_step!(agent, model)
    agent.mood == true && return
    minhappy = model.properties[:min_to_be_happy]
    neighbor_cells = node_neighbors(agent, model)
    count_neighbors_same_group = 0
    for neighbor_cell in neighbor_cells
        node_contents = get_node_contents(neighbor_cell, model)
        length(node_contents) == 0 && continue
        agent_id = node_contents[1]
        neighbor_agent_group = model.agents[agent_id].group
        if neighbor_agent_group == agent.group
            count_neighbors_same_group += 1
        end
    end
    if count_neighbors_same_group>= minhappy
        agent.mood = true
    else
        move_agent_single!(agent, model)
    end
    return
end

model = initialize()

step!(model, agent_step!, 100)

properties =[:pos, :mood, :group]

n = 100
when = 1:n

data = step!(model, agent_step!, n, properties, when=when)
data[1:100, :]

using AgentsPlots
p = plot2D(data, :group, t=100, nodesize=10)
