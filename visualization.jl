function create_graph()
    infected(x) = count(i == :I for i in x)
    recovered(x) = count(i == :R for i in x)
    susceptible(x) = count(i == :S for i in x)
    data_to_collect = Dict(:status => [infected, recovered, susceptible, length])
    data = step!(model, agent_step!, 100, data_to_collect)
    N = sum(fullmap) # Total initial population
    x = data.step
    p = Plots.plot(x, log10.(data[:, Symbol("infected(status)")]), label = "infected")
    plot!(p, x, log10.(data[:, Symbol("recovered(status)")]), label = "recovered")
    plot!(p, x, log10.(data[:, Symbol("susceptible(status)")]), label = "susceptible")
    dead = log10.(N .- data[:, Symbol("length(status)")])
    plot!(p, x, dead, label = "dead")
    xlabel!(p, "steps")
    ylabel!(p, "log( count )")
    p
end

function create_gif()
    properties = [:status, :pos]
    #plot the ith step of the simulation
    anim = @animate for i ∈ 1:50
        data = step!(model, agent_step!, 1, properties)
        p = plot2D(data, :status, nodesize=3)
        title!(p, "Day $(i)")
    end
    gif(anim, "covid_evolution.gif", fps = 3);
end

export create_graph, create_gif
