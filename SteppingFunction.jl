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
                #distant = Shopping + Sport, shopping 2x/week (https://de.statista.com/statistik/daten/studie/214882/umfrage/einkaufsfrequenz-beim-lebensmitteleinkauf/)
                #sports 2,5x per week https://de.statista.com/statistik/daten/studie/177007/umfrage/tage-pro-woche-an-denen-sport-getrieben-wird/
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
            #since actual cases are about 1,8x higher than reported cases, divide this (https://www.mpg.de/14906897/0604-defo-137749-wie-viele-menschen-haben-tatsaechlich-covid-19)
            infected_count = round(sum([in(agent.health_status, (:E,:IwS,:NQ,:Q,:HS)) for agent in  all_agents])/1.8)
            push!(infected_timeline,infected_count)
            model.infected_now = infected_count
            #delay the reported infections by two days as Verzug COronadaten shows https://www.ndr.de/nachrichten/info/Coronavirus-Neue-Daten-stellen-Epidemie-Verlauf-infrage,corona2536.html
            #nowcast shows 3 days delay and 10% less infected as report delay
            length(infected_timeline)<4 ? model.infected_reported=last(infected_timeline)*0.9 : model.infected_reported = infected_timeline[length(infected_timeline)-3]
            println("infected timeline is $infected_timeline")
            println("infected growth is $infected_timeline_growth")
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

#mossong 2008, contacts by age,
function contacts_reworked(input)
    y = 11.17771 + 0.5156303*input - 0.01447889*input^2 + 0.00009245592*input^3
    return y
end

#TODO
#add vor verification streek how infection prob grows with household size
#we could add hospitals and let agents go there, maybe future work

function agent_day!(model, social_active_group, distant_active_group,infected_edges,all_agents,infected_timeline_growth)

    #put functions within parent scope so we can read from this scope
    function move_infect!(agent)
        if agent.health_status == :Q || agent.health_status == :HS
            #if agent is quarantined or has heavy symptoms
            #agent goes home and does not move
            if agent.pos != agent.household
                move_agent!(agent,agent.household,model)
                return false
            else
                return false
            end
        elseif in(agent.health_status, (:E,:IwS,:NQ))
            #if agent is infected and moves, add edges on his way to the array of infected edges
            if time_of_day == :work || time_of_day == :work_back
                append!(infected_edges, collect(dst.(agent.workplaceroute)))
                append!(infected_edges, collect(src.(agent.workplaceroute)))
            elseif time_of_day == :social || time_of_day == :social_back
                append!(infected_edges, collect(dst.(agent.socialroute)))
                append!(infected_edges, collect(src.(agent.socialroute)))
            end
            return true
        elseif agent.health_status == :S
            #if not, see if the agents route coincides with the pool and see if the agent gets infected by this.
            if time_of_day == :work || time_of_day == :back_work
                possible_edges = length(filter(x -> in(x,infected_edges),merge(collect(dst.(agent.workplaceroute)),collect(src.(agent.workplaceroute)))))
            elseif time_of_day == :social || time_of_day == :back_social
                possible_edges = length(filter(x -> in(x,infected_edges),merge(collect(dst.(agent.socialroute)),collect(src.(agent.socialroute)))))
            end
            #if our route coincides with the daily route of others
            if (possible_edges>0)
                agent.behavior > 1 ? risk = 3.73 : risk = 15.4
                #use agent wealth as additional factor
                wealth_modificator = agent.wealth/219
                wealth_modificator < 0.01 && (wealth_modificator = 0.01)
                wealth_modificator > 1.9 && (wealth_modificator = 1.9)
                #risk increases when agent
                risk=risk*(2-wealth_modificator)
                #see if the agent gets infected. Risk is taken from Chu 2020, /100 for scale and *0.03 for mossong travel rate of 3 perc of contacts
                rand(Binomial(possible_edges,(risk/100)*0.003)) >= 1 ? agent.health_status = :E : agent.health_status = agent.health_status
            end
            return true
        end
    end
    function move_step!(agent, model)
        #check which time of day it is, then calculate move infection if not in quarantine, and finally move the agent
        if time_of_day == :work && agent.workplace != 0
            #on the weekends, only ~20% go to work https://www.destatis.de/DE/Themen/Arbeit/Arbeitsmarkt/Qualitaet-Arbeit/Dimension-3/wochenendarbeitl.html
            if length(social_active_group)==Int(round(length(social_groups)/3))
                if rand() < 0.0276
                    move = move_infect!(agent)
                    move == true && move_agent!(agent,agent.workplace,model)
                end
            else
                move = move_infect!(agent)
                move == true && move_agent!(agent,agent.workplace,model)
            end
        elseif time_of_day == :social && in(agent.socialgroup, social_active_group)
            move = move_infect!(agent)
            move == true && move_agent!(agent,agent.socialgroup,model)
        elseif time_of_day == :social && in(agent.distantgroup, distant_active_group)
            move = move_infect!(agent)
            move == true && move_agent!(agent,agent.socialgroup,model)
        else
            #move back home
            move = move_infect!(agent)
            move == true && move_agent!(agent,agent.household,model)
        end
    end

    function infect_step!(agent, model)
        behavior!(agent,model)
        transmit!(agent,model)
        update!(agent,model)
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
        acquaintances_infected = length(filter(x -> in(x.health_status, (:NQ,:Q,:HS)) && (x.household == agent.household || x.workplace == agent.workplace || x.socialgroup == agent.socialgroup || x.distantgroup == agent.distantgroup),all_agents))

        if acquaintances_infected == 0 || model.infected_reported == 0
            acquaintances_infected = 1
        end
        #add them as a modifier to the fear rate
        if agent.acquaintances_growth != 0
            #get the growth rate of infected
            growth = acquaintances_infected/agent.acquaintances_growth
            agent.acquaintances_growth = acquaintances_infected
        else
            growth = 1
        end

        #fear grows if reported cases are growing, decay kicks in when cases shrink for 3 consecutive days
        #if length(timeline_growth >3 && last 3 entries decays) || model.properties.decay == true
        infected_growth = last(infected_timeline_growth)/100
        agent.fear = fear_growth(infected_growth,growth)
        time = length(infected_timeline_growth)# - findlast(x -> x>1,infected_timeline_growth) + 1
        #and apply the exponential decay to it
        agent.fear = Int16(round(fear_decay(agent.fear, time)))
        #from now on, the decay function governs the behavior
        #model.properties[:fear_decay] = true

        #TODO or kicks decay in after a fixed delay we have when dealing with fear (how long for same stimulus? whats the time needed?)

        # if (length(infected_timeline_growth)>3 && ((infected_timeline_growth[length(infected_timeline_growth)-2:length(infected_timeline_growth)].< 1)) == trues(3)) || model.properties[:fear_decay]
        #     println("reached decay")
        #     #find last point of growth so we can get the time the decay lasted
        #     time = length(infected_timeline_growth) - findlast(x -> x>1,infected_timeline_growth) + 1
        #     #and apply the exponential decay to it
        #     agent.fear = fear_decay(agent.fear, time)
        #     #from now on, the decay function governs the behavior
        #     model.properties[:fear_decay] = true
        # else
        #     #fear(global reported case growth, personal rate and time)
        #     infected_growth = last(infected_timeline_growth)/100
        #     agent.fear = fear_growth(infected_growth,personal_rate)
        # end
        #agent behavior is computed as norm + attitude + decay(threat)
        #println("agent behavior is $(agent.behavior) with attitude $attitude, social norm $mean_behavior and threat $(agent.fear)")
        agent.behavior = Int16(round(mean([mean_behavior,attitude])*(agent.fear/100)))
        if(agent.id == 10)
            println("the fear is $(agent.fear), the time is $time, with $acquaintances_infected and a growth of $growth")
            println("agent behavior is $(agent.behavior) with attitude $attitude and social norm $mean_behavior")
        end
    end

    function transmit!(agent, model)
        #skip transmission for non-sick agents
        !in(agent.health_status, (:E,:IwS,:NQ,:Q,:HS)) && return
        #also skip if exposed, but not yet infectious. RKI Steckbrief says 2 days before onset of symptoms
        agent.health_status == :E && agent.days_infected < model.properties[:exposed_period]-2 && return
        #and 5 days after onset of symptoms
        agent.days_infected > model.properties[:exposed_period] + 5 && return
        prop = model.properties

        #mean rate Chu 2020 f
        rate = if agent.behavior >=1
            0.0366
        else
            0.095
        end
        #rate of secondary infections in household very high, Wei Li 2020, but at least contained to household
        if agent.health_status == :Q
            rate = 0.163
        end

        #infect the number of contacts and then return
        #get node of agent, skip if only him
        node_contents = get_node_contents(agent.pos, model)
        length(node_contents)==1 && return
        #
        contacts = contacts_reworked(Int32(agent.age))

        #if agent is older than 80, function gets negative. Fix this and also giving agents a contact ceiling of 30, set it to mean #contacts if outside bounds
        if 0 <= contacts < 30
            contacts = 14
        end

        #reduce it to the proporties of contact as mossong 2008.  Joined school and work, home and is about 35(work)+23(back)+16(social)+23(back) = 90 perc
        if time_of_day == :work
            contacts*=0.35
        elseif  time_of_day == :social
            contacts*=0.16
        else
            contacts*=0.26
        end
        contacts = round(contacts)
        #check if age_contacts bigger than available agents, set it then to the #available agents
        if contacts > length(node_contents) - 1
            contacts = length(node_contents) - 1
        end

        contacts < 0 && return
        #draw from bernoulli distribution with infection rate and average number of contacts according to age.
        infect_people = countmap(rand(Bernoulli(rate),Int32(round(contacts))))[1]
        #check if there are no people to infect
        infect_people  == 0 && return
        #if we have drawn more people than available, set infect_people to all other agents
        length(node_contents) < infect_people && (infect_people = length(node_contents)-1)
        #println("attempt to infect $infect_people people out of $contacts contacts in a $(length(node_contents)) long node with age $(agent.age)")
        timeout = infect_people*2
        t = 0

        #trying to infect n others in this node, timeout if in a node without eligible neighbors
        while infect_people > 0 && t < timeout
            target = model[rand(node_contents)]
            #TODO add the product of individual protection and and target protection - keeping it real simple for now
            if target.health_status == :S
                target.health_status = :E
                infect_people -= 1
            end
            t +=1
        end
    end

    #increase infection time
    update!(agent, model) = in(agent.health_status, (:E,:IWS,:NQ,:Q,:M)) && (agent.days_infected +=1)

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
        elseif (agent.health_status == :NQ || agent.health_status ==:Q) && agent.days_infected > round(rand(Normal(model.properties[:exposed_period]+4,2)))
            #see if agent gets severe symptoms or stays only mildly infected, happens ~4 days after symptoms show up
            #base rate is 12% in hospital, influenced by agent age, source RKI Situationsbericht 30.03
            if rand()*agent.age/50<0.12
                agent.health_status = :HS
            end
        elseif (agent.health_status == :NQ || agent.health_status ==:IwS) && agent.days_infected > round(rand(Normal(14,3))) #RKI Krankheitsverlauf zwei Wochen
            #become immune again after being NQ,Q without heavy symptoms
            agent.health_status == :M
        elseif in(agent.health_status,(:HS,:Q)) && agent.days_infected >= 9+round(rand(Normal(10,4))) #after RKI Durchschn. Zeitintervall Behandlung, Median 10 Tage nach Hospitalisierung
            if agent.health_status == :HS
            #see if agent with heavy symptoms dies or recovers. Happens after three weeks as ? specifies
            #no age here, since we already used this for severe cases. Source RKI Steckbrief
                if rand()<0.22
                    kill_agent!(agent, model)
                else
                    agent.health_status = :M
                    agent.days_infected = 0
                end
            #become immune after these 19 days if only Q
            else
                agent.health_status = :M
                agent.days_infected = 0
            end
        elseif agent.health_status == :M && agent.days_infected > round(rand(Normal(75,15))) #become susceptible again after two-three months (Long 2020)
            agent.health_status = :S
        end
    end

    #data collection functions
    infected(x) = count(in(i,(:E,:IwS,:Q,:NQ,:HS)) for i in x)
    recovered(x) = count(in(i,(:M,:D)) for i in x)
    susceptible(x) = count(i == :S for i in x)
    mean_sentiment(x) = Int64(round(mean(x)))
    data_to_collect = [(:health_status,infected),(:health_status,recovered),(:health_status,susceptible),(:behavior,mean_sentiment),(:fear,mean_sentiment)]

    #preallocate some arrays
    aquaintances_vector = Vector{Int64}(undef, length(all_agents))
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
