using HypothesisTests, Distances
#read final data
final_data = DataFrame!(CSV.File("ExcelCharts\\h5_data.csv",silencewarnings=true))
fear = final_data.Fear
behavior = final_data.Behavior
infected = final_data.Infected
#read, prepare and return real world data
fear_real, behavior_real, infected_real = get_validation_data()
#plot all
fear = fear[1:112]
fear_real = fear_real[1:112]
behavior = behavior[1:112]
behavior_real = behavior_real[1:112]
infected = infected[1:112]
infected_real = infected_real[1:112]
Plots.plot(fear,label="fear_model")
plot!(fear_real,label="fear_real",legend=:bottomright)
Plots.plot(behavior,label="behavior_model")
plot!(behavior_real,label="behavior_real",legend=:bottomright)
Plots.plot(infected,label="infected_model")
display(plot!(infected_real,label="infected_real",legend=:bottomright))

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
#println(ChisqTest(hcat(fear,fear_real)))
#same for behavior_real
behavior_real = Int.(round.(behavior_real))
behavior = Int.(round.(behavior))
behavior = replace(behavior, 0 => 1)
behavior_real = replace(behavior_real, 0 => 1)
#println(ChisqTest(hcat(behavior,behavior_real)))
#and infections
infected = Int.(round.(infected))
infected_real = Int.(round.(infected_real))
#println(ChisqTest(hcat(infected,infected_real)))
#compute RMSE
println("RMSE Fear is $(Distances.nrmsd(fear,fear_real))")
println("RMSE Behavior is $(Distances.nrmsd(behavior,behavior_real))")
println("RMSE Infected is $(Distances.nrmsd(infected,infected_real))")
#compute MAE%
println("MAE% Fear is $(Distances.meanad(fear,fear_real)/mean(fear_real))")
println("MAE% Behavior is $(Distances.meanad(behavior,behavior_real)/mean(behavior_real))")
println("MAE% Infected is $(Distances.meanad(infected,infected_real)/mean(infected_real))")
#compute r2
println("CorrCof Fear is $(cor(fear,fear_real)^2)")
println("CorrCof Behavior is $(cor(behavior,behavior_real)^2)")
println("CorrCof Infected is $(cor(infected,infected_real)^2)")
#compute F-Test
println("F-Test Fear is $(VarianceFTest(fear,fear_real))")
println("F-Test Behavior is $(VarianceFTest(behavior,behavior_real))")
println("F-Test Infected is $(VarianceFTest(infected,infected_real))")
