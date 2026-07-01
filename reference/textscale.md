# Measure a latent quantity from text

Runs the full textscale pipeline in a single call: generates pairwise
comparisons, retrieves embeddings, annotates pairs with an LLM, fits and
validates a model on the train/test split, refits on all comparisons,
and returns scores for every document.

## Usage

``` r
textscale(
  documents,
  prompt,
  document_type = c("text", "image"),
  prop = 0.8,
  holdout = NULL,
  blocks = NULL,
  n_train = 10000,
  n_test = 5000,
  seed = NULL,
  llm_model = "gpt-5.4-mini",
  embedding_model = NULL,
  embeddings_cache = "textscale_embeddings.rds",
  annotations_cache = "textscale_annotations.rds",
  annotations_path = "textscale_annotations.json",
  parallel = FALSE,
  allow_ties = TRUE,
  method = "ridge",
  ci = TRUE,
  ci_method = "laplace",
  validate = TRUE,
  force = FALSE,
  ...
)
```

## Arguments

- documents:

  A character vector of documents to scale. When
  `document_type = "image"`, a character vector of paths to local image
  files.

- prompt:

  Instruction text for the LLM annotator. Should be a plain question or
  directive describing which document should be judged "greater" on the
  latent dimension — no placeholder syntax needed. For example:
  `"Which political ad is more negative toward its opponent?"`. The
  document text (or, for images, the images themselves) is appended
  automatically as labelled options A and B.

- document_type:

  One of `"text"` (default) or `"image"`. When `"image"`, `documents`
  are treated as local image file paths: embeddings are retrieved via
  OpenRouter's multimodal embeddings endpoint (requires
  `OPENROUTER_API_KEY`) and the LLM annotator is shown the images
  directly instead of interpolated text. See
  [`get_embeddings()`](https://joeornstein.github.io/textscale/reference/get_embeddings.md)
  and
  [`annotate_comparisons()`](https://joeornstein.github.io/textscale/reference/annotate_comparisons.md)
  for details.

- prop:

  Proportion of documents assigned to the training split. Defaults to
  `0.8`. Cannot be used together with `holdout`.

- holdout:

  Optional logical vector the same length as `documents`. `TRUE` marks a
  document for the test set, `FALSE` for the training set. When
  supplied, overrides `prop` for train/test assignment. Cannot be used
  together with `prop`.

- blocks:

  Optional vector (character, factor, or integer) the same length as
  `documents`. When supplied, only within-block pairs are generated. See
  [`generate_comparisons()`](https://joeornstein.github.io/textscale/reference/generate_comparisons.md)
  for details.

- n_train:

  Maximum number of training comparison pairs to generate. Defaults to
  `10000`.

- n_test:

  Maximum number of test comparison pairs to generate. Defaults to
  `5000`.

- seed:

  Integer random seed for reproducible pair sampling. Defaults to
  `NULL`.

- llm_model:

  OpenAI model name used for annotation. Defaults to `"gpt-5.4-mini"`.

- embedding_model:

  Character string naming the embedding model to use. When `NULL` (the
  default),
  [`get_embeddings()`](https://joeornstein.github.io/textscale/reference/get_embeddings.md)
  picks a built-in default based on `document_type`.

- embeddings_cache:

  File path for caching embeddings as an RDS file. Passed to
  [`get_embeddings()`](https://joeornstein.github.io/textscale/reference/get_embeddings.md).
  Defaults to `"textscale_embeddings.rds"` in the current working
  directory. Set to `NULL` to disable caching.

- annotations_cache:

  File path for caching annotations as an RDS file. Passed to
  [`annotate_comparisons()`](https://joeornstein.github.io/textscale/reference/annotate_comparisons.md).
  Defaults to `"textscale_annotations.rds"` in the current working
  directory. Set to `NULL` to disable caching.

- annotations_path:

  File path for checkpointing batch API calls. Passed to
  [`annotate_comparisons()`](https://joeornstein.github.io/textscale/reference/annotate_comparisons.md)
  as `path`. Defaults to `"textscale_annotations.json"` in the current
  working directory. Set to `NULL` to disable checkpointing. Ignored
  when `parallel = TRUE`.

- parallel:

  Logical. If `FALSE` (the default), annotations are submitted via the
  OpenAI Batch API at 50% of standard prices. Set to `TRUE` to use
  [`ellmer::parallel_chat_text()`](https://ellmer.tidyverse.org/reference/parallel_chat.html)
  for immediate results at standard prices.

- allow_ties:

  Logical. If `TRUE` (the default), the LLM may respond with `"tie"`
  when the two texts are indistinguishable. Ties are automatically
  dropped before model fitting and validation. Set to `FALSE` to force a
  choice between A and B. Passed to
  [`annotate_comparisons()`](https://joeornstein.github.io/textscale/reference/annotate_comparisons.md).

- method:

  Fitting method passed to
  [`fit_model()`](https://joeornstein.github.io/textscale/reference/fit_model.md).
  One of `"ridge"` (default), `"lasso"`, `"enet"`, or `"svm"`.

- ci:

  Logical. If `TRUE`, the `scores` element of the returned object is a
  tibble with `score`, `lower`, and `upper` columns. Defaults to `TRUE`.

- ci_method:

  Method for computing confidence intervals. One of `"laplace"`
  (default) or `"bootstrap"`. Passed to
  [`score_documents()`](https://joeornstein.github.io/textscale/reference/score_documents.md).
  Ignored when `ci = FALSE`.

- validate:

  Logical. If `TRUE` (the default),
  [`validate_model()`](https://joeornstein.github.io/textscale/reference/validate_model.md)
  is called on the held-out test split and its output is printed.

- force:

  Logical. If `FALSE` (the default), the pipeline stops when validation
  metrics are poor (accuracy \< 0.55 or ICI \> 0.20) and warns when they
  are marginal (accuracy \< 0.65 or ICI \> 0.10). Set `force = TRUE` to
  downgrade stops to warnings and continue scoring regardless of
  validation results. Ignored when `validate = FALSE`.

- ...:

  Additional arguments passed to
  [`fit_model()`](https://joeornstein.github.io/textscale/reference/fit_model.md)
  (e.g. `alpha`, `nlambda`, `lambda_min_ratio`).

## Value

A `textscale_result` object (a list) containing:

- `scores`:

  Document scores on the latent dimension. A named numeric vector by
  default, or a tibble with `score`, `lower`, and `upper` if
  `ci = TRUE`.

- `model_final`:

  The `textscale_model` fit on all comparisons, used to produce
  `scores`. Pass to
  [`score_documents()`](https://joeornstein.github.io/textscale/reference/score_documents.md)
  to scale new documents.

- `model_eval`:

  The `textscale_model` fit on training comparisons only, used for
  validation.

- `validation`:

  A `textscale_validation` object from
  [`validate_model()`](https://joeornstein.github.io/textscale/reference/validate_model.md),
  or `NULL` if `validate = FALSE`. Call
  [`print()`](https://rdrr.io/r/base/print.html) on it for metrics and
  [`plot()`](https://rdrr.io/r/graphics/plot.default.html) for the
  calibration plot.

- `comparisons`:

  The annotated comparisons tibble.

- `embeddings`:

  The document embedding matrix.
