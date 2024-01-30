### A Pluto.jl notebook ###
# v0.19.37

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    quote
        local iv = try Base.loaded_modules[Base.PkgId(Base.UUID("6e696c72-6542-2067-7265-42206c756150"), "AbstractPlutoDingetjes")].Bonds.initial_value catch; b -> missing; end
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : iv(el)
        el
    end
end

# ╔═╡ b606fda9-417b-4e23-b78c-e284c349239e
# Several packages are still pending registration in the General registy.
# Until registration is complete, they have to be added manually:
begin
    import Pkg
    Pkg.activate(; temp = true)
    Pkg.add(["JuMP", "HiGHS"])
    Pkg.add(["ShortCodes", "PrettyTables", "DataFrames", "PlutoUI"])
    Pkg.add(["CairoMakie", "AlgebraOfGraphics"])
    Pkg.add(["TimeStruct"])
    Pkg.add(url = "https://github.com/EnergyModelsX/EnergyModelsBase.jl.git")
    Pkg.add(url = "https://github.com/EnergyModelsX/EnergyModelsGeography.jl.git")
    Pkg.add(url = "https://github.com/EnergyModelsX/EnergyModelsInvestments.jl.git")
    Pkg.add(url = "https://github.com/EnergyModelsX/EnergyModelsRenewableProducers.jl.git")
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
!!! nb "Registration pending"

	As soon as the process of registering all EnergyModelsX packages in the [General registry](https://github.com/JuliaRegistries/General?tab=readme-ov-file#general) is completed, the EnergyModelsX packages will be available through the package manager by name as other open packages such as `JuMP` and `DataFrames`.
"""

# ╔═╡ 0ff4447b-dd81-4ae1-b36c-5b540f96308e
Pkg.status()

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
    [emission_data],    # additional data (here emissions) 
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

# ╔═╡ 985484db-f5fb-4fd2-9b75-a0c18a51797c
power_mainland = RefSource(
    "Power mainland",   # id
    FixedProfile(120),  # cap
    FixedProfile(50),   # opex_var
    FixedProfile(15),  # opex_fixed
    Dict(power => 1),   # output
    [emission_data],
)

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
@bind power_cost PlutoUI.Slider(0.1:0.1:10; default = 10)

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
inv_data_wind = InvData(
    capex_cap = FixedProfile(100_000),    # (CAPEX for the defined capacity)
    cap_max_inst = FixedProfile(20),  # (maximum possible installed)
    cap_max_add = FixedProfile(20),   # (maximum added in a strategic period)
    cap_min_add = FixedProfile(0),    # (minimum added in a strategic period)
)

# ╔═╡ 678bc5f1-4c83-4068-aead-5698fd6cbca0
md" We generate some synthetic capacity factors for our wind turbine project:"

# ╔═╡ c9597105-1197-4f48-9d2a-13ed81310567
md" The wind generation node is of type `NonDisRES` (Non-dispatchable renewable energy source)"

# ╔═╡ a77d20c1-9a14-47ec-9c99-b8ae491cd4a9
#Investment capacity limited to node capacity for  BinaryInvestment
inv_data_transmission = TransInvData(
    capex_trans = FixedProfile(500_000),
    trans_max_inst = FixedProfile(50),
    trans_max_add = FixedProfile(100),
    trans_min_add = FixedProfile(0),
    inv_mode = BinaryInvestment(),
    trans_start = 0,
)


# ╔═╡ 7a30713a-5beb-4597-b83e-d43dbf67a8d3
transmission_data = [inv_data_transmission, emission_data]

# ╔═╡ befeccf8-a0d1-4658-b6a2-d7103f13ecc8
transmission_line = RefStatic(
    "transline",                # id
    power,                      # resource
    FixedProfile(transmission_capacity),  # capacity
    FixedProfile(0.1),          # transmission loss (ratio)
    FixedProfile(power_cost),   # opex_var
    FixedProfile(0.1),          # opex_fixed
    1,                          # directions
    transmission_data,          # data
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

# ╔═╡ Cell order:
# ╟─d534fe86-1268-44be-b18c-b2895615a4b9
# ╟─277e899e-b3a2-11ee-3c91-dd9707765363
# ╟─e4be1763-c58a-4e57-a429-e48b2dfb579c
# ╟─b122be93-bc75-4601-ba83-8262b2fb1c18
# ╟─60787e62-73a1-4149-a297-b92470fc8372
# ╠═b606fda9-417b-4e23-b78c-e284c349239e
# ╠═0ff4447b-dd81-4ae1-b36c-5b540f96308e
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
# ╠═ab2ab128-d41f-43a8-8611-c77b297a6741
# ╠═27b88036-263a-46ae-b12a-fb85dae4512d
# ╠═99cae247-f58f-4e90-b834-5211d405adfa
# ╠═84eca013-6ca9-4092-9548-28d7762b44ac
# ╠═74b309e6-6e80-44d8-a09a-b7ac0767e074
# ╠═8739a599-95f6-4978-9087-aac6d5f3ee0d
# ╠═7323169a-d87e-4b33-9abe-6b98f6dc52b8
# ╠═d8be386e-6274-4288-a0cf-71b93c0e7632
# ╠═f482541e-4943-4715-9875-5313f319b89f
# ╠═229f049a-8362-4b1f-8fa2-f6d342a96675
# ╠═bdce2eda-9d55-4408-aa4f-12f38d27a8df
# ╠═8632e056-5f9b-4383-8de5-5329eb98a5f4
# ╠═0a1af73a-98d4-4f81-baa0-d77bf84f006a
