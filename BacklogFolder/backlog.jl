#code to generate the household size distriution
pop = vcat(rand([1, 1], 17333, 1),rand([2,2], 13983, 1),rand([3, 3], 4923, 1),rand([4, 4], 3748, 1),rand([5, 5], 1390, 1))
pop = pop[1:end,1]
household = fit(Categorical,pop)
#code for workplacesize
amount_sizes = [452,1299,799,667,595,270,200]
sum_sizes = sum(amount_sizes)
size_probabilities = amount_sizes./sum_sizes
#redid this so we have continuous numbers and not that Categorical stuff
#create a range
range = vcat(rand(1:7,452),rand(8:17,1299),rand(18:33,799),rand(34:67,667),rand(68:167,595),rand(168:333,270),rand(334:667,200))
wealthrange = vcat(rand(1:7,452),rand(8:17,1299),rand(18:33,799),rand(34:67,667),rand(68:167,595),rand(168:333,270),rand(334:667,200))
testrange = hcat(range,wealthrange)
testdist = fit(Poisson, range)
plot(testdist)

#Rayleigh seems to work best, using this for now
workplacesize_distribution = fit(Rayleigh,range)
plot(workplacesize_distribution)
#old Categorical workplacesize
size_classes = [1:7, 8:17, 18:33, 34:67, 68:167, 168:333, 334:667]
size_probabilities = [0.10555815039701075, 0.30336291452592246, 0.1865950490425035, 0.1557683325548809, 0.13895375992526857, 0.06305464736104624, 0.046707146193367584]
workplacesize_distribution = DiscreteNonParametric(size_classes,size_probabilities)
#finally, generating the worksize distribution via a function+random

wealth_distribution = BetaPrime(2.29201,108.029)
wealth_data = rand(wealth_distribution,1000)
workplace_arr = exp_workplace.(wealth_data)
plot(workplace_arr)
using CurveFit
ExpFit([10.0,100.0,200.0,300.0,500.0],[500.0,100.0,50.0,20.0,10.0])
function exp_workplace(x)
    return (2990.168x^-0.7758731)-x/10+rand(0:(2*x/10))
end

#trust in health system distrivution
strenght_trust=[20,40,3,4]
probability = [0.17,0.46,0.24,0.07]
range = vcat([80 for i in 1:17],[60 for i in 1:46],[40 for i in 1:24],[20 for i in 1:7])
trust_distribution = fit(Normal,range)#
plot(trust_distribution)
mean(trust_distribution)
a = histogram(workplace_arr)
savefig(a,"Graphics\\histogram_workplace_distribution.png")
#saving a fig
a = plot(workplacesize_distribution)
savefig(a,"Graphics\\workplace_size_rayleigh.png")

#message attitude function
#read the csv and extract the values
@time rawdata_attitude = CSV.read("SourceData\\attitude.csv")
attitude = rawdata_attitude.Value
rawdata_norms = CSV.read("SourceData\\norms.csv")
norms = rawdata_norms.Value
plot(attitude)
println(attitude)
for f in 1:length(attitude)
    if f % 8 == 0
        println(f,"  ",attitude[f])
    end
end
#leftovers from csv manipulation that are now merged into rawdata.csv

#wrote changes to csv so we dont have to do basic cleaning again and again
#read the data
#rawdata = CSV.read("SourceData\\zensus3.csv")
#drop irrelevant columns and redundant rows
#select!(rawdata,Not(16))
#rawdata = rawdata[rawdata.Einwohner.!=-1,:]
#CSV.write("SourceData\\zensus.csv",rawdata)

#add povertydata to rawdata
rawdata.kaufkraft = zeros(Int64)
subX = rawdata.X
subY = rawdata.Y
pointarray = Vector(undef,length(subY))
for i in 1:length(subY)
    pointarray[i] = Luxor.Point(subX[i], subY[i])
end
rawdata.Point= pointarray
pointarr = rawdata.Point

povertydata = CSV.read("SourceData\\Income_Regions.csv")
povertydata = select!(povertydata,:relative_kaufkraftarmut,:MultiPolygon)
#replace.(povertydata.:MultiPolygon, r"[\\]" => "")
iterator = eachrow(povertydata)
inside = Array
for row in iterator
    array = split(row.:MultiPolygon,",")
    longs = array[1:2:end]
    lats = array[2:2:end]
    deleteat!(longs, (length(longs)-5):length(longs))
    deleteat!(lats, (length(lats)-5):length(lats))
    pointarray = Vector(undef,length(lats))
    arraysize = 0
    length(longs)<=length(lats) ? arraysize = length(longs) : arraysize = length(lats)
    for i in 1:arraysize
        point = Luxor.Point(parse(Float64,longs[i]),parse(Float64,lats[i]))
        pointarray[i] = point
    end
    deleteat!(pointarray, (length(pointarray)-1):length(pointarray))
    #print(pointarray)
    #deleteat!(pointarray, findall(x->!isa(x,Point2D), pointarray))
    pointarray = convert(Array{Luxor.Point,1},pointarray)
    #polygon = Luxor.Point(parse(Float64(lats)),parse(Float64(longs)))#Luxor.poly(pointarray;close=true)
    inside = [isinside(p,pointarray;allowonedge=true) for p in pointarr]
    rawdata[inside,:kaufkraft] = row.:relative_kaufkraftarmut
end

#Code for weighted map route calculation
heuristic(u,v) = OpenStreetMapX.get_distance(u, v, m.nodes, m.n)
a_star_algorithm(model.space.graph,  # the g
                          1,           # the start vertex
                          10,           # the end vertex
                          LightGraphs.weights(model.space.graph),
                          heuristic)

point_to_nodes((50.761,6.11),aachen_map)

OpenStreetMapX.find_route()
OpenStreetMapX.shortest_route(aachen_map,20,100)

@time a = a_star(model.space.graph,1,100)
a[2]
a_star(model.space.graph,1,100,aachen_map.w)
a = LLA(50.76121,6.111)
OpenStreetMapX.add_new_node!(aachen_map.nodes,ENU(a,LLA_ref))
OpenStreetMapX.add_new_node!()
c,d = OpenStreetMapX.get_edges(aachen_map.nodes,aachen_map.roadways)
weights = OpenStreetMapX.distance(aachen_map.nodes,c)

boundary_point()
