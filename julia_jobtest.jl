using ClusterManagers

addprocs(SlurmManager(4), t="00:5:00")
