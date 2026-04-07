# textscale (development)

* `annotate_comparisons()` now reports a summary after annotation completes,
  including the total number of annotations and the number/percentage of ties
  (when any are present). Tie-dropping messages have been removed from
  `fit_model()` and `validate_model()`; tie counts are instead surfaced in
  `print.textscale_validation()` and the calibration plot caption.

* Fixed a test that incorrectly assumed `doc_id_a < doc_id_b`, which has not
  held since the A/B randomization fix in the previous version.

* `annotate_comparisons()` gains an `allow_ties` argument (default `TRUE`). When enabled, the LLM may respond with `"tie"` for pairs that are indistinguishable on the dimension of interest. Ties are recorded in the `winner` column and automatically dropped by `fit_model()`, `validate_model()`, and the bootstrap path in `score_documents()`. Set `allow_ties = FALSE` to restore the previous forced-choice behaviour. `textscale()` passes this argument through via its own new `allow_ties` parameter.

* `annotate_comparisons()` gains an `instructions` argument for describing the
  comparison task in plain language (e.g., `"Which text is more conservative?"`).
  Instructions are prepended to the system prompt automatically, and `prompt`
  now defaults to `"A: {{text_a}}\nB: {{text_b}}"`, so users no longer need to
  embed the document template themselves. `textscale()` now passes its `prompt`
  argument through as `instructions`.

* `generate_comparisons()`: fixed bias in rejection sampling that always placed
  earlier document IDs in the `doc_id_a` column. Pair assignment is now random,
  preventing spurious correlation when documents are ordered by the measure of
  interest.

* `textscale()` gains a `ci_method` argument (`"laplace"` or `"bootstrap"`) passed to `score_documents()`. `comparisons` is now forwarded automatically so `ci_method = "bootstrap"` works without extra steps.

* `textscale()` now defaults to `ci = TRUE` (scores are returned as a tibble with `score`, `lower`, and `upper` columns). The `embeddings_cache` and `annotations_cache` arguments now default to `"textscale_embeddings.rds"` and `"textscale_annotations.rds"` in the working directory, enabling caching without any configuration.

* New `textscale()` function runs the full pipeline in a single call:
  generates comparisons, retrieves embeddings, annotates with an LLM,
  validates on a train/test split, refits on all comparisons, and returns
  document scores. The `prompt` argument accepts plain instruction text —
  the `A: {{text_a}} / B: {{text_b}}` formatting is handled automatically.
  Returns a `textscale_result` object with scores, both fitted models,
  validation metrics, comparisons, and the embedding matrix.

* `fit_model()` gains a `refit` argument. When `refit = TRUE`, the `split`
  column is ignored and all comparisons are used for fitting. The recommended
  workflow is to call `fit_model()` (training split only) and
  `validate_model()` to evaluate performance, then call
  `fit_model(refit = TRUE)` on all comparisons before scoring documents.

* `fit_model()` gains a `method` argument (`"ridge"`, `"lasso"`, `"enet"`, `"svm"`) to select the fitting method used to identify the latent dimension. The default remains `"ridge"` (L2-regularized logistic regression). The new `"svm"` option fits a linear support vector machine via `e1071::svm()` and an `alpha` argument controls the elastic net mixing parameter for `method = "enet"`. For glmnet methods, the fitted model now includes a `sigma_post` component (the Laplace posterior covariance of `beta`) used by `score_documents()` to compute confidence intervals.

* `score_documents()` gains `ci`, `level`, `ci_method`, `n_boot`, and `comparisons` arguments for computing per-document 95% confidence intervals. The default `ci_method = "laplace"` derives intervals analytically from the Laplace posterior covariance stored in the model (fast; treats `lambda` as fixed). Setting `ci_method = "bootstrap"` resamples training pairs and refits the model `n_boot` times, returning empirical quantile intervals (slower but works for all model types). When `ci = FALSE` (the default), a plain numeric vector is returned as before.

# textscale 0.0.0.9000

* Initial package scaffold. Added `annotate_comparisons()`,
  `fit_model()`, `generate_comparisons()`, `score_documents()`, and
  `validate_model()` as stubs defining the core five-step pipeline API.
