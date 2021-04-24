### A Pluto.jl notebook ###
# v0.14.3

using Markdown
using InteractiveUtils

# ╔═╡ 5387f5da-32e9-11eb-0755-4761179a9e2e
begin
	using CSV
	using DataFrames
	using Underscores
	using Chain
	using Plots
	using StatsPlots
	using Dates
	using Statistics
end

# ╔═╡ 341942e4-34b0-11eb-06cb-5567deeb8ff3
md"""
## MMGeneration repository report
"""

# ╔═╡ 1700751e-32ea-11eb-2542-8dc5191e8fdd
df = CSV.File("data/mmgeneration.csv", delim = '\1') |> DataFrame;

# ╔═╡ 4d51622c-32ea-11eb-0447-115d7d50b528
let
	mergedpr = @chain df begin
		filter(x -> x.state == "MERGED", _)
		size(1)
	end

	closedpr = @chain df begin
		filter(x -> x.state == "CLOSED" && !x.merged, _)
		size(1)
	end

	mergers = @_ df.mergedBy |> filter(!ismissing(_), __) |>
		unique |> length

	authors = @_ df.author |> filter(!ismissing(_), __) |>
		unique |> length

	topmergers = @chain df begin
		filter(x -> x.merged, _)
    	groupby(:mergedBy)
    	combine(nrow => :cnt)
    	sort(:cnt, rev = true)
    	first(10)
	end

	topauthors = @chain df begin
    	filter(x -> !ismissing(x.author), _)
    	groupby(:author)
    	combine(nrow => :cnt)
    	sort(:cnt, rev = true)
    	first(10)
	end

	dt = Date(maximum(df.createdAt))
md"""
### Overall statistics (on the date $dt)

* Number of PRs: **$(size(df, 1))**

* Number of merged PRs: **$mergedpr**

* Number of closed (non merged PRs): **$closedpr**

* Number of mergers (those who can accept and merge PR): **$mergers**

* Number of PR authors: **$authors**


### Top mergers

$topmergers

### Top authors

$topauthors
"""
end

# ╔═╡ c217826c-32ea-11eb-2a1d-e736665734e2
let
	df1 = @chain df begin
		transform(:createdAt => (x -> Dates.format.(x, "yyyy-mm")) => :create_month)
		groupby(:create_month)
		combine(nrow => :cnt)
	end

	df2 = @chain df begin
		filter(x -> x.merged, _)
		transform(:createdAt => (x -> Dates.format.(x, "yyyy-mm")) => :create_month)
		groupby(:create_month)
		combine(nrow => :cnt)
	end

	acc = @chain innerjoin(df1, df2; on = :create_month, makeunique = true) begin
	    transform([:cnt, :cnt_1] => ((x, y) -> y./x) => :acceptance)
    	rename!(["month", "created_cnt", "merged_cnt", "acceptance"])
	end


	p = plot(df1.create_month, df1.cnt, label = "New PRs", legend = :bottom)
	p = plot!(df2.create_month, df2.cnt, label = "Merged PRs")

	p2 = plot(acc.month, acc.acceptance, label = nothing)
md"""
### PR dynamics

##### New PRs each month
$df1

##### Merged PRs
Here you can see all merged PRs aggregated by the month of their creation. Comparing with the previuos table, you can estimate ratio of merged to created PRs. Of course, this statistics is skewed, since older PRs have more time to be merged, that is why later we compare number of closed or merged PRs during some period of time (1 month or 1 month).

$df2

#### Plot of new and merged PR, aggregated by the month of PR creation
$p

#### Ratio of merged/created PRs
$p2
"""
end

# ╔═╡ 47f606d6-32ed-11eb-3310-8d8049de3912
let
	df1 = @chain df begin
		filter(x -> !ismissing(x.mergedBy), _)
		transform(:mergedAt => (x -> Dates.format.(x, "yyyy-mm")) => :merge_month)
		groupby(:merge_month)
		combine(:mergedBy => (x -> length(unique(x))) => :uniq_mergers)
		sort(:merge_month)
	end

	newmergers = @chain df begin
		filter(x -> !ismissing(x.mergedBy), _)
		groupby(:mergedBy)
		combine(:mergedAt => minimum => :first_merge_ts)
		transform(:first_merge_ts => (x -> Dates.format.(x, "yyyy-mm")) => :first_merge_month)
		groupby(:first_merge_month)
		combine(nrow => :cnt)
		sort(:first_merge_month)
	end

	p = plot(df1.merge_month, df1.uniq_mergers, label = "Active unique mergers", legend = :bottom)
	p = plot!(newmergers.first_merge_month, newmergers.cnt, label = "New mergers")
md"""
### Mergers dynamic

On this plot you can see various types of "mergers" aggregated by the month when they were active (i.e. they were actually merging PRs).

`Active unique mergers` means number of unique users, who were accepting PRs during each month.

`New mergers` for some month, means number of users who were merging PRs and made their first merge this month,

$p

##### New mergers each month
$newmergers
"""
end

# ╔═╡ 15860222-32ee-11eb-0156-0562ec7cbf24
let
	function onemonth(ts)
		mints = minimum(ts)
		@_ filter((_ - mints) <= Millisecond(Day(365)), ts)
	end

	df1 = @chain df begin
		filter(x -> !ismissing(x.author), _)
		transform(:createdAt => (x -> Dates.format.(x, "yyyy-mm")) => :create_month)
		groupby(:create_month)
		combine(:author => (x -> length(unique(x))) => :uniq_authors)
		sort(:create_month)
	end

	newauthors = @chain df begin
		filter(x -> !ismissing(x.author), _)
		groupby(:author)
		combine(:createdAt => minimum => :first_create_ts,
		        :createdAt => (x -> length(onemonth(x))) => :prcnt)
		transform(:first_create_ts => (x -> Dates.format.(x, "yyyy-mm")) => :first_create_month)
		groupby(:first_create_month)
		combine(
			nrow => :cnt,
			:prcnt => (x -> quantile(x, 0.5)) => :med,
			:prcnt => (x -> quantile(x, 0.75)) => :q75,
			:prcnt => (x -> quantile(x, 0.95)) => :q95,
		 )
		sort(:first_create_month)
	end

	p = plot(df1.create_month, df1.uniq_authors, label = "Active unique authors", legend = :bottom)
	p = plot!(newauthors.first_create_month, newauthors.cnt, label = "New authors")

	plot(newauthors.first_create_month, newauthors.med, label = "median", legend = :topright)
	plot!(newauthors.first_create_month, newauthors.q75, label = "75% quantile")
	p2 = plot!(newauthors.first_create_month, newauthors.q95, label = "95% quantile")


md"""
### Authors dynamic

On this plot you can see number of active PR authors, i.e. they were actually creating PRs during corresponding month.

`Active unique authors` means number of unique users, who were creating PRs during each month.

`New authors` for some month means number of users who were creating PRs and made their first PR this month.

By comparing this plot with the `mergers` plots, you can maje correspondence between flow of authors and PRs on one hand and adequacy of merging efforts on the other hand.

By comparing with the dynamics of `New PRs` you can estimate average number of PRs per author and as a result PR efforts of an average author.

$p

#### Quantiles of PR number per new author

This one is expanding on previous plot, by estimating amount of PRs generated by new authors during the month after first PR. For example, you can see, that starting from 2017 more than a half (median) authors generated only one PR.In terms of retention it means, that more than half of new authors never returns to PR activity.

$p2
"""
end

# ╔═╡ 97a61064-32f1-11eb-3608-399a0b6972de
let
	df1 = @chain df begin
    	transform([:createdAt, :closedAt] => ((x, y) -> getfield.(y .- x, :value)) => :delta)
    	transform(:delta => (x -> abs.(x)/1000/60/60) => :delta)
    	select([:number, :createdAt, :closedAt, :delta])
		transform(:createdAt => (x -> Dates.format.(x, "yyyy-mm")) => :month)
		groupby(:month)
		combine(
			:delta => (x -> quantile(x, 0.05)) => :q1,
			:delta => (x -> quantile(x, 0.25)) => :q2,
			:delta => (x -> quantile(x, 0.5)) => :q3,
			:delta => (x -> quantile(x, 0.75)) => :q4,
			nrow => :cnt,
			:delta => (x -> sum(x .>= 24*30)) => :cnt_month_wait,
		)
	end

	df2 = @chain df1 begin
		select([:month, :cnt, :cnt_month_wait])
		transform(
			[:cnt, :cnt_month_wait] => ((x, y) -> y./x) => :ratio_month_wait,
		)
	end

	plot(df1.month, df1.q1, label = "5% quantile", yaxis = :log, legend = :bottomright)
	plot!(df1.month, df1.q2, label = "25% quantile", yaxis = :log)
	plot!(df1.month, df1.q3, label = "median", yaxis = :log)
	p = plot!(df1.month, df1.q4, label = "75% quantile", yaxis = :log)

	plot(df2.month, df2.ratio_month_wait, legend = :bottomright, label = ">1 month")
	p2 = plot!(df2.month[1:end-1], df2.ratio_month_wait[1:end-1], label = ">1 month")

md"""
### Quantiles of waiting time (hours) of PR close/merge

In this table and related plot you can see how long it took to wait till PR is closed (which can be either rejecting or merging) in different months. Since waiting time is heavily skewed we are using quantiles, q1 is 5% quantile, q2 is 25% quantile, q3 is median(50% quantile), q4 is 75% quantile. We do not used 95% quantile, since it went to infinity in 2019 (more than 5% of PRs were never closed). This data can be read as follows: it took 21 hour for half PRs to be closed in 2014 and 78 hours in 2019.

N.B.: y axis is in log scale, so linear growth on the plot means exponential growth in absolute values.

$(df1[!, [:month, :q1, :q2, :q3, :q4]])

$p


### PRs with long close time
in this table and plot, you can see number and ratio of PRs that has waited longer then one month (or one month) to be closed or they are still open up to this moment. For example, out of 1826 PRs created in 2014 only 253 (13.8%) PRs were closed after one month after creation. On the contrary out of 2042 PRs created in 2019 515(25%) were not closed during one month after creation.

month 2020 is skewed for the statistics of 1 month since for many PRs one month is not over yet. So it should not be taken into account and was removed from the corresponding plot. But 1 month statistics for 2020 is acceptable.

$df2

$p2
"""
end

# ╔═╡ b287f230-3424-11eb-0222-4db2a5660145
let
	x = @chain df begin
		sort(:createdAt)
		filter(x -> !ismissing(x.author), _)
		groupby(:author)
		transform(:createdAt => (x -> 1:size(x, 1)) => :rn)
		filter(:rn => ==(1), _)
		transform(:createdAt => (x -> Dates.format.(x, "yyyy-mm")) => :month)
		groupby(:month)
		combine(
			:merged => (x -> sum(x)) => :merged_cnt,
			:closed => (x -> sum(x)) => :closed_cnt,
			:closed => (x -> length(x) - sum(x)) => :open_cnt,
			:merged => (x -> length(x)) => :pr_cnt,
		)
		transform(
			[:merged_cnt, :closed_cnt] => ((x, y) -> y .- x) => :rejected_cnt,
			[:merged_cnt, :pr_cnt] => ((x, y) -> x./y) => :ratio,
		)
		transform(
			[:open_cnt, :pr_cnt] => ((x, y) -> x./y) => :open_ratio,
			[:rejected_cnt, :pr_cnt] => ((x, y) -> x./y) => :rejected_ratio,
		)
	end

	plot(x.month, x.ratio, label = "Merged")
	plot!(x.month, x.open_ratio, label = "Open")
	p = plot!(x.month, x.rejected_ratio, label = "Rejected")
md"""
### State of the first PR of new authors.
Here you can find what has happened with the first PR of new authors. Generally PR can be in one of three states: Open, Merged or Closed (i.e. Rejected). Of course this statistics is skewed, since it older PR has more chances to be in Merged or Rejected state.

$p

$x
"""
end

# ╔═╡ 2129de2c-34b1-11eb-1dd9-fb44921d4628
let
	core = @_ unique(df.mergedBy) |> filter(!ismissing(_), __) |> Set

	df1 = @chain df begin
		transform(
			:author => (x -> ifelse.(in.(x, Ref(core)), "Core", "Other")) => :iscore,
			:createdAt => (x -> Dates.format.(x, "yyyy-mm")) => :month,
		)
		groupby([:month, :iscore])
		combine(nrow => :cnt)
		unstack(:iscore, :cnt)
		transform([:Core, :Other] => ((x, y) -> y./(y .+ x)) => :other_ratio)
	end

	plot(df1.month, df1.Core, label = "Core", legend = :topleft, title = "Number of PRs by developer group")
	p = plot!(df1.month, df1.Other, label = "Other")

	p2 = plot(df1.month , df1.other_ratio, label = nothing, title = "Percentage of PRs from non-core developers")

	df2 = @chain df begin
		transform(
			:author => (x -> ifelse.(in.(x, Ref(core)), "Core", "Other")) => :iscore,
			:createdAt => (x -> Dates.format.(x, "yyyy-mm")) => :month,
			[:createdAt, :closedAt] => ((x, y) -> getfield.(y .- x, :value)) => :delta,
		)
		transform(:delta => (x -> abs.(x)/1000/60/60) => :delta)
		groupby([:month, :iscore])
		combine(:delta => (x -> quantile(x, 0.5)) => :median)
		unstack(:iscore, :median)
	end

	plot(df2.month, df2.Core, label = "Core", legend = :topleft)
	p3 = plot!(df2.month, df2.Other, label = "Other")
md"""
### Core and non-core developers

#### PRs by developer group
In the following table and plot is shown number of PR aggregated by the month of creation and whether it was created by someone from core team (developers who can merge PRs) and other contributors. `other_ratio` field is a ratio of PRs made by non core developers to the all PRs.

$df1

$p

$p2

#### Median waiting times by developer group
Here you can see median waiting time of PRs split by developer group. You can compare it with overall median times presented in "Quantiles of waiting time" section. The same definition of waiting time is used.

$df2

$p3
"""
end

# ╔═╡ Cell order:
# ╟─5387f5da-32e9-11eb-0755-4761179a9e2e
# ╟─341942e4-34b0-11eb-06cb-5567deeb8ff3
# ╟─4d51622c-32ea-11eb-0447-115d7d50b528
# ╟─c217826c-32ea-11eb-2a1d-e736665734e2
# ╟─47f606d6-32ed-11eb-3310-8d8049de3912
# ╟─15860222-32ee-11eb-0156-0562ec7cbf24
# ╟─97a61064-32f1-11eb-3608-399a0b6972de
# ╟─b287f230-3424-11eb-0222-4db2a5660145
# ╟─2129de2c-34b1-11eb-1dd9-fb44921d4628
# ╟─1700751e-32ea-11eb-2542-8dc5191e8fdd
