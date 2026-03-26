# Fit a textscale model

Fits a model on the differences between document embeddings to identify
a latent scaling dimension. The default method is L2-regularized
logistic regression (`"ridge"`), with alternatives including `"lasso"`,
`"enet"` (elastic net), and `"svm"` (linear support vector machine).

## Usage

``` r
fit_model(
  comparisons,
  embeddings,
  method = c("ridge", "lasso", "enet", "svm"),
  alpha = 0.5,
  nlambda = 200,
  lambda_min_ratio = 1e-09,
  refit = FALSE,
  ...
)
```

## Arguments

- comparisons:

  An annotated tibble produced by
  [`annotate_comparisons()`](https://joeornstein.github.io/textscale/reference/annotate_comparisons.md),
  containing columns `doc_id_a`, `doc_id_b`, and `winner`.

- embeddings:

  A numeric matrix of document embeddings with one row per document. Row
  order must correspond to the integer indices in `comparisons` (i.e.
  row `i` is the embedding for the document at position `i` in the
  original `documents` vector passed to
  [`generate_comparisons()`](https://joeornstein.github.io/textscale/reference/generate_comparisons.md)).

- method:

  One of `"ridge"` (default), `"lasso"`, `"enet"`, or `"svm"`. Controls
  the fitting method used to identify the latent dimension. `"ridge"`,
  `"lasso"`, and `"enet"` use
  [`glmnet::cv.glmnet()`](https://glmnet.stanford.edu/reference/cv.glmnet.html)
  with alpha 0, 1, and `alpha` respectively. `"svm"` fits a linear
  support vector machine via
  [`e1071::svm()`](https://rdrr.io/pkg/e1071/man/svm.html).

- alpha:

  The elastic net mixing parameter, used only when `method = "enet"`.
  Must be between 0 and 1 (0 = ridge, 1 = lasso). Defaults to `0.5`.

- nlambda:

  Number of lambda values to evaluate during cross-validation. Defaults
  to `200`. Ignored when `method = "svm"`.

- lambda_min_ratio:

  Ratio of the smallest to largest lambda evaluated. Defaults to `1e-9`.
  Increase if you see a warning that the optimal lambda is at the
  boundary of the search range. Ignored when `method = "svm"`.

- refit:

  Logical. If `TRUE`, all comparisons are used for fitting regardless of
  any `split` column. Use this after validating on a train/test split to
  produce a final model trained on the full set of annotations before
  scoring documents. Defaults to `FALSE`.

- ...:

  Additional arguments passed to
  [`glmnet::cv.glmnet()`](https://glmnet.stanford.edu/reference/cv.glmnet.html)
  (for glmnet methods) or
  [`e1071::svm()`](https://rdrr.io/pkg/e1071/man/svm.html) (for
  `method = "svm"`).

## Value

A `textscale_model` object (a list) containing:

- `beta`:

  Coefficient vector defining the latent dimension (intercept excluded).

- `method`:

  The fitting method used.

- `lambda`:

  The selected regularization parameter. Present for glmnet methods
  only.

- `cv_fit`:

  The full
  [`glmnet::cv.glmnet()`](https://glmnet.stanford.edu/reference/cv.glmnet.html)
  object. Present for glmnet methods only.

- `glmnet_fit`:

  The
  [`glmnet::glmnet()`](https://glmnet.stanford.edu/reference/glmnet.html)
  model refit at `lambda`. Present for glmnet methods only.

- `svm_fit`:

  The [`e1071::svm()`](https://rdrr.io/pkg/e1071/man/svm.html) model
  object. Present when `method = "svm"` only.
