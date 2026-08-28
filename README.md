# Toys4EWMV-SLC

**An academic step-by-step tutorial for fitting the EWMV-SLC model to Balloon Analogue Risk Task (BART) data with `cmdstanr`.**

EWMV-SLC is a hierarchical Bayesian cognitive model of risky decision-making introduced by **Wei et al. (2026)** in the *Journal of Behavioral Addictions* ("Diminishing loss sensitivity during risky decision-making among male individuals with gambling disorder"). It extends the **Exponential-Weight Mean–Variance (EWMV)** model with a *diminishing loss sensitivity* parameter (ζ, `zeta`), which captures how loss aversion grows *slower* as loss magnitude increases — a key mechanism differentiating individuals with gambling disorder (GD) from healthy controls.

This repository contains:

- the fully commented Stan model (`_scripts/bart_ewmv-slc.stan`),
- a complete `cmdstanr` fitting pipeline (`_scripts/cmdstanr.R`),
- an annotated Quarto tutorial (`cmdstanr.qmd`),
- a small BART sample dataset (`_data/bart_sample.csv`).

## Code provenance

Our code is adapted from:

- **Park, Yang, Vassileva & Ahn (2021)**, *Development of a novel computational model for the Balloon Analogue Risk Task: The exponential-weight mean–variance model*, *Journal of Mathematical Psychology* (the original EWMV model);
- the **hBayesDM** project (**Ahn, Haines & Zhang, 2017**, *Computational Psychiatry*; <https://github.com/CCS-Lab/hBayesDM/>).

In addition, we re-implemented the pipeline on top of the **cmdstanr** framework and exploited CmdStan's `reduce_sum` with `threads_per_chain`, enabling **within-chain (chain-parallel) computation**: chains run in parallel *and* each chain splits the per-subject likelihood across multiple CPU threads. This makes full use of multi-core CPUs and greatly improves computational speed and fitting efficiency compared with the classical `rstan` implementation.

---

## New to Docker? A quick primer

**What is Docker?** Docker runs pre-packaged environments ("images") on your
computer inside isolated containers. You do not need to install R, CmdStan, or
any R package: the image `koalalive/stan4cogneuro:1.0.2` already contains
everything, and your project folder is attached ("mounted") into the container
so results land on your computer.

**New to the command line?** Every command in this README is typed in a
terminal (Windows: search "PowerShell" or press `Win+R` then `cmd`; macOS:
`Cmd+Space` → "Terminal"; Linux: `Ctrl+Alt+T`). A beginner-friendly walkthrough
of the basics (opening a terminal, `cd`, `dir`/`ls`, pasting commands) is in
`cmdstanr.qmd`, section "Command line basics".

**Why use Docker for this tutorial?**

- **Deployment made simple:** the whole environment (R 4.1.3, CmdStan,
  `cmdstanr`, `posterior`, `bayesplot`, `loo`, `tidyverse`) already lives inside
  one image. One `docker run` command is all you need — no installing
  compilers, no package version conflicts, no "it works on my machine".
- **Reproducibility by design:** the image pins exact software versions, so the
  pipeline behaves identically on any computer, today and years from now. For
  academic work this is essential: co-authors, reviewers, or a future you can
  re-run the analysis and obtain the same results.
- **Easy to share:** the environment travels with the image on Docker Hub
  (`koalalive/stan4cogneuro:1.0.2`), not with your computer. Anyone with Docker
  — on Windows, macOS, or Linux — can run the same analysis without touching
  their local setup.

**Terms you will see below:**

| Term | Meaning |
|------|---------|
| image | The ready-made environment (e.g. `koalalive/stan4cogneuro:1.0.2`) |
| container | One running instance of an image (e.g. your `ewmv-rstudio`) |
| volume (`-v`) | Attaches a folder from your computer into the container, e.g. `-v "$(pwd)":/root/stan` |
| port (`-p`) | Maps a container port to your computer, e.g. `-p 8787:8787` |

**Step 0 — Install Docker (once):**

- **Windows** (Docker Desktop, uses the WSL2 backend):
  <https://docs.docker.com/desktop/setup/install/windows-install/>
- **macOS** (Docker Desktop): <https://docs.docker.com/desktop/setup/install/mac-install/>
- **Linux** (Docker Engine): <https://docs.docker.com/engine/install/>

Verify the installation in a terminal:

```bash
docker --version
```

**Step 1 — Common commands:**

| Command | What it does |
|---------|--------------|
| `docker pull koalalive/stan4cogneuro:1.0.2` | Download the image (needed once) |
| `docker run ...` | Start a container from the image (use the commands in this README) |
| `docker ps` | List running containers |
| `docker ps -a` | List all containers, including stopped ones |
| `docker logs ewmv-rstudio` | Show the container's output |
| `docker stop ewmv-rstudio` | Stop a running container |
| `docker rm ewmv-rstudio` | Remove a stopped container (files in mounted folders stay on your computer) |
| `docker rm -f ewmv-rstudio` | Stop and remove in one command |

**Troubleshooting:**

- **`'docker' is not recognized` / `command not found`**: Docker Desktop is not
  installed or not started. Install it (links above), restart your terminal,
  and make sure Docker Desktop is actually running.
- **Windows asks for WSL2**: Docker Desktop installs/updates it automatically;
  if you need it manually: <https://learn.microsoft.com/en-us/windows/wsl/install>
- **`port is already allocated`**: something else is using port 8787. Find it
  with `docker ps` and stop it, or map a different host port instead:
  `-p 8788:8787` and open `http://localhost:8788`.
- **`the container name is already in use`**: remove the old one first —
  `docker rm -f ewmv-rstudio`.
- **Browser shows nothing**: check `docker ps` — the container must be listed
  with status `Up`.

---

## Run it in 3 steps

::: {.callout-note}
You only need **Docker**. No local R, no C++ toolchain, no CmdStan setup.
:::

```bash
# 1. Pull the environment
docker pull koalalive/stan4cogneuro:1.0.2

# 2. Run the full fitting pipeline inside the container
#    (PowerShell: ${PWD}, CMD: %CD%, Bash/Zsh: $(pwd))
#    NOTE: R is not on the default PATH, always use the full path below.
docker run --rm -v "$(pwd)":/root/stan -w /root/stan \
  koalalive/stan4cogneuro:1.0.2 \
  /root/miniconda3/envs/stan/bin/Rscript _scripts/cmdstanr.R

# 3. (Optional) open the project in RStudio Server (browser IDE): see below
```

**What to expect (measured on a 16-core machine):** model compilation takes about 1–2 minutes on the first run; the MCMC fit (4 chains × 1000 posterior draws, 3 threads per chain) takes about 2.5 minutes. Results are written to `_rds/` (sampler CSV output, a saved `.rds` fit, and `trace_mu_zeta.png`).

::: {.callout-tip}
## For AI agents

- Always run from the repository **root** (the paths `_scripts/...`, `_data/...` are relative to it).
- **R is not on `$PATH`** inside the image — use the full interpreter path: `/root/miniconda3/envs/stan/bin/Rscript` (or `/root/miniconda3/envs/stan/bin/R`).
- The script `_scripts/cmdstanr.R` already forces the image's conda toolchain (GCC 14 + conda libstdc++) so model compilation succeeds without extra environment setup — do not override `LDFLAGS`/`LD_LIBRARY_PATH` yourself.
- Optional speed-up: cache compiled models across runs with a named volume: add `-v cmdstan_cache:/root/.cmdstanr` (compilation happens only the first time per volume).
- Known limitation: `rstan::read_stan_csv()` cannot fully parse the CmdStan 2.37 CSV header (rstan 2.32.x expects `save_warmup = 0`, CmdStan 2.37 writes `save_warmup = false`). The script detects this and continues with `cmdstanr`/`posterior` results — no action needed.
:::

---

## Human-friendly: RStudio Server (browser IDE, port 8787)

Want to run the code interactively in an IDE? Mount the folder you need into **`/root/stan`** inside the container — RStudio Server starts automatically — and open **`http://localhost:8787`** in your browser.

**Bash (macOS / Linux):**

```bash
docker run -it --name ewmv-rstudio -p 8787:8787 \
  -v "$(pwd)":/root/stan \
  koalalive/stan4cogneuro:1.0.2
```

**Zsh (macOS / Linux):**

```zsh
docker run -it --name ewmv-rstudio -p 8787:8787 \
  -v "$(pwd)":/root/stan \
  koalalive/stan4cogneuro:1.0.2
```

**Windows PowerShell:**

```powershell
docker run -it --name ewmv-rstudio -p 8787:8787 `
  -v "${PWD}:/root/stan" `
  koalalive/stan4cogneuro:1.0.2
```

**Windows CMD:**

```bat
docker run -it --name ewmv-rstudio -p 8787:8787 -v "%CD%":/root/stan koalalive/stan4cogneuro:1.0.2
```

- **Open** `http://localhost:8787` in your browser and log in with the RStudio account of the image (default: user `rstudio-server`, password `rstudio` — customize if your image uses different credentials).
- **Mount your own data**: add another volume, e.g. `-v "D:/my_data":/root/stan/data`, and your CSV files will appear inside the project folder.
- The mount point inside the container is **`/root/stan`** — open that folder yourself from RStudio's Files pane (or open the `Toys4EWMV-SLC.Rproj` project if present); the mounted folder is your working directory.

---

## What is BART? What is EWMV-SLC?

**BART (Balloon Analogue Risk Task)** is a classic behavioral measure of risky decision-making: participants inflate a virtual balloon, each pump gains money but increases the chance of an explosion (which loses the money on that trial). Pumping decisions reveal how people trade off reward vs. risk.

**Hierarchical Bayesian models** of BART assume each participant has their own (a) subjective belief about the explosion probability, (b) loss aversion, and (c) decision sensitivity, all drawn from group-level distributions. The model outputs group-level parameters (e.g. `mu_zeta`), which can then be compared between groups (e.g. GD vs. controls), and subject-level parameters for individual differences.

**EWMV-SLC** (exponential-weight mean–variance with diminishing loss sensitivity) adds to the EWMV model a loss-sensitivity exponent ζ that lets the effective loss weight *diminish* as the accumulated loss grows, better describing real loss evaluation. See the paper for details on the GD findings.

## Project structure

| Path | What it is |
|------|------------|
| `_data/bart_sample.csv` | Sample BART data (long format: `subjID, pumps, explosion`) |
| `_scripts/bart_ewmv-slc.stan` | The EWMV-SLC Stan model (threaded with `reduce_sum`) |
| `_scripts/bart_fit.R` | Data preprocessing (`bart_fit_preprocess`) + the classic `rstan` reference fit |
| `_scripts/bart_diagnosis.R` | R-hat & trace-plot diagnosis helper (`bart_ewmvslc_diagnosis`) |
| `_scripts/cmdstanr.R` | The minimal `cmdstanr` pipeline (compile → sample → diagnose → LOO) |
| `cmdstanr.qmd` | Annotated Quarto tutorial explaining every step |
| `_rds/` | Saved fits (`.rds`) and CmdStan CSV output files |

## Environment

**Recommended: one Docker image for everything.**

The image [`koalalive/stan4cogneuro:1.0.2`](https://hub.docker.com/r/koalalive/stan4cogneuro) (available on Docker Hub) bundles R with CmdStan, `cmdstanr`, `posterior`, `bayesplot`, `loo`, `tidyverse`, and `rstan`, so nothing has to be installed locally.

**Alternative: local installation** (for experienced users)

- R ≥ 4.1, a working C++ toolchain (RTools on Windows / Xcode on macOS / g++ on Linux) and CmdStan (`cmdstanr::install_cmdstan()`);
- R packages: `cmdstanr`, `posterior`, `bayesplot`, `loo`, `tidyverse`, `rstan`.

## Reproduce the analysis

The single entry point is `_scripts/cmdstanr.R`. It does:

1. **Preprocess** — `bart_fit_preprocess()` reshapes the long-format data into the `N × T` matrices expected by Stan (`data_list`).
2. **Compile** — `cmdstan_model(cpp_options = list(stan_threads = TRUE))` (with threading enabled, required by `reduce_sum`).
3. **Sample** — `model$sample()` with `parallel_chains = 4` (chains in parallel) and `threads_per_chain = 3` (threads within each chain).
4. **Diagnose** — `$summary()`, `$diagnostic_summary()`, and `bayesplot` trace plots of the group-level means (`mu_phi` … `mu_zeta`).
5. **Compare** — LOO-CV (`loo`) on the pointwise `log_lik` for model comparison.

### Why cmdstanr (vs. rstan)?

| | `rstan` (`bart_fit.R`) | `cmdstanr` (this tutorial) |
|---|---|---|
| Sampling backend | RStan (BH) | CmdStan C++ executable |
| Chain parallelism | yes (`mc.cores`) | yes (`parallel_chains`) |
| Within-chain threads | no | **yes** (`threads_per_chain` + `reduce_sum`) |
| Multi-core utilization | one process per chain | **chains × threads simultaneously** |
| Output format | `stanfit` | `CmdStanMCMC` (`posterior` draws) |

## Model parameters (EWMV-SLC)

| Parameter | Meaning | Constraint |
|-----------|---------|------------|
| `phi[j]` | Initial subjective explosion probability | (0, 1) |
| `eta[j]` | Learning rate updating the belief from trial feedback | (0, 1) |
| `rho[j]` | Mean–variance (risk) correction weight | (-0.5, 0.5) |
| `tau[j]` | Decision temperature (inverse sensitivity) | (0, ∞) |
| `lambda[j]` | Loss aversion | (0, ∞) |
| `zeta[j]` | **Diminishing loss sensitivity exponent** (novel in EWMV-SLC) | (0, ∞) |
| `mu_*` | Group-level means of the parameters above | derived |

## Citation

If you use this repository, please cite the source paper and the adapted works:

**Wei, H., Zhong, G., Liu, J., Wei, Y., Zhang, X., Yang, P., Xu, X., Zhao, M., & Du, J. (2026).** Diminishing loss sensitivity during risky decision-making among male individuals with gambling disorder. *Journal of Behavioral Addictions*, *15*(1), 371–383. <https://doi.org/10.1556/2006.2025.00230>

**Park, H., Yang, J., Vassileva, J., & Ahn, W.-Y. (2021).** Development of a novel computational model for the Balloon Analogue Risk Task: The exponential-weight mean–variance model. *Journal of Mathematical Psychology*, *102*, 102532. <https://doi.org/10.1016/j.jmp.2021.102532>

**Ahn, W.-Y., Haines, N., & Zhang, L. (2017).** Revealing neurocomputational mechanisms of reinforcement learning and decision-making with the hBayesDM package. *Computational Psychiatry*, *1*(1), 24–57. <https://doi.org/10.1162/cpsy_a_00002>

```bibtex
@article{wei2026diminishing,
  author  = {Wei, Hanyu and Zhong, Gangliang and Liu, Jingyang and Wei, Yicheng
             and Zhang, Xiyuan and Yang, Peiqiong and Xu, Xin and Zhao, Min
             and Du, Jiang},
  title   = {Diminishing loss sensitivity during risky decision-making among
             male individuals with gambling disorder},
  journal = {Journal of Behavioral Addictions},
  volume  = {15},
  number  = {1},
  pages   = {371--383},
  year    = {2026},
  doi     = {10.1556/2006.2025.00230}
}

@article{park2021exponential,
  author  = {Park, Harhim and Yang, Jaeyeong and Vassileva, Jasmin
             and Ahn, Woo-Young},
  title   = {Development of a novel computational model for the Balloon
             Analogue Risk Task: The exponential-weight mean--variance model},
  journal = {Journal of Mathematical Psychology},
  volume  = {102},
  pages   = {102532},
  year    = {2021},
  doi     = {10.1016/j.jmp.2021.102532}
}

@article{ahn2017hbayesdm,
  author  = {Ahn, Woo-Young and Haines, Nathaniel and Zhang, Lei},
  title   = {Revealing neurocomputational mechanisms of reinforcement learning
             and decision-making with the {hBayesDM} package},
  journal = {Computational Psychiatry},
  volume  = {1},
  number  = {1},
  pages   = {24--57},
  year    = {2017},
  doi     = {10.1162/cpsy_a_00002}
}
```

Also cite the `cmdstanr` package when using this pipeline:

> Gabry, J., Češnovar, R., Johnson, A., & Bronder, S. (2023). *cmdstanr: R
> Interface to 'CmdStan'* [Computer software]. The Stan Development Team.
> <https://mc-stan.org/cmdstanr/>

## Acknowledgments

We sincerely thank **Gangliang Zhong**, **Yujie Bai**, **Lingjie Wei**, and **Aimin Zhao** for their generous provision of computational resources and testing support, which made this repository possible.

## License

MIT — see [LICENSE](LICENSE) (© 2025 WEI Hanyu).
