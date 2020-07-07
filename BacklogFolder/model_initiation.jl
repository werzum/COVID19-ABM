function model_initiation(;beta_undet, beta_det, densitymap, infection_period = 8, reinfection_probability = 0.02,
    detection_time = 14, death_rate = 0.02, seed=0)#Is infected per city, starts with 1 infected

    Random.seed!(seed)
    properties = Dict(:beta_det=> beta_det, :beta_undet=>beta_undet,
    :infection_period=>infection_period, :reinfection_probability=>reinfection_probability,
    :detection_time=>detection_time, :death_rate=> death_rate)

    xsize = width(densitymap)
    ysize = height(densitymap)
    space = Space((xsize, ysize), moore = true)
    model = ABM(agent, space; properties=properties)

    #add individuals
    i = 1
    for x in 1:xsize, y in 1:ysize
        if densitymap[y,x] > 0
            for j in 1:densitymap[y,x]
                a = agent(i, (x,y), 0, :S)
                add_agent_pos!(a, model)
                i += 1
            end
        end
    end

    #add random infected individuals close to munich with a low percentage in  the area
    for x in 400:410, y in 100:110
        inds = get_node_contents((x,y), model)
        for n in inds
            if rand()<0.1
                agent = id2agent(n, model)
                agent.status = :I
                agent.days_infected = 1
            end
        end
    end

    return model
end

export model_initiation
