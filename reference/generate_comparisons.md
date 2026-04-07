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
  holdout = NULL,
  blocks = NULL,
  seed = NULL
)
```

## Arguments

- documents:

  A character vector of documents to compare.

- n_train:

  Maximum number of unique pairs to sample from the training set.
  Defaults to `10000`. Set to `NULL` to return all possible training
  pairs. When no split is active, this limits the overall sample.

- n_test:

  Maximum number of unique pairs to sample from the test set. Defaults
  to `5000`. Set to `NULL` to return all possible test pairs. Only used
  when a split is active (`prop` or `holdout`).

- prop:

  Optional proportion of documents assigned to the training set (e.g.
  `0.8`). When supplied, a `split` column is added to the result. Cannot
  be used together with `holdout`.

- holdout:

  Optional logical vector the same length as `documents`. `TRUE` marks a
  document for the test set, `FALSE` for the training set. When
  supplied, a `split` column is added to the result. Cannot be used
  together with `prop`.

- blocks:

  Optional vector (character, factor, or integer) the same length as
  `documents`. When supplied, only within-block pairs are generated and
  a `block` column is included in the output. Blocks with fewer than 2
  documents are skipped.

- seed:

  Optional integer random seed for reproducibility.

## Value

A tibble with columns `doc_id_a`, `doc_id_b`, `text_a`, and `text_b`.
`doc_id_a` and `doc_id_b` are integer row indices into `documents`. When
a split is active, an additional `split` column contains `"train"` or
`"test"`. When `blocks` is supplied, a `block` column identifies which
block each pair belongs to.

## Details

When `prop` or `holdout` is supplied, the result includes a `split`
column (`"train"` / `"test"`) that
[`fit_model()`](https://joeornstein.github.io/textscale/reference/fit_model.md)
and
[`validate_model()`](https://joeornstein.github.io/textscale/reference/validate_model.md)
respect automatically.

When `blocks` is supplied, only within-block pairs are generated. Blocks
with fewer than 2 documents are skipped with a message.

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
#> 2        3        1 Hello world         The quick brown fox
#> 3        3        2 Hello world         A lazy dog         
#> 4        1        4 The quick brown fox Foo bar            
#> 5        2        4 A lazy dog          Foo bar            
#> 6        3        4 Hello world         Foo bar            
# With an 80/20 train/test split, default sample sizes
generate_comparisons(docs, prop = 0.8, seed = 1)
#> `n_train` (10000) exceeds the number of unique train pairs (3). Using all 3.
#> `n_test` (5000) exceeds the number of unique test pairs (0). Using all 0.
#> # A tibble: 3 × 5
#>   doc_id_a doc_id_b text_a              text_b              split
#>      <int>    <int> <chr>               <chr>               <chr>
#> 1        1        3 The quick brown fox Hello world         train
#> 2        4        1 Foo bar             The quick brown fox train
#> 3        4        3 Foo bar             Hello world         train
# With blocks
generate_comparisons(docs, blocks = c("a", "a", "b", "b"), n_train = NULL)
#> # A tibble: 2 × 5
#>   doc_id_a doc_id_b text_a     text_b              block
#>      <int>    <int> <chr>      <chr>               <chr>
#> 1        2        1 A lazy dog The quick brown fox a    
#> 2        4        3 Foo bar    Hello world         b    
# With user-supplied holdout
generate_comparisons(docs, holdout = c(FALSE, FALSE, TRUE, TRUE))
#> `n_train` (10000) exceeds the number of unique train pairs (1). Using all 1.
#> `n_test` (5000) exceeds the number of unique test pairs (1). Using all 1.
#> # A tibble: 2 × 5
#>   doc_id_a doc_id_b text_a              text_b     split
#>      <int>    <int> <chr>               <chr>      <chr>
#> 1        1        2 The quick brown fox A lazy dog train
#> 2        3        4 Hello world         Foo bar    test 
```
