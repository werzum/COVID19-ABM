@time for i =1:10000000
    i^i
end

@time Threads.@threads for i = 1:10000000
    i^i
end
