# Annotate pairwise comparisons using an LLM

Submits each comparison pair to an LLM and records which document "wins"
on the latent dimension of interest.

## Usage

``` r
annotate_comparisons(
  comparisons,
  instructions = NULL,
  prompt = "A: {{text_a}}\nB: {{text_b}}",
  model = "gpt-5.4-mini",
  document_type = c("text", "image"),
  resize = "high",
  system_prompt = NULL,
  allow_ties = TRUE,
  path = "textscale_annotations.json",
  parallel = FALSE,
  cache = NULL,
  ...
)
```

## Arguments

- comparisons:

  A tibble produced by
  [`generate_comparisons()`](https://joeornstein.github.io/textscale/reference/generate_comparisons.md).

- instructions:

  A plain-language description of the comparison task (e.g.,
  `"Which text is more conservative?"`). Prepended to `system_prompt` so
  the LLM knows what to judge. When using `annotate_comparisons()` on
  its own, this is typically the only argument you need beyond
  `comparisons`.

- prompt:

  An
  [`ellmer::interpolate()`](https://ellmer.tidyverse.org/reference/interpolate.html)
  template string for formatting each document pair. Defaults to
  `"A: {{text_a}}\\nB: {{text_b}}"`. Override this only if you need a
  non-standard document layout. Ignored when `document_type = "image"`.

- model:

  Character string naming the OpenAI model to use. Defaults to
  `"gpt-5.4-mini"`. When `document_type = "image"`, must name a
  vision-capable model.

- document_type:

  One of `"text"` (default) or `"image"`. When `"image"`,
  `text_a`/`text_b` in `comparisons` are treated as paths to local image
  files: each is attached to the LLM turn via
  [`ellmer::content_image_file()`](https://ellmer.tidyverse.org/reference/content_image_url.html)
  (labelled "Image A:"/"Image B:") instead of being interpolated into
  `prompt`, and the default `system_prompt` notes that the images are
  shown in that order.

- resize:

  Passed to
  [`ellmer::content_image_file()`](https://ellmer.tidyverse.org/reference/content_image_url.html)
  as the `resize` argument. Only used when `document_type = "image"`.
  Defaults to `"high"`.

- system_prompt:

  System prompt sent to the LLM. When `NULL` (the default), an
  appropriate prompt is generated based on the `allow_ties` argument.
  Supply a custom value to override this behaviour entirely. When
  `instructions` is supplied, it is prepended to `system_prompt`.

- allow_ties:

  Logical. If `TRUE` (the default), the LLM may respond with `"tie"`
  when the two texts are indistinguishable on the dimension of interest.
  Ties are recorded in the `winner` column and automatically dropped by
  downstream functions
  ([`fit_model()`](https://joeornstein.github.io/textscale/reference/fit_model.md),
  [`validate_model()`](https://joeornstein.github.io/textscale/reference/validate_model.md)).
  If `FALSE`, the system prompt instructs the LLM to choose A or B with
  no ties allowed. Ignored when a custom `system_prompt` is supplied.

- path:

  File path for checkpointing batch API calls (passed to
  [`ellmer::batch_chat_text()`](https://ellmer.tidyverse.org/reference/batch_chat.html)).
  Defaults to `"textscale_annotations.json"` in the current working
  directory. Deleted automatically once the batch completes and results
  are written to `cache`. Set to `NULL` to disable checkpointing.
  Ignored when `parallel = TRUE`.

- parallel:

  Logical. If `FALSE` (the default), annotations are submitted via the
  OpenAI Batch API at 50% of standard prices. Set to `TRUE` to use
  [`ellmer::parallel_chat_text()`](https://ellmer.tidyverse.org/reference/parallel_chat.html)
  for immediate results at standard prices.

- cache:

  Optional path to an `.rds` file. If the file exists, cached
  annotations are matched to the incoming `comparisons` by `text_a` and
  `text_b`. Rows whose text pair is found in the cache reuse the stored
  `winner`; only rows without a cache hit are sent to the LLM. The
  updated result (cached + new) is written back to `cache` after
  annotation. If `cache` is `NULL` all rows are annotated and nothing is
  written to disk. Caches written by textscale carry a prompt hash and
  will be ignored if the prompt changes; externally supplied caches (no
  hash attribute) bypass this check.

- ...:

  Additional arguments passed to
  [`ellmer::batch_chat_text()`](https://ellmer.tidyverse.org/reference/batch_chat.html)
  or
  [`ellmer::parallel_chat_text()`](https://ellmer.tidyverse.org/reference/parallel_chat.html).

## Value

The input `comparisons` tibble with an additional `winner` column
containing `"A"`, `"B"`, or (when `allow_ties = TRUE`) `"tie"` for each
pair.

## Details

The simplest way to use this function is to supply `instructions`
describing the comparison task in plain language (e.g.,
`"Which text is more conservative?"`). The instructions are
automatically prepended to the system prompt, and each LLM turn contains
the two documents formatted as `"A: <text_a>\\nB: <text_b>"`.

For advanced use, the `prompt` argument is an
[`ellmer::interpolate()`](https://ellmer.tidyverse.org/reference/interpolate.html)
template string that may reference any column in `comparisons` with
`{{column_name}}` syntax (most commonly `{{text_a}}` and `{{text_b}}`).

By default, annotations are submitted via the OpenAI Batch API
([`ellmer::batch_chat_text()`](https://ellmer.tidyverse.org/reference/batch_chat.html)),
which is 50% cheaper than standard pricing but may take up to 24 hours
to complete. The `path` argument checkpoints batch progress to a `.json`
file so interrupted jobs can be resumed without re-calling the API. Set
`parallel = TRUE` to use
[`ellmer::parallel_chat_text()`](https://ellmer.tidyverse.org/reference/parallel_chat.html)
instead, which returns results immediately at standard API prices.

Before sending requests to the API, the function prints an estimated
cost based on approximate token counts (1 token ≈ 4 characters) and
published OpenAI prices. The estimate assumes one output token per
comparison (single-letter response). Prices may be out of date; see
<https://openai.com/api/pricing/> for current rates.
