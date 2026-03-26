#' Wisconsin political ads (2008)
#'
#' A dataset of 935 Wisconsin congressional campaign advertisements from the
#' 2008 election cycle, drawn from Carlson & Montgomery (2017). The dataset
#' includes textscale scores measuring ad negativity, derived from the
#' human-annotated pairwise comparisons published with that paper.
#'
#' @format A tibble with 935 rows and 10 columns:
#' \describe{
#'   \item{text}{Full text of the advertisement.}
#'   \item{candidate}{Candidate identifier.}
#'   \item{state}{Two-letter state abbreviation.}
#'   \item{tone}{Numeric tone code assigned by Carlson & Montgomery
#'     (1 = Promoting, 2 = Mostly promoting, 3 = Contrasting,
#'     4 = Mostly attacking, 5 = Attacking). `NA` for ads without a
#'     tone code.}
#'   \item{alphas}{Continuous negativity score from Carlson &
#'     Montgomery's Bradley-Terry model.}
#'   \item{score}{textscale negativity score derived from pairwise
#'     comparisons.}
#'   \item{score_lower}{Lower bound of the 95% credible interval for
#'     `score`.}
#'   \item{score_upper}{Upper bound of the 95% credible interval for
#'     `score`.}
#'   \item{split}{Whether the document was in the `"Train"` or `"Test"`
#'     split used to validate the model.}
#'   \item{tone_label}{Factor version of `tone` with descriptive labels.}
#' }
#'
#' @source Carlson, T. N., & Montgomery, J. M. (2017). A pairwise comparison
#'   framework for fast, flexible, and reliable human coding of political
#'   texts. *Political Analysis*, 25(1), 97–110.
#'   \doi{10.1017/pan.2016.2}
"ad_tone"


#' Validation results for the ad-tone model
#'
#' A `textscale_validation` object produced by [validate_model()] for the
#' ad-tone example. Contains test-set accuracy and calibration metrics for
#' the model fit to the Carlson & Montgomery (2017) Wisconsin ads.
#'
#' @format A `textscale_validation` object (a list) with three elements:
#' \describe{
#'   \item{metrics}{A one-row tibble with columns `n_pairs`, `n_correct`,
#'     `accuracy`, and `ici`.}
#'   \item{cal_df}{A data frame with columns `prob` (predicted probability)
#'     and `result` (observed outcome) for each test comparison. Used to
#'     construct the calibration plot.}
#'   \item{ici}{Integrated Calibration Index (scalar).}
#' }
#'
#' @seealso [validate_model()], [ad_tone]
"ad_tone_validation"
