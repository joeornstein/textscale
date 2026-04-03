#' Generate pairwise comparisons from a set of documents
#'
#' Samples unique pairs of documents to be used as input to
#' [textscale::annotate_comparisons()]. Each row of the returned tibble
#' represents one comparison between two documents.
#'
#' When `prop` or `holdout` is supplied, the result includes a `split`
#' column (`"train"` / `"test"`) that
#' [textscale::fit_model()] and [textscale::validate_model()] respect
#' automatically.
#'
#' When `blocks` is supplied, only within-block pairs are generated. Blocks
#' with fewer than 2 documents are skipped with a message.
#'
#' When fewer unique pairs exist than the requested `n_train` or
#' `n_test`, all available pairs are returned with a message.
#'
#' @param documents A character vector of documents to compare.
#' @param n_train Maximum number of unique pairs to sample from the
#'   training set. Defaults to `10000`. Set to `NULL` to return all
#'   possible training pairs. When no split is active, this limits the
#'   overall sample.
#' @param n_test Maximum number of unique pairs to sample from the test
#'   set. Defaults to `5000`. Set to `NULL` to return all possible test
#'   pairs. Only used when a split is active (`prop` or `holdout`).
#' @param prop Optional proportion of documents assigned to the training
#'   set (e.g. `0.8`). When supplied, a `split` column is added to the
#'   result. Cannot be used together with `holdout`.
#' @param holdout Optional logical vector the same length as `documents`.
#'   `TRUE` marks a document for the test set, `FALSE` for the training
#'   set. When supplied, a `split` column is added to the result. Cannot
#'   be used together with `prop`.
#' @param blocks Optional vector (character, factor, or integer) the same
#'   length as `documents`. When supplied, only within-block pairs are
#'   generated and a `block` column is included in the output. Blocks
#'   with fewer than 2 documents are skipped.
#' @param seed Optional integer random seed for reproducibility.
#'
#' @return A tibble with columns `doc_id_a`, `doc_id_b`, `text_a`, and
#'   `text_b`. `doc_id_a` and `doc_id_b` are integer row indices into
#'   `documents`. When a split is active, an additional `split` column
#'   contains `"train"` or `"test"`. When `blocks` is supplied, a
#'   `block` column identifies which block each pair belongs to.
#'
#' @export
#'
#' @examples
#' docs <- c("The quick brown fox", "A lazy dog", "Hello world", "Foo bar")
#' # All unique pairs
#' generate_comparisons(docs, n_train = NULL)
#' # With an 80/20 train/test split, default sample sizes
#' generate_comparisons(docs, prop = 0.8, seed = 1)
#' # With blocks
#' generate_comparisons(docs, blocks = c("a", "a", "b", "b"), n_train = NULL)
#' # With user-supplied holdout
#' generate_comparisons(docs, holdout = c(FALSE, FALSE, TRUE, TRUE))
generate_comparisons <- function(documents,
                                 n_train = 10000,
                                 n_test  = 5000,
                                 prop    = NULL,
                                 holdout = NULL,
                                 blocks  = NULL,
                                 seed    = NULL) {
  if (!is.null(seed)) set.seed(seed)

  n_docs <- length(documents)
  if (n_docs < 2) stop("`documents` must contain at least 2 elements.")

  # --- Validate holdout ---
  if (!is.null(holdout) && !is.null(prop)) {
    stop("Supply either `holdout` or `prop`, not both.")
  }
  if (!is.null(holdout)) {
    if (!is.logical(holdout)) stop("`holdout` must be a logical vector.")
    if (length(holdout) != n_docs) {
      stop("`holdout` must be the same length as `documents`.")
    }
    if (sum(!holdout) < 2) stop("`holdout` must have at least 2 FALSE (train) values.")
    if (sum(holdout) < 2) stop("`holdout` must have at least 2 TRUE (test) values.")
  }

  # --- Validate blocks ---
  if (!is.null(blocks)) {
    if (length(blocks) != n_docs) {
      stop("`blocks` must be the same length as `documents`.")
    }
  }

  # --- Determine train/test assignment ---
  has_split <- !is.null(prop) || !is.null(holdout)

  if (!is.null(holdout)) {
    train_idx <- which(!holdout)
    test_idx  <- which(holdout)
  } else if (!is.null(prop)) {
    train_idx <- sort(sample(n_docs, floor(prop * n_docs)))
    test_idx  <- setdiff(seq_len(n_docs), train_idx)
  } else {
    train_idx <- seq_len(n_docs)
    test_idx  <- integer(0)
  }

  # --- Helpers ---

  # Generate all within-group pairs; idx values are positions in `documents`
  all_pairs <- function(idx) {
    k <- length(idx)
    if (k < 2) return(list(a = integer(0), b = integer(0)))
    pos <- which(upper.tri(matrix(0L, k, k)), arr.ind = TRUE)
    list(a = idx[pos[, 1]], b = idx[pos[, 2]])
  }

  # Rejection-sample n unique pairs from idx (positions in `documents`)
  rejection_sample <- function(idx, n) {
    k <- length(idx)
    ids_a   <- integer(n)
    ids_b   <- integer(n)
    n_found <- 0L
    seen    <- new.env(hash = TRUE, parent = emptyenv(), size = n)

    while (n_found < n) {
      batch <- max(n - n_found, 100L) * 2L
      a <- idx[sample.int(k, batch, replace = TRUE)]
      b <- idx[sample.int(k, batch, replace = TRUE)]
      keep <- a != b
      a <- a[keep]; b <- b[keep]
      # Canonical order for dedup key only; keep original a/b assignment
      lo <- pmin(a, b)
      hi <- pmax(a, b)
      for (i in seq_along(a)) {
        if (n_found >= n) break
        key <- paste0(lo[i], "_", hi[i])
        if (!exists(key, envir = seen, inherits = FALSE)) {
          n_found <- n_found + 1L
          ids_a[n_found] <- a[i]
          ids_b[n_found] <- b[i]
          assign(key, TRUE, envir = seen)
        }
      }
    }
    list(a = ids_a, b = ids_b)
  }

  # Sample n pairs from a group of document indices. Uses rejection sampling
  # when n is much smaller than choose(k, 2) to avoid materializing all pairs.
  sample_from_group <- function(idx, n) {
    k <- length(idx)
    if (k < 2) return(list(a = integer(0), b = integer(0)))
    n_possible <- choose(k, 2)
    if (is.null(n) || n >= n_possible) {
      return(all_pairs(idx))
    }
    # Use rejection sampling when we need less than half the possible pairs
    if (n < n_possible / 2) {
      rejection_sample(idx, n)
    } else {
      p <- all_pairs(idx)
      keep <- sample(n_possible, n)
      list(a = p$a[keep], b = p$b[keep])
    }
  }

  # --- Warn about small blocks ---
  if (!is.null(blocks)) {
    block_sizes <- table(blocks)
    small <- names(block_sizes)[block_sizes < 2]
    if (length(small) > 0) {
      message(
        "Skipping ", length(small), " block(s) with fewer than 2 documents: ",
        paste(small, collapse = ", ")
      )
    }
  }

  # Build pairs for a set of document indices, with optional blocks and budget.
  # n is the total budget (NULL = all pairs).
  build_pairs <- function(idx, block_values, n, label) {
    if (is.null(block_values)) {
      # No blocks: single group
      n_possible <- choose(length(idx), 2)
      if (!is.null(n) && n > n_possible) {
        message(
          "`n_", label, "` (", n, ") exceeds the number of unique ", label,
          " pairs (", n_possible, "). Using all ", n_possible, "."
        )
        n <- NULL
      }
      p <- sample_from_group(idx, n)
      list(a = p$a, b = p$b, block = NULL)
    } else {
      # With blocks: allocate budget proportionally
      grp <- block_values[idx]
      block_levels <- unique(grp)

      # Compute per-block doc indices and available pairs
      block_idx_list <- lapply(block_levels, function(bl) idx[grp == bl])
      block_n_possible <- vapply(
        block_idx_list,
        function(bi) if (length(bi) < 2) 0 else choose(length(bi), 2),
        numeric(1)
      )

      # Drop blocks with < 2 docs
      valid <- block_n_possible > 0
      block_levels    <- block_levels[valid]
      block_idx_list  <- block_idx_list[valid]
      block_n_possible <- block_n_possible[valid]

      if (length(block_levels) == 0) {
        return(list(a = integer(0), b = integer(0), block = character(0)))
      }

      total_possible <- sum(block_n_possible)

      if (!is.null(n) && n > total_possible) {
        message(
          "`n_", label, "` (", n, ") exceeds the number of unique ", label,
          " pairs (", total_possible, "). Using all ", total_possible, "."
        )
        n <- NULL
      }

      if (is.null(n)) {
        # Return all pairs from all blocks
        block_targets <- block_n_possible
      } else {
        # Proportional allocation with rounding
        shares <- block_n_possible / total_possible
        block_targets <- floor(shares * n)
        # Distribute remainder randomly, weighted by fractional parts
        remainder <- n - sum(block_targets)
        if (remainder > 0) {
          fractional <- (shares * n) - block_targets
          # Break ties randomly
          extra_idx <- order(fractional + stats::runif(length(fractional)) * 1e-9,
                            decreasing = TRUE)[seq_len(remainder)]
          block_targets[extra_idx] <- block_targets[extra_idx] + 1L
        }
        # Cap at available
        block_targets <- pmin(block_targets, block_n_possible)
      }

      all_a <- integer(0)
      all_b <- integer(0)
      all_block <- character(0)
      for (j in seq_along(block_levels)) {
        if (block_targets[j] == 0) next
        p <- sample_from_group(block_idx_list[[j]], block_targets[j])
        all_a <- c(all_a, p$a)
        all_b <- c(all_b, p$b)
        all_block <- c(all_block, rep(as.character(block_levels[j]), length(p$a)))
      }
      list(a = all_a, b = all_b, block = all_block)
    }
  }

  if (has_split) {
    # --- Split mode ---
    tr <- build_pairs(train_idx, blocks, n_train, "train")
    te <- build_pairs(test_idx,  blocks, n_test,  "test")

    ids_a  <- c(tr$a, te$a)
    ids_b  <- c(tr$b, te$b)
    splits <- c(rep("train", length(tr$a)), rep("test", length(te$a)))

    result <- tibble::tibble(
      doc_id_a = ids_a,
      doc_id_b = ids_b,
      text_a   = documents[ids_a],
      text_b   = documents[ids_b],
      split    = splits
    )

    if (!is.null(blocks)) {
      result$block <- c(tr$block, te$block)
    }

    result
  } else {
    # --- No-split mode ---
    pairs <- build_pairs(seq_len(n_docs), blocks, n_train, "train")

    result <- tibble::tibble(
      doc_id_a = pairs$a,
      doc_id_b = pairs$b,
      text_a   = documents[pairs$a],
      text_b   = documents[pairs$b]
    )

    if (!is.null(blocks)) {
      result$block <- pairs$block
    }

    result
  }
}
