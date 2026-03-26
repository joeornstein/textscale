# Annotate pairwise comparisons using an LLM

Submits each comparison pair to an LLM and records which document "wins"
on the latent dimension of interest. The `prompt` is interpolated for
each row using
[`ellmer::interpolate()`](https://ellmer.tidyverse.org/reference/interpolate.html),
so it may reference any column in `comparisons` with `{{column_name}}`
syntax. Most prompts will use `{{text_a}}` and `{{text_b}}`.

## Usage

``` r
annotate_comparisons(
  comparisons,
  prompt,
  model = "gpt-4.1-mini",
  system_prompt = "Respond with a single letter ('A' or 'B') only. No ties allowed.",
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

- prompt:

  An
  [`ellmer::interpolate()`](https://ellmer.tidyverse.org/reference/interpolate.html)
  template string. Use `{{text_a}}` and `{{text_b}}` to reference the
  two documents being compared. Example:
  `"Which is heavier?\\nA: {{text_a}}\\nB: {{text_b}}"`.

- model:

  Character string naming the OpenAI model to use. Defaults to
  `"gpt-4.1-mini"`.

- system_prompt:

  System prompt sent to the LLM. Defaults to instructing the model to
  respond with a single letter.

- path:

  File path for checkpointing batch API calls (passed to
  [`ellmer::batch_chat_text()`](https://ellmer.tidyverse.org/reference/batch_chat.html)).
  Defaults to `"textscale_annotations.json"` in the current working
  directory. Set to `NULL` to disable checkpointing. Ignored when
  `parallel = TRUE`.

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
containing `"A"` or `"B"` for each pair.

## Details

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
