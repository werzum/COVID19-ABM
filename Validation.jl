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
