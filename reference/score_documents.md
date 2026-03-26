# Score documents on the latent dimension

Projects document embeddings onto the latent dimension identified by a
fitted textscale model. Scores are the linear predictor
`embeddings %*% beta` (i.e., log-odds, without the intercept), and are
therefore comparable across documents but arbitrary up to a linear
transformation.

## Usage

``` r
score_documents(
  model,
  embeddings,
  ci = FALSE,
  level = 0.95,
  ci_method = c("laplace", "bootstrap"),
  n_boot = 500,
  comparisons = NULL
)
```

## Arguments

- model:

  A `textscale_model` object produced by
  [`fit_model()`](https://joeornstein.github.io/textscale/reference/fit_model.md).

- embeddings:

  A numeric matrix of document embeddings to score, with one row per
  document.

- ci:

  Logical. If `TRUE`, return a tibble with `score`, `lower`, and `upper`
  columns. Defaults to `FALSE`.

- level:

  Confidence level for the interval. Defaults to `0.95`.

- ci_method:

  One of `"laplace"` (default) or `"bootstrap"`. See **Confidence
  interval methods** for details.

- n_boot:

  Number of bootstrap resamples. Defaults to `500`. Ignored when
  `ci_method = "laplace"`.

- comparisons:

  Annotated comparisons tibble produced by
  [`annotate_comparisons()`](https://joeornstein.github.io/textscale/reference/annotate_comparisons.md).
  Required when `ci_method = "bootstrap"`. If a `split` column is
  present, only training rows are resampled.

## Value

When `ci = FALSE` (the default), a numeric vector of latent dimension
scores, one per document. When `ci = TRUE`, a tibble with columns
`score`, `lower`, and `upper`.

## Details

When `ci = TRUE`, a tibble is returned with columns `score`, `lower`,
and `upper` instead of a plain numeric vector.

## Confidence interval methods

**`"laplace"`** (default): Derives per-document score variances from the
Laplace approximation to the posterior covariance of `beta`:
`Var(score_i) = x_i' * (X'WX + lambda*I)^{-1} * x_i`, where `X` is the
matrix of training embedding differences and `W` is the diagonal matrix
of fitted working weights. This is fast (a single matrix multiply) and
treats `lambda` as fixed at the CV-selected value. Not available for
`method = "svm"` models.

**`"bootstrap"`**: Resamples training pairs with replacement and refits
the model `n_boot` times at the original fixed `lambda`, then takes
empirical quantiles of the resulting score distributions. Slower but
propagates more of the sampling variability, and works for all model
types including `"svm"`. Requires `comparisons` to be supplied.
