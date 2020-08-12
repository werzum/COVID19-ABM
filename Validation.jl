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
    #using normal fear since fear over 100 isnt consistent at all
    fear_model = b.mean_fear
    println("rmse is $(rmse(fear_yougov[1:steps*7],fear_model[1:steps*7]))")
    Plots.plot(fear_yougov,label="fear_yougov")
    plot!(fear_model,label="fear_model")
end

function rmse(series1,series2)
    errors = [(series1[i]-series2[i])^2 for i in 1:length(series2)]
    rmse = sqrt(mean(errors))
end

function run_multiple(model,social_groups,distant_groups,steps,replicates)
    #reset the model for all workers and add 1 infected to it
    reset_model_parallel(1)
    #collect all data in one dataframe
    all_data = pmap(j -> agent_week!(deepcopy(model),social_groups,distant_groups,steps,false), 1:replicates)

    # Infection rate/risk (base value for both, *0.5:0.1:1.5
    # Behavior treshold, as factor(or. 100) *50:10:150
    # Fear Growth, as factor(or. 100) *50:10:150
    # Fear Decay, as factor(or. 100) *50:10:150
    # Factor of fear on the behavior, *0.5:0.1:1.5
    # Message Influence, norms and attitude growth, *50:10:150
    # Attitude, Norm, decay, *50:10:150

    #get the data and average it
    infected = Array{Int32}(undef,steps*7)
    for elm in all_data
        infected = hcat(infected,elm.infected_adjusted)
    end
    infected = infected[:,setdiff(1:end,1)]
    #plot all results so we have an idea
    display(Plots.plot(infected,label="infected"))
    infected = mean(infected,dims=2)
    #and return the last value, which represents the total number of infected
    print(infected)
    return last(infected)
end
