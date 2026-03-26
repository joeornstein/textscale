# Pairwise annotations from Carlson & Montgomery (2017)

Human-annotated pairwise comparisons from the Wisconsin congressional
ads study of Carlson & Montgomery (2017). Each row records which of two
ads was judged more negative by human annotators. Document indices
reference row positions in
[ad_tone](https://joeornstein.github.io/textscale/reference/ad_tone.md).

## Usage

``` r
cm_comparisons
```

## Format

A tibble with 9,528 rows and 4 columns:

- doc_id_a:

  Integer row index of the first ad in
  [ad_tone](https://joeornstein.github.io/textscale/reference/ad_tone.md).

- doc_id_b:

  Integer row index of the second ad in
  [ad_tone](https://joeornstein.github.io/textscale/reference/ad_tone.md).

- winner:

  `"A"` if the first ad was judged more negative; `"B"` if the second ad
  was.

- split:

  Whether the pair belongs to the `"train"` or `"test"` split used to
  validate the textscale model in
  [ad_tone_validation](https://joeornstein.github.io/textscale/reference/ad_tone_validation.md).

## Source

Carlson, T. N., & Montgomery, J. M. (2017). A pairwise comparison
framework for fast, flexible, and reliable human coding of political
texts. *American Political Science Review*, 111(4), 835–843.
[doi:10.1017/S0003055417000302](https://doi.org/10.1017/S0003055417000302)

## See also

[ad_tone](https://joeornstein.github.io/textscale/reference/ad_tone.md),
[ad_tone_validation](https://joeornstein.github.io/textscale/reference/ad_tone_validation.md)
