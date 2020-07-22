function agent_week!(model, social_groups, distant_groups,steps)
    agent_data = DataFrame(step=Int64[],infected=Int64[],recovered=Int64[],susceptible=Int64[],mean_behavior=Int64[],mean_fear=Int64[])
    infected_timeline = Vector{Int16}(undef,0)
    infected_timeline_growth = Vector{Int16}(undef,0)
    for step in 1:steps
        println("step $step")
        for i in 1:7
            model.days_passed+=1
            #select social&distant active groups randomly, more agents are social active on the weekend
            if i < 6
                social_active_group = rand(social_groups,Int.(round.(length(social_groups)/10)))
                distant_active_group = rand(distant_groups,Int.(round.(length(distant_groups)/10)))
            else
                social_active_group = rand(social_groups,Int.(round.(length(social_groups)/3)))
                distant_active_group = rand(distant_groups,Int.(round.(length(distant_groups)/3)))
            end
            infected_edges = Vector{Int32}(undef,0)
            #to avoid costly recomputation in behavior, we collect all agents once and then use it in behavior
            all_agents = collect(allagents(model))
            println("mean behavior is $(mean([agent.behavior for agent in all_agents]))")
            println("mean fear is $(mean([agent.fear for agent in all_agents]))")
            #get the current case growth
            if (length(infected_timeline)>1)
                today = infected_timeline[length(infected_timeline)]
                before = infected_timeline[length(infected_timeline)-1]
            else
                today = 100
                before = 100
            end
            push!(infected_timeline_growth,case_growth(today, before))
            #run the model
            day_data = agent_day!(model, social_active_group, distant_active_group,infected_edges,all_agents,infected_timeline_growth)
            #update the count of infected now and reported
            infected_count = sum([in(agent.health_status, (:E,:I,:IwS,:NQ)) for agent in  all_agents])
            push!(infected_timeline,infected_count)
            model.infected_now = infected_count
            #delay the reported infections by seven days
            length(infected_timeline)<8 ? model.infected_reported=0 : model.infected_reported = infected_timeline[length(infected_timeline)-7]
            println("infected timeline is $infected_timeline")
            println("infected_count is $infected_count and reported are $(model.infected_reported) at time $(model.days_passed)")
            #and add the data to the dataframe
            append!(agent_data,day_data)
        end
    end
    return agent_data
end

function fear_growth(case_growth,personal_cases)
    #lambda = max attainable fear factor -> 2?
    #us - unconditioned stimuli, cs - conditioned stimuli -> merge both to one stimuli, cases
    #return fear change of 1 if both rates are 1
    return Int16(round(100*1.58198*(1-ℯ^(-case_growth*personal_cases))))
end

function fear_decay(fear,time)
    #modify fear so that it decays over time
    return fear*ℯ^(-(time/200))
end

function case_growth(today,before)
    if !in(0,(today,before))
        return Int16(round(100*(today/before)))
    else
        return 100
    end
end

#TODO
#add transfer between social/distant activities and determine when to use which activity
#add vor verification streek how infection prob grows with household size

function agent_day!(model, social_active_group, distant_active_group,infected_edges,all_agents,infected_timeline_growth)

    #TODO add difference between work and social activites

    #put functions within parent scope so we can read from this scope
    function move_step!(agent, model)
        #if agent is infected, add edges on his way to the array of infected edges
        if in(agent.health_status, (:E,:I,:IwS,:NQ))
            if time_of_day == :work || time_of_day == :work_back
                append!(infected_edges, collect(dst.(agent.workplaceroute)))
                append!(infected_edges, collect(src.(agent.workplaceroute)))
            elseif time_of_day == :social || time_of_day == :social_back
                append!(infected_edges, collect(dst.(agent.socialroute)))
                append!(infected_edges, collect(src.(agent.socialroute)))
            end
        elseif agent.health_status == :S
            #if not, see if the agents route coincides with the pool and see if the agent gets infected by this.
            if time_of_day == :work || time_of_day == :back_work
                possible_edges = length(filter(x -> in(x,infected_edges),agent.workplaceroute))
            elseif time_of_day == :social || time_of_day == :back_social
                possible_edges = length(filter(x -> in(x,infected_edges),agent.socialroute))
            end
            if (possible_edges>0)
                println("found $possible_edeges possible edges")
                agent.behavior > 1 ? risk = 3.73 : risk = 15.4
                #use agent wealth as additional factor
                risk = agent.wealth/219
                risk < 0.01 ? risk = 0.01 : risk = risk
                risk*=2-agent.wealth/219
                #see if the agent gets infected. Risk is taken from Chu 2020, /100 for scale and /10 to keep confunding factors in mind.
                rand(Binomial(length(possible_edges),risk/1000)) >= 1 ? agent.health_status = :E : agent.health_status = agent.health_status
            end
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
        acquaintances_infected = length(filter(x -> in(x.health_status, (:E,:I,:IwS,:NQ)) && (x.household == agent.household || x.workplace == agent.workplace || x.socialgroup == agent.socialgroup || x.distantgroup == agent.distantgroup), all_agents))
        #add them as a modifier to the fear rate
        if acquaintances_infected == 0 || model.infected_reported == 0
            personal_rate = 1
        else
            personal_rate = 1+model.infected_reported/acquaintances_infected
        end

        #fear grows if reported cases are growing and decays otherwise
        if last(infected_timeline_growth)>=1
            #fear(global reported case growth, personal rate and time)
            infected_growth = last(infected_timeline_growth)/100
            agent.fear = fear_growth(infected_growth,personal_rate)
        else
            #find last point of growth so we can get the time the decay lasted
            time = length(infected_timeline_growth) - findlast(x -> x>1,infected_timeline_growth) + 1
            #and apply the exponential decay of it
            agent.fear = fear_decay(agent.fear, time)
        end
        #agent behavior is computed as norm + attitude + decay(threat)
        #println("agent behavior is $(agent.behavior) with attitude $attitude, social norm $mean_behavior and threat $(agent.fear)")
        agent.behavior = Int16(round(mean([mean_behavior,attitude])*(agent.fear/100)))
        #println("agent behavior is $(agent.behavior) with attitude $attitude and social norm $mean_behavior and threat $(threat_decay(mean([number_acquaintances_infected,global_threat])))")
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
        #some agents are asymptomatic(IwS), the rest first becomes NonQuarantined
        if agent.health_status == :E && agent.days_infected == model.properties[:exposed_period]
            if rand()>0.222 #streeck infection fatality asymptomatic cases
                agent.health_status = :NQ
            else
                agent.health_status = :IwS
            end
        elseif agent.health_status == :NQ && agent.days_infected == model.properties[:exposed_period]+1
            #decide if going into quarantine, influenced by behavior
            #this decision is only taken once when becoming symptomatic
            if rand()*agent.behavior/100>0.5
                agent.health_status = :Q
            end
        elseif (agent.health_status == :NQ || agent.health_status ==:Q) && agent.days_infected == model.properties[:exposed_period]+2
            #see if agent gets severe symptoms or stays only mildly infected
            #base rate is 12% in hospital, influenced by agent age, source RKI Situationsbericht 30.03
            if rand()*agent.age/50<0.12
                agent.health_status = :HS
            end
        elseif in(agent.health_status,(:HS,:IwS)) && agent.days_infected >= rand(Normal(18,4)) #after RKI Durchschn. Zeitintervall Behandlung
            if agent.health_status == :HS
            #see if agent with heavy symptoms dies or recovers. Happens after three weeks as ? specifies
            #no age here, since we already used this for severe cases. Source RKI Steckbrief
                if rand()<0.22
                    kill_agent!(agent, model)
                else
                    agent.health_status = :M
                    agent.days_infected = 0
                end
            #become immune after these 21 days if IwS
            else
                agent.health_status = :M
                agent.days_infected = 0
            end
        elseif agent.health_status == :M && agent.days_infected > rand(Normal(75,15)) #become susceptible again after two-three months (Long 2020)
            agent.health_status = :S
        end
    end

    #data collection functions
    infected(x) = count(in(i,(:E,:I,:IwS,:Q,:NQ)) for i in x)
    recovered(x) = count(in(i,(:M,:D)) for i in x)
    susceptible(x) = count(i == :S for i in x)
    mean_sentiment(x) = Int64(round(mean(x)))
    data_to_collect = [(:health_status,infected),(:health_status,recovered),(:health_status,susceptible),(:behavior,mean_sentiment),(:fear,mean_sentiment)]

    #run the model - agents go to work, collect data
    time_of_day = :work
    data1, _ = run!(model, move_step!, 1; adata = data_to_collect)
    data2, _ = run!(model, infect_step!, 1; adata = data_to_collect)
    #back home
    time_of_day = :back_work
    data3, _ = run!(model, move_step!,1; adata = data_to_collect)
    data4, _ = run!(model, infect_step!,1; adata = data_to_collect)

    #if social/distant
    time_of_day = :social
    data5, _ = run!(model, move_step!,1; adata = data_to_collect)
    data6, _ = run!(model, infect_step!,1; adata = data_to_collect)

    #and back home
    time_of_day = :back_social
    data7, _ = run!(model, move_step!,1; adata = data_to_collect)
    data8, _ = run!(model, infect_step!,1; adata = data_to_collect)

    #combine dfs,rename them appropriately and return them
    data = vcat(data1, data2, data3, data4, data5, data6, data7, data8)
    rename!(data,[:step, :infected, :recovered, :susceptible,:mean_behavior,:mean_fear])
    return data
end

export agent_step!, agent_week!



#agent_week!(model, social_groups, distant_groups,1)
#
# for i in 1:100
#     agent = random_agent(model)
#     agent.health_status = :I
# end
