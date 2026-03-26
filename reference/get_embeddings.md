# Get text embeddings with optional caching

A thin wrapper around
[`fuzzylink::get_embeddings()`](https://joeornstein.github.io/software/fuzzylink/reference/get_embeddings.html)
that adds file-based caching. If `cache` points to an existing file,
embeddings for documents already present in the cache are loaded from
disk. Embeddings for any documents not found in the cache are fetched
via the API and appended to the cache before returning.

## Usage

``` r
get_embeddings(documents, cache = NULL, ...)
```

## Arguments

- documents:

  A character vector of texts to embed.

- cache:

  Optional path to an `.rds` file. If the file exists, cached embeddings
  matching `documents` (by row name) are reused. Any new documents are
  fetched and written back to the cache. If `NULL`, embeddings are
  always computed fresh without caching.

- ...:

  Additional arguments passed to
  [`fuzzylink::get_embeddings()`](https://joeornstein.github.io/software/fuzzylink/reference/get_embeddings.html).

## Value

A numeric matrix with one row per document and one column per embedding
dimension. Row names are set to `documents`.
