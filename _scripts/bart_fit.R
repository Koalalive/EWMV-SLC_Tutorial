#### PREPROCESS BART DATA ####
library(tidyverse) # load the tidyverse package

bart_fit_preprocess <- function(bart, Trials, Nmax){
  pumps <- array( ,dim = c(length(unique(bart$subjID)), Trials)) # initialize pumps array
  explosion <- array( ,dim = c(length(unique(bart$subjID)), Trials)) # initialize explosion array
  for (i in 1:length(unique(bart$subjID))) {
    pumps[i,] <- bart %>% 
      filter(., subjID == unique(bart$subjID)[i]) %>% 
      pull(., pumps)
    explosion[i,] <- bart %>% 
      filter(., subjID == unique(bart$subjID)[i]) %>% 
      pull(., explosion)
  } # create arrays of pumps and explosions for each subject
  data_list <- list(
    N = length(unique(bart$subjID)),
    T = Trials, 
    Tsubj = rep(Trials,length(unique(bart$subjID))),
    P = Nmax + 1, 
    pumps = pumps,
    explosion = explosion
  ) # create a list of data for following anlaysis
  return(data_list)
}

#### FIT BART MODEL ####
library(rstan) # load the rstan package

options(mc.cores = parallel::detectCores()) # use all cores for parallelization
rstan_options(auto_write = TRUE) # save compiled models to disk

bart_fit_ewmvslc <- function(data_list, warmup, iter, chains, thin, seed, path = ""){
  gc() # garbage collection
  stanmodel_arg <- rstan::stan_model("./_scripts/bart_ewmv-slc.stan") # compile the model
  pars <- c("mu_pr", "sigma", "phi_pr", "eta_pr", "rho_pr", "tau_pr", "lambda_pr", "zeta_pr", 
            "phi", "eta", "rho", "tau", "lambda", "zeta", 
            "mu_phi", "mu_eta", "mu_rho", "mu_tau", "mu_lambda", "mu_zeta", 
            "log_lik", "lp__") # parameters to monitor
  bart_fit <- sampling(object = stanmodel_arg, data = data_list, pars = pars,
                       warmup = warmup, iter = iter, chains = chains, thin = thin, seed = seed) # fit the model
  if (path != "") {
    saveRDS(bart_fit, file = path) # save the fit to selected path
  }
  return(bart_fit)
}
