using HTTP
using JSON3
using Dates
using CSV
using Mustache
using Underscores
using DataFrames
using Logging, LoggingFacilities
using GitHub

@_ ConsoleLogger(stdout; show_limited=false) |>
   OneLineTransformerLogger |>
   TimestampTransformerLogger(__, BeginningMessageLocation(); format = "yyyy-mm-dd HH:MM:SS") |>
   global_logger

const TOKEN = strip(read("pat", String))
const GRAPHQLURL = "https://api.github.com/graphql"
const OUTFILE = "contributors.csv"
const DATAROOT = "data"
const REPOS = [
               ("open-mmlab", "mmpose", "mmpose-contributors.csv"),
               ("open-mmlab", "mmtracking", "mmtracking-contributors.csv"),
               ("open-mmlab", "mmgeneration", "mmgeneration-contributors.csv"),
               ("open-mmlab", "mmocr", "mmocr-contributors.csv"),
               ("open-mmlab", "mmaction2", "mmaction2-contributors.csv"),
               ("open-mmlab", "mmclassification", "mmclassification-contributors.csv"),
               ("open-mmlab", "mmediting", "mmediting-contributors.csv"),
               ("open-mmlab", "mmdetection", "mmdetection-contributors.csv"),
               ("open-mmlab", "mmsegmentation", "mmsegmentation-contributors.csv"),
               ("open-mmlab", "mmdetection3d", "mmdetection3d-contributors.csv"),
               ("open-mmlab", "mmcv", "mmcv-contributors.csv"),
               ("open-mmlab", "mim", "mim-contributors.csv"),
              ]
const QUERY = mt"""
{
  user(login: "{{ login }}") {
    createdAt
    company
    name
    location
  }
}
"""

const REMAIN_QUERY = """
query {
  viewer {
    login
  }
  rateLimit {
    limit
    cost
    remaining
    resetAt
  }
}
"""

struct STAR
    name::String
    company::String
    location::String
    # country::String
    # state::String
    # city::String
    # lat::Float64
    # lng::Float64
    createdAt::DateTime
end

function STAR(node)
    name = isnothing(node.name) ? "" : node.name
    company = isnothing(node.company) ? "" : node.company
    location = isnothing(node.location) ? "" : node.location
    createdAt = DateTime(node.createdAt[1:end-1])
    STAR(name, company, location, createdAt)
end

function execute(query, graphqlurl = GRAPHQLURL, token = TOKEN)
  body = JSON3.write(Dict("query" => query))
  res = HTTP.request("POST", "https://api.github.com/graphql", Dict("Authorization" => "bearer $token"), body)

  return JSON3.read(String(res.body))
end

function remain(; query = REMAIN_QUERY)
    res = execute(query)
    res = res.data.rateLimit
    return (; limit = res.limit, reset_ts = DateTime(res.resetAt[1:end-1]), remaining = res.remaining)
end

function collect(owner, repo, output = OUTFILE; query = QUERY, token=TOKEN)
    myauth = GitHub.authenticate(token)
    contribs, _ = contributors("$owner/$repo"; auth=myauth)
    contribs = [x["contributor"].login for x in contribs]

    res = map(contribs) do login
      q = render(query, Dict("login" => login))
      res = execute(q)
      @info "Current contributor: " login
      r = remain()
      @info "Remain: " r.limit r.remaining r.reset_ts
      STAR(res.data.user)
    end
    res = DataFrame(res)
    CSV.write(output, res; delim = '\1', append = true)
end


for (owner, repo, outfile) in REPOS
    outfile = joinpath(DATAROOT, outfile)
    collect(owner, repo, outfile)
end
