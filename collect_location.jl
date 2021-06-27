using CSV
using DataFrames
using UnicodePlots
using Dates
using Statistics
using Chain
using Underscores
using DelimitedFiles
using HTTP
using JSON3
using Logging, LoggingFacilities
using ProgressMeter
using PlotlyJS
using PyCall
using StatsBase

folium = pyimport("folium")

@_ ConsoleLogger(stdout; show_limited=false) |>
   OneLineTransformerLogger |>
   TimestampTransformerLogger(__, BeginningMessageLocation(); format = "yyyy-mm-dd HH:MM:SS") |>
   global_logger

repo = "PaddleDetection"
repo = "PaddleOCR"
repo = "mmocr"
repo = "mmediting"
repo = "mmpose"
repo = "mmtracking"
repo = "mmdetection3d"
repo = "mmsegmentation"
repo = "mmgeneration"
repo = "mmclassification"
repo = "mmaction2"
repo = "mmdetection"
repo = "mmcv"
repo = "mm"

# df = CSV.File("data/$repo-stars.csv", delim = '\1') |> DataFrame
# locations = strip.(replace.(filter(!ismissing, df.location), ["@" => ""]))

# const TOKEN = strip(read("pat2", String))

# function execute_loc(query, token = TOKEN)
#     body = JSON3.write(Dict("location" => query, "options" => Dict("thumbMaps"=> false, "maxResults"=> 1)))
#     res = nothing
#     for i in 1:10
#         try
#             res = HTTP.request("POST", "http://www.mapquestapi.com/geocoding/v1/address?key=$token", [],body)
#         catch e
#             println("try $i time for $query")
#             sleep(0.2)
#         end
#         isnothing(res) || break
#     end

#     try
#         loc = JSON3.read(String(res.body)).results[1].locations[1]
#         return (;country=loc.adminArea1, state=loc.adminArea3, city=loc.adminArea5, lat=loc.displayLatLng.lat, lng=loc.displayLatLng.lng)
#     catch e
#         loc = nothing
#         print(e)
#         return (;country="", state="", city="", lat=0, lng=0)
#     end
# # country, state, city
# end

# struct LOCATION
#     country::String
#     state::String
#     city::String
#     lat::Float64
#     lng::Float64
# end


# result = @showprogress map(locations) do location
#     loc = execute_loc(location)
#     return LOCATION(loc.country, loc.state, loc.city, loc.lat, loc.lng)
# end

# df2 = DataFrame(result)
# df2 = df2[(!=)("").(df2.country), :]
# CSV.write("data/$repo-stars-locations.csv", result; delim = '\1', append = false)


df2 = CSV.File("data/$repo-stars-locations.csv", delim = '\1') |> DataFrame
m = folium.Map(location=[20,0], tiles="OpenStreetMap", zoom_start=2)

country_map = Dict()

function execute(country)
    res = HTTP.request("GET", "https://restcountries.eu/rest/v2/name/$country")
    return JSON3.read(String(res.body))[1]
end

for r in eachrow(df2)
    if ismissing(r.city) && !ismissing(r.country)
        if !(r.country in keys(country_map))
            try
                c = execute(r.country)
                country_map[r.country] = (;city=c.capital, lat=c.latlng[1], lng=c.latlng[2])
                println(country_map[r.country])
            catch
            end
        else
            r.city = country_map[r.country].city
            r.lat = country_map[r.country].lat
            r.lng = country_map[r.country].lng
        end
    end
end
nums = countmap([x for x in zip(df2.lat, df2.lng)])

for r in eachrow(df2)
    folium.Circle(
       location=(r.lat, r.lng),
       popup=r.country * (ismissing(r.state) ? "" : ", $(r.state)") * (ismissing(r.city) ? "" : ", $(r.city)"),
       radius=min(100, nums[(r.lat, r.lng)])*1000,
       color="crimson",
       opacity=0.25,
       fill=true,
       fill_color="crimson"
    ).add_to(m)
end

m.save("$repo-map.html")
