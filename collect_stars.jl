#!/usr/bin/env julia
using HTTP
using JSON3
using Dates
using CSV
using Mustache
using Underscores
using DataFrames
using Logging, LoggingFacilities

@_ ConsoleLogger(stdout; show_limited=false) |>
   OneLineTransformerLogger |>
   TimestampTransformerLogger(__, BeginningMessageLocation(); format = "yyyy-mm-dd HH:MM:SS") |>
   global_logger

const TOKEN = strip(read("pat", String))
const GRAPHQLURL = "https://api.github.com/graphql"
const OUTFILE = "stars.csv"
const DATAROOT = "data"
const REPOS = [
               ("open-mmlab", "mmpose", "mmpose-stars.csv"),
               ("open-mmlab", "mmtracking", "mmtracking-stars.csv"),
               ("open-mmlab", "mmgeneration", "mmgeneration-stars.csv"),
               ("open-mmlab", "mmocr", "mmocr-stars.csv"),
               ("open-mmlab", "mmaction2", "mmaction2-stars.csv"),
               ("open-mmlab", "mmclassification", "mmclassification-stars.csv"),
               ("open-mmlab", "mmediting", "mmediting-stars.csv"),
               ("open-mmlab", "mmdetection", "mmdetection-stars.csv"),
               ("open-mmlab", "mmsegmentation", "mmsegmentation-stars.csv"),
               ("open-mmlab", "mmdetection3d", "mmdetection3d-stars.csv"),
               ("open-mmlab", "mmcv", "mmcv-stars.csv"),
               ("open-mmlab", "mim", "mim-stars.csv"),
              #  ("PaddlePaddle", "PaddleDetection", "PaddleDetection-stars.csv"),
              #  ("PaddlePaddle", "PaddleOCR", "PaddleOCR-stars.csv"),
              ]
const QUERY = mt"""
{
  repository(name: "{{ repo }}", owner: "{{ owner }}") {
    stargazers(first: 100{{{ cursor }}}) {
      nodes {
        name
        company
        location
        createdAt
      }
      edges {
        cursor
        starredAt
      }
    }
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
    starredAt::DateTime
end

function STAR(node)
    name = isnothing(node[:name]) ? "" : node[:name]
    company = isnothing(node[:company]) ? "" : node[:company]
    location = isnothing(node[:location]) ? "" : node[:location]
    createdAt = DateTime(node[:createdAt][1:end-1])
    starredAt = DateTime(node[:starredAt][1:end-1])
    STAR(name, company, location, createdAt, starredAt)
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

function collect(owner, repo, output = OUTFILE; query = QUERY)
    num = 0
    q = render(query, Dict("cursor" => "", "owner" => owner, "repo" => repo))
    res = execute(q)
    cursor = res.data.repository.stargazers.edges[end].cursor
    edges = copy(res.data.repository.stargazers.edges)
    nodes = copy(res.data.repository.stargazers.nodes)
    for (n, e) in zip(nodes, edges)
      n[:starredAt] = e[:starredAt]
    end
    res = @_ map(STAR(_), nodes)
    num += length(res)
    @info "Current star number: " num
    res = DataFrame(res)
    CSV.write(output, res; delim = '\1', append = false)
    r = remain()
    @info "Remain: " r.limit r.remaining r.reset_ts
    while true
        q = render(query, Dict("cursor" => ", after: \"$cursor\"", "owner" => owner, "repo" => repo))
        res = execute(q)
        isempty(res.data.repository.stargazers.edges) && break
        cursor = res.data.repository.stargazers.edges[end].cursor
        edges = copy(res.data.repository.stargazers.edges)
        nodes = copy(res.data.repository.stargazers.nodes)
        for (n, e) in zip(nodes, edges)
          n[:starredAt] = e[:starredAt]
        end
        res = @_ map(STAR(_), nodes)
        num += length(res)
        @info "Current star number: " num
        res = DataFrame(res)
        CSV.write(output, res; delim = '\1', append = true)
        r = remain()
        @info "Remain: " r.limit r.remaining r.reset_ts
    end
end

for (owner, repo, outfile) in REPOS
    outfile = joinpath(DATAROOT, outfile)
    collect(owner, repo, outfile)
end
