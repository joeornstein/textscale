# Get text embeddings with optional caching

A thin wrapper around
[`fuzzylink::get_embeddings()`](https://joeornstein.github.io/software/fuzzylink/reference/get_embeddings.html)
that adds file-based caching. If `cache` points to an existing file,
embeddings for documents already present in the cache are loaded from
disk. Embeddings for any documents not found in the cache are fetched
via the API and appended to the cache before returning.

## Usage

``` r
get_embeddings(
  documents,
  cache = NULL,
  type = c("text", "image"),
  model = NULL,
  ...
)
```

## Arguments

- documents:

  A character vector of texts to embed. When `type = "image"`, a
  character vector of paths to local image files.

- cache:

  Optional path to an `.rds` file. If the file exists, cached embeddings
  matching `documents` (by row name) are reused. Any new documents are
  fetched and written back to the cache. If `NULL`, embeddings are
  always computed fresh without caching.

- type:

  One of `"text"` (default) or `"image"`. `"text"` embeds `documents`
  via
  [`fuzzylink::get_embeddings()`](https://joeornstein.github.io/software/fuzzylink/reference/get_embeddings.html)
  (OpenAI/Mistral text embeddings). `"image"` treats `documents` as
  local image file paths and embeds them via OpenRouter's multimodal
  embeddings endpoint, which requires an `OPENROUTER_API_KEY`
  environment variable.

- model:

  Character string naming the embedding model to use. When `NULL` (the
  default), each `type` uses its own built-in default:
  `"text-embedding-3-large"` for `type = "text"`, or
  `"google/gemini-embedding-2"` for `type = "image"`.

- ...:

  Additional arguments passed to
  [`fuzzylink::get_embeddings()`](https://joeornstein.github.io/software/fuzzylink/reference/get_embeddings.html)
  (for `type = "text"`) or to the internal OpenRouter request body (for
  `type = "image"`).

## Value

A numeric matrix with one row per document and one column per embedding
dimension. Row names are set to `documents`.
