using CSV
using DataFrames
using UnicodePlots
using Dates
using Statistics
using Chain
using Underscores
using DelimitedFiles

repo = "mmdetection"
repo = "PaddleDetection"
repo = "PaddleOCR"
repo = "mmpose"
repo = "mmocr"
repo = "mmediting"
repo = "mm"

df = CSV.File("data/$repo-stars.csv", delim = '\1') |> DataFrame
# df1 = @chain df begin
#     transform(:createdAt => (x -> Dates.format.(x, "yyyy-mm")) => :create_month)
#     groupby(:create_month)
#     combine(nrow => :cnt)
# end
# df1 = sort(df1, :create_month)
# p = plot(df1.create_month, df1.cnt, title = "$repo User Created Time", legend = :bottom)
df2 = @chain df begin
    transform(:createdAt => (x -> Dates.format.(x, "yyyy")) => :create_year)
    groupby(:create_year)
    combine(nrow => :cnt)
end
df2 = sort(df2, :create_year)
barplot(df2.create_year, df2.cnt, title="$repo users created time")

companies = strip.(replace.(filter(!ismissing, df.company), ["@" => ""]))
writedlm("$repo.txt", lowercase.(companies))

# https://www.wordclouds.com/
