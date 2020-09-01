# Julia - a COVID-19 ABM

An agent-based model of the COVID epidemy in germany, with a focus on the influence of communication and individual behaviour. Agents.jl is used for the Agent Based Simulation.

#### SpatialSetup 
Spatial Setup contains the functions required to load OSM and geographic data and returns a model filled with realistic agents with daily routes, social connections and workplaces. OSM data can be easily downloaded by https://protomaps.com/, data for the geographic distribution is taken from the German Census 2011.

#### Stepping Function
SteppingFunction handles the model runs and contains the logic for agent actions and disease spread. Parameters for the disease spread are mainly sourced of the RKI COVID-19 factsheet.

#### Validation
Validation provides functions to run the model for a given time with given instances and compare the results to real-world data. Behavior and Mobility data is taken from the COVID 19 Mobility Data provided by Apple. Fear data is taken from a YouGov survey, infection data from the RKI Covid 19 Dashboard.
