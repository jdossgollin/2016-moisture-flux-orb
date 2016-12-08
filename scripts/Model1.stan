data{
  int<lower=1> N; // length of time series
  int<lower=1> p; // number local predictors
  int<lower=1> k; // number global predictors
  matrix[N, p] X;
  matrix[N, k] Z;
  vector[N] y; // the predictand
}
parameters{
  // first order
  real beta0;
  vector[p] beta;
  real<lower=0> sigma;
  // second order
  vector[p] alpha0; // intercepts
  matrix[k, p] alpha;
  vector<lower=0>[p] tau;
}
model{
  // first-order
  y ~ normal(beta0 + X * beta, sigma);
  // second order
  for(j in 1:p){
    X[, j] ~ normal(alpha0[j] + Z * alpha[, j], tau[j]);
  }
  // priors
  tau ~ normal(0, 10);
  sigma ~ normal(0, 10);
}
