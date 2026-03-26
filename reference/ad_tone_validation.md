# Validation results for the ad-tone model

A `textscale_validation` object produced by
[`validate_model()`](https://joeornstein.github.io/textscale/reference/validate_model.md)
for the ad-tone example. Contains test-set accuracy and calibration
metrics for the textscale model fit to the Carlson & Montgomery (2017)
Wisconsin ads using the human pairwise annotations in
[cm_comparisons](https://joeornstein.github.io/textscale/reference/cm_comparisons.md).

## Usage

``` r
ad_tone_validation
```

## Format

A `textscale_validation` object (a list) with three elements:

- metrics:

  A one-row tibble with columns `n_pairs`, `n_correct`, `accuracy`, and
  `ici`.

- cal_df:

  A data frame with columns `prob` (predicted probability) and `result`
  (observed outcome) for each test comparison. Used to construct the
  calibration plot.

- ici:

  Integrated Calibration Index (scalar).

## See also

[`validate_model()`](https://joeornstein.github.io/textscale/reference/validate_model.md),
[ad_tone](https://joeornstein.github.io/textscale/reference/ad_tone.md),
[cm_comparisons](https://joeornstein.github.io/textscale/reference/cm_comparisons.md)
