# AGENTS.md — Guide for AI Agents

This file tells AI coding agents how to work with this repository. Follow it
and the README; the quick-start commands below are **verified working**.

## What this project is

- **Topic**: fitting the **EWMV-SLC** hierarchical Bayesian model (BART task:
  Balloon Analogue Risk Task) to behavioral data.
- **Source paper**: Wei et al. (2026), *Journal of Behavioral Addictions*,
  "Diminishing loss sensitivity during risky decision-making among male
  individuals with gambling disorder" ([@wei2026diminishing] in
  `references.bib`).
- **Code provenance**: the model is adapted from Park et al. (2021) *Journal of
  Mathematical Psychology* (EWMV model) and the hBayesDM project (Ahn et al.,
  2017, *Computational Psychiatry*). Our contribution: a cmdstanr pipeline with
  **within-chain threading** (`reduce_sum` + `threads_per_chain`).
- **Environment**: the Docker image `koalalive/stan4cogneuro:1.0.2`
  (R 4.1.3, cmdstanr 0.9.0, CmdStan 2.37.0, RStudio Server on port 8787).

## Quick start (verified)

R is **NOT on `$PATH`** in the image — always use the full interpreter path:

```bash
# Windows PowerShell: replace $(pwd) with %CD%
docker run --rm -v "$(pwd)":/root/stan -w /root/stan \
  koalalive/stan4cogneuro:1.0.2 \
  /root/miniconda3/envs/stan/bin/Rscript _scripts/cmdstanr.R
```

Timing (16 cores, measured): compile ~1–2 min (first run), fit (4 chains ×
1000 draws, 3 threads/chain) ~2.5 min. Outputs go to `_rds/` (sampler CSVs,
`bart_fit_ewmvslc_sample_cmdstan.rds`, `trace_mu_zeta.png`).

For an interactive IDE (RStudio Server starts automatically):

```bash
docker run -it --name ewmv-rstudio -p 8787:8787 \
  -v "$(pwd)":/root/stan \
  koalalive/stan4cogneuro:1.0.2
# then open http://localhost:8787 (default user: rstudio-server / rstudio)
```

## Critical environment facts (do not "fix" them)

1. **R path**: use `/root/miniconda3/envs/stan/bin/Rscript` (and
   `/root/miniconda3/envs/stan/bin/R`).
2. **Toolchain**: the image mixes conda GCC 14 with system GCC 11. Linking the
   wrong libstdc++ fails with `undefined reference to __cxa_call_terminate`.
   `_scripts/cmdstanr.R` already forces the conda toolchain (it sets
   `PATH`/`LD_LIBRARY_PATH`/`LIBRARY_PATH`/`LDFLAGS` if `/root/miniconda3/envs/stan`
   exists). **Do NOT override** these variables yourself.
3. **rstan compatibility**: `rstan::read_stan_csv()` cannot parse CmdStan 2.37
   CSV headers (`save_warmup = false` vs numeric). The script wraps it in
   `tryCatch` and continues — treat this as expected behavior, not a bug.
4. **RStudio login**: username `rstudio-server`; password `rstudio` by default.
   The image starts RStudio Server on startup (no extra bootstrap script needed).

## File map

| Path | What it is |
|------|------------|
| `_data/bart_sample.csv` | Sample data: 3 subjects × 100 trials, columns `subjID, pumps, explosion` |
| `_scripts/bart_ewmv-slc.stan` | EWMV-SLC model (threaded `reduce_sum`); all comments in English |
| `_scripts/bart_fit.R` | `bart_fit_preprocess()` (long→array reshape) + legacy rstan fit function |
| `_scripts/bart_diagnosis.R` | `bart_ewmvslc_diagnosis()` (R-hat + trace plots) |
| `_scripts/cmdstanr.R` | **Main pipeline**: preprocess → compile → sample → diagnose → save → LOO |
| `cmdstanr.qmd` | Annotated English Quarto tutorial (read as source; chunks run in RStudio) |
| `README.md` | Human-facing docs (academic citations, quick start, RStudio guide) |
| `references.bib` | Citation entries: @wei2026diminishing, @park2021exponential, @ahn2017hbayesdm, @cmdstanr |

## What NOT to do

- Do not edit `_scripts/bart_ewmv-slc.stan` model logic without explaining the
  change (it implements the published EWMV-SLC likelihood; utility equation in
  `cmdstanr.qmd` `{#eq-utility}`).
- Do not modify the citation entries in `references.bib` or the acknowledgments
  (Gangliang Zhong, Yujie Bai, Lingjie Wei, Aimin Zhao) in README/`cmdstanr.qmd`.
- Do not commit `_rds/` outputs or compile artifacts (covered by `.gitignore`).
- Do not run heavy fits repeatedly: build on the cached compile (optional
  `-v cmdstan_cache:/root/.cmdstanr` volume) or shrink `iter_sampling` for
  quick tests (edit the `#### SET PARAMETERS ####` block in `cmdstanr.R`).
