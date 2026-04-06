docs <- c("cat", "dog", "fish")
comparisons <- generate_comparisons(docs)

test_that("cache is returned immediately when file exists", {
  tmp <- tempfile(fileext = ".rds")
  on.exit(unlink(tmp))

  cached <- comparisons
  cached$winner <- "A"
  saveRDS(cached, tmp)

  result <- annotate_comparisons(comparisons, instructions = "irrelevant", cache = tmp, parallel = TRUE)
  expect_equal(result, cached, ignore_attr = TRUE)
})

test_that("cache file is written after annotation", {
  tmp_cache <- tempfile(fileext = ".rds")
  on.exit(unlink(tmp_cache))

  local_mocked_bindings(
    .chat_openai = function(...) NULL,
    .parallel_chat_text = function(chat, prompts, ...) rep("A", length(prompts))
  )

  result <- annotate_comparisons(comparisons, instructions = "?", cache = tmp_cache, parallel = TRUE)
  expect_true(file.exists(tmp_cache))
  expect_equal(readRDS(tmp_cache), result)
})

# --- allow_ties ---------------------------------------------------------------

test_that("allow_ties = TRUE preserves tie responses", {
  local_mocked_bindings(
    .chat_openai = function(...) NULL,
    .parallel_chat_text = function(chat, prompts, ...) c("A", "tie", "B")
  )

  result <- annotate_comparisons(comparisons, instructions = "?",
                                 allow_ties = TRUE, parallel = TRUE)
  expect_equal(result$winner, c("A", "tie", "B"))
})

test_that("allow_ties = FALSE warns on tie responses", {
  local_mocked_bindings(
    .chat_openai = function(...) NULL,
    .parallel_chat_text = function(chat, prompts, ...) c("A", "Tie", "B")
  )

  expect_warning(
    annotate_comparisons(comparisons, instructions = "?",
                         allow_ties = FALSE, parallel = TRUE),
    "not among"
  )
})

test_that("tie variants are normalised to lowercase 'tie'", {
  local_mocked_bindings(
    .chat_openai = function(...) NULL,
    .parallel_chat_text = function(chat, prompts, ...) c("A", " Tie ", "TIE")
  )

  result <- annotate_comparisons(comparisons, instructions = "?",
                                 allow_ties = TRUE, parallel = TRUE)
  expect_equal(result$winner, c("A", "tie", "tie"))
})
