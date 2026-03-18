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
