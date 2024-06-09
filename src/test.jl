@info "Loading packages"

using Pkg
# packages = ["CSV", "DataFrames", "JLD2", "MLJ", "MLJFlux", "NNlib", "Flux" "Plots", "StatsBase"]
# Pkg.add(packages)

using CSV
using DataFrames
using JLD2
using MLJ
using MLJFlux
using NNlib
using Flux
using Random
using Plots
using StatsBase

m = Pkg.Operations.Context().env.manifest
println("       CSV $(m[findfirst(v -> v.name == "CSV", m)].version)")
println("DataFrames $(m[findfirst(v -> v.name == "DataFrames", m)].version)")
println("      JLD2 $(m[findfirst(v -> v.name == "JLD2", m)].version)")
println("       MLJ $(m[findfirst(v -> v.name == "MLJ", m)].version)")
println("   MLJFlux $(m[findfirst(v -> v.name == "MLJFlux", m)].version)")
println("      Flux $(m[findfirst(v -> v.name == "Flux", m)].version)")
println("     NNlib $(m[findfirst(v -> v.name == "MLJFlux", m)].version)")
println("     Plots $(m[findfirst(v -> v.name == "Plots", m)].version)")
println(" StatsBase $(m[findfirst(v -> v.name == "StatsBase", m)].version)")
println()

@info "Loading data"

# load training data
if isfile("data/clozapine_test.csv")
    println("Loading: clozapine_test.csv")
    test_data = CSV.read("data/clozapine_test.csv", header=true, DataFrame)
else
    error("File data/clozapine_test.csv cannot be opened!")
    exit(-1)
end

# load models
if isfile("models/clozapine_regressor_model.jlso")
    println("Loading: clozapine_regressor_model.jlso")
    clo_model_regressor = machine("models/clozapine_regressor_model.jlso")
else
    error("File models/clozapine_regressor_model.jlso cannot be opened!")
    exit(-1)
end
if isfile("models/norclozapine_regressor_model.jlso")
    println("Loading: norclozapine_regressor_model.jlso")
    nclo_model_regressor = machine("models/norclozapine_regressor_model.jlso")
else
    error("File models/norclozapine_regressor_model.jlso cannot be opened!")
    exit(-1)
end
if isfile("models/scaler_clo.jld")
    println("Loading: scaler_clo.jld")
    scaler_clo = JLD2.load_object("models/scaler_clo.jld")
else
    error("File models/scaler_clo.jld cannot be opened!")
    exit(-1)
end
if isfile("models/scaler_nclo.jld")
    println("Loading: scaler_nclo.jld")
    scaler_nclo = JLD2.load_object("models/scaler_nclo.jld")
else
    error("File models/scaler_nclo.jld cannot be opened!")
    exit(-1)
end

println()
println("Number of entries: $(nrows(test_data))")
println("Number of features: $(ncol(test_data) - 2)")
println()

@info "Predicting norclozapine level"

data_nclo = Matrix(test_data[:, 3:end])
clo_level = test_data[:, 1]
nclo_level = test_data[:, 2]

# standaridize
data_nclo[:, 2:5] = StatsBase.transform(scaler_nclo, data_nclo[:, 2:5])
data_nclo[isnan.(data_nclo)] .= 0

# create DataFrame
x1 = DataFrame(:male=>data_nclo[:, 1])
x2 = DataFrame(data_nclo[:, 2:5], ["age", "dose", "bmi", "crp"])
x3 = DataFrame(data_nclo[:, 6:end], ["inducers_3a4", "inhibitors_3a4", "substrates_3a4", "inducers_1a2", "inhibitors_1a2", "substrates_1a2"])
data_nclo = Float32.(hcat(x1, x2, x3))
data_nclo = coerce(data_nclo, :male=>OrderedFactor{2}, :age=>Continuous, :dose=>Continuous, :bmi=>Continuous, :crp=>Continuous, :inducers_3a4=>Continuous, :inhibitors_3a4=>Continuous, :substrates_3a4=>Continuous, :inducers_1a2=>Continuous, :inhibitors_1a2=>Continuous, :substrates_1a2=>Continuous)

# predict
nclo_level_pred = MLJ.predict(nclo_model_regressor, data_nclo)

println()

@info "Predicting clozapine level"

data_clo = Matrix(test_data[:, 3:end])
data_clo = hcat(data_clo[:, 1], nclo_level_pred, data_clo[:, 2:end])

# standardize
data_clo[:, 2:6] = StatsBase.transform(scaler_clo, data_clo[:, 2:6])
data_clo[isnan.(data_clo)] .= 0

# create DataFrame
x1 = DataFrame(:male=>data_clo[:, 1])
x2 = DataFrame(data_clo[:, 2:6], ["nclo", "age", "dose", "bmi", "crp"])
x3 = DataFrame(data_clo[:, 7:end], ["inducers_3a4", "inhibitors_3a4", "substrates_3a4", "inducers_1a2", "inhibitors_1a2", "substrates_1a2"])
data_clo = Float32.(hcat(x1, x2, x3))
data_clo = coerce(data_clo, :male=>OrderedFactor{2}, :nclo=>Continuous, :age=>Continuous, :dose=>Continuous, :bmi=>Continuous, :crp=>Continuous, :inducers_3a4=>Continuous, :inhibitors_3a4=>Continuous, :substrates_3a4=>Continuous, :inducers_1a2=>Continuous, :inhibitors_1a2=>Continuous, :substrates_1a2=>Continuous)

clo_level_pred = MLJ.predict(clo_model_regressor, data_clo)

clo_level_pred = round.(clo_level_pred.^2, digits=1)
nclo_level_pred = round.(nclo_level_pred.^2, digits=1)

println()

@info "Regressor accuracy"
println("Predicted levels:")
error_clo = zeros(length(clo_level_pred))
error_nclo = zeros(length(nclo_level_pred))
for idx in eachindex(clo_level_pred)
    error_clo[idx] = round.(clo_level_pred[idx] - clo_level[idx], digits=2)
    error_nclo[idx] = round.(nclo_level_pred[idx] - nclo_level[idx], digits=2)
    println("Subject ID: $idx \t  CLO level: $(clo_level[idx]) \t prediction: $(clo_level_pred[idx]) \t error: $(error_clo[idx])")
    println("Subject ID: $idx \t NCLO level: $(nclo_level[idx]) \t prediction: $(nclo_level_pred[idx]) \t error: $(error_nclo[idx])")
    println()
end

println("Predicting: CLOZAPINE")
println("  R²:\t", round(RSquared()(clo_level_pred, clo_level), digits=2))
println("  RMSE:\t", round(RootMeanSquaredError()(clo_level_pred, clo_level), digits=2))
println("Predicting: NORCLOZAPINE")
println("  R²:\t", round(RSquared()(nclo_level_pred, nclo_level), digits=2))
println("  RMSE:\t", round( RootMeanSquaredError()(nclo_level_pred, nclo_level), digits=2))
println()

@info "Classifying into groups"

println("Classification based on predicted clozapine level:")
clo_group = repeat(["norm"], length(clo_level))
clo_group[clo_level .> 550] .= "high"
clo_group_pred = repeat(["norm"], length(clo_level_pred))
clo_group_pred[clo_level_pred .> 550] .= "high"

cm = zeros(Int64, 2, 2)
cm[1, 1] = count(clo_group_pred[clo_group .== "norm"] .== "norm")
cm[1, 2] = count(clo_group_pred[clo_group .== "high"] .== "norm")
cm[2, 2] = count(clo_group_pred[clo_group .== "high"] .== "high")
cm[2, 1] = count(clo_group_pred[clo_group .== "norm"] .== "high")

println("Confusion matrix:")
println("  misclassification rate: ", round(sum([cm[1, 2], cm[2, 1]]) / sum(cm), digits=2))
println("  accuracy: ", round(1 - sum([cm[1, 2], cm[2, 1]]) / sum(cm), digits=2))
println("""
                     group
                  norm   high   
                ┌──────┬──────┐
           norm │ $(lpad(cm[1, 1], 4, " ")) │ $(lpad(cm[1, 2], 4, " ")) │
prediction      ├──────┼──────┤
           high │ $(lpad(cm[2, 1], 4, " ")) │ $(lpad(cm[2, 2], 4, " ")) │
                └──────┴──────┘
         """)

println("Classification adjusted for predicted norclozapine level:")
clo_group_pred_adj = repeat(["norm"], length(clo_level_pred))
clo_group_pred_adj[clo_level_pred .> 550] .= "high"
clo_group_pred_adj[nclo_level_pred .>= 400] .= "high"
clo_group_pred_adj[nclo_level_pred .< 400] .= "norm"

cm = zeros(Int64, 2, 2)
cm[1, 1] = count(clo_group_pred_adj[clo_group .== "norm"] .== "norm")
cm[1, 2] = count(clo_group_pred_adj[clo_group .== "high"] .== "norm")
cm[2, 2] = count(clo_group_pred_adj[clo_group .== "high"] .== "high")
cm[2, 1] = count(clo_group_pred_adj[clo_group .== "norm"] .== "high")

println("Confusion matrix:")
println("  misclassification rate: ", round(sum([cm[1, 2], cm[2, 1]]) / sum(cm), digits=2))
println("  accuracy: ", round(1 - sum([cm[1, 2], cm[2, 1]]) / sum(cm), digits=2))
println("""
                     group
                  norm   high   
                ┌──────┬──────┐
           norm │ $(lpad(cm[1, 1], 4, " ")) │ $(lpad(cm[1, 2], 4, " ")) │
prediction      ├──────┼──────┤
           high │ $(lpad(cm[2, 1], 4, " ")) │ $(lpad(cm[2, 2], 4, " ")) │
                └──────┴──────┘
         """)


#=
yhat2 = MLJ.predict(model_classifier, x)
println("Classifier:")
yhat2_adj_p = zeros(2, length(yhat2))
for idx in eachindex(yhat2)
    yhat2_adj_p[1, idx] = yhat2.prob_given_ref[:1][idx]
    yhat2_adj_p[2, idx] = yhat2.prob_given_ref[:2][idx]
end
for idx in eachindex(yhat2)
    print("Subject ID: $idx \t group: $(uppercase(String(y2[idx]))) \t")
    p_high = Float64(broadcast(pdf, yhat2[idx], "high"))
    p_norm = Float64(broadcast(pdf, yhat2[idx], "norm"))
    if p_norm > p_high
        print("prediction: NORM, prob = $(round(p_norm, digits=2)) \t")
    else
        print("prediction: HIGH, prob = $(round(p_high, digits=2)) \t")
    end
    if yhat1[idx] > 550
        p_high += 0.1
        p_norm -= 0.1
    else
        p_norm += 0.1
        p_high -= 0.1
    end
    if yhat3[idx] > 400
        p_high += 0.4
        p_norm -= 0.4
    else
        p_norm += 0.4
        p_high -= 0.4
    end
    p_high > 1.0 && (p_high = 1.0)
    p_high < 0.0 && (p_high = 0.0)
    p_norm > 1.0 && (p_norm = 1.0)
    p_norm < 0.0 && (p_norm = 0.0)
    yhat2_adj_p[1, idx] = p_high
    yhat2_adj_p[2, idx] = p_norm

    if p_norm > p_high
        println("adj. prediction: NORM, prob = $(round(p_norm, digits=2))")
    else
        println("adj. prediction: HIGH, prob = $(round(p_high, digits=2))")
    end
end
println()

yhat2_adj = deepcopy(yhat2)
for idx in eachindex(yhat2)
    yhat2_adj.prob_given_ref[:1][idx] = yhat2_adj_p[1, idx]
    yhat2_adj.prob_given_ref[:2][idx] = yhat2_adj_p[2, idx] 
end

println("Classifier accuracy:")
println("  cross-entropy: ", round(cross_entropy(yhat2, y2), digits=2))
println("  log-loss: ", round(log_loss(yhat2, y2) |> mean, digits=2))
println("  AUC: ", round(auc(yhat2, y2), digits=2))
println("  misclassification rate: ", round(misclassification_rate(mode.(yhat2), y2), digits=2))
println("  accuracy: ", round(1 - misclassification_rate(mode.(yhat2), y2), digits=2))
println("Confusion matrix:")
cm = confusion_matrix(mode.(yhat2), y2)
println("  sensitivity (TP): ", round(cm.mat[1, 1] / sum(cm.mat[:, 1]), digits=2))
println("  specificity (TP): ", round(cm.mat[2, 2] / sum(cm.mat[:, 2]), digits=2))
println("""
                     group
                  norm   high   
                ┌──────┬──────┐
           norm │ $(lpad(cm.mat[4], 4, " ")) │ $(lpad(cm.mat[2], 4, " ")) │
prediction      ├──────┼──────┤
           high │ $(lpad(cm.mat[3], 4, " ")) │ $(lpad(cm.mat[1], 4, " ")) │
                └──────┴──────┘
         """)
println("Adjusted classifier accuracy:")
println("  cross-entropy: ", round(cross_entropy(yhat2_adj, y2), digits=2))
println("  log-loss: ", round(log_loss(yhat2_adj, y2) |> mean, digits=2))
println("  AUC: ", round(auc(yhat2_adj, y2), digits=2))
println("  misclassification rate: ", round(misclassification_rate(mode.(yhat2_adj), y2), digits=2))
println("  accuracy: ", round(1 - misclassification_rate(mode.(yhat2_adj), y2), digits=2))
println("Confusion matrix:")
cm = confusion_matrix(mode.(yhat2_adj), y2)
println("  sensitivity (TP): ", round(cm.mat[1, 1] / sum(cm.mat[:, 1]), digits=2))
println("  specificity (TP): ", round(cm.mat[2, 2] / sum(cm.mat[:, 2]), digits=2))
println("""
                     group
                  norm   high   
                ┌──────┬──────┐
           norm │ $(lpad(cm.mat[4], 4, " ")) │ $(lpad(cm.mat[2], 4, " ")) │
prediction      ├──────┼──────┤
           high │ $(lpad(cm.mat[3], 4, " ")) │ $(lpad(cm.mat[1], 4, " ")) │
                └──────┴──────┘
         """)

=#

p1 = Plots.plot(clo_level .- clo_level_pred, ylims=(-400, 400), xlabel="patients", title="clozapine", legend=false)
# p1 = Plots.plot!(clo_level_pred, line=:dot, lw=2)
p2 = Plots.plot(nclo_level .- nclo_level_pred, ylims=(-400, 400), xlabel="patients", ylabel="error", title="norclozapine", legend=false)
# p2 = Plots.plot!(nclo_level_pred, label="prediction", line=:dot, lw=2)
p = Plots.plot(p1, p2, layout=(2, 1))
savefig(p, "images/rr_testing_accuracy.png")
