function agent_week!(model, social_groups, distant_groups,steps)
    agent_data = DataFrame(step=Int64[],infected_health_status=Int64[],recovered_health_status=Int64[],susceptible_health_status=Int64[],length_health_status=Int64[])
    infected_timeline = Vector{Int16}(undef,0)
    for step in steps
        for i in 1:5
            #select social&distant active groups randomly
            social_active_group = rand(social_groups,Int.(round.(length(social_groups)/10)))
            distant_active_group = rand(distant_groups,Int.(round.(length(distant_groups)/10)))
            infected_edges = Vector{Int32}(undef,0)
            #run the model
            all_agents = collect(allagents(model))
            day_data = agent_day!(model, social_active_group, distant_active_group,infected_edges,all_agents)
            #update the count of infected now and reported
            infected_count = sum([in(agent.health_status, (:E,:I,:IwS,:NQ)) for agent in  all_agents])
            push!(infected_timeline,infected_count)
            model.infected_now = infected_count
            #delay the reported infections by seven days
            length(infected_timeline)<7 ? access_index=1 : access_index=length(infected_timeline)-6
            #change this to infected_reported later
            model.infected_cases = infected_timeline[access_index]
            println("infected_count is $infected_count and reported are $(model.infected_cases)")
            #and add the data to the dataframe
            append!(agent_data,day_data)
        end
        #same procedure for the weekend, but bigger social active/distant groups
        for i in 1:2
            social_active_group = rand(social_groups,Int.(round.(length(social_groups)/3)))
            distant_active_group = rand(distant_groups,Int.(round.(length(distant_groups)/3)))
            infected_edges = Vector{Int32}(undef,0)
            all_agents = collect(allagents(model))
            day_data = agent_day!(model, social_active_group, distant_active_group,infected_edges,all_agents)
            infected_count = sum([in(agent.health_status, (:E,:I,:IwS,:NQ)) for agent in  all_agents])
            push!(infected_timeline,infected_count)
            model.infected_now = infected_count
            length(infected_timeline)<7  ? access_index=1 : access_index=length(infected_timeline)-6
            model.infected_cases = infected_timeline[access_index]
            println("infected_count is $infected_count and reported are $(model.infected_cases)")
            append!(agent_data,day_data)
        end
    end
    return agent_data
end

function threat_decay(x)
    #fitted to datapoints of statista "disziplin lässt nach" curve
    return 0.7960317 + 0.03615835*x - 0.00103458*x^2 + 0.000007423604*x^3
end

function global_infection_threat(x)
    #taken from covid cases and threat
    return 0.00007614213*x + 0.6517766
end

function agent_day!(model, social_active_group, distant_active_group,infected_edges,all_agents)

    #TODO add difference between work and social activites

    #put functions within parent scope so we can read from this scope
    function move_step!(agent, model)
        #if agent is infected, add edges on his way to the array of infected edges
        if (agent.health_status == :I)
            append!(infected_edges, collect(dst.(agent.workplaceroute)))
            append!(infected_edges, collect(src.(agent.workplaceroute)))
        end
        #then go to workplace, social group, or home depending on the time of day
        if time_of_day == :work && agent.workplace != 0
            move_agent!(agent,agent.workplace,model)
        elseif time_of_day == :social && in(agent.socialgroup, social_active_group)
            move_agent!(agent,agent.socialgroup,model)
        else
            move_agent!(agent,agent.household,model)
        end
    end

    function infect_step!(agent, model)
        behavior!(agent,model)
        transmit!(agent,model)
        update!(agent,model)
        #add somewhere the possibility to become infected by travelling the same edges - not exactly transmit, maybe rather update
        recover_or_die!(agent,model)
    end

    function behavior!(agent, model)
        #get behavior of others in same nodes
        node_agents = get_node_agents(agent.pos,model)
        mean_behavior = mean([agent.behavior for agent in node_agents])

        #get the agents attitude
        attitude = agent.attitude

        #get personal environment infected and compute a threat value
        #get #infected within agents environment
        number_acquaintances_infected = length(filter(x -> in(x.health_status, (:E,:I,:IwS,:NQ)) && (x.household == agent.household || x.workplace == agent.workplace || x.socialgroup == agent.socialgroup || x.distantgroup == agent.distantgroup), all_agents))
        #add these linearly*0.1 to the model
        #threat is delayed as #cases vs fear shows, fear shows variation of 20 percent
        #global_threat = global_infection_threat(model.delayed_numbers)
        #for agent in allagents(model)

        #how to implement temporal decay?
    end

    function transmit!(agent, model)
        #skip transmission for non-sick agents
        !in(agent.health_status, (:E,:I,:IwS,:NQ)) && return
        prop = model.properties

        #set the detected/undetected infection rate
        rate = if in(agent.health_status,(:E,:I,:IWS,:NQ))
                prop[:beta_det]
        else
            prop[:beta_undet]
        end

        #draw a random number of people to infect in this node
        d = Poisson(rate)
        n = rand(d) #determine number of people to infect, based on the rate
        n == 0 && return #skip if probability of infection =0
        timeout = n*2
        t = 0

        #infect the number of contacts and then return
        #get node of agent, skip if only him
        node_contents = get_node_contents(agent.pos, model)
        length(node_contents)==1 && return

        #trying to infect n others in this node, timeout if in a node without eligible neighbors
        while n > 0 && t < timeout
            target = id2agent(rand(node_contents), model)
            #TODO add the product of individual protection and and target protection - keeping it real simple for now
            if target.health_status == :S
                target.health_status = :I
                n -= 1
            end
            t +=1
        end
    end

    #increase infection time
    update!(agent, model) = in(agent.health_status, (:E,:I,:IWS,:NQ,:Q,:M)) && (agent.days_infected +=1)

    #transition agent to new state
    function recover_or_die!(agent, model)
        if agent.health_status == :E && agent.days_infected >= 3 #here should go model.properties[:exposed_period]
            #TODO now 50 50 chance, let age influence this
            if rand()>0.5
                agent.health_status = :I
            else
                agent.health_status = :IwS
            end
        elseif agent.health_status == :I && agent.days_infected >= 5
            if rand()>0.5
                agent.health_status = :NQ
            else
                agent.health_status = :Q
            end
        elseif in(agent.health_status, (:NQ,:Q)) && agent.days_infected >= 10
            if rand() <= model.properties[:death_rate]
                kill_agent!(agent, model)
            else
                agent.health_status = :M
                agent.days_infected = 0
            end
        elseif agent.health_status == :M && agent.days_infected > 30 #become susceptible again after two weeks
            agent.health_status = :S
        end
    end

    #data collection functions
    infected(x) = count(in(i,(:E,:I,:IwS,:Q,:NQ)) for i in x)
    recovered(x) = count(in(i,(:M,:D)) for i in x)
    susceptible(x) = count(i == :S for i in x)
    data_to_collect = [(:health_status,f) for f in (infected, recovered, susceptible, length)]

    #run the model - agents go to work, collect data
    time_of_day = :work
    data1, _ = run!(model, move_step!, 1; adata = data_to_collect)
    data2, _ = run!(model, infect_step!, 1; adata = data_to_collect)
    #back home
    time_of_day = :back
    data3, _ = run!(model, move_step!,1; adata = data_to_collect)
    data4, _ = run!(model, infect_step!,1; adata = data_to_collect)

    #if social/distant
    time_of_day = :social
    data5, _ = run!(model, move_step!,1; adata = data_to_collect)
    data6, _ = run!(model, infect_step!,1; adata = data_to_collect)

    #and back home
    time_of_day = :back
    data7, _ = run!(model, move_step!,1; adata = data_to_collect)
    data8, _ = run!(model, infect_step!,1; adata = data_to_collect)

    #combine dfs and return them
    data = vcat(data1, data2, data3, data4, data5, data6, data7, data8)
    return data
end

export agent_step!



agent_week!(model, social_groups, distant_groups,3)

for i in 1:100
    agent = random_agent(model)
    agent.health_status = :I
end
