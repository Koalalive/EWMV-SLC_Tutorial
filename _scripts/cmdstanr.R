# ============================================================================
# EWMV-SLC model fitting with cmdstanr
# ----------------------------------------------------------------------------
# Pipeline: load data -> preprocess -> compile -> sample -> inspect ->
#           convergence diagnostics -> save -> rstan conversion -> LOO-CV
#
# The model file is _scripts/bart_ewmv-slc.stan. The model is compiled with
# threading support (stan_threads = TRUE) because the likelihood uses Stan's
# reduce_sum, and sampling runs chains in parallel (parallel_chains) while
# each chain also uses multiple worker threads (threads_per_chain).
# ============================================================================

# ============================================================================
# Toolchain setup for the koalalive/stan4cogneuro Docker image
# ----------------------------------------------------------------------------
# This image ships BOTH a conda toolchain (GCC 14) and the system GCC 11.
# Compiling with the system compiler while linking against the conda
# libstdc++ (or the other way round) fails with
#     undefined reference to `__cxa_call_terminate'
# because the two libstdc++ versions expose different CXXABI symbols.
# The block below forces the conda toolchain to be used consistently, so that
# `Rscript _scripts/cmdstanr.R` works with zero extra setup inside Docker.
# On other systems the conda path does not exist and nothing changes.
# ----------------------------------------------------------------------------
stan_conda <- "/root/miniconda3/envs/stan"
if (dir.exists(file.path(stan_conda, "bin"))) {
  Sys.setenv(
    PATH            = paste0(stan_conda, "/bin:", Sys.getenv("PATH")),
    LD_LIBRARY_PATH = paste0(stan_conda, "/lib"),
    LIBRARY_PATH    = paste0(stan_conda, "/lib"),
    LDFLAGS         = paste0("-L", stan_conda, "/lib -Wl,-rpath,", stan_conda, "/lib")
  )
}

library(cmdstanr)  # R interface to CmdStan (compilation, sampling, summaries)
library(posterior) # working with draws objects (draws_array / draws_matrix)
library(bayesplot) # MCMC visualization (trace plots, histograms, intervals)
library(loo)       # leave-one-out cross-validation / WAIC
library(tidyverse) # data manipulation and plotting

# Load the project helper functions
source("_scripts/bart_fit.R")        # bart_fit_preprocess(): data reshaping
source("_scripts/bart_diagnosis.R")  # bart_ewmvslc_diagnosis(): R-hat + traces

#### SET PARAMETERS ####
n.iter   <- 2000  # total iterations per chain (warmup + sampling)
n.burnin <- 1000  # number of burn-in (warmup) iterations
n.chain  <- 4     # number of Markov chains
Trials   <- 100   # number of trials per subject
Nmax     <- 12    # maximum number of pumps

#### LOAD DATA ####
bart_sample <- read_csv("_data/bart_sample.csv")  # load the formatted data
print(bart_sample)                                # inspect the data

#### PREPROCESS DATA FOR STAN ####
# Convert the long-format trial data into the N x T matrices the model expects
data_list <- bart_sample %>%
  bart_fit_preprocess(., Trials, Nmax)

#### COMPILE THE STAN MODEL ####
# The first execution compiles the model and typically takes about one minute.
# stan_threads = TRUE is required by reduce_sum inside the model.
model_file <- "_scripts/bart_ewmv-slc.stan"
model <- cmdstan_model(model_file,
                       cpp_options = list(stan_threads = TRUE))

#### RUN MCMC SAMPLING ####
# parallel_chains = 4 (chains in parallel) + threads_per_chain = 3
# (within-chain threading). On a 16-core machine the fit may take a few
# minutes. output_dir keeps the raw CmdStan CSV output on disk (_rds/).
threads_per_chain <- 3

start_time <- Sys.time()

bart_fit_ewmvslc_sample_cmdstan <- model$sample(
  data = data_list,
  chains = n.chain,
  parallel_chains = n.chain,
  threads_per_chain = threads_per_chain,
  iter_warmup = n.burnin,
  iter_sampling = n.iter - n.burnin,
  seed = 1234,
  output_dir = "_rds"
)

print(Sys.time() - start_time)

#### INSPECT THE FIT ####
samples_posterior <- bart_fit_ewmvslc_sample_cmdstan$draws()
summary_tbl <- bart_fit_ewmvslc_sample_cmdstan$summary()
print(summary_tbl)

#### CONVERGENCE DIAGNOSTICS ####
bart_fit_ewmvslc_sample_draws <- bart_fit_ewmvslc_sample_cmdstan$draws()

# R-hat for every parameter; values close to 1.00 indicate convergence.
# Classic Gelman-Rubin diagnostic (Gelman & Rubin, 1992); the implementation
# here is the rank-normalized split R-hat of Vehtari et al. (2021).
rhat_all <- posterior::rhat(bart_fit_ewmvslc_sample_draws)
print(rhat_all)

# Quick convergence check: flag any parameter with R-hat above 1.01
bad_rhat <- names(rhat_all)[rhat_all > 1.01]
if (length(bad_rhat) == 0) {
  cat("Convergence check: all parameters have R-hat <= 1.01.\n")
} else {
  cat("Parameters with R-hat > 1.01 (may need more iterations):",
      paste(bad_rhat, collapse = ", "), "\n")
}

# Trace plot of the group-level loss-sensitivity exponent mu_zeta
bart_fit_ewmvslc_sample_draws %>%
  bayesplot::mcmc_trace(regex_pars = "mu_zeta")

# Save the trace plot to disk (non-interactive session)
ggsave("_rds/trace_mu_zeta.png", width = 8, height = 5, dpi = 150)

# Sampler diagnostics (R-hat, ESS, divergences)
diagnostic_sum <- bart_fit_ewmvslc_sample_cmdstan$diagnostic_summary()
print(diagnostic_sum)

#### SAVE THE FIT ####
saveRDS(bart_fit_ewmvslc_sample_cmdstan,
        file = "_rds/bart_fit_ewmvslc_sample_cmdstan.rds")
bart_fit_ewmvslc_sample_cmdstan <- readRDS(
  "_rds/bart_fit_ewmvslc_sample_cmdstan.rds"
)

#### CONVERT TO rstan stanfit (optional) ####
# read_stan_csv() reads the raw per-chain CmdStan CSV output files (kept in
# _rds/ via output_dir), not an in-memory draws object.
# NOTE: rstan 2.32.x cannot fully parse the CmdStan 2.37 CSV header (it writes
# "save_warmup = false" instead of a numeric flag). If the conversion fails it
# is skipped with a message; all analyses above (summary, diagnostics, plots,
# LOO) were already produced with cmdstanr/posterior only.
library(rstan)
stanfit <- tryCatch(
  rstan::read_stan_csv(bart_fit_ewmvslc_sample_cmdstan$output_files()),
  error = function(e) {
    message("rstan conversion skipped (CmdStan 2.37 CSV header not fully ",
            "supported by rstan 2.32.x): ", conditionMessage(e))
    message("Use the cmdstanr/posterior results directly (see summary above).")
    NULL
  }
)
if (!is.null(stanfit)) print(stanfit)

#### LOO-CV FOR MODEL COMPARISON ####
# PSIS-LOO (Pareto-smoothed importance sampling leave-one-out cross-validation;
# Vehtari et al., 2017) implemented in the loo package.
bart_fit_ewmvslc_sample_loo <- bart_fit_ewmvslc_sample_cmdstan$draws("log_lik")
loo_result <- loo(bart_fit_ewmvslc_sample_loo)
print(loo_result)
