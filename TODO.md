# TODO

**10-fold CV as an alternative to 80/20 split.** Swap
[`generate_comparisons()`](https://joeornstein.github.io/textscale/reference/generate_comparisons.md)
to sample uniformly across all pairs, annotate once, then emit a `fold`
column (1..k) instead of `split`. Have
[`validate_model()`](https://joeornstein.github.io/textscale/reference/validate_model.md)
iterate folds, pool held-out predictions for the ICI smooth, and report
fold-level accuracy spread alongside the Agresti–Coull CI. Keep
`prop`/`holdout` as alternatives. Note: pooled held-out pairs are
correlated (same doc appears in multiple folds’ train sets), so the
independence assumption in the CI/ICI is mildly violated.

Update documentation so users know the annotations are batch-submitted
by default. Could take up to 24 hours.

Figure out why the caching doesn’t play nicely with Quarto rendering?

Needs some sort of progress message between when the annotations are
complete and the model is fitting; there’s a long `ellmer` delay for
large batches.
