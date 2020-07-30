function draw_map(model,lat,long)
    N = Agents.nodes(model)
    ncolor = Vector(undef, length(N))
    nodesizevec = Vector(undef, length(N))
    #color and size the nodes according to the population
    #could set size to population and color to other attributes (sickness, belief,...)
    for (i, n) in enumerate(N)
        a = get_node_agents(n, model)
        #set color for empty nodes and populated nodes
        b = [agent.workplace for agent in a]
        b = mean(b)
        #ncolor[i]=cgrad(:]inferno)[mean(b)/10]
        b==0 ? ncolor[i]=RGBA(1.0, 1.0, 1.0, 0.6) : ncolor[i]=RGBA(0.0, 0.6, 0.6, 0.8)
        length(a)==0 ? nodesizevec[i] = 2 : nodesizevec[i] = 3
    end
    gplot(model.space.graph, long, lat, nodefillc=ncolor, nodesize=nodesizevec)
end

#paint the edges of edgecolor red for all edges in the route
function generate_edgecolors(route, edgecolors)
    for i in route
        start =  src(i)
        fin = dst(i)
        if has_edge(model.space.graph,start,fin) || has_edge(model.space.graph,fin,start)
            edge1 = LightGraphs.SimpleEdge(start, fin)
            edge2 = LightGraphs.SimpleEdge(fin, start)
            #check for all edges if its equal (forward and backward) to the route edge, if so set color to yellow
            for (index,value) in enumerate(edges(model.space.graph))
                if(value == edge1 || value == edge2 )
                    edgecolors[index] = colorant"red"
                    continue
                end
            end
        end
    end
    return edgecolors
end

function draw_route(model,lat,long)
    #draw random agent and get the route
    agent = random_agent(model)
    workplaceroute = agent.workplaceroute
    socialroute = agent.socialroute
    distantroute = agent.distantroute
    while(length(workplaceroute)<10)
        agent = random_agent(model)
        thisroute = agent.workplaceroute
    end
    #make array of normal edge colors
    edgecolors = [colorant"lightgray" for i in  1:ne(model.space.graph)]
    #and add all routes to edgecolors
    edgecolors = generate_edgecolors(workplaceroute, edgecolors)
    edgecolors = generate_edgecolors(socialroute, edgecolors)
    edgecolors = generate_edgecolors(distantroute, edgecolors)
    #set the home as yellow point in the map
    nodecolors = [colorant"turquoise" for i in  1:ne(model.space.graph)]
    nodecolors[agent.household] = colorant"yellow"
    gplot(model.space.graph, long, lat, edgestrokec=edgecolors, nodefillc=nodecolors)
end

function create_chart(steps)
    #one step is a week!
    b = agent_week!(model, social_groups, distant_groups,steps)
    p = plot(b.infected,label="infected")
    plot!(p,b.susceptible,label="susceptible")
    plot!(p,b.recovered,label="recovered")
    plot!(p,b.mean_fear.*100,label="fear")
    plot!(p,b.mean_behavior.*100,label="behavior")
end

function create_gif()
    properties = [:status, :pos]
    #plot the ith step of the simulation
    anim = @animate for i ∈ 1:50
        data = step!(model, agent_step!, 1, properties)
        p = plot2D(data, :status, nodesize=3)
        title!(p, "Day $(i)")
    end
    gif(anim, "Graphics\\covid_evolution.gif", fps = 3);
end

export draw_map,draw_route,create_chart, create_gif

#=savefig examples
savefig(a,"Graphics\\example_route.png")
using Compose
draw(PNG("Graphics\\example_route.png",16cm,16cm),a)
=#
