#library(rstanarm) # load the rstanarm package
library(loo) # load the loo package
library(bayesplot) # load the bayesplot package

#### CLASS ####
setClass(
  Class     = "McmcDiagnosis",
  slots     = c(
    rhats = "numeric",
    trace  = "list"
  ),
  prototype = list(
    rhats  = c(),
    trace      = c()
  )
) # create a new class for storing MCMC diagnostics

#### DIAGNOSIS ####
bart_ewmvslc_diagnosis <- function(fit_bart){
  rhats <- bayesplot::rhat(fit_bart) # calculate the R-hat statistic
  trace_phi <- traceplot(fit_bart, pars = "mu_phi", inc_warmup = FALSE) # trace plot for phi
  trace_eta <- traceplot(fit_bart, pars = "mu_eta", inc_warmup = FALSE) # trace plot for eta
  trace_rho <- traceplot(fit_bart, pars = "mu_rho", inc_warmup = FALSE) # trace plot for rho
  trace_tau <- traceplot(fit_bart, pars = "mu_tau", inc_warmup = FALSE) # trace plot for tau
  trace_lambda <- traceplot(fit_bart, pars = "mu_lambda", inc_warmup = FALSE) # trace plot for lambda
  trace_zeta <- traceplot(fit_bart, pars = "mu_zeta", inc_warmup = FALSE) # trace plot for zeta
  bart_diagnosis <- new("McmcDiagnosis", 
                        rhats = rhats, trace = list("phi" = trace_phi, 
                                                    "eta" = trace_eta,
                                                    "rho" = trace_rho,
                                                    "tau" = trace_tau,
                                                    "lambda" = trace_lambda,
                                                    "zeta" = trace_zeta)) # store the diagnostics
  return(bart_diagnosis)
}
