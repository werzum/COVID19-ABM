using Test
using Agents
using Plots
#import the COVID module so we can access its definitions
import .COVID_SIR

#Further test ideas:
#zw. 0 und X, Geographische Bounds (nichts außerhalb der Grenzen?),
#number infected after X steps within percent deviation of real numbers of germany, upper and lower bound for reasonable growth,

@testset "Full Test" begin

    model = COVID_SIR.model_initiation(densitymap = COVID_SIR.fullmap; COVID_SIR.params...)
    #create data for 50 steps so that we can check its properties
    data = COVID_SIR.create_data(model,50)

    @testset "Space Initialization" begin
        #proper map dimensions
        @test typeof(COVID_SIR.fullmap)== Array{Int64,2}
        @test (1,1) < size(COVID_SIR.fullmap) <(10000,10000)
        @test 100 < nv(model) < 1000000
    end

    @testset "Infection Initialization and Behavior" begin
        #realistic number of agents, successfully populated
        @test nagents(model) > 100 && nagents(model) < 100000
        #infected on first day between 1 and 99
        @test 0 < data[1,Symbol("infected(status)")] < 100
        #growth, but no unrealistic growth
        @test data[1,Symbol("infected(status)")] < data[2,Symbol("infected(status)")] < 400
        #number of SIRs is not significantly smaller than nagents from the beginning (right now some are dying?!)
        #Here we check wether the sum of SIR is about same to nagents(model) for all timesteps
        @test minimum(nagents(model)-1000 .< [sum(data[i,[Symbol("infected(status)"),Symbol("susceptible(status)"),Symbol("recovered(status)")]]) for i in 1:50])
    end

end
