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

function draw_route(model,lat,long)
    #draw random agent and get the route
    agent = random_agent(model)
    thisroute = agent.workplaceroute
    while(length(thisroute)<10)
        agent = random_agent(model)
        thisroute = agent.workplaceroute
    end
    #make array of normal edge colors
    edgecolors = [colorant"lightgray" for i in  1:ne(model.space.graph)]
    for i in thisroute
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
    gplot(model.space.graph, long, lat, edgestrokec=edgecolors)
end

#=savefig examples
savefig(a,"Graphics\\example_route.png")
using Compose
draw(PNG("Graphics\\example_route.png",16cm,16cm),a)
=#

export draw_map,draw_route
