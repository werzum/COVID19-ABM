
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

    rawdata1 = CSV.read("SourceData\\census_updated.csv")
    rawdata = CSV.read("SourceData\\zensus3.csv")

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
end

    return rawdata

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
    return densitymap
end

export getDensityData, generateDensity
