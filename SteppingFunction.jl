function agent_week!(model, social_groups, distant_groups)
    for i in 1:5
        social_active_group = rand(social_groups,Int.(round.(length(social_groups)/10)))
        distant_active_group = rand(distant_groups,Int.(round.(length(distant_groups)/10)))
        agent_day(model, day, social_active_group,distant_active_group)
    end
    for i in 1:2
        social_active_group = rand(social_groups,Int.(round.(length(social_groups)/3)))
        distant_active_group = rand(distant_groups,Int.(round.(length(distant_groups)/3)))
        step!(model, agent_step!)
    end
end

function agent_day!(model,day)
    #to work
    step!(model, agent_step!)
    #back home
    step!(model, agent_step!)
    #if social/distant
    step!(model, agent_step!)
    #and back home
    step!(model, agent_step!)
end

function agent_step!(agent, model)
    move!(agent, model)
    transmit!(agent,model)
    update!(agent,model)
    recover_or_die!(agent,model)
end

function move!(agent, model)
    if agent.workplace != 0
        move_agent!(agent,agent.workplace,model)

    #if he wants to move
    if rand()<0.005
        #get random coordinates
        dims = model.space.dimensions
        randx = rand(1:1:dims[1])
        randy = rand(1:1:dims[2])
        while length(get_node_contents((randx,randy), model))==0
            randx = rand(1:1:dims[1])
            randy = rand(1:1:dims[2])
        end
        #and move the agent to a none-empty place
        if length(get_node_contents((randx,randy), model))>1
            move_agent!(agent,(randx,randy), model)
        end
    end
end

function transmit!(agent, model)
    #cant transmit if healthy/recovered
    agent.status == :S && return
    agent.status == :R && return
    prop = model.properties

    #set the detected/undetected infection rate, also check if he doesnt show symptoms
    rate = if agent.days_infected >= prop[:detection_time] && rand()<=0.8
            prop[:beta_det]
    else
        prop[:beta_undet]
    end

    d = Poisson(rate)
    n = rand(d) #determine number of people to infect, based on the rate
    n == 0 && return #skip if probability of infection =0
    timeout = n*2
    t = 0
    #infect the number of contacts and then return
    #node_contents = get_node_contents(agent, model)
    neighbors = node_neighbors(agent, model)

    #trying to infect n others from random neighbor node, timeout if in a node without
    while n > 0 && t < timeout
        node = rand(neighbors)
        contents = get_node_contents(node, model)
        if length(contents)>1
            infected = id2agent(rand(contents), model)
            if infected.status == :S || (infected.status == :R && rand() <= prop[:reinfection_probability])
                infected.status = :I
                n -= 1
            end
        end
        t +=1
    end
end

update!(agent, model) = agent.status == :I && (agent.days_infected +=1)

function recover_or_die!(agent, model)
    if agent.days_infected >= model.properties[:infection_period]
        if rand() <= model.properties[:death_rate]
            kill_agent!(agent, model)
        else
            agent.status = :R
            agent.days_infected = 0
        end
    end
end

export agent_step!
