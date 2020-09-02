using HypothesisTests
#read final data
final_data = DataFrame!(CSV.File("results_80rep.csv",silencewarnings=true))
fear = final_data.Fear
behavior = final_data.Behavior
infected = final_data.Infected
#read, prepare and return real world data
fear_real, behavior_real, infected_real = get_validation_data()
#plot all
Plots.plot(behavior_real.*100,label="behavior_real")
plot!(infected_real,label="infected_real")
plot!(infected,label="infected_model")
plot!(fear.*100,label="fear_model")
plot!(fear_real.*100,label="fear_real")
display(plot!(behavior.*100,label="behavior_model"))
#MAPEs
error = mape(fear_real,fear)
println("error fear is $error")
error = mape(behavior_real,behavior)
println("error behavior is $error")
error = mape(infected_real,infected)
println("error infected is $error")
#chi square test results
#prepare fear so there is no division by zero and data is rounded to int
fear = Int.(round.(fear))
fear[fear.==0] .= 1
fear = replace(fear, 0 => 1)
fear_real = Int.(round.(fear_real))
fear_real = replace(fear_real, 0 => 1)
println(ChisqTest(hcat(fear,fear_real[1:length(fear)])))
#same for behavior_real
behavior_real = Int.(round.(behavior_real))
behavior = Int.(round.(behavior))
println(ChisqTest(hcat(behavior,behavior_real[1:length(behavior)])))
#and infections
infected = Int.(infected)
infected_real = Int.(round.(infected_real))
println(ChisqTest(hcat(infected,infected_real[1:length(infected)])))
