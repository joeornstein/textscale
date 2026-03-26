# Wisconsin political ads (2008)

A dataset of 935 Wisconsin congressional campaign advertisements from
the 2008 election cycle. Ad texts and pairwise annotations are drawn
from Carlson & Montgomery (2017); five-point tone codes are from the
Wisconsin Advertising Project (WiscAds). The `score` column contains
textscale negativity scores derived from the pairwise comparisons in
[cm_comparisons](https://joeornstein.github.io/textscale/reference/cm_comparisons.md).

## Usage

``` r
ad_tone
```

## Format

A tibble with 935 rows and 10 columns:

- text:

  Full text of the advertisement.

- candidate:

  Coded candidate identifier (factor).

- state:

  Two-letter state abbreviation. Empty string for ads with no state on
  record.

- tone:

  Numeric tone code from the Wisconsin Advertising Project (1 =
  Promoting, 2 = Mostly promoting, 3 = Contrasting, 4 = Mostly
  attacking, 5 = Attacking). `NA` for ads without a tone code.

- alphas:

  Continuous negativity score from the SentimentIt model in Carlson &
  Montgomery (2017).

- score:

  textscale negativity score derived from the pairwise comparisons in
  [cm_comparisons](https://joeornstein.github.io/textscale/reference/cm_comparisons.md).

- score_lower:

  Lower bound of the 95% confidence interval for `score`.

- score_upper:

  Upper bound of the 95% confidence interval for `score`.

- split:

  Whether the document was in the `"Train Set"` or `"Test Set"` split
  used to validate the model.

- tone_label:

  Factor version of `tone` with descriptive labels.

## Source

Carlson, T. N., & Montgomery, J. M. (2017). A pairwise comparison
framework for fast, flexible, and reliable human coding of political
texts. *American Political Science Review*, 111(4), 835–843.
[doi:10.1017/S0003055417000302](https://doi.org/10.1017/S0003055417000302)

## See also

[cm_comparisons](https://joeornstein.github.io/textscale/reference/cm_comparisons.md),
[ad_tone_validation](https://joeornstein.github.io/textscale/reference/ad_tone_validation.md)
