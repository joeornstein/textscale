# Validate a textscale model on held-out comparisons

Evaluates how well a fitted textscale model predicts the outcome of
held-out pairwise comparisons. For each pair, the document with the
higher latent score is predicted to win; this is compared against the
observed `winner` label.

## Usage

``` r
validate_model(
  model,
  comparisons,
  embeddings,
  force = FALSE,
  min_test_pairs = 50L
)

# S3 method for class 'textscale_validation'
plot(x, bins = 10, ...)
```

## Arguments

- model:

  A `textscale_model` object produced by
  [`fit_model()`](https://joeornstein.github.io/textscale/reference/fit_model.md).

- comparisons:

  An annotated comparisons tibble produced by
  [`annotate_comparisons()`](https://joeornstein.github.io/textscale/reference/annotate_comparisons.md).
  If a `split` column is present, only test-set rows are used.

- embeddings:

  A numeric matrix of document embeddings. Row `i` must correspond to
  document `i` in the original `documents` vector passed to
  [`generate_comparisons()`](https://joeornstein.github.io/textscale/reference/generate_comparisons.md).

- force:

  Logical. If `FALSE` (the default), the function stops when the upper
  bound of the 95% CI on accuracy falls below 0.55 or ICI exceeds 0.20,
  and warns when the accuracy CI upper bound is below 0.65 or ICI
  exceeds 0.10. Set `force = TRUE` to downgrade stops to warnings and
  continue anyway. When calling via
  [`textscale()`](https://joeornstein.github.io/textscale/reference/textscale.md),
  pass `force = TRUE` there instead.

- min_test_pairs:

  Integer. Minimum number of (non-tie) test pairs required to fit the
  calibration smooth used to compute the ICI. When fewer pairs are
  available, the GAM step is skipped, `ici` is recorded as `NA`, and
  only accuracy (with its Agresti-Coull CI) is reported. Defaults to
  `50`.

- x:

  A `textscale_validation` object.

- bins:

  Number of equal-width bins for the reliability diagram points. Default
  is 10.

- ...:

  Ignored.

## Value

A `textscale_validation` object. Call
[`print()`](https://rdrr.io/r/base/print.html) to display the accuracy
and ICI metrics; call
[`plot()`](https://rdrr.io/r/graphics/plot.default.html) to display a
calibration plot and retrieve the underlying `ggplot` object.

[`plot()`](https://rdrr.io/r/graphics/plot.default.html) returns the
`ggplot` calibration plot invisibly.

## Details

The **Integrated Calibration Index (ICI)** is the mean absolute
deviation of the calibration smooth from the diagonal, evaluated over a
fine grid. It expresses the average miscalibration in probability units
(e.g. 0.05 = predicted probabilities are off by ~5 percentage points on
average). Values below ~0.03 are typical of well-calibrated models;
values above ~0.07 suggest the model's predicted probabilities should be
interpreted cautiously, though the rank ordering of document scores may
still be valid.

When `comparisons` contains a `split` column (produced by
[`generate_comparisons()`](https://joeornstein.github.io/textscale/reference/generate_comparisons.md)
with `prop` supplied), only the rows where `split == "test"` are
evaluated. `embeddings` should be the full document embedding matrix in
this case; `doc_id_a` and `doc_id_b` index into it directly.
