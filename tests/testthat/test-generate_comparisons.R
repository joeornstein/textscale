docs <- c("The quick brown fox", "A lazy dog", "Hello world", "Foo bar")

test_that("all-pairs mode returns correct number of rows", {
  out <- generate_comparisons(docs)
  expect_equal(nrow(out), choose(length(docs), 2))
})

test_that("sampled mode returns requested n rows", {
  out <- generate_comparisons(docs, n_train = 3, seed = 1)
  expect_equal(nrow(out), 3)
})

test_that("output has expected columns", {
  out <- generate_comparisons(docs, n_train = 3)
  expect_named(out, c("doc_id_a", "doc_id_b", "text_a", "text_b"))
})

test_that("doc ids are within range", {
  out <- generate_comparisons(docs, n_train = 5, seed = 1)
  expect_true(all(out$doc_id_a >= 1 & out$doc_id_a <= length(docs)))
  expect_true(all(out$doc_id_b >= 1 & out$doc_id_b <= length(docs)))
})

test_that("doc_id_a is always less than doc_id_b (no reversed pairs)", {
  out <- generate_comparisons(docs)
  expect_true(all(out$doc_id_a < out$doc_id_b))
})

test_that("no duplicate pairs are returned", {
  out <- generate_comparisons(docs)
  keys <- paste(out$doc_id_a, out$doc_id_b)
  expect_equal(length(unique(keys)), nrow(out))
})

test_that("text columns match doc ids", {
  out <- generate_comparisons(docs, n_train = 5, seed = 1)
  expect_equal(out$text_a, docs[out$doc_id_a])
  expect_equal(out$text_b, docs[out$doc_id_b])
})

test_that("seed produces reproducible output", {
  out1 <- generate_comparisons(docs, n_train = 3, seed = 42)
  out2 <- generate_comparisons(docs, n_train = 3, seed = 42)
  expect_equal(out1, out2)
})

test_that("error on fewer than 2 documents", {
  expect_snapshot(error = TRUE, generate_comparisons("only one"))
})

test_that("message when n_train exceeds possible pairs", {
  expect_message(
    generate_comparisons(docs, n_train = choose(length(docs), 2) + 1),
    "exceeds the number of unique",
    fixed = TRUE
  )
})

# --- blocks tests ---

test_that("blocks produces only within-block pairs", {
  docs8 <- paste("doc", 1:8)
  blk <- c("a", "a", "a", "a", "b", "b", "b", "b")
  out <- generate_comparisons(docs8, blocks = blk, n_train = NULL)
  # Every pair should have both docs in the same block
  expect_true(all(blk[out$doc_id_a] == blk[out$doc_id_b]))
  # block column should be present

  expect_true("block" %in% names(out))
  expect_true(all(out$block == blk[out$doc_id_a]))
})

test_that("blocks output has correct total pairs", {
  docs6 <- paste("doc", 1:6)
  blk <- c("a", "a", "a", "b", "b", "b")
  out <- generate_comparisons(docs6, blocks = blk, n_train = NULL)
  # 3 docs in each block → choose(3,2) * 2 = 6 pairs

  expect_equal(nrow(out), choose(3, 2) * 2)
})

test_that("blocks with sampling respects n_train", {
  docs8 <- paste("doc", 1:8)
  blk <- c("a", "a", "a", "a", "b", "b", "b", "b")
  out <- generate_comparisons(docs8, blocks = blk, n_train = 4, seed = 42)
  expect_equal(nrow(out), 4)
  # Still within-block

  expect_true(all(blk[out$doc_id_a] == blk[out$doc_id_b]))
})

test_that("blocks skips small blocks with message", {
  docs5 <- paste("doc", 1:5)
  blk <- c("a", "a", "a", "a", "b")
  # block "b" has only 1 doc
  expect_message(
    out <- generate_comparisons(docs5, blocks = blk, n_train = NULL),
    "Skipping 1 block"
  )
  expect_true(all(out$block == "a"))
})

test_that("blocks with prop produces within-block split pairs", {
  docs8 <- paste("doc", 1:8)
  blk <- c("a", "a", "a", "a", "b", "b", "b", "b")
  out <- generate_comparisons(docs8, blocks = blk, prop = 0.5,
                              n_train = NULL, n_test = NULL, seed = 99)
  expect_true("split" %in% names(out))
  expect_true("block" %in% names(out))
  # All pairs within-block
  expect_true(all(blk[out$doc_id_a] == blk[out$doc_id_b]))
})

test_that("blocks length mismatch errors", {
  expect_error(
    generate_comparisons(docs, blocks = c("a", "b")),
    "same length"
  )
})

test_that("blocks with seed is reproducible", {
  docs8 <- paste("doc", 1:8)
  blk <- c("a", "a", "a", "a", "b", "b", "b", "b")
  out1 <- generate_comparisons(docs8, blocks = blk, n_train = 3, seed = 77)
  out2 <- generate_comparisons(docs8, blocks = blk, n_train = 3, seed = 77)
  expect_equal(out1, out2)
})

# --- rejection sampling tests ---

test_that("rejection sampling produces correct, unique pairs", {
  # 200 docs → choose(200,2) = 19900 possible; requesting 50 triggers rejection sampling
  docs200 <- paste("doc", seq_len(200))
  out <- generate_comparisons(docs200, n_train = 50, seed = 314)
  expect_equal(nrow(out), 50)
  expect_true(all(out$doc_id_a != out$doc_id_b))
  # Uniqueness: canonical key should have no duplicates
  keys <- paste(pmin(out$doc_id_a, out$doc_id_b), pmax(out$doc_id_a, out$doc_id_b))
  expect_equal(length(unique(keys)), 50)
  # Position assignment should not always put the smaller id in a
  expect_true(any(out$doc_id_a > out$doc_id_b))
})

test_that("rejection sampling within blocks works for large blocks", {
  docs200 <- paste("doc", seq_len(200))
  blk <- rep(c("x", "y"), each = 100)
  out <- generate_comparisons(docs200, blocks = blk, n_train = 40, seed = 628)
  expect_equal(nrow(out), 40)
  expect_true(all(blk[out$doc_id_a] == blk[out$doc_id_b]))
  expect_true(all(out$doc_id_a != out$doc_id_b))
  keys <- paste(pmin(out$doc_id_a, out$doc_id_b), pmax(out$doc_id_a, out$doc_id_b))
  expect_equal(length(unique(keys)), 40)
})

# --- holdout tests ---

test_that("holdout produces correct train/test pairs", {
  docs6 <- paste("doc", 1:6)
  ho <- c(FALSE, FALSE, FALSE, FALSE, TRUE, TRUE)
  out <- generate_comparisons(docs6, holdout = ho, n_train = NULL, n_test = NULL)
  expect_true("split" %in% names(out))

  train_rows <- out[out$split == "train", ]
  test_rows  <- out[out$split == "test", ]

  # Train pairs: both docs should have holdout = FALSE
  expect_true(all(!ho[train_rows$doc_id_a] & !ho[train_rows$doc_id_b]))
  # Test pairs: both docs should have holdout = TRUE
  expect_true(all(ho[test_rows$doc_id_a] & ho[test_rows$doc_id_b]))

  expect_equal(nrow(train_rows), choose(4, 2))
  expect_equal(nrow(test_rows), choose(2, 2))
})

test_that("holdout + prop errors", {
  expect_error(
    generate_comparisons(docs, holdout = c(TRUE, TRUE, FALSE, FALSE), prop = 0.5),
    "either.*holdout.*or.*prop"
  )
})

test_that("holdout must be logical", {
  expect_error(
    generate_comparisons(docs, holdout = c(1, 0, 1, 0)),
    "logical"
  )
})

test_that("holdout wrong length errors", {
  expect_error(
    generate_comparisons(docs, holdout = c(TRUE, FALSE)),
    "same length"
  )
})

test_that("holdout needs >= 2 in each group", {
  expect_error(
    generate_comparisons(docs, holdout = c(TRUE, FALSE, FALSE, FALSE)),
    "at least 2 TRUE"
  )
  expect_error(
    generate_comparisons(docs, holdout = c(TRUE, TRUE, TRUE, FALSE)),
    "at least 2 FALSE"
  )
})

# --- blocks + holdout tests ---

test_that("blocks + holdout produces within-block within-split pairs", {
  docs8 <- paste("doc", 1:8)
  blk <- c("a", "a", "a", "a", "b", "b", "b", "b")
  ho  <- c(FALSE, FALSE, TRUE, TRUE, FALSE, FALSE, TRUE, TRUE)
  out <- generate_comparisons(docs8, blocks = blk, holdout = ho,
                              n_train = NULL, n_test = NULL)

  expect_true("split" %in% names(out))
  expect_true("block" %in% names(out))

  # All pairs within-block
  expect_true(all(blk[out$doc_id_a] == blk[out$doc_id_b]))

  # Train pairs: both docs not holdout
  train_rows <- out[out$split == "train", ]
  expect_true(all(!ho[train_rows$doc_id_a] & !ho[train_rows$doc_id_b]))

  # Test pairs: both docs holdout
  test_rows <- out[out$split == "test", ]
  expect_true(all(ho[test_rows$doc_id_a] & ho[test_rows$doc_id_b]))
})
