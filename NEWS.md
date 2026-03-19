# textscale (development)

* `fit_model()` gains a `method` argument (`"ridge"`, `"lasso"`, `"enet"`, `"svm"`) to select the fitting method used to identify the latent dimension. The default remains `"ridge"` (L2-regularized logistic regression). The new `"svm"` option fits a linear support vector machine via `e1071::svm()` and an `alpha` argument controls the elastic net mixing parameter for `method = "enet"`. For glmnet methods, the fitted model now includes a `sigma_post` component (the Laplace posterior covariance of `beta`) used by `score_documents()` to compute confidence intervals.

* `score_documents()` gains `ci`, `level`, `ci_method`, `n_boot`, and `comparisons` arguments for computing per-document 95% confidence intervals. The default `ci_method = "laplace"` derives intervals analytically from the Laplace posterior covariance stored in the model (fast; treats `lambda` as fixed). Setting `ci_method = "bootstrap"` resamples training pairs and refits the model `n_boot` times, returning empirical quantile intervals (slower but works for all model types). When `ci = FALSE` (the default), a plain numeric vector is returned as before.

# textscale 0.0.0.9000

* Initial package scaffold. Added `annotate_comparisons()`,
  `fit_model()`, `generate_comparisons()`, `score_documents()`, and
  `validate_model()` as stubs defining the core five-step pipeline API.
