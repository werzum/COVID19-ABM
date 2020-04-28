using Agents, Random, DataFrames, LightGraphs
using Distributions: Poisson, DiscreteNonParametric
using CSV

mutable struct agent <: AbstractAgent
    id::Int
    pos::Int
    days_infected::Int
    status::Symbol #1: S, 2: I, 3:R
end

function translateDensity(x::Int, seed = 0)
    Random.seed!(seed)
    if x == 1
           return(rand(1:250))
       elseif x == 2
           return(rand(250:500))
       elseif x == 3
           return(rand(500:2000))
       elseif x == 4
           return(rand(2000:4000))
       elseif x == 5
           return(rand(5000:8000))
       elseif x == 6
           return(rand(8000:8100))
    end
    return 0
end


function getDensityData()

    rawdata = CSV.read("census.csv")
    #names(rawdata)

    rawdata.x = (rawdata.x_mp_1km .- 500) ./ 1000
    rawdata.y = (rawdata.y_mp_1km .- 500) ./ 1000

    xmin = minimum(rawdata.x)
    xmax = maximum(rawdata.x)
    xsize = Int(xmax - xmin) + 1

    ymin = minimum(rawdata.y)
    ymax = maximum(rawdata.y)
    ysize = Int(ymax - ymin) + 1

    rawdata.x = rawdata.x .- xmin .+1
    rawdata.y = rawdata.y .- ymin .+1

    rawdata
end


function generateDensity(rawdata, target = 80000000, seed = 0)
    Random.seed!(seed)
    xmin = minimum(rawdata.x)
    xmax = maximum(rawdata.x)
    xsize = Int(xmax - xmin) + 1

    ymin = minimum(rawdata.y)
    ymax = maximum(rawdata.y)
    ysize = Int(ymax - ymin) + 1
    # empty map
    densitymap = zeros(Int64, xsize, ysize)
    println("$(nrow(rawdata)) sets of data.")
    for i in 1:nrow(rawdata)
        value = rawdata[i,:Einwohner]
        x = Int(rawdata.x[i])
        y = Int(rawdata.y[i])
        densitymap[x, y] = translateDensity(value)
    end

    correctionfactor = target / sum(densitymap)
    densitymap = (x->Int.(round(x))).(densitymap' .* correctionfactor)

end

rawdata = getDensityData()
fullmap = generateDensity(rawdata, 80000, 123123123)
sum(fullmap)

gr()
heatmap(fullmap)

function model_initiation(;Ns, C, migration_rates, beta_undet, beta_det, infection_period = 8, reinfection_probability = 0.02,
    detection_time = 14, death_rate = 0.02, Is=[zeros(Int, length(Ns)-1)...,1], seed=0)#Is infected per city, starts with 1 infected

    Random.seed!(seed)
    @assert length(Ns)==length(Is)==length(beta_undet)==length(beta_det)==size(migration_rates,1) #lenght of all vectors is equal
    @assert size(migration_rates,1) == size(migration_rates,2) #should be a square matrix

    C = length(Ns) #number of cities
    #normalize migration rates
    migration_rates_sum = sum(migration_rates, dims=2) #sum of probability of migration to each city by summing up all individuals
    for c in 1:C
        migration_rates[c,:] ./= migration_rates_sum[c] #for each city, migration rate for all
        #individuals is normalized by dividing through the sum of migration rates to the city
    end

    properties = Dict(:Ns=>Ns, :beta_det=> beta_det, :beta_undet=>beta_undet, :migration_rates=>migration_rates,
    :infection_period=>infection_period, :reinfection_probability=>reinfection_probability,
    :detection_time=>detection_time, :C=> C, :death_rate=> death_rate)

    space = Space(complete_digraph(C))
    model = ABM(agent, space; properties=properties)

    #add individuals
    for city in 1:C, n in 1:Ns[city]
        ind = add_agent!(city, model, 0, :S) #properties 0, :S are transferred to constructor
        #resulting in days_infected_0, status:S
    end

    #add infected individuals
    for city in 1:C
        inds = get_node_contents(city, model)
        for n in 1:Is[city]
            agent = id2agent(inds[n], model)
            agent.status = :I
            agent.days_infected = 1
        end
    end

    return model
end

using LinearAlgebra:diagind

function create_params(;C, max_travel_rate, infection_period = 10, reinfection_probability = 0.02,
    detection_time = 6, death_rate = 0.02, Is=[zeros(Int, C-1)..., 1], seed = 19)

    Random.seed!(seed)
    Ns = rand(50:10000, C) #create C cities with populations between 50 and 5000
    beta_undet = rand(0.3:0.02:0.6, C) #random prob for infection from undetected
    beta_det = beta_undet ./ 10 #"." performs operation element-by-element on array

    Random.seed!(seed)
    #setting up the array of migration rates
    migration_rates = zeros(C, C)
    for c in 1:C
        for c2 in 1:C
            migration_rates[c,c2] = (Ns[c]+Ns[c2])/Ns[c]
        end
    end
    maxM = maximum(migration_rates)
    migration_rates = (migration_rates .* max_travel_rate)./maxM
    migration_rates[diagind(migration_rates)] .= 1.0

    params = Dict(:Ns=>Ns, :beta_det=> beta_det, :beta_undet=>beta_undet, :migration_rates=>migration_rates,
    :infection_period=>infection_period, :reinfection_probability=>reinfection_probability,
    :detection_time=>detection_time, :C=> C, :death_rate=> death_rate, :Is => Is)

    return params
end

params = create_params(C=8, max_travel_rate=0.01)
model = model_initiation(;params...)#... is "splat" operator, passing all contents as argmuents

using AgentsPlots
using Plots

plotargs = (node_size	= 0.2, method = :circular, linealpha = 0.4)

plotabm(model; plotargs...)

#modify edges so that the reflect migration rate
g = model.space.graph
edgewidthsdict = Dict()
for node in 1:nv(g)
    nbs = neighbors(g, node)
    for nb in nbs
        edgewidthsdict[(node, nb)] = params[:migration_rates][node,nb]
    end
end

#and show it
edgewidthsf(s,d,w) = edgewidthsdict[(s,d)]*250
plotargs = merge(plotargs, (edgewidth = edgewidthsf,))
plotabm(model; plotargs...)

#color node with ratio of infected
infected_fraction(x) = cgrad(:inferno)[count(a.status == :I for a in x)/length(x)]
plotabm(model, infected_fraction; plotargs...)

function agent_step!(agent, model)
    migrate!(agent, model)
    transmit!(agent,model)
    update!(agent,model)
    recover_or_die!(agent,model)
end

function migrate!(agent, model)
    nodeid = agent.pos
    d = DiscreteNonParametric(1:model.properties[:C], model.properties[:migration_rates][nodeid, :])
    m = rand(d)
    if m != nodeid
        move_agent!(agent, m, model)
    end
end

function transmit!(agent, model)
    agent.status == :S && return
    agent.status == :R && return
    prop = model.properties

    #set the detected/undetected infection rate, also check if he doesnt show symptoms
    rate = if agent.days_infected >= prop[:detection_time] && rand()<=0.8
            prop[:beta_det][agent.pos]
    else
        prop[:beta_undet][agent.pos]
    end

    d = Poisson(rate)
    n = rand(d) #determine number of people to infect, based on the rate?
    n == 0 && return #skip if probability of infection =0

    #infect the number of contacts and then return
    for contactID in get_node_contents(agent, model)
        contact = id2agent(contactID, model)
        if contact.status == :S || (contact.status == :R && rand() <= prop[:reinfection_probability])
            contact.status = :I
            n -= 1
            n == 0 && return
        end
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

model = model_initiation(;params...)

#generate a gif for the model steps
anim = @animate for i = 1:30
    step!(model, agent_step!, 1)
    pl = plotabm(model, infected_fraction; plotargs...)
    title!(pl, "Day $(i)")
end

gif(anim, "covid_evo.gif", fps = 3);

model

#make chart and show data
infected(x) = count(i == :I for i in x)
recovered(x) = count(i == :R for i in x)
susceptible(x) = count(i == :S for i in x)

model = model_initiation(;params...)
data_to_collect = Dict(:status => [infected, recovered, susceptible, length])
data = step!(model, agent_step!, 100, data_to_collect)

N = sum(model.properties[:Ns]) # Total initial population
x = data.step
p = Plots.plot(x, log10.(data[:, Symbol("infected(status)")]), label = "infected")
plot!(p, x, log10.(data[:, Symbol("recovered(status)")]), label = "recovered")
plot!(p, x, log10.(data[:, Symbol("susceptible(status)")]), label = "susceptible")
dead = log10.(N .- data[:, Symbol("length(status)")])
plot!(p, x, dead, label = "dead")
xlabel!(p, "steps")
ylabel!(p, "log( count )")
p
