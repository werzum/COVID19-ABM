# Julia - a COVID-19 ABM

An agent-based model of the COVID epidemy in germany, with a focus on the influence of communication and individual behaviour. Agents.jl is used for the Agent Based Simulation.

#### SpatialSetup 
Spatial Setup contains the functions required to load OSM and geographic data and returns a model filled with realistic agents with daily routes, social connections and workplaces. OSM data can be easily downloaded by https://protomaps.com/, data for the geographic distribution is taken from the German Census 2011.

#### Stepping Function
SteppingFunction handles the model runs and contains the logic for agent actions and disease spread. Parameters for the disease spread are mainly sourced of the RKI COVID-19 factsheet.

#### Validation
Validation provides functions to run the model for a given time with given instances and compare the results to real-world data. Behavior and Mobility data is taken from the COVID 19 Mobility Data provided by Apple. Fear data is taken from a YouGov survey, infection data from the RKI Covid 19 Dashboard.
With that, a graph comparing the fear and behavior trend is produced:
![Fear and behavior Aachen](Graphics/Fear_behavior_h1.png?raw=true "Fear and behavior Aachen")

#### Model Components Overview
![Chart of model components](Graphics/ModelComponents.png?raw=true "Model Components Overview")

#### Applied behavior model
The behavioral model is based on the features determining behavior of the TELL ME project (Badham, Gilbert et al., 2015), that is fear, behavior and attitude, while giving more weight to the non-linear growth of the fear aspect as discussed by Epstein (2014). The following figure shows how agent behavior is determined:
![Behavioral model](Graphics/BehaviorModel.png?raw=true "Behavioral Model")

### Set-Up Information

#### Required Data
Different datasets are required for the set-up of the simulation. On request, I can provide the datasets for the German Census, OSMs of Aachen and German News-frequencies for certain tags. All data is placed in /SourceData.

##### OpenStreetMap
The easiest option I found is heading to [protomaps] (https://protomaps.com/extracts) and download a map of your selection. Then, use [this](https://wiki.openstreetmap.org/wiki/Osmconvert) converter tool to convert .osm.pbf to .osm. Other options would be going to openstreetmap.org/, but they limit the selectable map size to 50.000 nodes which is quite small, or download a county/country-sized dataset [here](https://download.geofabrik.de/).
An example map looks like this:
![Comparison chart of the maps of Aachen](Graphics/map_comparison.png?raw=true "Map Comparison")

##### Census
Demographic information is taken from the German Census 2011. It provides information about the amount of inhabitants, the share of women, people over 65 and under 18 in each square of a grid of cells of Germany. In order to substitute this information, a CSV with bounding boxes in Min/Max Lat/Long format and #inhabitants, %women, %over65, %under18 is required. More information about the dataset (in German) can be found [here] (https://www.opengeodata.nrw.de/produkte/bevoelkerung/zensus2011/ergebnisse_1km-gitter/).

##### Wealth Data
Wealth Data is incorporated into the map to adjust the number of workplace contacts and usage of public transport. [This](https://iw.carto.com/viz/71f414f4-ad68-4c60-aad8-0e4af400080c/public_map) map was used - it provides the mean purchasing power per district in Germany. For each square cell of the Census grid, I checked in which district it belongs to (ie. it is inside of) and then assigned it the purchasing power. Replicating this wealth data might become quite complicated, it could be simplified (at the loss of precise wealth data, of course) to simply assign the mean wealth to all cells.

##### Message Frequencies
Message frequencies for certain tags are used to replicate messages in the model, the GDELT Project API is used to collect these messages. An example queue is [this](https://api.gdeltproject.org/api/v2/doc/doc?query=(social%20distancing%20OR%20waschen%20OR%20tragen)%20%22covid%22&mode=timelinevolinfo&TIMELINESMOOTH=5&sourcecountry:germany&TIMERES=day&sourcelanguage:german&STARTDATETIME=20200101000000). It searches for the keyords "Social Distancing" and "Waschen" in German Newslets and written in German from the 01.01.2020 - more documentation for the API can be found [here](https://blog.gdeltproject.org/gdelt-doc-2-0-api-debuts/).
In SteppingFunctions/messages, the frequencies are manually normalized so that they fit from 1-10. This should be adjusted to fit a new dataset.

##### Validation Data
The protective behavior adoption was measured using [Apples Mobility Data](https://covid19.apple.com/mobility), which showed the same trend as studies regarding the adoption of protective behavior but is much more detailed. The dataset should provide mobility data for all countries and within relevant timespans for COVID-19.
For infection data, data from [OurWorldInData](https://ourworldindata.org/coronavirus-source-data) was used, though this can be easily substituted.

#### Other Setup Requirements
I modified the Agents.jl packacge individually to allow the addition of households to the model map after it was loaded. This can be done by making line the GraphSpace(line 26) mutable at .julia/packages/Agents/(...)/src/core/discrete_space.jl. The result should look like this: mutable struct GraphSpace{G} <: DiscreteSpace
