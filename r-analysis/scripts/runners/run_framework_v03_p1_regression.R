# =============================================================================
# run_framework_v03_p1_regression.R — Framework v0.3 P1 error contract
#
# 用法：Rscript scripts/runners/run_framework_v03_p1_regression.R
# =============================================================================

args_full <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args_full, value = TRUE)
if (length(file_arg) < 1) stop("请用 Rscript 运行", call. = FALSE)
this_dir <- dirname(normalizePath(sub("^--file=", "", file_arg[1]), winslash = "/"))
root <- normalizePath(file.path(this_dir, "..", ".."), winslash = "/")
runner <- file.path(root, "runners", "run_analysis.R")
out_root <- file.path(root, "output", "tasks", "framework_v03_p1_regression")
dir.create(out_root, recursive = TRUE, showWarnings = FALSE)

prep <- file.path(root, "scripts", "prep", "prepare_virus_regression_fixtures.R")
if (file.exists(prep)) {
  suppressWarnings(system2("Rscript", shQuote(prep), stdout = TRUE, stderr = TRUE))
}

`%||%` <- function(a, b) {
  if (is.null(a) || (length(a) == 1 && is.na(a))) b else a
}

read_result <- function(output_dir) {
  path <- file.path(output_dir, "analysis_result.json")
  if (!file.exists(path)) return(NULL)
  jsonlite::fromJSON(path, simplifyVector = TRUE)
}

run_case <- function(case_id, type, fasta, metadata = NULL,
                     expect_exit, expect_status, expect_error_code = NULL,
                     forbid_error_code = FALSE, error_substr = NULL) {
  out_dir <- file.path(out_root, case_id)
  if (dir.exists(out_dir)) unlink(out_dir, recursive = TRUE, force = TRUE)
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

  args <- c(shQuote(runner), "--type", type, "--fasta", shQuote(fasta),
            "--output", shQuote(out_dir))
  if (!is.null(metadata) && nzchar(metadata)) {
    args <- c(args, "--metadata", shQuote(metadata))
  }

  message("---- ", case_id, " ----")
  log <- suppressWarnings(system2("Rscript", args = args, stdout = TRUE, stderr = TRUE))
  exit_code <- attr(log, "status")
  if (is.null(exit_code)) exit_code <- 0L
  exit_code <- as.integer(exit_code)

  result <- read_result(out_dir)
  notes <- character()
  ok <- TRUE

  if (exit_code != as.integer(expect_exit)) {
    ok <- FALSE
    notes <- c(notes, paste0("exit 期望 ", expect_exit, " 实际 ", exit_code))
  }
  actual_status <- if (is.null(result)) "<missing>" else as.character(result$status)
  expect_statuses <- expect_status
  if (!actual_status %in% expect_statuses) {
    ok <- FALSE
    notes <- c(notes, paste0("status 期望 ", paste(expect_statuses, collapse = "|"),
                             " 实际 ", actual_status))
  }
  if (is.null(result)) {
    ok <- FALSE
    notes <- c(notes, "analysis_result.json 缺失")
  } else {
    has_code <- "error_code" %in% names(result)
    if (isTRUE(forbid_error_code)) {
      if (has_code) {
        ok <- FALSE
        notes <- c(notes, "success/partial 不应存在 error_code")
      }
    }
    if (!is.null(expect_error_code)) {
      if (!has_code) {
        ok <- FALSE
        notes <- c(notes, "缺少 error_code")
      } else if (!identical(as.character(result$error_code), expect_error_code)) {
        ok <- FALSE
        notes <- c(notes, paste0("error_code 期望 ", expect_error_code,
                                 " 实际 ", result$error_code))
      }
    }
    if (!is.null(error_substr)) {
      msg <- as.character(result$error_message %||% "")
      if (!grepl(error_substr, msg, fixed = TRUE) && !grepl(error_substr, msg, perl = TRUE)) {
        ok <- FALSE
        notes <- c(notes, paste0("error_message 未包含: ", error_substr))
      }
    }
  }

  list(
    case_id = case_id,
    ok = ok,
    exit_code = exit_code,
    status = actual_status,
    error_code = if (is.null(result) || is.null(result$error_code)) {
      NA_character_
    } else {
      as.character(result$error_code)
    },
    error_message = if (is.null(result)) "" else as.character(result$error_message %||% ""),
    notes = if (length(notes)) paste(notes, collapse = " | ") else "PASS"
  )
}

cases <- list(
  list(
    case_id = "virus_valid",
    type = "virus",
    fasta = file.path(root, "test-data", "virus", "valid", "sequences.fasta"),
    metadata = file.path(root, "test-data", "virus", "valid", "metadata.csv"),
    expect_exit = 0L,
    expect_status = c("success", "partial"),
    forbid_error_code = TRUE
  ),
  list(
    case_id = "bacteria_valid",
    type = "bacteria",
    fasta = file.path(root, "test-data", "bacteria", "valid", "valid.fasta"),
    metadata = file.path(root, "test-data", "bacteria", "valid", "metadata.csv"),
    expect_exit = 0L,
    expect_status = c("success", "partial"),
    forbid_error_code = TRUE
  ),
  list(
    case_id = "virus_empty",
    type = "virus",
    fasta = file.path(root, "test-data", "virus", "empty", "empty.fasta"),
    metadata = NULL,
    expect_exit = 1L,
    expect_status = "error",
    expect_error_code = "EMPTY_FASTA"
  ),
  list(
    case_id = "virus_tip_mismatch",
    type = "virus",
    fasta = file.path(root, "test-data", "virus", "metadata_mismatch", "sequences.fasta"),
    metadata = file.path(root, "test-data", "virus", "metadata_mismatch", "metadata.csv"),
    expect_exit = 1L,
    expect_status = "error",
    expect_error_code = "TIP_METADATA_MISMATCH",
    error_substr = "不匹配"
  ),
  list(
    case_id = "unknown_organism",
    type = "fungi_unknown_xyz",
    fasta = file.path(root, "test-data", "virus", "valid", "sequences.fasta"),
    metadata = NULL,
    expect_exit = 2L,
    expect_status = "not_implemented",
    expect_error_code = "UNSUPPORTED_ORGANISM"
  )
)

results <- lapply(cases, function(c) do.call(run_case, c))

summary_path <- file.path(out_root, "summary.json")
payload <- list(
  generated_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
  framework = "v0.3-p1",
  cases = lapply(results, function(r) {
    list(
      case_id = r$case_id,
      ok = r$ok,
      exit_code = r$exit_code,
      status = r$status,
      error_code = r$error_code,
      error_message = r$error_message,
      notes = r$notes
    )
  })
)
jsonlite::write_json(payload, summary_path, auto_unbox = TRUE, pretty = TRUE)

n_pass <- sum(vapply(results, function(r) isTRUE(r$ok), logical(1)))
n_fail <- length(results) - n_pass
message("======== Framework v0.3 P1 regression ========")
for (r in results) {
  message(sprintf(
    "[%s] %s | exit=%s status=%s code=%s | %s",
    if (isTRUE(r$ok)) "PASS" else "FAIL",
    r$case_id, r$exit_code, r$status,
    if (is.na(r$error_code)) "<none>" else r$error_code,
    r$notes
  ))
}
message(sprintf("Passed %d / %d  (summary: %s)", n_pass, length(results), summary_path))
quit(save = "no", status = if (n_fail == 0) 0 else 1)
