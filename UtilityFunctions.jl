function add_infected(x)
    for i in 1:x
        agent = random_agent(model)
        agent.health_status = :E
    end
end

function reset_infected(model)
    all_agents = collect(allagents(model))
    for agent in all_agents
        agent.health_status = :S
        agent.fear = 0
        agent.behavior = 0
        agent.days_infected = 0
    end
    model.properties[:days_passed] = 0
end

function restart_model(agents,steps)
    reset_infected(model)
    add_infected(agents)
    create_chart(steps)
end

export add_infected,reset_infected,restart_model
