# Toys4EWMV-SLC

**An academic step-by-step tutorial for fitting the EWMV-SLC model to
Balloon Analogue Risk Task (BART) data with `cmdstanr`.**

EWMV-SLC is a hierarchical Bayesian cognitive model of risky decision-making
introduced by **Wei et al. (2026)** in the *Journal of Behavioral Addictions*
("Diminishing loss sensitivity during risky decision-making among male
individuals with gambling disorder"). It extends the **Exponential-Weight
Mean–Variance (EWMV)** model with a *diminishing loss sensitivity* parameter
(ζ, `zeta`), which captures how loss aversion grows *slower* as loss magnitude
increases — a key mechanism differentiating individuals with gambling disorder
(GD) from healthy controls.

This repository contains:

- the fully commented Stan model (`_scripts/bart_ewmv-slc.stan`),
- a complete `cmdstanr` fitting pipeline (`_scripts/cmdstanr.R`),
- an annotated Quarto tutorial (`cmdstanr.qmd`),
- a small BART sample dataset (`_data/bart_sample.csv`).

## Code provenance

Our code is adapted from:

- **Park, Yang, Vassileva & Ahn (2021)**, *Development of a novel computational
  model for the Balloon Analogue Risk Task: The exponential-weight mean–variance
  model*, *Journal of Mathematical Psychology* (the original EWMV model);
- the **hBayesDM** project (**Ahn, Haines & Zhang, 2017**,
  *Computational Psychiatry*; <https://github.com/CCS-Lab/hBayesDM/>).

In addition, we re-implemented the pipeline on top of the **cmdstanr** framework
and exploited CmdStan's `reduce_sum` with `threads_per_chain`, enabling
**within-chain (chain-parallel) computation**: chains run in parallel *and*
each chain splits the per-subject likelihood across multiple CPU threads. This
makes full use of multi-core CPUs and greatly improves computational speed and
fitting efficiency compared with the classical `rstan` implementation.

---

## TL;DR — run it in 3 steps

::: {.callout-note}
You only need **Docker**. No local R, no C++ toolchain, no CmdStan setup.
:::

```bash
# 1. Pull the environment (image will be published soon)
docker pull koalalive/cmdstanr4cogneuro:1.0.1

# 2. Run the full fitting pipeline inside the container
#    (Windows PowerShell: replace $(pwd) with %CD%)
#    NOTE: R is not on the default PATH, always use the full path below.
docker run --rm -v "$(pwd)":/root/stan -w /root/stan \
  koalalive/cmdstanr4cogneuro:1.0.1 \
  /root/miniconda3/envs/stan/bin/Rscript _scripts/cmdstanr.R

# 3. (Optional) open the project in RStudio Server (browser IDE): see below
```

**What to expect (measured on a 16-core machine):** model compilation takes
about 1–2 minutes on the first run; the MCMC fit (4 chains × 1000 posterior
draws, 3 threads per chain) takes about 2.5 minutes. Results are written to
`_rds/` (sampler CSV output, a saved `.rds` fit, and `trace_mu_zeta.png`).

::: {.callout-tip}
## For AI agents

- Always run from the repository **root** (the paths `_scripts/...`, `_data/...`
  are relative to it).
- **R is not on `$PATH`** inside the image — use the full interpreter path:
  `/root/miniconda3/envs/stan/bin/Rscript` (or `/root/miniconda3/envs/stan/bin/R`).
- The script `_scripts/cmdstanr.R` already forces the image's conda toolchain
  (GCC 14 + conda libstdc++) so model compilation succeeds without extra
  environment setup — do not override `LDFLAGS`/`LD_LIBRARY_PATH` yourself.
- Optional speed-up: cache compiled models across runs with a named volume:
  add `-v cmdstan_cache:/root/.cmdstanr` (compilation happens only the first
  time per volume).
- Known limitation: `rstan::read_stan_csv()` cannot fully parse the CmdStan
  2.37 CSV header (rstan 2.32.x expects `save_warmup = 0`, CmdStan 2.37 writes
  `save_warmup = false`). The script detects this and continues with
  `cmdstanr`/`posterior` results — no action needed.
:::

---

## 中文快速上手 (Chinese Quick Start)

这个项目是 **Wei et al. (2026, *Journal of Behavioral Addictions*)** 一文中
**EWMV-SLC 模型**（带有"损失敏感性递减"机制的层级贝叶斯 BART 决策模型）的
学术复现教程。代码改编自 **Park et al. (2021)** 的 EWMV 模型和 **hBayesDM**
项目，并在此基础上引入 **cmdstanr** 框架，通过 `reduce_sum` + `threads_per_chain`
实现**链内并行**，充分利用多核 CPU，显著提高运算速度和拟合效率。

**只装 Docker 就能跑（不需要装 R）：**

```bash
docker pull koalalive/cmdstanr4cogneuro:1.0.1

# Windows PowerShell 用 %CD% 替代 $(pwd)
# 注意：镜像里 R 不在默认 PATH，必须用完整路径
docker run --rm -v "%CD%":/root/stan -w /root/stan \
  koalalive/cmdstanr4cogneuro:1.0.1 \
  /root/miniconda3/envs/stan/bin/Rscript _scripts/cmdstanr.R
```

时间预期（16 核实测）：首次编译约 1–2 分钟；4 链 × 1000 抽样、每链 3 线程，
约 2.5 分钟。

---

## 人用：RStudio Server（浏览器 IDE，端口 8787）

想用 IDE 手动跑代码（"古法编程"）？把需要的文件夹挂载到容器内的
**`/root/stan`**，映射 **8787 端口**，然后浏览器打开 **`http://localhost:8787`**
即可。

```bash
# Windows PowerShell 用 %CD% 替代 $(pwd)
docker run -d --name ewmv-rstudio \
  -p 8787:8787 \
  -e RS_PASSWORD=rstudio \                # 改成你自己的密码
  -v "$(pwd)":/root/stan \                # 挂载项目/示例文件夹
  koalalive/cmdstanr4cogneuro:1.0.1 \
  bash /root/stan/_scripts/start_rstudio.sh
```

- **浏览器打开** `http://localhost:8787`，登录用户名 **`rstudio-server`**，
  密码为上面 `RS_PASSWORD` 设置的值（默认 `rstudio`）。
- **挂载自己的数据**：再加一个卷即可，例如
  `-v "D:/my_data":/root/stan/data`，你的 CSV 就会出现在项目文件夹里。
- 项目文件夹整体挂载在容器内 `/root/stan`，进入 RStudio 后打开
  `Toys4EWMV-SLC.Rproj` 项目，工作目录即为你挂载的文件夹。

---

## What is BART? What is EWMV-SLC?

**BART (Balloon Analogue Risk Task)** is a classic behavioral measure of risky
decision-making: participants inflate a virtual balloon, each pump gains money
but increases the chance of an explosion (which loses the money on that trial).
Pumping decisions reveal how people trade off reward vs. risk.

**Hierarchical Bayesian models** of BART assume each participant has their own
(a) subjective belief about the explosion probability, (b) loss aversion, and
(c) decision sensitivity, all drawn from group-level distributions. The model
outputs group-level parameters (e.g. `mu_zeta`), which can then be compared
between groups (e.g. GD vs. controls), and subject-level parameters for
individual differences.

**EWMV-SLC** (exponential-weight mean–variance with diminishing loss
sensitivity) adds to the EWMV model a loss-sensitivity exponent ζ that lets the
effective loss weight *diminish* as the accumulated loss grows, better
describing real loss evaluation. See the paper for details on the GD findings.

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

The image [`koalalive/cmdstanr4cogneuro:1.0.1`](https://hub.docker.com/r/koalalive/cmdstanr4cogneuro)
(published in the near future) bundles R with CmdStan, `cmdstanr`, `posterior`,
`bayesplot`, `loo`, `tidyverse`, and `rstan`, so nothing has to be installed
locally.

**Alternative: local installation** (for experienced users)

- R ≥ 4.1, a working C++ toolchain (RTools on Windows / Xcode on macOS / g++
  on Linux) and CmdStan (`cmdstanr::install_cmdstan()`);
- R packages: `cmdstanr`, `posterior`, `bayesplot`, `loo`, `tidyverse`, `rstan`.

## Reproduce the analysis

The single entry point is `_scripts/cmdstanr.R`. It does:

1. **Preprocess** — `bart_fit_preprocess()` reshapes the long-format data into
   the `N × T` matrices expected by Stan (`data_list`).
2. **Compile** — `cmdstan_model(cpp_options = list(stan_threads = TRUE))`
   (with threading enabled, required by `reduce_sum`).
3. **Sample** — `model$sample()` with `parallel_chains = 4` (chains in parallel)
   and `threads_per_chain = 3` (threads within each chain).
4. **Diagnose** — `$summary()`, `$diagnostic_summary()`, and `bayesplot` trace
   plots of the group-level means (`mu_phi` … `mu_zeta`).
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

**Wei, H., Zhong, G., Liu, J., Wei, Y., Zhang, X., Yang, P., Xu, X., Zhao, M., &
Du, J. (2026).** Diminishing loss sensitivity during risky decision-making among
male individuals with gambling disorder. *Journal of Behavioral Addictions*,
*15*(1), 371–383. <https://doi.org/10.1556/2006.2025.00230>

**Park, H., Yang, J., Vassileva, J., & Ahn, W.-Y. (2021).** Development of a
novel computational model for the Balloon Analogue Risk Task: The
exponential-weight mean–variance model. *Journal of Mathematical Psychology*,
*102*, 102532. <https://doi.org/10.1016/j.jmp.2021.102532>

**Ahn, W.-Y., Haines, N., & Zhang, L. (2017).** Revealing neurocomputational
mechanisms of reinforcement learning and decision-making with the hBayesDM
package. *Computational Psychiatry*, *1*(1), 24–57.
<https://doi.org/10.1162/cpsy_a_00002>

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

We sincerely thank **Gangliang Zhong**, **Yujie Bai**, **Lingjie Wei**, and
**Aimin Zhao** for their generous provision of computational resources and
testing support, which made this repository possible.

## License

MIT — see [LICENSE](LICENSE) (© 2025 WEI Hanyu).
