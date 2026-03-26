# Generate pairwise comparisons from a set of documents

Samples unique pairs of documents to be used as input to
[`annotate_comparisons()`](https://joeornstein.github.io/textscale/reference/annotate_comparisons.md).
Each row of the returned tibble represents one comparison between two
documents.

## Usage

``` r
generate_comparisons(
  documents,
  n_train = 10000,
  n_test = 5000,
  prop = NULL,
  seed = NULL
)
```

## Arguments

- documents:

  A character vector of documents to compare.

- n_train:

  Maximum number of unique pairs to sample from the training set.
  Defaults to `10000`. Set to `NULL` to return all possible training
  pairs. Ignored when `prop` is `NULL`, in which case it limits the
  overall sample.

- n_test:

  Maximum number of unique pairs to sample from the test set. Defaults
  to `5000`. Set to `NULL` to return all possible test pairs. Only used
  when `prop` is supplied.

- prop:

  Optional proportion of documents assigned to the training set (e.g.
  `0.8`). When supplied, a `split` column is added to the result and
  `doc_id_a`/`doc_id_b` index into the full `documents` vector so the
  same embedding matrix can be used for both fitting and validation.

- seed:

  Optional integer random seed for reproducibility.

## Value

A tibble with columns `doc_id_a`, `doc_id_b`, `text_a`, and `text_b`.
`doc_id_a` and `doc_id_b` are integer row indices into `documents`. When
`prop` is supplied, an additional `split` column contains `"train"` or
`"test"`.

## Details

When `prop` is supplied, documents are randomly partitioned into
training and test sets. Up to `n_train` within-train pairs and up to
`n_test` within-test pairs are sampled, and a `split` column (`"train"`
/ `"test"`) is added to the result.
[`fit_model()`](https://joeornstein.github.io/textscale/reference/fit_model.md)
and
[`validate_model()`](https://joeornstein.github.io/textscale/reference/validate_model.md)
both respect this column automatically.

When fewer unique pairs exist than the requested `n_train` or `n_test`,
all available pairs are returned with a message.

## Examples

``` r
docs <- c("The quick brown fox", "A lazy dog", "Hello world", "Foo bar")
# All unique pairs
generate_comparisons(docs, n_train = NULL)
#> # A tibble: 6 × 4
#>   doc_id_a doc_id_b text_a              text_b     
#>      <int>    <int> <chr>               <chr>      
#> 1        1        2 The quick brown fox A lazy dog 
#> 2        1        3 The quick brown fox Hello world
#> 3        2        3 A lazy dog          Hello world
#> 4        1        4 The quick brown fox Foo bar    
#> 5        2        4 A lazy dog          Foo bar    
#> 6        3        4 Hello world         Foo bar    
# With an 80/20 train/test split, default sample sizes
generate_comparisons(docs, prop = 0.8, seed = 1)
#> `n_train` (10000) exceeds the number of unique train pairs (3). Using all 3.
#> `n_test` (5000) exceeds the number of unique test pairs (0). Using all 0.
#> # A tibble: 3 × 5
#>   doc_id_a doc_id_b text_a              text_b      split
#>      <int>    <int> <chr>               <chr>       <chr>
#> 1        1        3 The quick brown fox Hello world train
#> 2        1        4 The quick brown fox Foo bar     train
#> 3        3        4 Hello world         Foo bar     train
```
