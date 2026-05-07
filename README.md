# Sparse Sensor Placement in Multi-Agent Reinforcement Learning Control of Rayleigh-Bénard Convection

This repository contains the public code accompanying the paper **"Sparse Sensor Placement in Multi-Agent Reinforcement Learning Control of Rayleigh-Bénard Convection"**.

The code supports RL training for fixed and varying initial conditions, deterministic evaluation of trained agents, and expert-apprentice training for sparse sensor placement.

## Repository Structure

- `FixedICTraining/`: RL training scripts for fixed initial conditions.
  - `train_fixed_ic_ppo.jl`
  - `train_fixed_ic_mat.jl`
- `VaryingICTraining/`: RL training scripts for varying initial conditions.
  - `train_varying_ic_ppo.jl`
  - `train_varying_ic_mat.jl`
  - `varying_ic.jl`, a compatibility wrapper used by apprentice training.
- `ApprenticeTraining/`: expert-apprentice distillation and pruning workflow.
  - `ApprenticeTraining.jl`
- `validation/`: validation helpers for fixed and varying initial conditions.
- `data/`: initial condition model states used by the Oceananigans simulations.
- `RL/`: repository-local snapshot of the custom Julia `RL` package.
- `saves/` directories: curated pretrained agents, hooks, masks, apprentice states, and validation outputs.

## Setup

Install Julia and start from the repository root.

Initialize the project environment with:

```bash
julia setup.jl
```

The setup script activates this repository, develops the local `RL/` package, and instantiates dependencies:

```julia
using Pkg

Pkg.activate(@__DIR__)
Pkg.develop(path=joinpath(@__DIR__, "RL"))
Pkg.instantiate()
```

For interactive work, start Julia from the repository root with:

```bash
julia --project=.
```

The top-level `Project.toml` resolves the custom RL package via:

```toml
[sources]
RL = { path = "RL" }
```

This means the project uses the checked-in `RL/` snapshot instead of a package registry or a local Julia dev path.

## RL Training

The RL scripts define the simulation, agent, training loop, save/load helpers, and deterministic rollout utilities. They are intended to be loaded into an interactive Julia session.

### Fixed Initial Conditions

For fixed-IC PPO:

```julia
include("FixedICTraining/train_fixed_ic_ppo.jl")
train()
```

For fixed-IC MAT:

```julia
include("FixedICTraining/train_fixed_ic_mat.jl")
train()
```

Run a deterministic test episode with the current agent:

```julia
render_run()
```

Saved agents can be loaded with the script-local `load` helper, for example:

```julia
load()
load(1001)
```

The exact available save numbers depend on the files present in `FixedICTraining/saves/`.

### Varying Initial Conditions

For varying-IC PPO:

```julia
include("VaryingICTraining/train_varying_ic_ppo.jl")
train()
```

For varying-IC MAT:

```julia
include("VaryingICTraining/train_varying_ic_mat.jl")
train()
```

Run a deterministic test episode with:

```julia
render_run()
```

For varying initial conditions, deterministic validation over the predefined validation offsets is available through:

```julia
validate_agent(use_apprentice = false)
```

`train_varying_ic_mat.jl` loads the varying-IC validation helper automatically. If you work from another script/session and `validate_agent` is not defined, load it explicitly:

```julia
include("validation/varying_ic_validation.jl")
```

Saved agents can be loaded via:

```julia
load()
load(9001)
```

The apprentice workflow uses the varying-IC MAT expert save `load(9001)` by default.

## Apprentice Training and Sparse Sensor Placement

The apprentice workflow is defined in:

```julia
include("ApprenticeTraining/ApprenticeTraining.jl")
```

At the top of `ApprenticeTraining.jl` (currently lines 8 and 9), configure the experiment case:

```julia
randomIC = true
group_channels = false
```

- `randomIC = false`: fixed initial condition setting.
- `randomIC = true`: varying initial condition setting.
- `group_channels = true`: temperature, vertical velocity, and horizontal velocity are grouped at each sensor location.
- `group_channels = false`: RBC channels are treated separately during pruning.

The corresponding MAT expert is loaded automatically:

- fixed IC: `FixedICTraining/train_fixed_ic_mat.jl` with `load()`
- varying IC: `VaryingICTraining/varying_ic.jl` with `load(9001)`

### Starting Apprentice Training

The main training entry points are:

```julia
gro_asc_train()
reweight_train()
lasso_train()
growl_train()
```

The naming used in the paper is:

- `gro_asc_train()`: **Group Ordered (ascending)**
- `reweight_train()`: **Group Reweighted**

`lasso_train()` and `growl_train()` are additional pruning variants kept for comparison.

The proximal-operator strengths and related method constants are defined in `APPRENTICE_KIND_CONFIG` in `ApprenticeTraining.jl` (currently around line 115). After editing this constant, reload the full file before running a new training session, because Julia constants are not safely updated in-place.

### Loading Apprentice Save States

Curated apprentice save states are included for the available combinations of:

- fixed or varying initial conditions
- grouped or separate RBC channels
- pruning method

Load them with:

```julia
gro_asc_load()
reweight_load()
lasso_load()
growl_load()
```

These functions default to the current `randomIC` and `group_channels` settings. They can also be called with explicit keyword arguments when needed, for example:

```julia
reweight_load(group_channels_value = true, rIC = false)
```

### Creating and Using Masks

After training or loading an apprentice, create a binary sensor mask from the learned encoder input weights:

```julia
update_mask()
```

The default threshold is `0.0`. A larger threshold increases sparsity, but also increases the risk that the apprentice loses control performance. Recommended values are below `0.01`:

```julia
update_mask(0.005)
```

Visualize the currently masked apprentice observation windows with:

```julia
plot_masked_input()
```

This function plots the masked observation window for the three RBC channels (temperature, vertical velocity, and horizontal velocity), then overlays the masked windows over the full sensor grid. It also prints the sparsity rates used in the paper analysis:

- window sparsity over all channel-specific inputs
- window sparsity with combined channels
- total sparsity with combined channels after overlaying all agent windows

By default, the mask plot is binary. To inspect the non-binary encoder back-projection values together with the mask, use:

```julia
plot_masked_input(binary = false)
```

### Evaluating Apprentices

For fixed initial conditions:

```julia
same_day_fixed(use_apprentice = true)
```

For varying initial conditions:

```julia
validate_agent(use_apprentice = true)
```

Both workflows use deterministic policy evaluation and display performance plots after evaluation.

You can also run a deterministic apprentice rollout with:

```julia
render_run_apprentice()
```

## Notes

- `Project.toml` is tracked at the repository root. A top-level `Manifest.toml` is intentionally not included.
- The custom `RL` package is vendored as a local source snapshot in `RL/`.
- Generated training frames and local scratch outputs should not be committed.
- The included save files are curated public artifacts; newly generated checkpoints should be reviewed before publication.
