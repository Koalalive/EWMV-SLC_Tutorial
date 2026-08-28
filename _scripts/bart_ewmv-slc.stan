functions {
  // Parallelized log-likelihood computation for a slice of subjects.
  // This function is used by reduce_sum in the model block so that the
  // likelihood can be evaluated in parallel across worker threads.
  real partial_sum(array[] int slice_subject_ids,         // subject IDs in the current slice
                   int start, int end,                     // start and end indices of the slice
                   int N, int T, int P,                    // data dimensions
                   array[] int Tsubj,                      // number of trials for each subject
                   array[,] int pumps,                     // number of pumps per trial
                   array[,] int explosion,                 // explosion indicator per trial
                   array[,,] int d,                        // pump decision indicator per trial
                   vector phi, vector eta, vector rho,     // subject-level parameters
                   vector tau, vector lambda, vector zeta) {

    real llik = 0;

    // Accumulate the log-likelihood over the subjects in this slice
    for (i in 1:size(slice_subject_ids)) {
      int j = slice_subject_ids[i];

      // Initialize the running counters for outcome feedback and pumping
      int n_succ = 0;
      int n_pump = 0;
      real p_burst = phi[j];

      for (k in 1:Tsubj[j]) {
        real u_gain = 1;
        real u_loss;
        real u_pump;
        real u_stop = 0;
        real delta_u;

        for (l in 1:(pumps[j, k] + 1 - explosion[j, k])) {
          u_loss = (l - 1);

          u_pump = (1 - p_burst) * u_gain - lambda[j] * p_burst * u_loss^zeta[j] +
                   rho[j] * p_burst * (1 - p_burst) * (u_gain + lambda[j] * u_loss^zeta[j])^2;

          delta_u = u_pump - u_stop;

          // Accumulate the log-likelihood contribution for this choice
          llik += bernoulli_logit_lpmf(d[j, k, l] | tau[j] * delta_u);
        }

        // Update the running counters after each trial
        n_succ += pumps[j, k] - explosion[j, k];
        n_pump += pumps[j, k];

        if (n_pump > 0) {
          p_burst = phi[j] + (1 - exp(-n_pump * eta[j])) * ((0.0 + n_pump - n_succ) / n_pump - phi[j]);
        }
      }
    }

    return llik;
  }
}

data {
  int<lower=1> N;                 // number of subjects
  int<lower=1> T;                 // maximum number of trials per subject
  array[N] int<lower=0> Tsubj;    // number of trials for each subject
  int<lower=2> P;                 // maximum number of pumps + 1
  array[N, T] int<lower=0> pumps; // number of pumps per trial
  array[N, T] int<lower=0, upper=1> explosion; // whether the balloon exploded (1 = exploded)
}

transformed data {
  // Pump decision indicator for each trial and pump step (1 = pump, 0 = stop)
  array[N, T, P] int d;

  // Array of subject indices used by reduce_sum to slice the data
  array[N] int subject_ids;

  for (j in 1:N) {
    subject_ids[j] = j;
    for (k in 1:Tsubj[j]) {
      for (l in 1:P) {
        if (l <= pumps[j, k])
          d[j, k, l] = 1;
        else
          d[j, k, l] = 0;
      }
    }
  }
}

parameters {
  // Group-level parameter means (on the unconstrained scale)
  vector[6] mu_pr;
  vector<lower=0>[6] sigma;

  // Standard normal deviations for the non-centered (Matt trick) parameterization
  vector[N] phi_pr;
  vector[N] eta_pr;
  vector[N] rho_pr;
  vector[N] tau_pr;
  vector[N] lambda_pr;
  vector[N] zeta_pr;
}

transformed parameters {
  // Subject-level parameters obtained via the non-centered (Matt trick) parameterization
  vector<lower=0, upper=1>[N] phi;
  vector<lower=0, upper=1>[N] eta;
  vector<lower=-0.5, upper=0.5>[N] rho;
  vector<lower=0>[N] tau;
  vector<lower=0>[N] lambda;
  vector<lower=0>[N] zeta;

  phi = Phi_approx(mu_pr[1] + sigma[1] * phi_pr);
  eta = Phi_approx(mu_pr[2] + sigma[2] * eta_pr);
  rho = 0.5 - Phi_approx(mu_pr[3] + sigma[3] * rho_pr);
  tau = exp(mu_pr[4] + sigma[4] * tau_pr);
  lambda = exp(mu_pr[5] + sigma[5] * lambda_pr);
  zeta = exp(mu_pr[6] + sigma[6] * zeta_pr);
}

model {
  // Priors
  mu_pr ~ normal(0, 1);
  sigma ~ normal(0, 0.2);

  phi_pr ~ normal(0, 1);
  eta_pr ~ normal(0, 1);
  rho_pr ~ normal(0, 1);
  tau_pr ~ normal(0, 1);
  lambda_pr ~ normal(0, 1);
  zeta_pr ~ normal(0, 1);

  // Parallelized log-likelihood evaluation with reduce_sum
  // grainsize: number of subjects processed by each worker task (tune for best performance)
  // A reasonable default is N / (number of chains * number of CPU cores)
  int grainsize = 1;

  target += reduce_sum(partial_sum, subject_ids, grainsize,
                      N, T, P, Tsubj, pumps, explosion, d,
                      phi, eta, rho, tau, lambda, zeta);
}

generated quantities {
  // Model-implied group-level means (on the constrained scale)
  real<lower=0, upper=1> mu_phi = Phi_approx(mu_pr[1]);
  real<lower=0, upper=1> mu_eta = Phi_approx(mu_pr[2]);
  real<lower=-0.5, upper=0.5> mu_rho = 0.5 - Phi_approx(mu_pr[3]);
  real<lower=0> mu_tau = exp(mu_pr[4]);
  real<lower=0> mu_lambda = exp(mu_pr[5]);
  real<lower=0> mu_zeta = exp(mu_pr[6]);

  // Pointwise log-likelihood (used for LOO-CV / WAIC model comparison)
  array[N] real log_lik;

  // Posterior predictive quantities (used for posterior predictive checks)
  array[N, T, P] real y_pred;

  // Initialize all posterior predictive values to -1 (placeholder for entries that are not observed)
  for (j in 1:N) {
    for (k in 1:T) {
      for (l in 1:P) {
        y_pred[j, k, l] = -1;
      }
    }
  }

  { // Local block to save time and memory
    for (j in 1:N) {
      // Initialize the running counters for outcome feedback and pumping
      int n_succ = 0;
      int n_pump = 0;
      real p_burst = phi[j];

      log_lik[j] = 0;

      for (k in 1:Tsubj[j]) {
        real u_gain = 1;
        real u_loss;
        real u_pump;
        real u_stop = 0;
        real delta_u;

        for (l in 1:(pumps[j, k] + 1 - explosion[j, k])) {
          u_loss = (l - 1);

          u_pump = (1 - p_burst) * u_gain - lambda[j] * p_burst * u_loss^zeta[j] +
                   rho[j] * p_burst * (1 - p_burst) * (u_gain + lambda[j] * u_loss^zeta[j])^2;

          delta_u = u_pump - u_stop;

          log_lik[j] += bernoulli_logit_lpmf(d[j, k, l] | tau[j] * delta_u);
          y_pred[j, k, l] = bernoulli_logit_rng(tau[j] * delta_u);
        }

        // Update the running counters after each trial
        n_succ += pumps[j, k] - explosion[j, k];
        n_pump += pumps[j, k];

        if (n_pump > 0) {
          p_burst = phi[j] + (1 - exp(-n_pump * eta[j])) * ((0.0 + n_pump - n_succ) / n_pump - phi[j]);
        }
      }
    }
  }
}
