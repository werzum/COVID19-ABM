function add_infected(x)
    for i in 1:x
        agent = random_agent(model)
        agent.health_status = :I
    end
end

function reset_infected(model)
    all_agents = collect(allagents(model))
    for agent in all_agents
        agent.health_status = :S
    end
end

export add_infected,reset_infected
