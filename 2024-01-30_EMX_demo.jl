### A Pluto.jl notebook ###
# v0.20.4

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    #! format: off
    quote
        local iv = try Base.loaded_modules[Base.PkgId(Base.UUID("6e696c72-6542-2067-7265-42206c756150"), "AbstractPlutoDingetjes")].Bonds.initial_value catch; b -> missing; end
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : iv(el)
        el
    end
    #! format: on
end

# ╔═╡ d534fe86-1268-44be-b18c-b2895615a4b9
using ShortCodes

# ╔═╡ 7d63ec90-e7cb-4e18-9ee4-5ba7c8694e94
using EnergyModelsBase

# ╔═╡ ffbee0c4-9193-49fb-9d43-f6d9957e82a1
using TimeStruct

# ╔═╡ dff63058-c619-4a10-9307-b16c77f3acfe
using JuMP, HiGHS

# ╔═╡ f9f10b56-c4be-40c8-9794-def8acb25094
using EnergyModelsGeography

# ╔═╡ 9c57324f-f798-4d37-8b7b-1bf46a8c6fd8
using EnergyModelsInvestments, EnergyModelsRenewableProducers

# ╔═╡ ab2ab128-d41f-43a8-8611-c77b297a6741
using PlutoUI

# ╔═╡ 74b309e6-6e80-44d8-a09a-b7ac0767e074
begin
    using CairoMakie, AlgebraOfGraphics
    CairoMakie.activate!(type = "svg")
end

# ╔═╡ bdce2eda-9d55-4408-aa4f-12f38d27a8df
using DataFrames

# ╔═╡ 277e899e-b3a2-11ee-3c91-dd9707765363
md"# EnergyModelsX
--from the [CleanExport project](https://www.sintef.no/en/projects/2020/cleanexport/)"

# ╔═╡ e4be1763-c58a-4e57-a429-e48b2dfb579c
html"""<img src="https://www.sintef.no/contentassets/c1d37b5302e44e989786f7367b1b9b59/cleanexport_2.jpg?width=1080&mode=crop&scale=both&quality=80" />"""

# ╔═╡ b122be93-bc75-4601-ba83-8262b2fb1c18
md"## Installing EnergyModelsX"

# ╔═╡ 60787e62-73a1-4149-a297-b92470fc8372
md"""
!!! nb "Registered Packages"

	As of 2024-02-05, all the EnergyModelsX packages are registered in the [General registry](https://github.com/JuliaRegistries/General?tab=readme-ov-file#general) and may be installed through the package manager by name as other open packages such as `JuMP` and `DataFrames`.
"""

# ╔═╡ 812befd7-032e-4c53-9fae-c4054af74c76
md"## Documentation
This notebook will give a quick introduction to the EnergyModelsX framework and models. Please refer to the [documentation on GitHub](https://energymodelsx.github.io/EnergyModelsBase.jl/dev/#EnergyModelsBase.jl) for more details"

# ╔═╡ 6918eee5-a178-40aa-851b-c461635fe091
WebPage("https://energymodelsx.github.io/EnergyModelsBase.jl/dev/")

# ╔═╡ bdb54c5b-9c8d-4881-b522-0d7088fff6ad
md"# A Simple Example
We will investigate a fictuous remote island location which is currently self-supported with power from coal, and different ways of reducing the CO₂ emissions.
"

# ╔═╡ 0e4f5b99-4954-4aa1-8f41-d1c34186e5a1
md"""
!!! nb "Disclaimer: Synthetic data"
	All data in the following demo is synthetic and is just provided for illustration of how to set up and use models.
"""

# ╔═╡ a3144c1a-a327-4b1f-a59d-33a29a31a435
md"## The Network"

# ╔═╡ ddd95f30-53af-4e23-96ff-2d303254ac71
BlockDiag("""blockdiag {
  "Coal supply" [color = "lightgray"];
  "Local power demand" [color = "pink"];
  "Coal supply" -> "Coal power plant" [label ="coal"];
  "Coal power plant"-> "Local power demand" [label="power"];
}""")

# ╔═╡ fd4adc62-6d0f-4288-982d-f27e25673175
md"## Defining the Case"

# ╔═╡ cea18e40-5c45-43e4-8525-178890c36ce7
md" For a pure operational model, we need `EnergyModelsBase`:"

# ╔═╡ decc9f11-0bca-458d-906e-d99cefd4204b
md"We define the resources that are relevant for our model:"

# ╔═╡ 7a4186eb-9983-4224-8363-96549869acef
begin
    power = ResourceCarrier("Power", 0)
    coal = ResourceCarrier("Coal", 0.35)  # CO₂ intensity (e.g. t/MWh)
    CO2 = ResourceEmit("CO2", 1)
    products = [power, coal, CO2]
end

# ╔═╡ d2e9dbd4-3c65-473d-b845-2d427084222d
md"In this analysis we only consider emissions from the energy carriers (no process emissions)"

# ╔═╡ 804b724b-8261-4947-8eb5-446c2582f39e
emission_data = EmissionsEnergy()

# ╔═╡ 612faf94-7040-49ab-8d77-64f3838ec79d
md"We start with a simple time structure, considering only one time period. For the time being we still need to define a two-level time struct:"

# ╔═╡ 64931367-f960-43ab-8279-5230b6aa7197
ts = TwoLevel(1, 1, SimpleTimes(1, 1))

# ╔═╡ 5bd90561-ab99-4b77-998a-79d7f0f7fa8e
coal_source = RefSource(
    "Coal source",      # id
    FixedProfile(1e12), # capacity
    FixedProfile(9),    # opex_var
    FixedProfile(0),    # opex_fixed
    Dict(coal => 1),    # output
    Data[],   		    # additional data (here nothing) 
)

# ╔═╡ e50fdf31-2a12-4fbe-9c47-686dc10632ec
coal_plant = RefNetworkNode(
    "Coal power plant", # id
    FixedProfile(25),   # capacity
    FixedProfile(6),    # opex_var
    FixedProfile(0),    # opex_fixed
    Dict(coal => 2.5),  # input
    Dict(power => 1),   # output
    [emission_data],    # additional data (here emissions)
)

# ╔═╡ 76c95758-0d0a-492d-9ec6-0767532e8967
power_demand_mw = FixedProfile(20)

# ╔═╡ 42aab7d9-7309-43bc-b21a-41a7bdec0a17
power_demand = RefSink(
    "Local demand",    # id
    power_demand_mw,   # capacity (demand)
    Dict(:surplus => FixedProfile(0), :deficit => FixedProfile(1e6)), # penalty
    Dict(power => 1),  # input (with conversion factor)
    [emission_data],   # additional data (here emissions)
)

# ╔═╡ 84d48acc-ce5c-4c55-8b63-e45d20a92b9b
md"We collect the nodes in the system as they will form part of the case input definition"

# ╔═╡ a870f9c8-35b4-485c-ad7b-5ae6dd873150
nodes = [coal_source, coal_plant, power_demand]

# ╔═╡ 5138de81-2ff3-4794-8f98-bfd9f1bc76d1
md" Similarly we define and collect the links between nodes. These serve as logical links between the nodes"

# ╔═╡ 75a42272-b0a7-48ff-945a-54e19d1f36ef
links = [
    Direct("coal-plant", coal_source, coal_plant),
    Direct("plant-demand", coal_plant, power_demand),
]

# ╔═╡ 9211890f-b728-4297-bf4e-03b389110f40
md" The nodes, links, products and time structure make up the case:"

# ╔═╡ e283dcd3-05f6-4e79-9a3f-be2800d16967
case = Dict(:nodes => nodes, :links => links, :products => products, :T => ts)


# ╔═╡ e3c7200f-5900-424b-875d-10ee78b7bf0c
md" For this analysis we use an `OperationalModel` (the default for `EnergyModelsBase`)"

# ╔═╡ 872da3ab-742a-4daf-a080-5368e2cf2950
modeltype = OperationalModel(
    Dict(CO2 => FixedProfile(1e12)),   # emission limit
    Dict(CO2 => FixedProfile(0)),      # emission price
    CO2,                               # CO₂ resource
)


# ╔═╡ 82a12165-6381-46fc-985e-3bc472a0cf8d
md" To create and solve the model we use the open-source MILP solver [`HiGHS`](https://highs.dev/). For users with access to commercial solvers, the solver can be easily switched for improved performance.

The usual functionality from JuMP is available to inspect or modify the model and read the results.
"

# ╔═╡ 5fe27d7a-ffa4-43c7-b8c4-472155a8c4ec
model = run_model(case, modeltype, HiGHS.Optimizer)

# ╔═╡ 740c1cc8-a44c-4a54-b573-0bc80da44c8f
latex_formulation(model)

# ╔═╡ 1976b9dd-9c62-4aa3-ba31-0932ab2cdaa2
md"## Results
We can use the standard JuMP functions to investigate the model solution:"

# ╔═╡ 773756be-e8dc-42ba-b03e-dfb909b9ddc5
solution_summary(model)

# ╔═╡ 88c2b560-1123-4f8e-81a0-da447084a070
md"The results may also be read as tables and exported to `DataFrame`s as here, or saved to CSV or database.

Flow into nodes:"

# ╔═╡ f21f3c6a-2b81-4d41-846a-421d90242e1d
md"Sink deficit:"

# ╔═╡ 218dde43-b45c-4d29-b51b-61bd1205dddf
md"Total emissions:"

# ╔═╡ b1dd50e6-66e2-4977-9f56-c8e2cd4c70c8
md"Emissions per node:"

# ╔═╡ ddcb618f-71b5-497f-90ea-dc9b834ebfe7
md" We set up new arrays for the multiperiod case as Pluto will automatically recalculate when we change the inputs."

# ╔═╡ 2053980e-bb80-4617-87bd-2d176d5f468c
md" After solving the model instance, we can inspect the results, e.g. the flow of each resource going into each node."

# ╔═╡ d1c06598-2177-4a55-a312-df4f33efde5e
md" By plotting the flows of Coal and Power we can verify that they follow the demand profile and that Coal is converted to Power at a fixed rate:"

# ╔═╡ fe14d4c6-ce89-4973-9a80-e5ec70a834b7
md"# Geography and Transmission
We will add a transmission cable from the mainland to access renewable power from the Mainland power grid.
## The Network
We model the new system by adding one availability node in each region, and a transmission line between them. This allows the Mainland power to serve the Local power demand within the capacity of the transmission line. 
"

# ╔═╡ 02ed4d4a-ac0e-4c54-8ddd-a7ad0f06e851
BlockDiag(
    """blockdiag {
  "Coal supply" [color = "lightgray"];
  "Local power demand" [color = "pink"];
"Remote availability" [color = "lightblue"];
"Mainland availability" [color = "lightblue"];
 "Mainland power" [color = "lightgreen"];
  "Coal supply" -> "Coal power plant" [label ="coal"];
  "Coal power plant"-> "Remote availability" [label="power"];
"Remote availability" -> "Local power demand" [label="power"];
"Mainland power" -> "Mainland availability" [label="power"];
"Mainland availability" -> "Remote availability" [thick, folded, label="transmission"];
group {"Mainland power";"Mainland availability"; color="lightgreen"}
group {"Coal supply"; "Coal power plant"; "Remote availability"; "Local power demand"; color="lightgray"}
}""",
)

# ╔═╡ d293520b-4152-4654-923c-4f1bf384f3c6
md"## Defining the Case"

# ╔═╡ 802bf139-becd-420c-a21c-6b5dc0e41ba5
md" We add the mainland (grid) power as another source node:"

# ╔═╡ c2232182-1b2f-4932-a711-679e01fb3355
md" We can reuse most of the nodes from before, and also add the two `GeoAvailability` nodes used for transmission between regions"

# ╔═╡ 3e32aa11-35c1-48b6-a0c3-51d48a636420
md" We update the (local) links between nodes"

# ╔═╡ 824647b5-80f8-45d2-bbd1-d8a3a75f0cf4
md" The `RefArea`s represent each geographical area and links to the availability node of each region:"

# ╔═╡ 3e00269e-5ee5-4d01-81f3-1202aec6e8c6
md" We use variables for `power_cost` and `transmission_capacity` to make them easier to change later, or they can be thought of as passed as arguments to a function or read from an external source."

# ╔═╡ 94963669-80b7-41d2-96bb-2cc0eba372c8
md"All transmission will also be passed as part of the case definition."

# ╔═╡ cf498b13-7619-4118-a301-4bdbfeec245d
md"## Results"

# ╔═╡ 0c9caebd-420d-4345-9893-2bdc5f8b39c5
@bind power_cost PlutoUI.Slider(0:1:100; default = 50)

# ╔═╡ e1bc8b77-8876-4969-afb4-8b1d92442855
power_cost

# ╔═╡ 985484db-f5fb-4fd2-9b75-a0c18a51797c
power_mainland = RefSource(
    "Power mainland",          # id
    FixedProfile(120),         # cap
    FixedProfile(power_cost),  # opex_var
    FixedProfile(15),          # opex_fixed
    Dict(power => 1),          # output
    [emission_data],
)

# ╔═╡ d5549e06-dcde-4724-9aeb-56f1ff04304f
@bind transmission_capacity PlutoUI.Slider(5:1:20; default = 10)

# ╔═╡ fc5c0d2f-91ba-4727-bba4-0981eff29bac
power_cost, transmission_capacity

# ╔═╡ 29e784c6-ed83-494e-841f-ab72dcd9d73e
md"We can try with different values of power cost: (**$(power_cost)**) and transmission capacity: (**$(transmission_capacity)**) by moving the sliders:

"

# ╔═╡ c7ebc721-126a-4675-ab4c-94e7af75b310
horizon_days = 7

# ╔═╡ 5c454b87-4fdd-41f8-8c31-b2a70b65ba6c
horizon_days

# ╔═╡ b589ddb6-a8ed-4a91-b007-f645d2ee0926
multiperiod_ts = TwoLevel(1, 1, SimpleTimes(horizon_days * 24, 1))

# ╔═╡ 4e402681-7144-4969-914e-7782e8f7a1d1
md"# Investments
We will consider investing in local wind generation in the remote area and/or the transmission line:
## The Network"

# ╔═╡ a44bac08-5c9e-4a5e-91dc-3a4b6f92789a
BlockDiag(
    """blockdiag {
"Wind generation" [color="lightgreen"];
"Remote availability" [color = "lightblue"];
"Wind generation" -> "Remote availability" [label="power"];
"Mainland availability" [color = "lightblue"];
  "Coal supply" [color = "lightgray"];
  "Local power demand" [color = "pink"];
  "Coal supply" -> "Coal power plant" [label ="coal"];
  "Coal power plant"-> "Remote availability" [label="power"];
"Remote availability" -> "Local power demand" [label="power"];
 "Mainland power" [color = "lightgreen"];
"Mainland power" -> "Mainland availability" [label="power"];
"Mainland availability" -> "Remote availability" [thick,folded, label="transmission"];
group {"Mainland power";"Mainland availability"; color="lightgreen"}
group {"Coal supply"; "Coal power plant"; "Remote availability"; "Local power demand"; "Wind generation"; color="lightgray"}
}""",
)

# ╔═╡ f549a531-14c5-43c0-ac7b-315214af9d4c
md"## Defining the Case"

# ╔═╡ 0af9269e-6cae-4f15-b23a-c4ea138e5791
md" For the wind power case we will use two model extensions:"

# ╔═╡ cde63969-78f3-40c8-9c9e-7aaf6ad658e1
md" We first define the investment options for the wind generation. By default, the investmendmode is `ContinuousInvestment`, limited by the parameters we specify:"

# ╔═╡ 0c5b0ccf-128c-4f16-b1ab-bb0ac3ec3fa2
inv_data_wind = SingleInvData(
    FixedProfile(100_000),    	# (CAPEX for the defined capacity)
    FixedProfile(20),          	# (maximum possible installed)
    ContinuousInvestment(FixedProfile(0), FixedProfile(20)), # min/max add per strategic period
    StudyLife(FixedProfile(20)),
)

# ╔═╡ 678bc5f1-4c83-4068-aead-5698fd6cbca0
md" We generate some synthetic capacity factors for our wind turbine project:"

# ╔═╡ c9597105-1197-4f48-9d2a-13ed81310567
md" The wind generation node is of type `NonDisRES` (Non-dispatchable renewable energy source)"

# ╔═╡ a77d20c1-9a14-47ec-9c99-b8ae491cd4a9
#Investment capacity limited to node capacity for  BinaryInvestment
inv_data_transmission = SingleInvData(
    FixedProfile(500_000),
    FixedProfile(50),
	FixedProfile(0),                    # Start with intitial capacity = 0
	BinaryInvestment(FixedProfile(50)), # Investment in additional capacity
    StudyLife(FixedProfile(50)),
)


# ╔═╡ 7a30713a-5beb-4597-b83e-d43dbf67a8d3
transmission_data = [inv_data_transmission]

# ╔═╡ befeccf8-a0d1-4658-b6a2-d7103f13ecc8
transmission_line = RefStatic(
    "transline",                			# id
    power,                      			# resource
    FixedProfile(transmission_capacity),  	# capacity
    FixedProfile(0.1),          			# transmission loss (ratio)
    FixedProfile(0),  						# opex_var
    FixedProfile(0.1),          			# opex_fixed
    1,                          			# directions
    transmission_data,          			# data
)

# ╔═╡ 3fd372f7-3589-4281-b1bd-92255c20990e
md" To create an investmentmodel, we use the modeltype `InvestmentModel` in place of the `OperationalModel` to generate variables and constraints for investment decisions."

# ╔═╡ 631fbb4d-1fe6-461f-8930-14585caca1ae
md" We reuse most of the nodes and links from before for the investment model:"

# ╔═╡ e74fd098-51a3-430f-905e-112cbe02d04a
md"For the investment model we make sure the length of the strategic period is 8760 hours (1 year)."

# ╔═╡ 6c60f2bd-6441-4b05-b05a-b066a0279463
inv_ts = TwoLevel(1,1,SimpleTimes(horizon_days * 24, 1); op_per_strat=8760)

# ╔═╡ 052e0093-98a2-4bc2-9318-2416ae241ec5
md"## Results"

# ╔═╡ 6eeab062-3283-461e-a426-394cf405328d
md"We can check how the models suggest investing in transmission and wind generation:"

# ╔═╡ 2c0e1acb-ca4d-4f04-847c-b5d98c644d74
md" We can see how the results of the investment model changes as we impose a stricter or slacker constraint on the CO₂ emissions (set by the slider below):"

# ╔═╡ e1eff250-74ef-4879-a3c3-ae83b0a25a2f
@bind co2_limit PlutoUI.Slider(0:1000:100_000; default = 54_000)

# ╔═╡ f9a039bd-fd98-4476-ab8d-6cffa755894b
modeltype_inv = InvestmentModel(
    Dict(CO2 => StrategicProfile([co2_limit])), # emission_limit
    Dict(CO2 => StrategicProfile([0])),         # emission_price
    CO2,                                        # CO₂ instance
    0.07,                                       # discount rate r
)

# ╔═╡ a8e9720f-28e3-4a8e-a8cf-d0e3c2cd34d4
co2_limit

# ╔═╡ 307d6c81-0e5c-4907-bd3f-cbbcfa187b68
md" # The End
**Technology for a better society**


SINTEF © 2024"

# ╔═╡ 7578e8e9-be07-4af5-89f2-99bf3ad39943
md" # Notebook Utils
Utility functions and imports to make main notebook less crowded follow here:
"

# ╔═╡ 27b88036-263a-46ae-b12a-fb85dae4512d
PlutoUI.TableOfContents()

# ╔═╡ 99cae247-f58f-4e90-b834-5211d405adfa
function syn_dem(N)
    generated_demand = vcat([syn_dem() for d = 1:N]...)
    # [(; hour = h, demand = d) for (h, d) in enumerate(generated_demand)]

end

# ╔═╡ 84eca013-6ca9-4092-9548-28d7762b44ac
function syn_dem()
    d = 5 * rand()
    hours = [
        8,
        8,
        8.5,
        9,
        10,
        11,
        13,
        14.1,
        12,
        11,
        10.5,
        10,
        10.5,
        11,
        11,
        11.5,
        13,
        13.5,
        13,
        12,
        10,
        9,
        8.5,
        8,
    ]
    hrand = [1 + 0.5 * rand() for _ in eachindex(hours)] ./ 50
    day = d .+ hours .+ hrand
end

# ╔═╡ 68f7cf23-00be-48ab-91fb-75fc87817f42
syn_demand = syn_dem(horizon_days)

# ╔═╡ 16b54533-7fa8-4643-af1a-bb02eab01e15
multiperiod_demand = OperationalProfile(syn_demand)

# ╔═╡ ac227d32-1554-474f-8abc-e56c546517d1
multiperiod_power_demand = RefSink(
    "Local demand",       # id
    multiperiod_demand,   # demand
    Dict(:surplus => FixedProfile(0), :deficit => FixedProfile(1e6)), #penalty
    Dict(power => 1),     # input
    [emission_data],      # data (here for emissions)
)

# ╔═╡ 07592fc1-ec10-4295-946d-621b36520178
multiperiod_nodes = [coal_source, coal_plant, multiperiod_power_demand]

# ╔═╡ 86b1f5bf-16be-4330-8c3c-254153c03863
@bind geo_ex PlutoUI.Select([
    (ts = ts, nodes = nodes) => "single period",
    (ts = multiperiod_ts, nodes = multiperiod_nodes) => "multi period",
])

# ╔═╡ f4f21e5d-9955-44a9-9f55-ba0287ecf1ef
geo_nodes = vcat(
    geo_ex.nodes,
    [
        GeoAvailability("Remote_availability", products),
        GeoAvailability("Mainland_availability", products),
        power_mainland,
    ],
)

# ╔═╡ 36b45cfe-2a7f-4592-9c62-1feb355dc554
geo_links = [
    Direct("coal-plant", coal_source, coal_plant),
    Direct("plant-availability", coal_plant, geo_nodes[4]),
    Direct("availability-demand", geo_nodes[4], geo_nodes[3]),
    Direct("power-mainlandav", geo_nodes[6], geo_nodes[5]),
]

# ╔═╡ 407c948a-5c6f-4640-aaa6-f7a46958f269
areas = [
    RefArea(1, "Remote", 10.751, 59.921, geo_nodes[4]),
    RefArea(2, "Mainland", 10.398, 63.4366, geo_nodes[5]),
]

# ╔═╡ b3bcdb92-5946-49a7-b82a-6504f3ee53a9
transmissions = [Transmission(areas[2], areas[1], [transmission_line])]

# ╔═╡ 819df70c-2ff8-4a46-be84-8d8af08b1b98
geo_case = Dict(
    :nodes => geo_nodes,
    :areas => areas,
    :transmission => transmissions,
    :links => geo_links,
    :products => products,
    :T => geo_ex.ts,
)

# ╔═╡ ee7f8344-e7cc-492b-8c85-367fe407ec65
geo_model = EnergyModelsGeography.create_model(geo_case, modeltype)

# ╔═╡ 3fcc860f-e7b1-402d-b113-c9e48b9ca5e7
set_optimizer(geo_model, HiGHS.Optimizer)

# ╔═╡ c6d36bbe-fcfd-4f12-949f-df4d7966f942
optimize!(geo_model)

# ╔═╡ 600dcc3f-04b8-493e-8fdb-5ed09c10bbd9
multiperiod_links = [
    Direct("coal-plant", coal_source, coal_plant),
    Direct("plant-demand", coal_plant, multiperiod_power_demand),
]

# ╔═╡ 9a013351-6742-40f6-9ff2-3642c1ed32af
multiperiod_case = Dict(
    :nodes => multiperiod_nodes,
    :links => multiperiod_links,
    :products => products,
    :T => multiperiod_ts,
)

# ╔═╡ b488deac-923c-4252-9f8f-dc9316e22b40
multiperiod_model = run_model(multiperiod_case, modeltype, HiGHS.Optimizer)

# ╔═╡ 8739a599-95f6-4978-9087-aac6d5f3ee0d
function plot_demand(d)
    df = DataFrame()
    df.hour = [i for i in eachindex(d)]
    df.demand = d
    axis = (width = 600, height = 600)
    draw(data(df) * mapping(:hour, :demand) * visual(Lines); axis)
end

# ╔═╡ aeec127b-0a07-4c8b-96f5-55d8037d4384
plot_demand(syn_demand)

# ╔═╡ 7323169a-d87e-4b33-9abe-6b98f6dc52b8
function plot_flow(d)
    d.hour = [i for i in eachindex(d.period)]
    # df_multiperiod
    axis = (width = 600, height = 600)
    draw(data(d) * mapping(:hour, :flow_in, color = :resource) * visual(Lines); axis)
end

# ╔═╡ d8be386e-6274-4288-a0cf-71b93c0e7632
function plot_flow_node(d)
    d.hour = [TimeStruct._oper(i) for i in d.period]
    d = d[map(x -> isa(x, ResourceCarrier), d.resource), :]
    d = d[map(x -> !contains(x.id, "availability"), d.node), :]
    axis = (width = 600, height = 125)
    draw(
        data(d) * mapping(:hour, :flow_out, color = :node, row = :node) * visual(Lines);
        axis,
    )
end

# ╔═╡ 8632e056-5f9b-4383-8de5-5329eb98a5f4
begin
    # Allow basic sorting of EMB types in DataFrames
    Base.isless(a::EnergyModelsBase.Node, b::EnergyModelsBase.Node) = a.id < b.id
    Base.isless(a::EnergyModelsBase.Resource, b::EnergyModelsBase.Resource) = a.id < b.id
    Base.length(a::EnergyModelsBase.Resource) = 1
end

# ╔═╡ f482541e-4943-4715-9875-5313f319b89f
"""
	syn_wind(n)
Generate synthetic wind data for hour `n`
"""
function syn_wind(n)
    max(0, min(1, 0.5 * sin(n * π / (36)) + 0.75rand()))
end

# ╔═╡ 229f049a-8362-4b1f-8fa2-f6d342a96675
"""
	syn_windata(N)
Generate synthetic wind data for `N` hours using `syn_wind()`
"""
function syn_windata(N)
    syn_wind.(1:N)
end

# ╔═╡ 3fc9c920-aa19-4d2c-8205-a6824294c8ed
wind_data = syn_windata(horizon_days * 24)

# ╔═╡ 05dff48f-e180-463c-98ca-cf1fdfe697f0
lines(wind_data)

# ╔═╡ 4cc14d25-fc1a-4b72-babe-2925754aa328
wind = NonDisRES(
    "wind",           # id
    FixedProfile(2),  # cap
    # FixedProfile(0.55),# profile (capacity factor)
    OperationalProfile(wind_data), # profile (capacity factor)
    FixedProfile(10), # opex_var
    FixedProfile(10), # opex_fixed
    Dict(power => 1), # output
    [inv_data_wind],  # data
)

# ╔═╡ 72a2c038-adb7-4edb-9fe6-ebdfa412ce28
inv_nodes = vcat(geo_nodes, [wind])

# ╔═╡ c4d4590e-0207-4f1c-b7cb-c573ee4772ab
inv_links = vcat(geo_links, [Direct("wind-remoteav", wind, geo_nodes[4])])

# ╔═╡ ebad63ba-07e9-49f2-8824-e0b2df78c993
inv_case = Dict(
    :nodes => inv_nodes,
    :links => inv_links,
    :products => products,
    :areas => areas,
    :transmission => transmissions,
    :T => inv_ts,
)


# ╔═╡ 464ce3ea-cbb8-4fe0-8a95-364d1cfe769f
inv_model = EnergyModelsGeography.create_model(inv_case, modeltype_inv)

# ╔═╡ ac5caf5c-8c0e-4ca7-8429-d625dc03f375
set_optimizer(inv_model, HiGHS.Optimizer)

# ╔═╡ 80c313ba-37e4-4cc2-9ac4-97e6b3edd61b
optimize!(inv_model)

# ╔═╡ 0a1af73a-98d4-4f81-baa0-d77bf84f006a
function model_results(model, variable = :flow_in; filter_resource = nothing)
    headers = Dict(
        :cap_add => [:node, :period, :cap_add],
        :trans_cap_invest_b => [:transmission, :period, :invest],
        :trans_cap_add => [:transmission, :period, :cap_add],
        :flow_out => [:node, :period, :resource, :flow_out],
        :flow_in => [:node, :period, :resource, :flow_in],
        :sink_deficit => [:node, :period, :deficit],
        :emissions_total => [:period, :resource, :emissions],
        :emissions_node => [:node, :period, :resource, :emissions],
    )
    if haskey(headers, variable)
        h = headers[variable]
        df = DataFrame(JuMP.Containers.rowtable(value, model[variable]; header = h))
        if :period in h
            sort!(df, :period)
        end
        if !isnothing(filter_resource)
            df = df[map(x -> contains(filter_resource, x.id), df.resource), :]
        end
        return df
    else
        return DataFrame(JuMP.Containers.rowtable(value, model[variable]))
    end
end

# ╔═╡ ca4ee06a-5ce0-4925-b763-bc92a6175529
model_results(model, :flow_in)

# ╔═╡ 2d609131-dcf1-4366-9778-cb21e73cac09
model_results(model, :sink_deficit)

# ╔═╡ a4e6afbe-df91-4293-89ac-ad0185c285e8
model_results(model, :emissions_total)

# ╔═╡ 9e8348d0-26e0-4053-836b-99828da0b614
model_results(model, :emissions_node)

# ╔═╡ 427dae10-74c2-422b-a400-1b37e176c21b
df_multiperiod = model_results(multiperiod_model, :flow_in)

# ╔═╡ 7a2d7d27-42ae-4dc8-94e5-886b33b8a4a5
plot_flow(df_multiperiod)

# ╔═╡ ccb91324-3886-43f5-8627-abf21fd6618d
model_results(multiperiod_model, :flow_in; filter_resource = "Power")

# ╔═╡ ac455ee7-839f-4095-9d55-328b74156d58
model_results(geo_model, :flow_out)

# ╔═╡ 13974fa0-b698-4b5b-8bf6-7a2c023cdb7c
model_results(geo_model, :flow_out; filter_resource = "Power")

# ╔═╡ 70aea58a-12f9-4f89-9154-9fc0e4c9328d
model_results(inv_model, :trans_cap_add)

# ╔═╡ 88f33cb3-22ff-450f-b553-ceb1d71bb81b
model_results(inv_model, :trans_cap_invest_b)

# ╔═╡ f7c8aa88-0a7f-4a7c-ba92-dd15ffaa84be
model_results(inv_model, :cap_add)

# ╔═╡ 82d96a2d-0503-441b-a9a7-c8b6338cdd6f
inv_flow_res = model_results(inv_model, :flow_out)

# ╔═╡ d7a01f8e-a687-469c-89b4-2a322d0359a7
plot_flow_node(inv_flow_res)

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
AlgebraOfGraphics = "cbdf2221-f076-402e-a563-3d30da359d67"
CairoMakie = "13f3f980-e62b-5c42-98c6-ff1f3baf88f0"
DataFrames = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
EnergyModelsBase = "5d7e687e-f956-46f3-9045-6f5a5fd49f50"
EnergyModelsGeography = "3f775d88-a4da-46c4-a2cc-aa9f16db6708"
EnergyModelsInvestments = "fca3f8eb-b383-437d-8e7b-aac76bb2004f"
EnergyModelsRenewableProducers = "b007c34f-ba52-4995-ba37-fffe79fbde35"
HiGHS = "87dc4568-4c63-4d18-b0c0-bb2238e4078b"
JuMP = "4076af6c-e467-56ae-b986-b466b2749572"
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
ShortCodes = "f62ebe17-55c5-4640-972f-b59c0dd11ccf"
TimeStruct = "f9ed5ce0-9f41-4eaa-96da-f38ab8df101c"

[compat]
AlgebraOfGraphics = "~0.8.11"
CairoMakie = "~0.12.12"
DataFrames = "~1.7.0"
EnergyModelsBase = "~0.9.0"
EnergyModelsGeography = "~0.11.0"
EnergyModelsInvestments = "~0.8.1"
EnergyModelsRenewableProducers = "~0.6.5"
HiGHS = "~1.14.0"
JuMP = "~1.23.2"
PlutoUI = "~0.7.61"
ShortCodes = "~0.3.6"
TimeStruct = "~0.9.2"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.11.3"
manifest_format = "2.0"
project_hash = "60b867d63602541ac8eb271dde21181e019a20be"

[[deps.AbstractFFTs]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "d92ad398961a3ed262d8bf04a1a2b8340f915fef"
uuid = "621f4979-c628-5d54-868e-fcf4e3e8185c"
version = "1.5.0"
weakdeps = ["ChainRulesCore", "Test"]

    [deps.AbstractFFTs.extensions]
    AbstractFFTsChainRulesCoreExt = "ChainRulesCore"
    AbstractFFTsTestExt = "Test"

[[deps.AbstractPlutoDingetjes]]
deps = ["Pkg"]
git-tree-sha1 = "6e1d2a35f2f90a4bc7c2ed98079b2ba09c35b83a"
uuid = "6e696c72-6542-2067-7265-42206c756150"
version = "1.3.2"

[[deps.AbstractTrees]]
git-tree-sha1 = "2d9c9a55f9c93e8887ad391fbae72f8ef55e1177"
uuid = "1520ce14-60c1-5f80-bbc7-55ef81b5835c"
version = "0.4.5"

[[deps.Accessors]]
deps = ["CompositionsBase", "ConstructionBase", "Dates", "InverseFunctions", "MacroTools"]
git-tree-sha1 = "3b86719127f50670efe356bc11073d84b4ed7a5d"
uuid = "7d9f7c33-5ae7-4f3b-8dc6-eff91059b697"
version = "0.1.42"

    [deps.Accessors.extensions]
    AxisKeysExt = "AxisKeys"
    IntervalSetsExt = "IntervalSets"
    LinearAlgebraExt = "LinearAlgebra"
    StaticArraysExt = "StaticArrays"
    StructArraysExt = "StructArrays"
    TestExt = "Test"
    UnitfulExt = "Unitful"

    [deps.Accessors.weakdeps]
    AxisKeys = "94b1ba4f-4ee9-5380-92f1-94cde586c3c5"
    IntervalSets = "8197267c-284f-5f27-9208-e0e47529a953"
    LinearAlgebra = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"
    StaticArrays = "90137ffa-7385-5640-81b9-e52037218182"
    StructArrays = "09ab397b-f2b6-538f-b94a-2f83cf4a842a"
    Test = "8dfed614-e22c-5e08-85e1-65c5234f0b40"
    Unitful = "1986cc42-f94f-5a68-af5c-568840ba703d"

[[deps.Adapt]]
deps = ["LinearAlgebra", "Requires"]
git-tree-sha1 = "cd8b948862abee8f3d3e9b73a102a9ca924debb0"
uuid = "79e6a3ab-5dfb-504d-930d-738a2a938a0e"
version = "4.2.0"
weakdeps = ["SparseArrays", "StaticArrays"]

    [deps.Adapt.extensions]
    AdaptSparseArraysExt = "SparseArrays"
    AdaptStaticArraysExt = "StaticArrays"

[[deps.AdaptivePredicates]]
git-tree-sha1 = "7e651ea8d262d2d74ce75fdf47c4d63c07dba7a6"
uuid = "35492f91-a3bd-45ad-95db-fcad7dcfedb7"
version = "1.2.0"

[[deps.AlgebraOfGraphics]]
deps = ["Accessors", "Colors", "Dates", "Dictionaries", "FileIO", "GLM", "GeoInterface", "GeometryBasics", "GridLayoutBase", "Isoband", "KernelDensity", "Loess", "Makie", "NaturalSort", "PlotUtils", "PolygonOps", "PooledArrays", "PrecompileTools", "RelocatableFolders", "StatsBase", "StructArrays", "Tables"]
git-tree-sha1 = "ad7d27bb258200fde0f8e9a7df5802dc5cda1d26"
uuid = "cbdf2221-f076-402e-a563-3d30da359d67"
version = "0.8.14"

[[deps.AliasTables]]
deps = ["PtrArrays", "Random"]
git-tree-sha1 = "9876e1e164b144ca45e9e3198d0b689cadfed9ff"
uuid = "66dad0bd-aa9a-41b7-9441-69ab47430ed8"
version = "1.1.3"

[[deps.Animations]]
deps = ["Colors"]
git-tree-sha1 = "e092fa223bf66a3c41f9c022bd074d916dc303e7"
uuid = "27a7e980-b3e6-11e9-2bcd-0b925532e340"
version = "0.4.2"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"
version = "1.1.2"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"
version = "1.11.0"

[[deps.Automa]]
deps = ["PrecompileTools", "SIMD", "TranscodingStreams"]
git-tree-sha1 = "a8f503e8e1a5f583fbef15a8440c8c7e32185df2"
uuid = "67c07d97-cdcb-5c2c-af73-a7f9c32a568b"
version = "1.1.0"

[[deps.AxisAlgorithms]]
deps = ["LinearAlgebra", "Random", "SparseArrays", "WoodburyMatrices"]
git-tree-sha1 = "01b8ccb13d68535d73d2b0c23e39bd23155fb712"
uuid = "13072b0f-2c55-5437-9ae7-d433b7a33950"
version = "1.1.0"

[[deps.AxisArrays]]
deps = ["Dates", "IntervalSets", "IterTools", "RangeArrays"]
git-tree-sha1 = "16351be62963a67ac4083f748fdb3cca58bfd52f"
uuid = "39de3d68-74b9-583c-8d2d-e117c070f3a9"
version = "0.4.7"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"
version = "1.11.0"

[[deps.BenchmarkTools]]
deps = ["Compat", "JSON", "Logging", "Printf", "Profile", "Statistics", "UUIDs"]
git-tree-sha1 = "e38fbc49a620f5d0b660d7f543db1009fe0f8336"
uuid = "6e4b80f9-dd63-53aa-95a3-0cdb28fa8baf"
version = "1.6.0"

[[deps.Bzip2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "1b96ea4a01afe0ea4090c5c8039690672dd13f2e"
uuid = "6e34b625-4abd-537c-b88f-471c36dfa7a0"
version = "1.0.9+0"

[[deps.CEnum]]
git-tree-sha1 = "389ad5c84de1ae7cf0e28e381131c98ea87d54fc"
uuid = "fa961155-64e5-5f13-b03f-caf6b980ea82"
version = "0.5.0"

[[deps.CRC32c]]
uuid = "8bf52ea8-c179-5cab-976a-9e18b702a9bc"
version = "1.11.0"

[[deps.CRlibm_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "e329286945d0cfc04456972ea732551869af1cfc"
uuid = "4e9b3aee-d8a1-5a3d-ad8b-7d824db253f0"
version = "1.0.1+0"

[[deps.Cairo]]
deps = ["Cairo_jll", "Colors", "Glib_jll", "Graphics", "Libdl", "Pango_jll"]
git-tree-sha1 = "71aa551c5c33f1a4415867fe06b7844faadb0ae9"
uuid = "159f3aea-2a34-519c-b102-8c37f9878175"
version = "1.1.1"

[[deps.CairoMakie]]
deps = ["CRC32c", "Cairo", "Cairo_jll", "Colors", "FileIO", "FreeType", "GeometryBasics", "LinearAlgebra", "Makie", "PrecompileTools"]
git-tree-sha1 = "0afa2b4ac444b9412130d68493941e1af462e26a"
uuid = "13f3f980-e62b-5c42-98c6-ff1f3baf88f0"
version = "0.12.18"

[[deps.Cairo_jll]]
deps = ["Artifacts", "Bzip2_jll", "CompilerSupportLibraries_jll", "Fontconfig_jll", "FreeType2_jll", "Glib_jll", "JLLWrappers", "LZO_jll", "Libdl", "Pixman_jll", "Xorg_libXext_jll", "Xorg_libXrender_jll", "Zlib_jll", "libpng_jll"]
git-tree-sha1 = "009060c9a6168704143100f36ab08f06c2af4642"
uuid = "83423d85-b0ee-5818-9007-b63ccbeb887a"
version = "1.18.2+1"

[[deps.ChainRulesCore]]
deps = ["Compat", "LinearAlgebra"]
git-tree-sha1 = "1713c74e00545bfe14605d2a2be1712de8fbcb58"
uuid = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
version = "1.25.1"
weakdeps = ["SparseArrays"]

    [deps.ChainRulesCore.extensions]
    ChainRulesCoreSparseArraysExt = "SparseArrays"

[[deps.CodecBzip2]]
deps = ["Bzip2_jll", "TranscodingStreams"]
git-tree-sha1 = "84990fa864b7f2b4901901ca12736e45ee79068c"
uuid = "523fee87-0ab8-5b00-afb7-3ecf72e48cfd"
version = "0.8.5"

[[deps.CodecZlib]]
deps = ["TranscodingStreams", "Zlib_jll"]
git-tree-sha1 = "962834c22b66e32aa10f7611c08c8ca4e20749a9"
uuid = "944b1d66-785c-5afd-91f1-9de20f533193"
version = "0.7.8"

[[deps.ColorBrewer]]
deps = ["Colors", "JSON"]
git-tree-sha1 = "e771a63cc8b539eca78c85b0cabd9233d6c8f06f"
uuid = "a2cac450-b92f-5266-8821-25eda20663c8"
version = "0.4.1"

[[deps.ColorSchemes]]
deps = ["ColorTypes", "ColorVectorSpace", "Colors", "FixedPointNumbers", "PrecompileTools", "Random"]
git-tree-sha1 = "403f2d8e209681fcbd9468a8514efff3ea08452e"
uuid = "35d6a980-a343-548e-a6ea-1d62b119f2f4"
version = "3.29.0"

[[deps.ColorTypes]]
deps = ["FixedPointNumbers", "Random"]
git-tree-sha1 = "b10d0b65641d57b8b4d5e234446582de5047050d"
uuid = "3da002f7-5984-5a60-b8a6-cbb66c0b333f"
version = "0.11.5"

[[deps.ColorVectorSpace]]
deps = ["ColorTypes", "FixedPointNumbers", "LinearAlgebra", "Requires", "Statistics", "TensorCore"]
git-tree-sha1 = "a1f44953f2382ebb937d60dafbe2deea4bd23249"
uuid = "c3611d14-8923-5661-9e6a-0046d554d3a4"
version = "0.10.0"
weakdeps = ["SpecialFunctions"]

    [deps.ColorVectorSpace.extensions]
    SpecialFunctionsExt = "SpecialFunctions"

[[deps.Colors]]
deps = ["ColorTypes", "FixedPointNumbers", "Reexport"]
git-tree-sha1 = "64e15186f0aa277e174aa81798f7eb8598e0157e"
uuid = "5ae59095-9a9b-59fe-a467-6f913c188581"
version = "0.13.0"

[[deps.CommonSubexpressions]]
deps = ["MacroTools"]
git-tree-sha1 = "cda2cfaebb4be89c9084adaca7dd7333369715c5"
uuid = "bbf7d656-a473-5ed7-a52c-81e309532950"
version = "0.3.1"

[[deps.Compat]]
deps = ["TOML", "UUIDs"]
git-tree-sha1 = "8ae8d32e09f0dcf42a36b90d4e17f5dd2e4c4215"
uuid = "34da2185-b29b-5c13-b0c7-acf172513d20"
version = "4.16.0"
weakdeps = ["Dates", "LinearAlgebra"]

    [deps.Compat.extensions]
    CompatLinearAlgebraExt = "LinearAlgebra"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"
version = "1.1.1+0"

[[deps.CompositionsBase]]
git-tree-sha1 = "802bb88cd69dfd1509f6670416bd4434015693ad"
uuid = "a33af91c-f02d-484b-be07-31d278c5ca2b"
version = "0.1.2"
weakdeps = ["InverseFunctions"]

    [deps.CompositionsBase.extensions]
    CompositionsBaseInverseFunctionsExt = "InverseFunctions"

[[deps.ConstructionBase]]
git-tree-sha1 = "76219f1ed5771adbb096743bff43fb5fdd4c1157"
uuid = "187b0558-2788-49d3-abe0-74a17ed4e7c9"
version = "1.5.8"
weakdeps = ["IntervalSets", "LinearAlgebra", "StaticArrays"]

    [deps.ConstructionBase.extensions]
    ConstructionBaseIntervalSetsExt = "IntervalSets"
    ConstructionBaseLinearAlgebraExt = "LinearAlgebra"
    ConstructionBaseStaticArraysExt = "StaticArrays"

[[deps.Contour]]
git-tree-sha1 = "439e35b0b36e2e5881738abc8857bd92ad6ff9a8"
uuid = "d38c429a-6771-53c6-b99e-75d170b6e991"
version = "0.6.3"

[[deps.Crayons]]
git-tree-sha1 = "249fe38abf76d48563e2f4556bebd215aa317e15"
uuid = "a8cc5b0e-0ffa-5ad4-8c14-923d3ee1735f"
version = "4.1.1"

[[deps.DataAPI]]
git-tree-sha1 = "abe83f3a2f1b857aac70ef8b269080af17764bbe"
uuid = "9a962f9c-6df0-11e9-0e5d-c546b8b5ee8a"
version = "1.16.0"

[[deps.DataFrames]]
deps = ["Compat", "DataAPI", "DataStructures", "Future", "InlineStrings", "InvertedIndices", "IteratorInterfaceExtensions", "LinearAlgebra", "Markdown", "Missings", "PooledArrays", "PrecompileTools", "PrettyTables", "Printf", "Random", "Reexport", "SentinelArrays", "SortingAlgorithms", "Statistics", "TableTraits", "Tables", "Unicode"]
git-tree-sha1 = "fb61b4812c49343d7ef0b533ba982c46021938a6"
uuid = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
version = "1.7.0"

[[deps.DataStructures]]
deps = ["Compat", "InteractiveUtils", "OrderedCollections"]
git-tree-sha1 = "1d0a14036acb104d9e89698bd408f63ab58cdc82"
uuid = "864edb3b-99cc-5e75-8d2d-829cb0a9cfe8"
version = "0.18.20"

[[deps.DataValueInterfaces]]
git-tree-sha1 = "bfc1187b79289637fa0ef6d4436ebdfe6905cbd6"
uuid = "e2d170a0-9d28-54be-80f0-106bbe20a464"
version = "1.0.0"

[[deps.Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"
version = "1.11.0"

[[deps.DelaunayTriangulation]]
deps = ["AdaptivePredicates", "EnumX", "ExactPredicates", "Random"]
git-tree-sha1 = "5620ff4ee0084a6ab7097a27ba0c19290200b037"
uuid = "927a84f5-c5f4-47a5-9785-b46e178433df"
version = "1.6.4"

[[deps.Dictionaries]]
deps = ["Indexing", "Random", "Serialization"]
git-tree-sha1 = "1cdab237b6e0d0960d5dcbd2c0ebfa15fa6573d9"
uuid = "85a47980-9c8c-11e8-2b9f-f7ca1fa99fb4"
version = "0.4.4"

[[deps.DiffResults]]
deps = ["StaticArraysCore"]
git-tree-sha1 = "782dd5f4561f5d267313f23853baaaa4c52ea621"
uuid = "163ba53b-c6d8-5494-b064-1a9d43ac40c5"
version = "1.1.0"

[[deps.DiffRules]]
deps = ["IrrationalConstants", "LogExpFunctions", "NaNMath", "Random", "SpecialFunctions"]
git-tree-sha1 = "23163d55f885173722d1e4cf0f6110cdbaf7e272"
uuid = "b552c78f-8df3-52c6-915a-8e097449b14b"
version = "1.15.1"

[[deps.Distances]]
deps = ["LinearAlgebra", "Statistics", "StatsAPI"]
git-tree-sha1 = "c7e3a542b999843086e2f29dac96a618c105be1d"
uuid = "b4f34e82-e78d-54a5-968a-f98e89d6e8f7"
version = "0.10.12"
weakdeps = ["ChainRulesCore", "SparseArrays"]

    [deps.Distances.extensions]
    DistancesChainRulesCoreExt = "ChainRulesCore"
    DistancesSparseArraysExt = "SparseArrays"

[[deps.Distributed]]
deps = ["Random", "Serialization", "Sockets"]
uuid = "8ba89e20-285c-5b6f-9357-94700520ee1b"
version = "1.11.0"

[[deps.Distributions]]
deps = ["AliasTables", "FillArrays", "LinearAlgebra", "PDMats", "Printf", "QuadGK", "Random", "SpecialFunctions", "Statistics", "StatsAPI", "StatsBase", "StatsFuns"]
git-tree-sha1 = "03aa5d44647eaec98e1920635cdfed5d5560a8b9"
uuid = "31c24e10-a181-5473-b8eb-7969acd0382f"
version = "0.25.117"

    [deps.Distributions.extensions]
    DistributionsChainRulesCoreExt = "ChainRulesCore"
    DistributionsDensityInterfaceExt = "DensityInterface"
    DistributionsTestExt = "Test"

    [deps.Distributions.weakdeps]
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    DensityInterface = "b429d917-457f-4dbc-8f4c-0cc954292b1d"
    Test = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[[deps.DocStringExtensions]]
deps = ["LibGit2"]
git-tree-sha1 = "2fb1e02f2b635d0845df5d7c167fec4dd739b00d"
uuid = "ffbed154-4ef7-542d-bbb7-c09d3a79fcae"
version = "0.9.3"

[[deps.Downloads]]
deps = ["ArgTools", "FileWatching", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"
version = "1.6.0"

[[deps.EarCut_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "e3290f2d49e661fbd94046d7e3726ffcb2d41053"
uuid = "5ae413db-bbd1-5e63-b57d-d24a61df00f5"
version = "2.2.4+0"

[[deps.EnergyModelsBase]]
deps = ["JuMP", "SparseVariables", "TimeStruct"]
git-tree-sha1 = "61a24ddb03a8466d5e0832203752382849528a59"
uuid = "5d7e687e-f956-46f3-9045-6f5a5fd49f50"
version = "0.9.0"
weakdeps = ["EnergyModelsInvestments"]

    [deps.EnergyModelsBase.extensions]
    EMIExt = "EnergyModelsInvestments"

[[deps.EnergyModelsGeography]]
deps = ["EnergyModelsBase", "JuMP", "SparseVariables", "TimeStruct"]
git-tree-sha1 = "e7c3c22b39e383a9ca493240e85af53754d807e3"
uuid = "3f775d88-a4da-46c4-a2cc-aa9f16db6708"
version = "0.11.0"
weakdeps = ["EnergyModelsInvestments"]

    [deps.EnergyModelsGeography.extensions]
    EMIExt = "EnergyModelsInvestments"

[[deps.EnergyModelsInvestments]]
deps = ["JuMP", "SparseVariables", "TimeStruct"]
git-tree-sha1 = "105beadc4236dc06f4ea71f8877bc70cf5126d02"
uuid = "fca3f8eb-b383-437d-8e7b-aac76bb2004f"
version = "0.8.1"

[[deps.EnergyModelsRenewableProducers]]
deps = ["EnergyModelsBase", "JuMP", "TimeStruct"]
git-tree-sha1 = "b01efc8f188d172669f7a2cb59cd2f9aa1f28589"
uuid = "b007c34f-ba52-4995-ba37-fffe79fbde35"
version = "0.6.5"
weakdeps = ["EnergyModelsInvestments"]

    [deps.EnergyModelsRenewableProducers.extensions]
    EMIExt = "EnergyModelsInvestments"

[[deps.EnumX]]
git-tree-sha1 = "bdb1942cd4c45e3c678fd11569d5cccd80976237"
uuid = "4e289a0a-7415-4d19-859d-a7e5c4648b56"
version = "1.0.4"

[[deps.ExactPredicates]]
deps = ["IntervalArithmetic", "Random", "StaticArrays"]
git-tree-sha1 = "b3f2ff58735b5f024c392fde763f29b057e4b025"
uuid = "429591f6-91af-11e9-00e2-59fbe8cec110"
version = "2.2.8"

[[deps.Expat_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "d55dffd9ae73ff72f1c0482454dcf2ec6c6c4a63"
uuid = "2e619515-83b5-522b-bb60-26c02a35a201"
version = "2.6.5+0"

[[deps.ExprTools]]
git-tree-sha1 = "27415f162e6028e81c72b82ef756bf321213b6ec"
uuid = "e2ba6199-217a-4e67-a87a-7c52f15ade04"
version = "0.1.10"

[[deps.Extents]]
git-tree-sha1 = "063512a13dbe9c40d999c439268539aa552d1ae6"
uuid = "411431e0-e8b7-467b-b5e0-f676ba4f2910"
version = "0.1.5"

[[deps.FFMPEG_jll]]
deps = ["Artifacts", "Bzip2_jll", "FreeType2_jll", "FriBidi_jll", "JLLWrappers", "LAME_jll", "Libdl", "Ogg_jll", "OpenSSL_jll", "Opus_jll", "PCRE2_jll", "Zlib_jll", "libaom_jll", "libass_jll", "libfdk_aac_jll", "libvorbis_jll", "x264_jll", "x265_jll"]
git-tree-sha1 = "8cc47f299902e13f90405ddb5bf87e5d474c0d38"
uuid = "b22a6f82-2f65-5046-a5b2-351ab43fb4e5"
version = "6.1.2+0"

[[deps.FFTW]]
deps = ["AbstractFFTs", "FFTW_jll", "LinearAlgebra", "MKL_jll", "Preferences", "Reexport"]
git-tree-sha1 = "7de7c78d681078f027389e067864a8d53bd7c3c9"
uuid = "7a1cc6ca-52ef-59f5-83cd-3a7055c09341"
version = "1.8.1"

[[deps.FFTW_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "4d81ed14783ec49ce9f2e168208a12ce1815aa25"
uuid = "f5851436-0d7a-5f13-b9de-f02708fd171a"
version = "3.3.10+3"

[[deps.FileIO]]
deps = ["Pkg", "Requires", "UUIDs"]
git-tree-sha1 = "b66970a70db13f45b7e57fbda1736e1cf72174ea"
uuid = "5789e2e9-d7fb-5bc7-8068-2c6fae9b9549"
version = "1.17.0"

    [deps.FileIO.extensions]
    HTTPExt = "HTTP"

    [deps.FileIO.weakdeps]
    HTTP = "cd3eb016-35fb-5094-929b-558a96fad6f3"

[[deps.FilePaths]]
deps = ["FilePathsBase", "MacroTools", "Reexport", "Requires"]
git-tree-sha1 = "919d9412dbf53a2e6fe74af62a73ceed0bce0629"
uuid = "8fc22ac5-c921-52a6-82fd-178b2807b824"
version = "0.8.3"

[[deps.FilePathsBase]]
deps = ["Compat", "Dates"]
git-tree-sha1 = "2ec417fc319faa2d768621085cc1feebbdee686b"
uuid = "48062228-2e41-5def-b9a4-89aafe57970f"
version = "0.9.23"
weakdeps = ["Mmap", "Test"]

    [deps.FilePathsBase.extensions]
    FilePathsBaseMmapExt = "Mmap"
    FilePathsBaseTestExt = "Test"

[[deps.FileWatching]]
uuid = "7b1f6079-737a-58dc-b8bc-7a2ca5c1b5ee"
version = "1.11.0"

[[deps.FillArrays]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "6a70198746448456524cb442b8af316927ff3e1a"
uuid = "1a297f60-69ca-5386-bcde-b61e274b549b"
version = "1.13.0"
weakdeps = ["PDMats", "SparseArrays", "Statistics"]

    [deps.FillArrays.extensions]
    FillArraysPDMatsExt = "PDMats"
    FillArraysSparseArraysExt = "SparseArrays"
    FillArraysStatisticsExt = "Statistics"

[[deps.FixedPointNumbers]]
deps = ["Statistics"]
git-tree-sha1 = "05882d6995ae5c12bb5f36dd2ed3f61c98cbb172"
uuid = "53c48c17-4a7d-5ca2-90c5-79b7896eea93"
version = "0.8.5"

[[deps.Fontconfig_jll]]
deps = ["Artifacts", "Bzip2_jll", "Expat_jll", "FreeType2_jll", "JLLWrappers", "Libdl", "Libuuid_jll", "Zlib_jll"]
git-tree-sha1 = "21fac3c77d7b5a9fc03b0ec503aa1a6392c34d2b"
uuid = "a3f928ae-7b40-5064-980b-68af3947d34b"
version = "2.15.0+0"

[[deps.Format]]
git-tree-sha1 = "9c68794ef81b08086aeb32eeaf33531668d5f5fc"
uuid = "1fa38f19-a742-5d3f-a2b9-30dd87b9d5f8"
version = "1.3.7"

[[deps.ForwardDiff]]
deps = ["CommonSubexpressions", "DiffResults", "DiffRules", "LinearAlgebra", "LogExpFunctions", "NaNMath", "Preferences", "Printf", "Random", "SpecialFunctions"]
git-tree-sha1 = "a2df1b776752e3f344e5116c06d75a10436ab853"
uuid = "f6369f11-7733-5829-9624-2563aa707210"
version = "0.10.38"
weakdeps = ["StaticArrays"]

    [deps.ForwardDiff.extensions]
    ForwardDiffStaticArraysExt = "StaticArrays"

[[deps.FreeType]]
deps = ["CEnum", "FreeType2_jll"]
git-tree-sha1 = "907369da0f8e80728ab49c1c7e09327bf0d6d999"
uuid = "b38be410-82b0-50bf-ab77-7b57e271db43"
version = "4.1.1"

[[deps.FreeType2_jll]]
deps = ["Artifacts", "Bzip2_jll", "JLLWrappers", "Libdl", "Zlib_jll"]
git-tree-sha1 = "786e968a8d2fb167f2e4880baba62e0e26bd8e4e"
uuid = "d7e528f0-a631-5988-bf34-fe36492bcfd7"
version = "2.13.3+1"

[[deps.FreeTypeAbstraction]]
deps = ["ColorVectorSpace", "Colors", "FreeType", "GeometryBasics"]
git-tree-sha1 = "d52e255138ac21be31fa633200b65e4e71d26802"
uuid = "663a7486-cb36-511b-a19d-713bb74d65c9"
version = "0.10.6"

[[deps.FriBidi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "846f7026a9decf3679419122b49f8a1fdb48d2d5"
uuid = "559328eb-81f9-559d-9380-de523a88c83c"
version = "1.0.16+0"

[[deps.Future]]
deps = ["Random"]
uuid = "9fa8497b-333b-5362-9e8d-4d0656e87820"
version = "1.11.0"

[[deps.GLM]]
deps = ["Distributions", "LinearAlgebra", "Printf", "Reexport", "SparseArrays", "SpecialFunctions", "Statistics", "StatsAPI", "StatsBase", "StatsFuns", "StatsModels"]
git-tree-sha1 = "273bd1cd30768a2fddfa3fd63bbc746ed7249e5f"
uuid = "38e38edf-8417-5370-95a0-9cbb8c7f171a"
version = "1.9.0"

[[deps.GeoFormatTypes]]
git-tree-sha1 = "8e233d5167e63d708d41f87597433f59a0f213fe"
uuid = "68eda718-8dee-11e9-39e7-89f7f65f511f"
version = "0.4.4"

[[deps.GeoInterface]]
deps = ["DataAPI", "Extents", "GeoFormatTypes"]
git-tree-sha1 = "294e99f19869d0b0cb71aef92f19d03649d028d5"
uuid = "cf35fbd7-0cd7-5166-be24-54bfbe79505f"
version = "1.4.1"

[[deps.GeometryBasics]]
deps = ["EarCut_jll", "Extents", "GeoInterface", "IterTools", "LinearAlgebra", "StaticArrays", "StructArrays", "Tables"]
git-tree-sha1 = "b62f2b2d76cee0d61a2ef2b3118cd2a3215d3134"
uuid = "5c1252a2-5f33-56bf-86c9-59e7332b4326"
version = "0.4.11"

[[deps.Gettext_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "Libiconv_jll", "Pkg", "XML2_jll"]
git-tree-sha1 = "9b02998aba7bf074d14de89f9d37ca24a1a0b046"
uuid = "78b55507-aeef-58d4-861c-77aaff3498b1"
version = "0.21.0+0"

[[deps.Giflib_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "6570366d757b50fabae9f4315ad74d2e40c0560a"
uuid = "59f7168a-df46-5410-90c8-f2779963d0ec"
version = "5.2.3+0"

[[deps.Glib_jll]]
deps = ["Artifacts", "Gettext_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Libiconv_jll", "Libmount_jll", "PCRE2_jll", "Zlib_jll"]
git-tree-sha1 = "b0036b392358c80d2d2124746c2bf3d48d457938"
uuid = "7746bdde-850d-59dc-9ae8-88ece973131d"
version = "2.82.4+0"

[[deps.Graphics]]
deps = ["Colors", "LinearAlgebra", "NaNMath"]
git-tree-sha1 = "a641238db938fff9b2f60d08ed9030387daf428c"
uuid = "a2bd30eb-e257-5431-a919-1863eab51364"
version = "1.1.3"

[[deps.Graphite2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "01979f9b37367603e2848ea225918a3b3861b606"
uuid = "3b182d85-2403-5c21-9c21-1e1f0cc25472"
version = "1.3.14+1"

[[deps.GridLayoutBase]]
deps = ["GeometryBasics", "InteractiveUtils", "Observables"]
git-tree-sha1 = "dc6bed05c15523624909b3953686c5f5ffa10adc"
uuid = "3955a311-db13-416c-9275-1d80ed98e5e9"
version = "0.11.1"

[[deps.Grisu]]
git-tree-sha1 = "53bb909d1151e57e2484c3d1b53e19552b887fb2"
uuid = "42e2da0e-8278-4e71-bc24-59509adca0fe"
version = "1.0.2"

[[deps.HarfBuzz_jll]]
deps = ["Artifacts", "Cairo_jll", "Fontconfig_jll", "FreeType2_jll", "Glib_jll", "Graphite2_jll", "JLLWrappers", "Libdl", "Libffi_jll"]
git-tree-sha1 = "55c53be97790242c29031e5cd45e8ac296dadda3"
uuid = "2e76f6c2-a576-52d4-95c1-20adfe4de566"
version = "8.5.0+0"

[[deps.HiGHS]]
deps = ["HiGHS_jll", "MathOptInterface", "PrecompileTools", "SparseArrays"]
git-tree-sha1 = "0938730463f925e04a52c82335b78ff1209b29e8"
uuid = "87dc4568-4c63-4d18-b0c0-bb2238e4078b"
version = "1.14.0"

[[deps.HiGHS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "Zlib_jll"]
git-tree-sha1 = "26694f04567e584b054b9f33a810cec52adafa38"
uuid = "8fd58aa0-07eb-5a78-9b36-339c94fd15ea"
version = "1.9.0+0"

[[deps.HypergeometricFunctions]]
deps = ["LinearAlgebra", "OpenLibm_jll", "SpecialFunctions"]
git-tree-sha1 = "2bd56245074fab4015b9174f24ceba8293209053"
uuid = "34004b35-14d8-5ef3-9330-4cdb6864b03a"
version = "0.3.27"

[[deps.Hyperscript]]
deps = ["Test"]
git-tree-sha1 = "179267cfa5e712760cd43dcae385d7ea90cc25a4"
uuid = "47d2ed2b-36de-50cf-bf87-49c2cf4b8b91"
version = "0.0.5"

[[deps.HypertextLiteral]]
deps = ["Tricks"]
git-tree-sha1 = "7134810b1afce04bbc1045ca1985fbe81ce17653"
uuid = "ac1192a8-f4b3-4bfe-ba22-af5b92cd3ab2"
version = "0.9.5"

[[deps.IOCapture]]
deps = ["Logging", "Random"]
git-tree-sha1 = "b6d6bfdd7ce25b0f9b2f6b3dd56b2673a66c8770"
uuid = "b5f81e59-6552-4d32-b1f0-c071b021bf89"
version = "0.2.5"

[[deps.ImageAxes]]
deps = ["AxisArrays", "ImageBase", "ImageCore", "Reexport", "SimpleTraits"]
git-tree-sha1 = "e12629406c6c4442539436581041d372d69c55ba"
uuid = "2803e5a7-5153-5ecf-9a86-9b4c37f5f5ac"
version = "0.6.12"

[[deps.ImageBase]]
deps = ["ImageCore", "Reexport"]
git-tree-sha1 = "eb49b82c172811fd2c86759fa0553a2221feb909"
uuid = "c817782e-172a-44cc-b673-b171935fbb9e"
version = "0.1.7"

[[deps.ImageCore]]
deps = ["ColorVectorSpace", "Colors", "FixedPointNumbers", "MappedArrays", "MosaicViews", "OffsetArrays", "PaddedViews", "PrecompileTools", "Reexport"]
git-tree-sha1 = "8c193230235bbcee22c8066b0374f63b5683c2d3"
uuid = "a09fc81d-aa75-5fe9-8630-4744c3626534"
version = "0.10.5"

[[deps.ImageIO]]
deps = ["FileIO", "IndirectArrays", "JpegTurbo", "LazyModules", "Netpbm", "OpenEXR", "PNGFiles", "QOI", "Sixel", "TiffImages", "UUIDs", "WebP"]
git-tree-sha1 = "696144904b76e1ca433b886b4e7edd067d76cbf7"
uuid = "82e4d734-157c-48bb-816b-45c225c6df19"
version = "0.6.9"

[[deps.ImageMetadata]]
deps = ["AxisArrays", "ImageAxes", "ImageBase", "ImageCore"]
git-tree-sha1 = "2a81c3897be6fbcde0802a0ebe6796d0562f63ec"
uuid = "bc367c6b-8a6b-528e-b4bd-a4b897500b49"
version = "0.9.10"

[[deps.Imath_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "0936ba688c6d201805a83da835b55c61a180db52"
uuid = "905a6f67-0a94-5f89-b386-d35d92009cd1"
version = "3.1.11+0"

[[deps.Indexing]]
git-tree-sha1 = "ce1566720fd6b19ff3411404d4b977acd4814f9f"
uuid = "313cdc1a-70c2-5d6a-ae34-0150d3930a38"
version = "1.1.1"

[[deps.IndirectArrays]]
git-tree-sha1 = "012e604e1c7458645cb8b436f8fba789a51b257f"
uuid = "9b13fd28-a010-5f03-acff-a1bbcff69959"
version = "1.0.0"

[[deps.Inflate]]
git-tree-sha1 = "d1b1b796e47d94588b3757fe84fbf65a5ec4a80d"
uuid = "d25df0c9-e2be-5dd7-82c8-3ad0b3e990b9"
version = "0.1.5"

[[deps.InlineStrings]]
git-tree-sha1 = "6a9fde685a7ac1eb3495f8e812c5a7c3711c2d5e"
uuid = "842dd82b-1e85-43dc-bf29-5d0ee9dffc48"
version = "1.4.3"

    [deps.InlineStrings.extensions]
    ArrowTypesExt = "ArrowTypes"
    ParsersExt = "Parsers"

    [deps.InlineStrings.weakdeps]
    ArrowTypes = "31f734f8-188a-4ce0-8406-c8a06bd891cd"
    Parsers = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"

[[deps.IntelOpenMP_jll]]
deps = ["Artifacts", "JLLWrappers", "LazyArtifacts", "Libdl"]
git-tree-sha1 = "0f14a5456bdc6b9731a5682f439a672750a09e48"
uuid = "1d5cc7b8-4909-519e-a0f8-d0f5ad9712d0"
version = "2025.0.4+0"

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"
version = "1.11.0"

[[deps.Interpolations]]
deps = ["Adapt", "AxisAlgorithms", "ChainRulesCore", "LinearAlgebra", "OffsetArrays", "Random", "Ratios", "Requires", "SharedArrays", "SparseArrays", "StaticArrays", "WoodburyMatrices"]
git-tree-sha1 = "88a101217d7cb38a7b481ccd50d21876e1d1b0e0"
uuid = "a98d9a8b-a2ab-59e6-89dd-64a1c18fca59"
version = "0.15.1"
weakdeps = ["Unitful"]

    [deps.Interpolations.extensions]
    InterpolationsUnitfulExt = "Unitful"

[[deps.IntervalArithmetic]]
deps = ["CRlibm_jll", "LinearAlgebra", "MacroTools", "RoundingEmulator"]
git-tree-sha1 = "0fcf2079f918f68c6412cab5f2679822cbd7357f"
uuid = "d1acc4aa-44c8-5952-acd4-ba5d80a2a253"
version = "0.22.23"

    [deps.IntervalArithmetic.extensions]
    IntervalArithmeticDiffRulesExt = "DiffRules"
    IntervalArithmeticForwardDiffExt = "ForwardDiff"
    IntervalArithmeticIntervalSetsExt = "IntervalSets"
    IntervalArithmeticRecipesBaseExt = "RecipesBase"

    [deps.IntervalArithmetic.weakdeps]
    DiffRules = "b552c78f-8df3-52c6-915a-8e097449b14b"
    ForwardDiff = "f6369f11-7733-5829-9624-2563aa707210"
    IntervalSets = "8197267c-284f-5f27-9208-e0e47529a953"
    RecipesBase = "3cdcf5f2-1ef4-517c-9805-6587b60abb01"

[[deps.IntervalSets]]
git-tree-sha1 = "dba9ddf07f77f60450fe5d2e2beb9854d9a49bd0"
uuid = "8197267c-284f-5f27-9208-e0e47529a953"
version = "0.7.10"

    [deps.IntervalSets.extensions]
    IntervalSetsRandomExt = "Random"
    IntervalSetsRecipesBaseExt = "RecipesBase"
    IntervalSetsStatisticsExt = "Statistics"

    [deps.IntervalSets.weakdeps]
    Random = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"
    RecipesBase = "3cdcf5f2-1ef4-517c-9805-6587b60abb01"
    Statistics = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"

[[deps.InverseFunctions]]
git-tree-sha1 = "a779299d77cd080bf77b97535acecd73e1c5e5cb"
uuid = "3587e190-3f89-42d0-90ee-14403ec27112"
version = "0.1.17"
weakdeps = ["Dates", "Test"]

    [deps.InverseFunctions.extensions]
    InverseFunctionsDatesExt = "Dates"
    InverseFunctionsTestExt = "Test"

[[deps.InvertedIndices]]
git-tree-sha1 = "6da3c4316095de0f5ee2ebd875df8721e7e0bdbe"
uuid = "41ab1584-1d38-5bbf-9106-f11c6c58b48f"
version = "1.3.1"

[[deps.IrrationalConstants]]
git-tree-sha1 = "e2222959fbc6c19554dc15174c81bf7bf3aa691c"
uuid = "92d709cd-6900-40b7-9082-c6be49f344b6"
version = "0.2.4"

[[deps.Isoband]]
deps = ["isoband_jll"]
git-tree-sha1 = "f9b6d97355599074dc867318950adaa6f9946137"
uuid = "f1662d9f-8043-43de-a69a-05efc1cc6ff4"
version = "0.1.1"

[[deps.IterTools]]
git-tree-sha1 = "42d5f897009e7ff2cf88db414a389e5ed1bdd023"
uuid = "c8e1da08-722c-5040-9ed9-7db0dc04731e"
version = "1.10.0"

[[deps.IteratorInterfaceExtensions]]
git-tree-sha1 = "a3f24677c21f5bbe9d2a714f95dcd58337fb2856"
uuid = "82899510-4779-5014-852e-03e436cf321d"
version = "1.0.0"

[[deps.JLLWrappers]]
deps = ["Artifacts", "Preferences"]
git-tree-sha1 = "a007feb38b422fbdab534406aeca1b86823cb4d6"
uuid = "692b3bcd-3c85-4b1f-b108-f13ce0eb3210"
version = "1.7.0"

[[deps.JSON]]
deps = ["Dates", "Mmap", "Parsers", "Unicode"]
git-tree-sha1 = "31e996f0a15c7b280ba9f76636b3ff9e2ae58c9a"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "0.21.4"

[[deps.JSON3]]
deps = ["Dates", "Mmap", "Parsers", "PrecompileTools", "StructTypes", "UUIDs"]
git-tree-sha1 = "1d322381ef7b087548321d3f878cb4c9bd8f8f9b"
uuid = "0f8b85d8-7281-11e9-16c2-39a750bddbf1"
version = "1.14.1"

    [deps.JSON3.extensions]
    JSON3ArrowExt = ["ArrowTypes"]

    [deps.JSON3.weakdeps]
    ArrowTypes = "31f734f8-188a-4ce0-8406-c8a06bd891cd"

[[deps.JpegTurbo]]
deps = ["CEnum", "FileIO", "ImageCore", "JpegTurbo_jll", "TOML"]
git-tree-sha1 = "fa6d0bcff8583bac20f1ffa708c3913ca605c611"
uuid = "b835a17e-a41a-41e7-81f0-2f016b05efe0"
version = "0.1.5"

[[deps.JpegTurbo_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "eac1206917768cb54957c65a615460d87b455fc1"
uuid = "aacddb02-875f-59d6-b918-886e6ef4fbf8"
version = "3.1.1+0"

[[deps.JuMP]]
deps = ["LinearAlgebra", "MacroTools", "MathOptInterface", "MutableArithmetics", "OrderedCollections", "PrecompileTools", "Printf", "SparseArrays"]
git-tree-sha1 = "02b6e65736debc1f47b40b0f7d5dfa0217ee1f09"
uuid = "4076af6c-e467-56ae-b986-b466b2749572"
version = "1.23.6"

    [deps.JuMP.extensions]
    JuMPDimensionalDataExt = "DimensionalData"

    [deps.JuMP.weakdeps]
    DimensionalData = "0703355e-b756-11e9-17c0-8b28908087d0"

[[deps.KernelDensity]]
deps = ["Distributions", "DocStringExtensions", "FFTW", "Interpolations", "StatsBase"]
git-tree-sha1 = "7d703202e65efa1369de1279c162b915e245eed1"
uuid = "5ab0869b-81aa-558d-bb23-cbf5423bbe9b"
version = "0.6.9"

[[deps.LAME_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "170b660facf5df5de098d866564877e119141cbd"
uuid = "c1c5ebd0-6772-5130-a774-d5fcae4a789d"
version = "3.100.2+0"

[[deps.LERC_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "aaafe88dccbd957a8d82f7d05be9b69172e0cee3"
uuid = "88015f11-f218-50d7-93a8-a6af411a945d"
version = "4.0.1+0"

[[deps.LLVMOpenMP_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "78211fb6cbc872f77cad3fc0b6cf647d923f4929"
uuid = "1d63c593-3942-5779-bab2-d838dc0a180e"
version = "18.1.7+0"

[[deps.LZO_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "1c602b1127f4751facb671441ca72715cc95938a"
uuid = "dd4b983a-f0e5-5f8d-a1b7-129d4a5fb1ac"
version = "2.10.3+0"

[[deps.LaTeXStrings]]
git-tree-sha1 = "dda21b8cbd6a6c40d9d02a73230f9d70fed6918c"
uuid = "b964fa9f-0449-5b57-a5c2-d3ea65f4040f"
version = "1.4.0"

[[deps.LazyArtifacts]]
deps = ["Artifacts", "Pkg"]
uuid = "4af54fe1-eca0-43a8-85a7-787d91b784e3"
version = "1.11.0"

[[deps.LazyModules]]
git-tree-sha1 = "a560dd966b386ac9ae60bdd3a3d3a326062d3c3e"
uuid = "8cdb02fc-e678-4876-92c5-9defec4f444e"
version = "0.3.1"

[[deps.LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"
version = "0.6.4"

[[deps.LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"
version = "8.6.0+0"

[[deps.LibGit2]]
deps = ["Base64", "LibGit2_jll", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"
version = "1.11.0"

[[deps.LibGit2_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll"]
uuid = "e37daf67-58a4-590a-8e99-b0245dd2ffc5"
version = "1.7.2+0"

[[deps.LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "MbedTLS_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"
version = "1.11.0+1"

[[deps.Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"
version = "1.11.0"

[[deps.Libffi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "27ecae93dd25ee0909666e6835051dd684cc035e"
uuid = "e9f186c6-92d2-5b65-8a66-fee21dc1b490"
version = "3.2.2+2"

[[deps.Libgcrypt_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libgpg_error_jll"]
git-tree-sha1 = "8be878062e0ffa2c3f67bb58a595375eda5de80b"
uuid = "d4300ac3-e22c-5743-9152-c294e39db1e4"
version = "1.11.0+0"

[[deps.Libglvnd_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libX11_jll", "Xorg_libXext_jll"]
git-tree-sha1 = "ff3b4b9d35de638936a525ecd36e86a8bb919d11"
uuid = "7e76a0d4-f3c7-5321-8279-8d96eeed0f29"
version = "1.7.0+0"

[[deps.Libgpg_error_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "df37206100d39f79b3376afb6b9cee4970041c61"
uuid = "7add5ba3-2f88-524e-9cd5-f83b8a55f7b8"
version = "1.51.1+0"

[[deps.Libiconv_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "be484f5c92fad0bd8acfef35fe017900b0b73809"
uuid = "94ce4f54-9a6c-5748-9c1c-f9c7231a4531"
version = "1.18.0+0"

[[deps.Libmount_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "89211ea35d9df5831fca5d33552c02bd33878419"
uuid = "4b2f31a3-9ecc-558c-b454-b3730dcb73e9"
version = "2.40.3+0"

[[deps.Libtiff_jll]]
deps = ["Artifacts", "JLLWrappers", "JpegTurbo_jll", "LERC_jll", "Libdl", "XZ_jll", "Zlib_jll", "Zstd_jll"]
git-tree-sha1 = "4ab7581296671007fc33f07a721631b8855f4b1d"
uuid = "89763e89-9b03-5906-acba-b20f662cd828"
version = "4.7.1+0"

[[deps.Libuuid_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "e888ad02ce716b319e6bdb985d2ef300e7089889"
uuid = "38a345b3-de98-5d2b-a5d3-14cd9215e700"
version = "2.40.3+0"

[[deps.LinearAlgebra]]
deps = ["Libdl", "OpenBLAS_jll", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"
version = "1.11.0"

[[deps.Loess]]
deps = ["Distances", "LinearAlgebra", "Statistics", "StatsAPI"]
git-tree-sha1 = "f749e7351f120b3566e5923fefdf8e52ba5ec7f9"
uuid = "4345ca2d-374a-55d4-8d30-97f9976e7612"
version = "0.6.4"

[[deps.LogExpFunctions]]
deps = ["DocStringExtensions", "IrrationalConstants", "LinearAlgebra"]
git-tree-sha1 = "13ca9e2586b89836fd20cccf56e57e2b9ae7f38f"
uuid = "2ab3a3ac-af41-5b50-aa03-7779005ae688"
version = "0.3.29"

    [deps.LogExpFunctions.extensions]
    LogExpFunctionsChainRulesCoreExt = "ChainRulesCore"
    LogExpFunctionsChangesOfVariablesExt = "ChangesOfVariables"
    LogExpFunctionsInverseFunctionsExt = "InverseFunctions"

    [deps.LogExpFunctions.weakdeps]
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    ChangesOfVariables = "9e997f8a-9a97-42d5-a9f1-ce6bfc15e2c0"
    InverseFunctions = "3587e190-3f89-42d0-90ee-14403ec27112"

[[deps.Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"
version = "1.11.0"

[[deps.MIMEs]]
git-tree-sha1 = "1833212fd6f580c20d4291da9c1b4e8a655b128e"
uuid = "6c6e2e6c-3030-632d-7369-2d6c69616d65"
version = "1.0.0"

[[deps.MKL_jll]]
deps = ["Artifacts", "IntelOpenMP_jll", "JLLWrappers", "LazyArtifacts", "Libdl", "oneTBB_jll"]
git-tree-sha1 = "5de60bc6cb3899cd318d80d627560fae2e2d99ae"
uuid = "856f044c-d86e-5d09-b602-aeab76dc8ba7"
version = "2025.0.1+1"

[[deps.MacroTools]]
git-tree-sha1 = "72aebe0b5051e5143a079a4685a46da330a40472"
uuid = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"
version = "0.5.15"

[[deps.Makie]]
deps = ["Animations", "Base64", "CRC32c", "ColorBrewer", "ColorSchemes", "ColorTypes", "Colors", "Contour", "Dates", "DelaunayTriangulation", "Distributions", "DocStringExtensions", "Downloads", "FFMPEG_jll", "FileIO", "FilePaths", "FixedPointNumbers", "Format", "FreeType", "FreeTypeAbstraction", "GeometryBasics", "GridLayoutBase", "ImageBase", "ImageIO", "InteractiveUtils", "Interpolations", "IntervalSets", "InverseFunctions", "Isoband", "KernelDensity", "LaTeXStrings", "LinearAlgebra", "MacroTools", "MakieCore", "Markdown", "MathTeXEngine", "Observables", "OffsetArrays", "Packing", "PlotUtils", "PolygonOps", "PrecompileTools", "Printf", "REPL", "Random", "RelocatableFolders", "Scratch", "ShaderAbstractions", "Showoff", "SignedDistanceFields", "SparseArrays", "Statistics", "StatsBase", "StatsFuns", "StructArrays", "TriplotBase", "UnicodeFun", "Unitful"]
git-tree-sha1 = "be3051d08b78206fb5e688e8d70c9e84d0264117"
uuid = "ee78f7c6-11fb-53f2-987a-cfe4a2b5a57a"
version = "0.21.18"

[[deps.MakieCore]]
deps = ["ColorTypes", "GeometryBasics", "IntervalSets", "Observables"]
git-tree-sha1 = "9019b391d7d086e841cbeadc13511224bd029ab3"
uuid = "20f20a25-4f0e-4fdf-b5d1-57303727442b"
version = "0.8.12"

[[deps.MappedArrays]]
git-tree-sha1 = "2dab0221fe2b0f2cb6754eaa743cc266339f527e"
uuid = "dbb5928d-eab1-5f90-85c2-b9b0edb7c900"
version = "0.4.2"

[[deps.Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"
version = "1.11.0"

[[deps.MathOptInterface]]
deps = ["BenchmarkTools", "CodecBzip2", "CodecZlib", "DataStructures", "ForwardDiff", "JSON3", "LinearAlgebra", "MutableArithmetics", "NaNMath", "OrderedCollections", "PrecompileTools", "Printf", "SparseArrays", "SpecialFunctions", "Test"]
git-tree-sha1 = "b691a4b4c8ef7a4fba051d546040bfd2ae6f0719"
uuid = "b8f27783-ece8-5eb3-8dc8-9495eed66fee"
version = "1.37.2"

[[deps.MathTeXEngine]]
deps = ["AbstractTrees", "Automa", "DataStructures", "FreeTypeAbstraction", "GeometryBasics", "LaTeXStrings", "REPL", "RelocatableFolders", "UnicodeFun"]
git-tree-sha1 = "f45c8916e8385976e1ccd055c9874560c257ab13"
uuid = "0a4f8689-d25c-4efe-a92b-7142dfc1aa53"
version = "0.6.2"

[[deps.MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"
version = "2.28.6+0"

[[deps.Memoize]]
deps = ["MacroTools"]
git-tree-sha1 = "2b1dfcba103de714d31c033b5dacc2e4a12c7caa"
uuid = "c03570c3-d221-55d1-a50c-7939bbd78826"
version = "0.4.4"

[[deps.Missings]]
deps = ["DataAPI"]
git-tree-sha1 = "ec4f7fbeab05d7747bdf98eb74d130a2a2ed298d"
uuid = "e1d29d7a-bbdc-5cf2-9ac0-f12de2c33e28"
version = "1.2.0"

[[deps.Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"
version = "1.11.0"

[[deps.Mocking]]
deps = ["Compat", "ExprTools"]
git-tree-sha1 = "2c140d60d7cb82badf06d8783800d0bcd1a7daa2"
uuid = "78c3b35d-d492-501b-9361-3d52fe80e533"
version = "0.8.1"

[[deps.MosaicViews]]
deps = ["MappedArrays", "OffsetArrays", "PaddedViews", "StackViews"]
git-tree-sha1 = "7b86a5d4d70a9f5cdf2dacb3cbe6d251d1a61dbe"
uuid = "e94cdb99-869f-56ef-bcf0-1ae2bcbe0389"
version = "0.3.4"

[[deps.MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"
version = "2023.12.12"

[[deps.MutableArithmetics]]
deps = ["LinearAlgebra", "SparseArrays", "Test"]
git-tree-sha1 = "491bdcdc943fcbc4c005900d7463c9f216aabf4c"
uuid = "d8a4904e-b15c-11e9-3269-09a3773c0cb0"
version = "1.6.4"

[[deps.NaNMath]]
deps = ["OpenLibm_jll"]
git-tree-sha1 = "cc0a5deefdb12ab3a096f00a6d42133af4560d71"
uuid = "77ba4419-2d1f-58cd-9bb1-8ffee604a2e3"
version = "1.1.2"

[[deps.NaturalSort]]
git-tree-sha1 = "eda490d06b9f7c00752ee81cfa451efe55521e21"
uuid = "c020b1a1-e9b0-503a-9c33-f039bfc54a85"
version = "1.0.0"

[[deps.Netpbm]]
deps = ["FileIO", "ImageCore", "ImageMetadata"]
git-tree-sha1 = "d92b107dbb887293622df7697a2223f9f8176fcd"
uuid = "f09324ee-3d7c-5217-9330-fc30815ba969"
version = "1.1.1"

[[deps.NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"
version = "1.2.0"

[[deps.Observables]]
git-tree-sha1 = "7438a59546cf62428fc9d1bc94729146d37a7225"
uuid = "510215fc-4207-5dde-b226-833fc4488ee2"
version = "0.5.5"

[[deps.OffsetArrays]]
git-tree-sha1 = "5e1897147d1ff8d98883cda2be2187dcf57d8f0c"
uuid = "6fe1bfb0-de20-5000-8ca7-80f57d26f881"
version = "1.15.0"
weakdeps = ["Adapt"]

    [deps.OffsetArrays.extensions]
    OffsetArraysAdaptExt = "Adapt"

[[deps.Ogg_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "887579a3eb005446d514ab7aeac5d1d027658b8f"
uuid = "e7412a2a-1a6e-54c0-be00-318e2571c051"
version = "1.3.5+1"

[[deps.OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"
version = "0.3.27+1"

[[deps.OpenEXR]]
deps = ["Colors", "FileIO", "OpenEXR_jll"]
git-tree-sha1 = "97db9e07fe2091882c765380ef58ec553074e9c7"
uuid = "52e1d378-f018-4a11-a4be-720524705ac7"
version = "0.3.3"

[[deps.OpenEXR_jll]]
deps = ["Artifacts", "Imath_jll", "JLLWrappers", "Libdl", "Zlib_jll"]
git-tree-sha1 = "8292dd5c8a38257111ada2174000a33745b06d4e"
uuid = "18a262bb-aa17-5467-a713-aee519bc75cb"
version = "3.2.4+0"

[[deps.OpenLibm_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "05823500-19ac-5b8b-9628-191a04bc5112"
version = "0.8.1+2"

[[deps.OpenSSL_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "a9697f1d06cc3eb3fb3ad49cc67f2cfabaac31ea"
uuid = "458c3c95-2e84-50aa-8efc-19380b2a3a95"
version = "3.0.16+0"

[[deps.OpenSpecFun_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl"]
git-tree-sha1 = "1346c9208249809840c91b26703912dff463d335"
uuid = "efe28fd5-8261-553b-a9e1-b2916fc3738e"
version = "0.5.6+0"

[[deps.Opus_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "6703a85cb3781bd5909d48730a67205f3f31a575"
uuid = "91d4177d-7536-5919-b921-800302f37372"
version = "1.3.3+0"

[[deps.OrderedCollections]]
git-tree-sha1 = "cc4054e898b852042d7b503313f7ad03de99c3dd"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.8.0"

[[deps.PCRE2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "efcefdf7-47ab-520b-bdef-62a2eaa19f15"
version = "10.42.0+1"

[[deps.PDMats]]
deps = ["LinearAlgebra", "SparseArrays", "SuiteSparse"]
git-tree-sha1 = "966b85253e959ea89c53a9abebbf2e964fbf593b"
uuid = "90014a1f-27ba-587c-ab20-58faa44d9150"
version = "0.11.32"

[[deps.PNGFiles]]
deps = ["Base64", "CEnum", "ImageCore", "IndirectArrays", "OffsetArrays", "libpng_jll"]
git-tree-sha1 = "cf181f0b1e6a18dfeb0ee8acc4a9d1672499626c"
uuid = "f57f5aa1-a3ce-4bc8-8ab9-96f992907883"
version = "0.4.4"

[[deps.Packing]]
deps = ["GeometryBasics"]
git-tree-sha1 = "bc5bf2ea3d5351edf285a06b0016788a121ce92c"
uuid = "19eb6ba3-879d-56ad-ad62-d5c202156566"
version = "0.5.1"

[[deps.PaddedViews]]
deps = ["OffsetArrays"]
git-tree-sha1 = "0fac6313486baae819364c52b4f483450a9d793f"
uuid = "5432bcbf-9aad-5242-b902-cca2824c8663"
version = "0.5.12"

[[deps.Pango_jll]]
deps = ["Artifacts", "Cairo_jll", "Fontconfig_jll", "FreeType2_jll", "FriBidi_jll", "Glib_jll", "HarfBuzz_jll", "JLLWrappers", "Libdl"]
git-tree-sha1 = "3b31172c032a1def20c98dae3f2cdc9d10e3b561"
uuid = "36c8627f-9965-5494-a995-c6b170f724f3"
version = "1.56.1+0"

[[deps.Parsers]]
deps = ["Dates", "PrecompileTools", "UUIDs"]
git-tree-sha1 = "8489905bcdbcfac64d1daa51ca07c0d8f0283821"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.8.1"

[[deps.Pixman_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "LLVMOpenMP_jll", "Libdl"]
git-tree-sha1 = "35621f10a7531bc8fa58f74610b1bfb70a3cfc6b"
uuid = "30392449-352a-5448-841d-b1acce4e97dc"
version = "0.43.4+0"

[[deps.Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "FileWatching", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "Random", "SHA", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"
version = "1.11.0"
weakdeps = ["REPL"]

    [deps.Pkg.extensions]
    REPLExt = "REPL"

[[deps.PkgVersion]]
deps = ["Pkg"]
git-tree-sha1 = "f9501cc0430a26bc3d156ae1b5b0c1b47af4d6da"
uuid = "eebad327-c553-4316-9ea0-9fa01ccd7688"
version = "0.3.3"

[[deps.PlotUtils]]
deps = ["ColorSchemes", "Colors", "Dates", "PrecompileTools", "Printf", "Random", "Reexport", "StableRNGs", "Statistics"]
git-tree-sha1 = "3ca9a356cd2e113c420f2c13bea19f8d3fb1cb18"
uuid = "995b91a9-d308-5afd-9ec6-746e21dbc043"
version = "1.4.3"

[[deps.PlutoUI]]
deps = ["AbstractPlutoDingetjes", "Base64", "ColorTypes", "Dates", "FixedPointNumbers", "Hyperscript", "HypertextLiteral", "IOCapture", "InteractiveUtils", "JSON", "Logging", "MIMEs", "Markdown", "Random", "Reexport", "URIs", "UUIDs"]
git-tree-sha1 = "7e71a55b87222942f0f9337be62e26b1f103d3e4"
uuid = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
version = "0.7.61"

[[deps.PolygonOps]]
git-tree-sha1 = "77b3d3605fc1cd0b42d95eba87dfcd2bf67d5ff6"
uuid = "647866c9-e3ac-4575-94e7-e3d426903924"
version = "0.1.2"

[[deps.PooledArrays]]
deps = ["DataAPI", "Future"]
git-tree-sha1 = "36d8b4b899628fb92c2749eb488d884a926614d3"
uuid = "2dfb63ee-cc39-5dd5-95bd-886bf059d720"
version = "1.4.3"

[[deps.PrecompileTools]]
deps = ["Preferences"]
git-tree-sha1 = "5aa36f7049a63a1528fe8f7c3f2113413ffd4e1f"
uuid = "aea7be01-6a6a-4083-8856-8a6e6704d82a"
version = "1.2.1"

[[deps.Preferences]]
deps = ["TOML"]
git-tree-sha1 = "9306f6085165d270f7e3db02af26a400d580f5c6"
uuid = "21216c6a-2e73-6563-6e65-726566657250"
version = "1.4.3"

[[deps.PrettyTables]]
deps = ["Crayons", "LaTeXStrings", "Markdown", "PrecompileTools", "Printf", "Reexport", "StringManipulation", "Tables"]
git-tree-sha1 = "1101cd475833706e4d0e7b122218257178f48f34"
uuid = "08abe8d2-0d0c-5749-adfa-8a2ac140af0d"
version = "2.4.0"

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"
version = "1.11.0"

[[deps.Profile]]
uuid = "9abbd945-dff8-562f-b5e8-e1ebf5ef1b79"
version = "1.11.0"

[[deps.ProgressMeter]]
deps = ["Distributed", "Printf"]
git-tree-sha1 = "8f6bc219586aef8baf0ff9a5fe16ee9c70cb65e4"
uuid = "92933f4c-e287-5a05-a399-4b506db050ca"
version = "1.10.2"

[[deps.PtrArrays]]
git-tree-sha1 = "1d36ef11a9aaf1e8b74dacc6a731dd1de8fd493d"
uuid = "43287f4e-b6f4-7ad1-bb20-aadabca52c3d"
version = "1.3.0"

[[deps.QOI]]
deps = ["ColorTypes", "FileIO", "FixedPointNumbers"]
git-tree-sha1 = "8b3fc30bc0390abdce15f8822c889f669baed73d"
uuid = "4b34888f-f399-49d4-9bb3-47ed5cae4e65"
version = "1.0.1"

[[deps.QuadGK]]
deps = ["DataStructures", "LinearAlgebra"]
git-tree-sha1 = "9da16da70037ba9d701192e27befedefb91ec284"
uuid = "1fd47b50-473d-5c70-9696-f719f8f3bcdc"
version = "2.11.2"

    [deps.QuadGK.extensions]
    QuadGKEnzymeExt = "Enzyme"

    [deps.QuadGK.weakdeps]
    Enzyme = "7da242da-08ed-463a-9acd-ee780be4f1d9"

[[deps.REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "StyledStrings", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"
version = "1.11.0"

[[deps.Random]]
deps = ["SHA"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"
version = "1.11.0"

[[deps.RangeArrays]]
git-tree-sha1 = "b9039e93773ddcfc828f12aadf7115b4b4d225f5"
uuid = "b3c3ace0-ae52-54e7-9d0b-2c1406fd6b9d"
version = "0.3.2"

[[deps.Ratios]]
deps = ["Requires"]
git-tree-sha1 = "1342a47bf3260ee108163042310d26f2be5ec90b"
uuid = "c84ed2f1-dad5-54f0-aa8e-dbefe2724439"
version = "0.4.5"
weakdeps = ["FixedPointNumbers"]

    [deps.Ratios.extensions]
    RatiosFixedPointNumbersExt = "FixedPointNumbers"

[[deps.Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[deps.RelocatableFolders]]
deps = ["SHA", "Scratch"]
git-tree-sha1 = "ffdaf70d81cf6ff22c2b6e733c900c3321cab864"
uuid = "05181044-ff0b-4ac5-8273-598c1e38db00"
version = "1.0.1"

[[deps.Requires]]
deps = ["UUIDs"]
git-tree-sha1 = "62389eeff14780bfe55195b7204c0d8738436d64"
uuid = "ae029012-a4dd-5104-9daa-d747884805df"
version = "1.3.1"

[[deps.Rmath]]
deps = ["Random", "Rmath_jll"]
git-tree-sha1 = "852bd0f55565a9e973fcfee83a84413270224dc4"
uuid = "79098fc4-a85e-5d69-aa6a-4863f24498fa"
version = "0.8.0"

[[deps.Rmath_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "58cdd8fb2201a6267e1db87ff148dd6c1dbd8ad8"
uuid = "f50d1b31-88e8-58de-be2c-1cc44531875f"
version = "0.5.1+0"

[[deps.RoundingEmulator]]
git-tree-sha1 = "40b9edad2e5287e05bd413a38f61a8ff55b9557b"
uuid = "5eaf0fd0-dfba-4ccb-bf02-d820a40db705"
version = "0.2.1"

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"
version = "0.7.0"

[[deps.SIMD]]
deps = ["PrecompileTools"]
git-tree-sha1 = "fea870727142270bdf7624ad675901a1ee3b4c87"
uuid = "fdea26ae-647d-5447-a871-4b548cad5224"
version = "3.7.1"

[[deps.Scratch]]
deps = ["Dates"]
git-tree-sha1 = "3bac05bc7e74a75fd9cba4295cde4045d9fe2386"
uuid = "6c6a2e73-6563-6170-7368-637461726353"
version = "1.2.1"

[[deps.SentinelArrays]]
deps = ["Dates", "Random"]
git-tree-sha1 = "712fb0231ee6f9120e005ccd56297abbc053e7e0"
uuid = "91c51154-3ec4-41a3-a24f-3f23e20d615c"
version = "1.4.8"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"
version = "1.11.0"

[[deps.ShaderAbstractions]]
deps = ["ColorTypes", "FixedPointNumbers", "GeometryBasics", "LinearAlgebra", "Observables", "StaticArrays", "StructArrays", "Tables"]
git-tree-sha1 = "79123bc60c5507f035e6d1d9e563bb2971954ec8"
uuid = "65257c39-d410-5151-9873-9b3e5be5013e"
version = "0.4.1"

[[deps.SharedArrays]]
deps = ["Distributed", "Mmap", "Random", "Serialization"]
uuid = "1a1011a3-84de-559e-8e89-a11a2f7dc383"
version = "1.11.0"

[[deps.ShiftedArrays]]
git-tree-sha1 = "503688b59397b3307443af35cd953a13e8005c16"
uuid = "1277b4bf-5013-50f5-be3d-901d8477a67a"
version = "2.0.0"

[[deps.ShortCodes]]
deps = ["Base64", "CodecZlib", "Downloads", "JSON3", "Memoize", "URIs", "UUIDs"]
git-tree-sha1 = "5844ee60d9fd30a891d48bab77ac9e16791a0a57"
uuid = "f62ebe17-55c5-4640-972f-b59c0dd11ccf"
version = "0.3.6"

[[deps.Showoff]]
deps = ["Dates", "Grisu"]
git-tree-sha1 = "91eddf657aca81df9ae6ceb20b959ae5653ad1de"
uuid = "992d4aef-0814-514b-bc4d-f2e9a6c4116f"
version = "1.0.3"

[[deps.SignedDistanceFields]]
deps = ["Random", "Statistics", "Test"]
git-tree-sha1 = "d263a08ec505853a5ff1c1ebde2070419e3f28e9"
uuid = "73760f76-fbc4-59ce-8f25-708e95d2df96"
version = "0.4.0"

[[deps.SimpleTraits]]
deps = ["InteractiveUtils", "MacroTools"]
git-tree-sha1 = "5d7e3f4e11935503d3ecaf7186eac40602e7d231"
uuid = "699a6c99-e7fa-54fc-8d76-47d257e15c1d"
version = "0.9.4"

[[deps.Sixel]]
deps = ["Dates", "FileIO", "ImageCore", "IndirectArrays", "OffsetArrays", "REPL", "libsixel_jll"]
git-tree-sha1 = "2da10356e31327c7096832eb9cd86307a50b1eb6"
uuid = "45858cf5-a6b0-47a3-bbea-62219f50df47"
version = "0.1.3"

[[deps.Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"
version = "1.11.0"

[[deps.SortingAlgorithms]]
deps = ["DataStructures"]
git-tree-sha1 = "66e0a8e672a0bdfca2c3f5937efb8538b9ddc085"
uuid = "a2af1166-a08f-5f64-846c-94a0d3cef48c"
version = "1.2.1"

[[deps.SparseArrays]]
deps = ["Libdl", "LinearAlgebra", "Random", "Serialization", "SuiteSparse_jll"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"
version = "1.11.0"

[[deps.SparseVariables]]
deps = ["Dictionaries", "JuMP", "LinearAlgebra", "PrecompileTools"]
git-tree-sha1 = "79f7b475226e1596dbaff88bbe4974fc74cc983b"
uuid = "2749762c-80ed-4b14-8f33-f0736679b02b"
version = "0.7.3"

[[deps.SpecialFunctions]]
deps = ["IrrationalConstants", "LogExpFunctions", "OpenLibm_jll", "OpenSpecFun_jll"]
git-tree-sha1 = "64cca0c26b4f31ba18f13f6c12af7c85f478cfde"
uuid = "276daf66-3868-5448-9aa4-cd146d93841b"
version = "2.5.0"
weakdeps = ["ChainRulesCore"]

    [deps.SpecialFunctions.extensions]
    SpecialFunctionsChainRulesCoreExt = "ChainRulesCore"

[[deps.StableRNGs]]
deps = ["Random"]
git-tree-sha1 = "83e6cce8324d49dfaf9ef059227f91ed4441a8e5"
uuid = "860ef19b-820b-49d6-a774-d7a799459cd3"
version = "1.0.2"

[[deps.StackViews]]
deps = ["OffsetArrays"]
git-tree-sha1 = "46e589465204cd0c08b4bd97385e4fa79a0c770c"
uuid = "cae243ae-269e-4f55-b966-ac2d0dc13c15"
version = "0.1.1"

[[deps.StaticArrays]]
deps = ["LinearAlgebra", "PrecompileTools", "Random", "StaticArraysCore"]
git-tree-sha1 = "0feb6b9031bd5c51f9072393eb5ab3efd31bf9e4"
uuid = "90137ffa-7385-5640-81b9-e52037218182"
version = "1.9.13"
weakdeps = ["ChainRulesCore", "Statistics"]

    [deps.StaticArrays.extensions]
    StaticArraysChainRulesCoreExt = "ChainRulesCore"
    StaticArraysStatisticsExt = "Statistics"

[[deps.StaticArraysCore]]
git-tree-sha1 = "192954ef1208c7019899fbf8049e717f92959682"
uuid = "1e83bf80-4336-4d27-bf5d-d5a4f845583c"
version = "1.4.3"

[[deps.Statistics]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "ae3bb1eb3bba077cd276bc5cfc337cc65c3075c0"
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"
version = "1.11.1"
weakdeps = ["SparseArrays"]

    [deps.Statistics.extensions]
    SparseArraysExt = ["SparseArrays"]

[[deps.StatsAPI]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "1ff449ad350c9c4cbc756624d6f8a8c3ef56d3ed"
uuid = "82ae8749-77ed-4fe6-ae5f-f523153014b0"
version = "1.7.0"

[[deps.StatsBase]]
deps = ["AliasTables", "DataAPI", "DataStructures", "LinearAlgebra", "LogExpFunctions", "Missings", "Printf", "Random", "SortingAlgorithms", "SparseArrays", "Statistics", "StatsAPI"]
git-tree-sha1 = "29321314c920c26684834965ec2ce0dacc9cf8e5"
uuid = "2913bbd2-ae8a-5f71-8c99-4fb6c76f3a91"
version = "0.34.4"

[[deps.StatsFuns]]
deps = ["HypergeometricFunctions", "IrrationalConstants", "LogExpFunctions", "Reexport", "Rmath", "SpecialFunctions"]
git-tree-sha1 = "b423576adc27097764a90e163157bcfc9acf0f46"
uuid = "4c63d2b9-4356-54db-8cca-17b64c39e42c"
version = "1.3.2"
weakdeps = ["ChainRulesCore", "InverseFunctions"]

    [deps.StatsFuns.extensions]
    StatsFunsChainRulesCoreExt = "ChainRulesCore"
    StatsFunsInverseFunctionsExt = "InverseFunctions"

[[deps.StatsModels]]
deps = ["DataAPI", "DataStructures", "LinearAlgebra", "Printf", "REPL", "ShiftedArrays", "SparseArrays", "StatsAPI", "StatsBase", "StatsFuns", "Tables"]
git-tree-sha1 = "9022bcaa2fc1d484f1326eaa4db8db543ca8c66d"
uuid = "3eaba693-59b7-5ba5-a881-562e759f1c8d"
version = "0.7.4"

[[deps.StringManipulation]]
deps = ["PrecompileTools"]
git-tree-sha1 = "725421ae8e530ec29bcbdddbe91ff8053421d023"
uuid = "892a3eda-7b42-436c-8928-eab12a02cf0e"
version = "0.4.1"

[[deps.StructArrays]]
deps = ["ConstructionBase", "DataAPI", "Tables"]
git-tree-sha1 = "9537ef82c42cdd8c5d443cbc359110cbb36bae10"
uuid = "09ab397b-f2b6-538f-b94a-2f83cf4a842a"
version = "0.6.21"

    [deps.StructArrays.extensions]
    StructArraysAdaptExt = "Adapt"
    StructArraysGPUArraysCoreExt = ["GPUArraysCore", "KernelAbstractions"]
    StructArraysLinearAlgebraExt = "LinearAlgebra"
    StructArraysSparseArraysExt = "SparseArrays"
    StructArraysStaticArraysExt = "StaticArrays"

    [deps.StructArrays.weakdeps]
    Adapt = "79e6a3ab-5dfb-504d-930d-738a2a938a0e"
    GPUArraysCore = "46192b85-c4d5-4398-a991-12ede77f4527"
    KernelAbstractions = "63c18a36-062a-441e-b654-da1e3ab1ce7c"
    LinearAlgebra = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"
    SparseArrays = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"
    StaticArrays = "90137ffa-7385-5640-81b9-e52037218182"

[[deps.StructTypes]]
deps = ["Dates", "UUIDs"]
git-tree-sha1 = "159331b30e94d7b11379037feeb9b690950cace8"
uuid = "856f2bd8-1eba-4b0a-8007-ebc267875bd4"
version = "1.11.0"

[[deps.StyledStrings]]
uuid = "f489334b-da3d-4c2e-b8f0-e476e12c162b"
version = "1.11.0"

[[deps.SuiteSparse]]
deps = ["Libdl", "LinearAlgebra", "Serialization", "SparseArrays"]
uuid = "4607b0f0-06f3-5cda-b6b1-a6196a1729e9"

[[deps.SuiteSparse_jll]]
deps = ["Artifacts", "Libdl", "libblastrampoline_jll"]
uuid = "bea87d4a-7f5b-5778-9afe-8cc45184846c"
version = "7.7.0+0"

[[deps.TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"
version = "1.0.3"

[[deps.TZJData]]
deps = ["Artifacts"]
git-tree-sha1 = "7def47e953a91cdcebd08fbe76d69d2715499a7d"
uuid = "dc5dba14-91b3-4cab-a142-028a31da12f7"
version = "1.4.0+2025a"

[[deps.TableTraits]]
deps = ["IteratorInterfaceExtensions"]
git-tree-sha1 = "c06b2f539df1c6efa794486abfb6ed2022561a39"
uuid = "3783bdb8-4a98-5b6b-af9a-565f29a5fe9c"
version = "1.0.1"

[[deps.Tables]]
deps = ["DataAPI", "DataValueInterfaces", "IteratorInterfaceExtensions", "OrderedCollections", "TableTraits"]
git-tree-sha1 = "598cd7c1f68d1e205689b1c2fe65a9f85846f297"
uuid = "bd369af6-aec1-5ad0-b16a-f7cc5008161c"
version = "1.12.0"

[[deps.Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"
version = "1.10.0"

[[deps.TensorCore]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "1feb45f88d133a655e001435632f019a9a1bcdb6"
uuid = "62fd8b95-f654-4bbd-a8a5-9c27f68ccd50"
version = "0.1.1"

[[deps.Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"
version = "1.11.0"

[[deps.TiffImages]]
deps = ["ColorTypes", "DataStructures", "DocStringExtensions", "FileIO", "FixedPointNumbers", "IndirectArrays", "Inflate", "Mmap", "OffsetArrays", "PkgVersion", "ProgressMeter", "SIMD", "UUIDs"]
git-tree-sha1 = "f21231b166166bebc73b99cea236071eb047525b"
uuid = "731e570b-9d59-4bfa-96dc-6df516fadf69"
version = "0.11.3"

[[deps.TimeStruct]]
deps = ["Dates", "TimeZones"]
git-tree-sha1 = "08c14d6ba32a3bf3f7c04f2aca2731c1bc2a4ec4"
uuid = "f9ed5ce0-9f41-4eaa-96da-f38ab8df101c"
version = "0.9.2"
weakdeps = ["DataFrames", "Unitful"]

    [deps.TimeStruct.extensions]
    TimeStructDataFramesExt = "DataFrames"
    TimeStructUnitfulExt = "Unitful"

[[deps.TimeZones]]
deps = ["Artifacts", "Dates", "Downloads", "InlineStrings", "Mocking", "Printf", "Scratch", "TZJData", "Unicode", "p7zip_jll"]
git-tree-sha1 = "2c705e96825b66c4a3f25031a683c06518256dd3"
uuid = "f269a46b-ccf7-5d73-abea-4c690281aa53"
version = "1.21.3"

    [deps.TimeZones.extensions]
    TimeZonesRecipesBaseExt = "RecipesBase"

    [deps.TimeZones.weakdeps]
    RecipesBase = "3cdcf5f2-1ef4-517c-9805-6587b60abb01"

[[deps.TranscodingStreams]]
git-tree-sha1 = "0c45878dcfdcfa8480052b6ab162cdd138781742"
uuid = "3bb67fe8-82b1-5028-8e26-92a6c54297fa"
version = "0.11.3"

[[deps.Tricks]]
git-tree-sha1 = "6cae795a5a9313bbb4f60683f7263318fc7d1505"
uuid = "410a4b4d-49e4-4fbc-ab6d-cb71b17b3775"
version = "0.1.10"

[[deps.TriplotBase]]
git-tree-sha1 = "4d4ed7f294cda19382ff7de4c137d24d16adc89b"
uuid = "981d1d27-644d-49a2-9326-4793e63143c3"
version = "0.1.0"

[[deps.URIs]]
git-tree-sha1 = "67db6cc7b3821e19ebe75791a9dd19c9b1188f2b"
uuid = "5c2747f8-b7ea-4ff2-ba2e-563bfd36b1d4"
version = "1.5.1"

[[deps.UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"
version = "1.11.0"

[[deps.Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"
version = "1.11.0"

[[deps.UnicodeFun]]
deps = ["REPL"]
git-tree-sha1 = "53915e50200959667e78a92a418594b428dffddf"
uuid = "1cfade01-22cf-5700-b092-accc4b62d6e1"
version = "0.4.1"

[[deps.Unitful]]
deps = ["Dates", "LinearAlgebra", "Random"]
git-tree-sha1 = "c0667a8e676c53d390a09dc6870b3d8d6650e2bf"
uuid = "1986cc42-f94f-5a68-af5c-568840ba703d"
version = "1.22.0"
weakdeps = ["ConstructionBase", "InverseFunctions"]

    [deps.Unitful.extensions]
    ConstructionBaseUnitfulExt = "ConstructionBase"
    InverseFunctionsUnitfulExt = "InverseFunctions"

[[deps.WebP]]
deps = ["CEnum", "ColorTypes", "FileIO", "FixedPointNumbers", "ImageCore", "libwebp_jll"]
git-tree-sha1 = "aa1ca3c47f119fbdae8770c29820e5e6119b83f2"
uuid = "e3aaa7dc-3e4b-44e0-be63-ffb868ccd7c1"
version = "0.1.3"

[[deps.WoodburyMatrices]]
deps = ["LinearAlgebra", "SparseArrays"]
git-tree-sha1 = "c1a7aa6219628fcd757dede0ca95e245c5cd9511"
uuid = "efce3f68-66dc-5838-9240-27a6d6f5f9b6"
version = "1.0.0"

[[deps.XML2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libiconv_jll", "Zlib_jll"]
git-tree-sha1 = "b8b243e47228b4a3877f1dd6aee0c5d56db7fcf4"
uuid = "02c8fc9c-b97f-50b9-bbe4-9be30ff0a78a"
version = "2.13.6+1"

[[deps.XSLT_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libgcrypt_jll", "Libgpg_error_jll", "Libiconv_jll", "XML2_jll", "Zlib_jll"]
git-tree-sha1 = "7d1671acbe47ac88e981868a078bd6b4e27c5191"
uuid = "aed1982a-8fda-507f-9586-7b0439959a61"
version = "1.1.42+0"

[[deps.XZ_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "56c6604ec8b2d82cc4cfe01aa03b00426aac7e1f"
uuid = "ffd25f8a-64ca-5728-b0f7-c24cf3aae800"
version = "5.6.4+1"

[[deps.Xorg_libX11_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libxcb_jll", "Xorg_xtrans_jll"]
git-tree-sha1 = "9dafcee1d24c4f024e7edc92603cedba72118283"
uuid = "4f6342f7-b3d2-589e-9d20-edeb45f2b2bc"
version = "1.8.6+3"

[[deps.Xorg_libXau_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "e9216fdcd8514b7072b43653874fd688e4c6c003"
uuid = "0c0b7dd1-d40b-584c-a123-a41640f87eec"
version = "1.0.12+0"

[[deps.Xorg_libXdmcp_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "89799ae67c17caa5b3b5a19b8469eeee474377db"
uuid = "a3789734-cfe1-5b06-b2d0-1dd0d9d62d05"
version = "1.1.5+0"

[[deps.Xorg_libXext_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libX11_jll"]
git-tree-sha1 = "d7155fea91a4123ef59f42c4afb5ab3b4ca95058"
uuid = "1082639a-0dae-5f34-9b06-72781eeb8cb3"
version = "1.3.6+3"

[[deps.Xorg_libXrender_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libX11_jll"]
git-tree-sha1 = "a490c6212a0e90d2d55111ac956f7c4fa9c277a6"
uuid = "ea2f1a96-1ddc-540d-b46f-429655e07cfa"
version = "0.9.11+1"

[[deps.Xorg_libpthread_stubs_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "c57201109a9e4c0585b208bb408bc41d205ac4e9"
uuid = "14d82f49-176c-5ed1-bb49-ad3f5cbd8c74"
version = "0.1.2+0"

[[deps.Xorg_libxcb_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "XSLT_jll", "Xorg_libXau_jll", "Xorg_libXdmcp_jll", "Xorg_libpthread_stubs_jll"]
git-tree-sha1 = "1a74296303b6524a0472a8cb12d3d87a78eb3612"
uuid = "c7cfdc94-dc32-55de-ac96-5a1b8d977c5b"
version = "1.17.0+3"

[[deps.Xorg_xtrans_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "6dba04dbfb72ae3ebe5418ba33d087ba8aa8cb00"
uuid = "c5fb5394-a638-5e4d-96e5-b29de1b5cf10"
version = "1.5.1+0"

[[deps.Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"
version = "1.2.13+1"

[[deps.Zstd_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "446b23e73536f84e8037f5dce465e92275f6a308"
uuid = "3161d3a3-bdf6-5164-811a-617609db77b4"
version = "1.5.7+1"

[[deps.isoband_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "51b5eeb3f98367157a7a12a1fb0aa5328946c03c"
uuid = "9a68df92-36a6-505f-a73e-abb412b6bfb4"
version = "0.2.3+0"

[[deps.libaom_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "522c1df09d05a71785765d19c9524661234738e9"
uuid = "a4ae2306-e953-59d6-aa16-d00cac43593b"
version = "3.11.0+0"

[[deps.libass_jll]]
deps = ["Artifacts", "Bzip2_jll", "FreeType2_jll", "FriBidi_jll", "HarfBuzz_jll", "JLLWrappers", "Libdl", "Zlib_jll"]
git-tree-sha1 = "e17c115d55c5fbb7e52ebedb427a0dca79d4484e"
uuid = "0ac62f75-1d6f-5e53-bd7c-93b484bb37c0"
version = "0.15.2+0"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"
version = "5.11.0+0"

[[deps.libfdk_aac_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "8a22cf860a7d27e4f3498a0fe0811a7957badb38"
uuid = "f638f0a6-7fb0-5443-88ba-1cc74229b280"
version = "2.0.3+0"

[[deps.libpng_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Zlib_jll"]
git-tree-sha1 = "055a96774f383318750a1a5e10fd4151f04c29c5"
uuid = "b53b4c65-9356-5827-b1ea-8c7a1a84506f"
version = "1.6.46+0"

[[deps.libsixel_jll]]
deps = ["Artifacts", "JLLWrappers", "JpegTurbo_jll", "Libdl", "libpng_jll"]
git-tree-sha1 = "c1733e347283df07689d71d61e14be986e49e47a"
uuid = "075b6546-f08a-558a-be8f-8157d0f608a5"
version = "1.10.5+0"

[[deps.libvorbis_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Ogg_jll", "Pkg"]
git-tree-sha1 = "490376214c4721cdaca654041f635213c6165cb3"
uuid = "f27f6e37-5d2b-51aa-960f-b287f2bc3b7a"
version = "1.3.7+2"

[[deps.libwebp_jll]]
deps = ["Artifacts", "Giflib_jll", "JLLWrappers", "JpegTurbo_jll", "Libdl", "Libglvnd_jll", "Libtiff_jll", "libpng_jll"]
git-tree-sha1 = "d2408cac540942921e7bd77272c32e58c33d8a77"
uuid = "c5f90fcd-3b7e-5836-afba-fc50a0988cb2"
version = "1.5.0+0"

[[deps.nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"
version = "1.59.0+0"

[[deps.oneTBB_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "d5a767a3bb77135a99e433afe0eb14cd7f6914c3"
uuid = "1317d2d5-d96f-522e-a858-c73665f53c3e"
version = "2022.0.0+0"

[[deps.p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"
version = "17.4.0+2"

[[deps.x264_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "14cc7083fc6dff3cc44f2bc435ee96d06ed79aa7"
uuid = "1270edf5-f2f9-52d2-97e9-ab00b5d0237a"
version = "10164.0.1+0"

[[deps.x265_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "dcc541bb19ed5b0ede95581fb2e41ecf179527d2"
uuid = "dfaa095f-4041-5dcd-9319-2fabd8486b76"
version = "3.6.0+0"
"""

# ╔═╡ Cell order:
# ╟─d534fe86-1268-44be-b18c-b2895615a4b9
# ╟─277e899e-b3a2-11ee-3c91-dd9707765363
# ╟─e4be1763-c58a-4e57-a429-e48b2dfb579c
# ╟─b122be93-bc75-4601-ba83-8262b2fb1c18
# ╟─60787e62-73a1-4149-a297-b92470fc8372
# ╟─812befd7-032e-4c53-9fae-c4054af74c76
# ╟─6918eee5-a178-40aa-851b-c461635fe091
# ╟─bdb54c5b-9c8d-4881-b522-0d7088fff6ad
# ╟─0e4f5b99-4954-4aa1-8f41-d1c34186e5a1
# ╟─a3144c1a-a327-4b1f-a59d-33a29a31a435
# ╟─ddd95f30-53af-4e23-96ff-2d303254ac71
# ╟─fd4adc62-6d0f-4288-982d-f27e25673175
# ╟─cea18e40-5c45-43e4-8525-178890c36ce7
# ╠═7d63ec90-e7cb-4e18-9ee4-5ba7c8694e94
# ╟─decc9f11-0bca-458d-906e-d99cefd4204b
# ╠═7a4186eb-9983-4224-8363-96549869acef
# ╟─d2e9dbd4-3c65-473d-b845-2d427084222d
# ╠═804b724b-8261-4947-8eb5-446c2582f39e
# ╟─612faf94-7040-49ab-8d77-64f3838ec79d
# ╠═ffbee0c4-9193-49fb-9d43-f6d9957e82a1
# ╠═64931367-f960-43ab-8279-5230b6aa7197
# ╠═5bd90561-ab99-4b77-998a-79d7f0f7fa8e
# ╠═e50fdf31-2a12-4fbe-9c47-686dc10632ec
# ╠═76c95758-0d0a-492d-9ec6-0767532e8967
# ╠═42aab7d9-7309-43bc-b21a-41a7bdec0a17
# ╟─84d48acc-ce5c-4c55-8b63-e45d20a92b9b
# ╠═a870f9c8-35b4-485c-ad7b-5ae6dd873150
# ╟─5138de81-2ff3-4794-8f98-bfd9f1bc76d1
# ╠═75a42272-b0a7-48ff-945a-54e19d1f36ef
# ╟─9211890f-b728-4297-bf4e-03b389110f40
# ╠═e283dcd3-05f6-4e79-9a3f-be2800d16967
# ╟─e3c7200f-5900-424b-875d-10ee78b7bf0c
# ╠═872da3ab-742a-4daf-a080-5368e2cf2950
# ╟─82a12165-6381-46fc-985e-3bc472a0cf8d
# ╠═dff63058-c619-4a10-9307-b16c77f3acfe
# ╠═5fe27d7a-ffa4-43c7-b8c4-472155a8c4ec
# ╠═740c1cc8-a44c-4a54-b573-0bc80da44c8f
# ╟─1976b9dd-9c62-4aa3-ba31-0932ab2cdaa2
# ╠═773756be-e8dc-42ba-b03e-dfb909b9ddc5
# ╟─88c2b560-1123-4f8e-81a0-da447084a070
# ╠═ca4ee06a-5ce0-4925-b763-bc92a6175529
# ╟─f21f3c6a-2b81-4d41-846a-421d90242e1d
# ╠═2d609131-dcf1-4366-9778-cb21e73cac09
# ╟─218dde43-b45c-4d29-b51b-61bd1205dddf
# ╠═a4e6afbe-df91-4293-89ac-ad0185c285e8
# ╟─b1dd50e6-66e2-4977-9f56-c8e2cd4c70c8
# ╠═9e8348d0-26e0-4053-836b-99828da0b614
# ╠═5c454b87-4fdd-41f8-8c31-b2a70b65ba6c
# ╠═b589ddb6-a8ed-4a91-b007-f645d2ee0926
# ╠═68f7cf23-00be-48ab-91fb-75fc87817f42
# ╠═aeec127b-0a07-4c8b-96f5-55d8037d4384
# ╟─ddcb618f-71b5-497f-90ea-dc9b834ebfe7
# ╠═16b54533-7fa8-4643-af1a-bb02eab01e15
# ╠═ac227d32-1554-474f-8abc-e56c546517d1
# ╠═07592fc1-ec10-4295-946d-621b36520178
# ╠═600dcc3f-04b8-493e-8fdb-5ed09c10bbd9
# ╠═9a013351-6742-40f6-9ff2-3642c1ed32af
# ╠═b488deac-923c-4252-9f8f-dc9316e22b40
# ╟─2053980e-bb80-4617-87bd-2d176d5f468c
# ╠═427dae10-74c2-422b-a400-1b37e176c21b
# ╟─d1c06598-2177-4a55-a312-df4f33efde5e
# ╠═7a2d7d27-42ae-4dc8-94e5-886b33b8a4a5
# ╠═ccb91324-3886-43f5-8627-abf21fd6618d
# ╟─fe14d4c6-ce89-4973-9a80-e5ec70a834b7
# ╟─02ed4d4a-ac0e-4c54-8ddd-a7ad0f06e851
# ╟─d293520b-4152-4654-923c-4f1bf384f3c6
# ╠═f9f10b56-c4be-40c8-9794-def8acb25094
# ╟─802bf139-becd-420c-a21c-6b5dc0e41ba5
# ╠═e1bc8b77-8876-4969-afb4-8b1d92442855
# ╠═985484db-f5fb-4fd2-9b75-a0c18a51797c
# ╟─c2232182-1b2f-4932-a711-679e01fb3355
# ╠═f4f21e5d-9955-44a9-9f55-ba0287ecf1ef
# ╟─3e32aa11-35c1-48b6-a0c3-51d48a636420
# ╠═36b45cfe-2a7f-4592-9c62-1feb355dc554
# ╟─824647b5-80f8-45d2-bbd1-d8a3a75f0cf4
# ╠═407c948a-5c6f-4640-aaa6-f7a46958f269
# ╟─3e00269e-5ee5-4d01-81f3-1202aec6e8c6
# ╠═fc5c0d2f-91ba-4727-bba4-0981eff29bac
# ╠═befeccf8-a0d1-4658-b6a2-d7103f13ecc8
# ╟─94963669-80b7-41d2-96bb-2cc0eba372c8
# ╠═b3bcdb92-5946-49a7-b82a-6504f3ee53a9
# ╠═819df70c-2ff8-4a46-be84-8d8af08b1b98
# ╠═ee7f8344-e7cc-492b-8c85-367fe407ec65
# ╠═3fcc860f-e7b1-402d-b113-c9e48b9ca5e7
# ╠═c6d36bbe-fcfd-4f12-949f-df4d7966f942
# ╟─cf498b13-7619-4118-a301-4bdbfeec245d
# ╠═ac455ee7-839f-4095-9d55-328b74156d58
# ╠═13974fa0-b698-4b5b-8bf6-7a2c023cdb7c
# ╟─29e784c6-ed83-494e-841f-ab72dcd9d73e
# ╠═0c9caebd-420d-4345-9893-2bdc5f8b39c5
# ╠═d5549e06-dcde-4724-9aeb-56f1ff04304f
# ╠═86b1f5bf-16be-4330-8c3c-254153c03863
# ╠═c7ebc721-126a-4675-ab4c-94e7af75b310
# ╟─4e402681-7144-4969-914e-7782e8f7a1d1
# ╟─a44bac08-5c9e-4a5e-91dc-3a4b6f92789a
# ╟─f549a531-14c5-43c0-ac7b-315214af9d4c
# ╟─0af9269e-6cae-4f15-b23a-c4ea138e5791
# ╠═9c57324f-f798-4d37-8b7b-1bf46a8c6fd8
# ╟─cde63969-78f3-40c8-9c9e-7aaf6ad658e1
# ╠═0c5b0ccf-128c-4f16-b1ab-bb0ac3ec3fa2
# ╟─678bc5f1-4c83-4068-aead-5698fd6cbca0
# ╠═3fc9c920-aa19-4d2c-8205-a6824294c8ed
# ╠═05dff48f-e180-463c-98ca-cf1fdfe697f0
# ╟─c9597105-1197-4f48-9d2a-13ed81310567
# ╠═4cc14d25-fc1a-4b72-babe-2925754aa328
# ╠═a77d20c1-9a14-47ec-9c99-b8ae491cd4a9
# ╠═7a30713a-5beb-4597-b83e-d43dbf67a8d3
# ╟─3fd372f7-3589-4281-b1bd-92255c20990e
# ╠═f9a039bd-fd98-4476-ab8d-6cffa755894b
# ╟─631fbb4d-1fe6-461f-8930-14585caca1ae
# ╠═72a2c038-adb7-4edb-9fe6-ebdfa412ce28
# ╠═c4d4590e-0207-4f1c-b7cb-c573ee4772ab
# ╟─e74fd098-51a3-430f-905e-112cbe02d04a
# ╠═6c60f2bd-6441-4b05-b05a-b066a0279463
# ╠═ebad63ba-07e9-49f2-8824-e0b2df78c993
# ╠═464ce3ea-cbb8-4fe0-8a95-364d1cfe769f
# ╠═ac5caf5c-8c0e-4ca7-8429-d625dc03f375
# ╠═80c313ba-37e4-4cc2-9ac4-97e6b3edd61b
# ╟─052e0093-98a2-4bc2-9318-2416ae241ec5
# ╟─6eeab062-3283-461e-a426-394cf405328d
# ╠═70aea58a-12f9-4f89-9154-9fc0e4c9328d
# ╠═88f33cb3-22ff-450f-b553-ceb1d71bb81b
# ╠═f7c8aa88-0a7f-4a7c-ba92-dd15ffaa84be
# ╠═82d96a2d-0503-441b-a9a7-c8b6338cdd6f
# ╠═d7a01f8e-a687-469c-89b4-2a322d0359a7
# ╟─2c0e1acb-ca4d-4f04-847c-b5d98c644d74
# ╠═a8e9720f-28e3-4a8e-a8cf-d0e3c2cd34d4
# ╠═e1eff250-74ef-4879-a3c3-ae83b0a25a2f
# ╟─307d6c81-0e5c-4907-bd3f-cbbcfa187b68
# ╟─7578e8e9-be07-4af5-89f2-99bf3ad39943
# ╟─ab2ab128-d41f-43a8-8611-c77b297a6741
# ╟─27b88036-263a-46ae-b12a-fb85dae4512d
# ╟─99cae247-f58f-4e90-b834-5211d405adfa
# ╟─84eca013-6ca9-4092-9548-28d7762b44ac
# ╟─74b309e6-6e80-44d8-a09a-b7ac0767e074
# ╟─8739a599-95f6-4978-9087-aac6d5f3ee0d
# ╟─7323169a-d87e-4b33-9abe-6b98f6dc52b8
# ╟─d8be386e-6274-4288-a0cf-71b93c0e7632
# ╟─f482541e-4943-4715-9875-5313f319b89f
# ╟─229f049a-8362-4b1f-8fa2-f6d342a96675
# ╟─bdce2eda-9d55-4408-aa4f-12f38d27a8df
# ╟─8632e056-5f9b-4383-8de5-5329eb98a5f4
# ╟─0a1af73a-98d4-4f81-baa0-d77bf84f006a
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
