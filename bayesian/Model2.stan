data{
  int<lower=1> N; // length of time series
  int<lower=1> k; // number global predictors
  matrix[N, k] Z;
  vector[N] y; // the predictand
}
parameters{
  // first order
  real beta0;
  vector[k] beta;
  real<lower=0> sigma;
}
model{
  // first-order
  y ~ normal(beta0 + Z * beta, sigma);
  // priors
  sigma ~ student_t(3, 0, 1);
}
