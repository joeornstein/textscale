docs <- c("cat", "dog", "fish")
comparisons <- generate_comparisons(docs)

test_that("cache is returned immediately when file exists", {
  tmp <- tempfile(fileext = ".rds")
  on.exit(unlink(tmp))

  cached <- comparisons
  cached$winner <- "A"
  saveRDS(cached, tmp)

  result <- annotate_comparisons(comparisons, prompt = "irrelevant", cache = tmp)
  expect_equal(result, cached, ignore_attr = TRUE)
})

test_that("cache file is written after annotation", {
  tmp_cache <- tempfile(fileext = ".rds")
  on.exit(unlink(tmp_cache))

  local_mocked_bindings(
    .chat_openai = function(...) NULL,
    .parallel_chat_text = function(chat, prompts, ...) rep("A", length(prompts))
  )

  result <- annotate_comparisons(comparisons, prompt = "?", cache = tmp_cache)
  expect_true(file.exists(tmp_cache))
  expect_equal(readRDS(tmp_cache), result)
})
