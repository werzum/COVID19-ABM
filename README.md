# Julia

An agent-based model of the COVID epidemy in germany, with a focus on the influence of communication and individual behaviour.

SpatialSetup contains the functions required to load OSM and geographic data and returns a model filled with realistic agents with daily routes, social connections and workplaces.
SteppingFunction handles the model runs and contains the logic for agent actions and disease spread.
Validation provides functions to run the model for a given time with given instances and compare the results to real-world data.
