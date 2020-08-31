@everywhere function validate_infected(steps)
    reset_infected(model)
    add_infected(1)
    b = agent_week!(model, social_groups, distant_groups,steps,false)
    csv_raw = CSV.read("SourceData\\covid19_ECDC.csv")
    csv_germany = filter(x -> x[Symbol("Country/Region")] == "Germany",csv_raw)
    #get cases from the 14.02., the start date of the model and five more months
    cases_germany = csv_germany.infections[46:200]
    cases_germany = cases_germany ./ 20
    cases_model = b.infected_adjusted
    Plots.plot!(b.infected_adjusted,label="infected")
    result = rmse(cases_germany,cases_model)
end

function validate_fear(steps)
    reset_infected(model)
    add_infected(1)
    b = agent_week!(model, social_groups, distant_groups,steps,false)
    csv_raw = CSV.read("SourceData\\fear_yougov.csv";delim=";")
    DataFrames.rename!(csv_raw,[:x,:y])
    csv_raw.x = [round(parse(Float16,replace(x,","=>"."))) for x in csv_raw.x]
    csv_raw.y = [round(parse(Float16,replace(x,","=>"."))) for x in csv_raw.y]
    sort(csv_raw,:x)
    #prepend some data as guess for the trend
    fear_yougov_prepend = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,2,3,6,9,14,18,21,25,28,31]
    #try to delete row 3, doesnt work so far.
    csv_raw = csv_raw[setdiff(1:end, 3), :]
    #parse the strings to Float16s
    #starting at the 16.03.
    #adding the missing month, since the graph only starts from the 16.03. and not as the model the 14.02.
    fear_yougov = vcat(fear_yougov_prepend,csv_raw.y)
    fear_yougov = fear_yougov.*2
    #using normal fear since fear over 100 isnt consistent at all
    fear_model = b.mean_fear
    #println("rmse is $(rmse(fear_yougov[1:steps*7],fear_model[1:steps*7]))")
    Plots.plot(fear_yougov,label="fear_yougov")
    plot!(fear_model,label="fear_model")
end

function mape(series1, series2)
    errors = [abs((series1[i]-series2[i])/series1[i])*100 for i in 1:length(series2)]
    #replace NaNs,Infs for division by zero
    replace!(x -> (isnan(x) || isinf(x)) ? 0 : x,errors)
    m = (1/length(series2))*sum(errors)
end

function run_multiple(model,social_groups,distant_groups,steps,replicates)
    #reset the model for all workers and add 1 infected to it
    reset_model_parallel(1)
    #collect all data in one dataframe
    all_data = pmap(j -> agent_week!(deepcopy(model),social_groups,distant_groups,steps,false), 1:replicates)

    #get the data and average it
    infected = Array{Int32}(undef,steps*7)
    for elm in all_data
        infected = hcat(infected,elm.infected_adjusted)
    end

    infected = infected[:,setdiff(1:end,1)]
    infected = mean(infected,dims=2)

    #get the case data from germany
    csv_raw = CSV.read("SourceData\\covid19_ECDC.csv")
    csv_germany = filter(x -> x[Symbol("Country/Region")] == "Germany",csv_raw)
    #get cases from the 14.02., the start date of the model and five more months
    cases_germany = csv_germany.infections[46:200]
    cases_germany = cases_germany ./ 20

    #plot all results so we have an idea
    Plots.plot(infected,label="infected_model")
    display(plot!(cases_germany,label="infected_real"))

    println("infected are $infected")
    print("real infected are $(cases_germany[1:length(infected)])")

    error = mape(cases_germany,infected)
    return error
end

function yougov_fit(x)
    return 31.11647 + 2.410283*x - 0.09911214*x^2 + 0.001044297*x^3
end

function run_multiple_fear(model,social_groups,distant_groups,steps,replicates)
    #reset the model for all workers and add 1 infected to it
    reset_model_parallel(1)
    #collect all data in one dataframe
    all_data = pmap(j -> agent_week!(deepcopy(model),social_groups,distant_groups,steps,false), 1:replicates)

    #get the data and average it
    infected = Array{Int32}(undef,steps*7)
    for elm in all_data
        infected = hcat(infected,elm.mean_fear)
    end

    infected = infected[:,setdiff(1:end,1)]
    print(infected)
    infected = mean(infected,dims=2)

    #get the case data from germany
    csv_raw = CSV.read("SourceData\\fear_yougov.csv";delim=";")
    DataFrames.rename!(csv_raw,[:x,:y])
    csv_raw.x = [round(parse(Float16,replace(x,","=>"."))) for x in csv_raw.x]
    csv_raw.y = [round(parse(Float16,replace(x,","=>"."))) for x in csv_raw.y]
    sort(csv_raw,:x)
    #prepend some data as guess for the trend

    fear_yougov_prepend = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,2,3,6,9,14,18,21,25,28,31]
    #try to delete row 3, doesnt work so far.
    csv_raw = csv_raw[setdiff(1:end, 3), :]
    #parse the strings to Float16s
    #starting at the 16.03.
    #adding the missing month, since the graph only starts from the 16.03. and not as the model the 14.02.
    fear_yougov = vcat(fear_yougov_prepend,csv_raw.y)
    #scale it to 100
    fear_yougov = fear_yougov.*2

    #plot all results so we have an idea
    Plots.plot(fear_yougov,label="fear_real")
    display(plot!(infected,label="fear_model"))
    # display(plot!(attitude.*10000,label="attitude"))
    # display(plot!(norms.*10,label="norms"))

    println("fear model are $infected")

    error = mape(fear_yougov,infected)
    println("error is $error")
    return error
end


function run_multiple_behavior(model,social_groups,distant_groups,steps,replicates)
    reset_model_parallel(1)
    all_data = pmap(j -> agent_week!(deepcopy(model),social_groups,distant_groups,steps,false), 1:replicates)
    infected = Array{Int32}(undef,steps*7)
    for elm in all_data
        infected = hcat(infected,elm.mean_behavior)
    end

    infected = infected[:,setdiff(1:end,1)]
    infected = mean(infected,dims=2)
    println(infected)
    csv_raw = CSV.read("SourceData\\Mobility_Data.csv")
    Plots.plot(csv_raw.Value,label="behavior_real")
    display(plot!(infected,label="behavior_model"))

    error = mape(csv_raw.Value,infected)
    println("error is $error")
    return error
end

function run_multiple_both(model,social_groups,distant_groups,steps,replicates)
    reset_model_parallel(1)
    all_data = pmap(j -> agent_week!(deepcopy(model),social_groups,distant_groups,steps,false), 1:replicates)
    behavior = Array{Int32}(undef,steps*7)
    for elm in all_data
        behavior = hcat(behavior,elm.mean_behavior)
    end

    behavior = behavior[:,setdiff(1:end,1)]
    behavior = mean(behavior,dims=2)

    fear = Array{Int32}(undef,steps*7)
    for elm in all_data
        fear = hcat(fear,elm.mean_fear)
    end
    fear = fear[:,setdiff(1:end,1)]
    fear = mean(fear,dims=2)

    #get the case data from germany
    csv_raw = CSV.read("SourceData\\fear_yougov.csv";delim=";")
    DataFrames.rename!(csv_raw,[:x,:y])
    csv_raw.x = [round(parse(Float16,replace(x,","=>"."))) for x in csv_raw.x]
    csv_raw.y = [round(parse(Float16,replace(x,","=>"."))) for x in csv_raw.y]
    sort(csv_raw,:x)
    #prepend some data as guess for the trend
    fear_yougov_prepend = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,2,3,6,9,14,18,21,25,28,31]
    #try to delete row 3, doesnt work so far.
    csv_raw = csv_raw[setdiff(1:end, 3), :]
    #parse the strings to Float16s

    #starting at the 16.03.
    #adding the missing month, since the graph only starts from the 16.03. and not as the model the 14.02.
    fear_yougov = vcat(fear_yougov_prepend,csv_raw.y)
    #scale it to 100
    fear_yougov = fear_yougov.*2
    csv_raw = CSV.read("SourceData\\Mobility_Data.csv")

    csv_infections = CSV.read("SourceData\\covid19_ECDC.csv")
    csv_infections = filter(x -> x[Symbol("Country/Region")] == "Germany",csv_infections)
    #get cases from the 14.02., the start date of the model and five more months
    csv_infections = csv_infections.infections[46:200]
    #both start with 1 infection
    csv_infections = csv_infections ./ 15
    infected = Array{Int32}(undef,steps*7)
    for elm in all_data
        infected = hcat(fear,elm.infected_adjusted)
    end
    infected = infected[:,setdiff(1:end,1)]
    infected = mean(infected,dims=2)

    Plots.plot(csv_raw.Value.*100,label="behavior_real")
    plot!(csv_infections,label="infected_real")
    plot!(infected,label="infected_model")
    plot!(fear.*100,label="fear_model")
    plot!(fear_yougov.*100,label="fear_real")
    display(plot!(behavior.*100,label="behavior_model"))


    error = mape(csv_raw.Value,behavior)
    println("error behavior is $error")
    println("behavior data is $behavior")
    error = mape(fear_yougov,fear)
    println("error fear is $error")
    println("fear data is $fear")
    error = mape(csv_infections,infected)
    println("error infected is $error")
    println("infected data is $infected")
    return error
end


using HypothesisTests
behavior = [0.0; 0.0; 0.0; 0.0; 0.0; 0.0; 0.0; 0.0; 0.0; 0.0; 0.0; 0.0; 0.0; 0.0; 0.0; 0.0; 0.0; 0.0; 0.0; 0.0; 0.0; 0.0; 0.375; 0.5; 0.875; 1.125; 1.625; 2.375; 3.375; 4.375; 5.5; 7.75; 10.375; 12.75; 15.75; 19.875; 20.875; 22.375; 27.25; 30.75; 33.375; 37.0; 40.875; 40.375; 40.875; 46.5; 49.875; 51.875; 53.25; 54.75; 51.875; 50.25; 54.875; 57.5; 59.25; 59.25; 57.625; 53.375; 50.0; 55.625; 59.25; 60.5; 59.375; 57.25; 52.625; 49.375; 55.25; 58.5; 59.375; 59.0; 56.625; 52.375; 49.875; 56.5; 59.0; 60.0; 59.625; 58.625; 53.875; 50.75; 55.375; 57.75; 58.0; 57.375; 56.0; 51.625; 48.0; 52.75; 54.75; 54.625; 53.0;
50.5; 47.0; 43.5; 47.5; 46.375; 44.875; 43.125; 42.125; 39.125; 36.625; 39.625; 38.5; 37.875; 39.25; 39.375; 36.75; 34.125; 37.75; 36.5; 34.75; 34.375]
behavior_real = csv_raw.Value
behavior_real = Int.(round.(behavior_real))
behavior = Int.(round.(behavior))

ChisqTest(hcat(behavior,behavior_real[1:length(behavior)]))

infected = [0.0; 0.0; 0.0; 0.0; 1.0; 1.0; 2.0; 3.0; 6.0; 8.0; 14.0; 17.0; 21.0; 28.0; 32.0; 49.0; 57.0; 83.0; 111.0; 134.0; 156.0; 193.0; 248.0; 286.0; 339.0; 401.0; 455.0; 516.0; 596.0; 692.0; 788.0;
889.0; 1022.0; 1175.0; 1284.0; 1382.0; 1557.0; 1706.0; 1849.0; 2018.0; 2200.0; 2344.0; 2482.0; 2674.0; 2892.0; 3122.0; 3343.0; 3564.0; 3744.0; 3901.0; 4132.0; 4348.0; 4594.0; 4835.0; 5072.0; 5195.0; 5304.0;
5455.0; 5715.0; 5987.0; 6199.0; 6410.0; 6510.0; 6623.0; 6787.0; 7058.0; 7357.0; 7599.0; 7764.0; 7849.0; 7932.0; 8300.0; 8745.0; 9133.0; 9420.0; 9618.0; 9708.0; 9794.0; 10031.0; 10408.0; 10717.0; 10947.0; 11116.0; 11193.0; 11264.0; 11445.0; 11636.0; 11858.0; 11974.0; 12088.0; 12153.0; 12215.0; 12352.0; 12442.0; 12538.0; 12626.0; 12707.0; 12749.0; 12787.0; 12884.0; 12943.0; 13011.0; 13096.0; 13180.0; 13223.0; 13259.0; 13342.0; 13415.0; 13490.0; 13569.0; 13642.0; 13680.0]
infected = Int.(infected)
csv_infections = Int.(round.(csv_infections))
ChisqTest(hcat(infected,csv_infections[1:length(infected)]))

ChisqTest(hcat([1,2,3,4,5],[1,2,4,5,6]))

fear = [0.0; 0.0; 0.0; 0.0; 0.0; 0.0; 0.0; 0.0; 0.0; 0.0; 0.0; 0.0; 0.0; 0.125; 0.25; 0.25; 0.375; 0.75; 0.875; 1.125; 1.625; 2.375; 2.875; 3.75; 5.25; 7.0; 9.25; 12.625; 17.125; 20.25; 26.375; 34.625; 42.375; 49.0; 56.0; 64.5; 62.375; 65.25; 80.0; 83.625; 87.875; 95.0; 100.5; 96.125; 97.375; 110.625; 112.75; 115.125; 116.625; 118.5; 110.625; 110.5; 122.0; 123.625; 125.125; 123.875; 121.25; 111.5; 109.5;
124.875; 128.0; 127.875; 125.75; 121.5; 112.0; 110.375; 126.625; 128.25; 128.25; 127.0; 122.875; 113.125; 114.125; 130.0; 130.0; 130.0; 129.125; 127.875; 117.625; 115.25; 128.875; 130.0; 129.625; 128.125; 126.0; 115.875; 108.75; 127.75; 127.875; 126.125; 123.75; 119.375; 109.75; 103.625; 121.5; 115.75; 113.125; 110.375; 110.0; 101.375; 93.625; 109.875; 104.875; 103.75; 108.25; 107.5; 99.125; 91.375; 108.0; 101.875; 97.875; 98.875]
fear = Int.(round.(fear))
fear[fear.==0] .= 1
fear = replace(fear, 0 => 1)
fear_yougov = Int.(round.(fear_yougov))
fear_yougov = replace(fear_yougov, 0 => 1)
ChisqTest(hcat(fear,fear_yougov[1:length(fear)]))

rsquared = cor(hcat(fear,fear_yougov[1:length(fear)])).^2

cor(hcat([1,2,3,4,4,3,2],[1,2,3,4,5,6,7]))

#TODO
#sherrytower notes that least squares (and with that r^2?) should not be used for cumulative incidence data
#have to test model at bigger space in order to get an idea. Let model run over night in some room
