# textscale

<!-- badges: start -->
<!-- badges: end -->

textscale measures latent quantities from text — things like ideological
tone, argument persuasiveness, or ad negativity — by combining pairwise
comparisons with text embeddings. You provide a collection of documents
and a question (e.g., *"Which ad is more negative?"*). An LLM annotates
a sample of document pairs. textscale then fits a ridge logistic
regression on embedding differences to identify the latent dimension, and
uses it to score any document — including ones never directly compared.

## Installation

```r
# install.packages("pak")
pak::pak("jornstein/textscale")
```

textscale uses [ellmer](https://ellmer.tidyverse.org/) for LLM calls and
[fuzzylink](https://github.com/joeornstein/fuzzylink) for embeddings. Both
require an OpenAI API key set as `OPENAI_API_KEY` in your environment.

## Usage

The package follows a five-step pipeline:

| Step | Function | Input | Output |
|------|----------|-------|--------|
| 1 | `generate_comparisons()` | documents | comparison pairs |
| 2 | `get_embeddings()` | documents | embedding matrix |
| 3 | `annotate_comparisons()` | comparison pairs + LLM prompt | pairs with winners |
| 4 | `fit_model()` | pairs with winners + embedding matrix | `textscale_model` |
| 5 | `score_documents()` | `textscale_model` + embedding matrix | latent dimension scores |


```r
library(textscale)

# 1. Generate pairwise comparisons from your documents,
#    holding out 20% for validation.
comparisons <- generate_comparisons(docs, prop = 0.8, seed = 42)

# 2. Get text embeddings (cached to disk for reuse).
embeddings <- get_embeddings(docs, cache = "embeddings.rds")

# 3. Have an LLM annotate each comparison.
#    Results are cached so interrupted runs can be resumed.
comparisons <- annotate_comparisons(
  comparisons,
  prompt = "Which political ad is more negative toward its opponent?
A: {{text_a}}
B: {{text_b}}",
  cache = "annotations.rds"
)

# 4. Fit the model on the training split.
model <- fit_model(comparisons, embeddings)

# 5. Score all documents on the latent dimension.
scores <- score_documents(model, embeddings)
```

### Validation

`validate_model()` evaluates predictive accuracy on the held-out test
split and prints a calibration plot:

```r
validate_model(model, comparisons, embeddings)
#> # A tibble: 1 × 3
#>   n_pairs n_correct accuracy
#>     <int>     <int>    <dbl>
#> 1    5000      4251    0.850
```

## How it works

For each annotated pair, textscale computes the difference between the
two document embeddings and labels it 1 if document A won and 0 if B won.
A ridge logistic regression fit on these differences identifies a
direction in embedding space that best separates winners from losers —
that direction is the latent dimension. Projecting any document's
embedding onto this direction gives its score, making it straightforward
to scale new documents without any additional LLM calls.

## Citation

If you use textscale in published research, please cite:

> Ornstein, Joseph T. (2026). *textscale: Measure Latent Quantities from
> Text Using Pairwise Comparisons*. R package version 0.0.0.9000.
