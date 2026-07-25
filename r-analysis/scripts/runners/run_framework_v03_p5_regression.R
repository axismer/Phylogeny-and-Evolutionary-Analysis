# =============================================================================
# run_framework_v03_p5_regression.R — Framework v0.3 P5 Fungi plugin
#
# 用法：Rscript scripts/runners/run_framework_v03_p5_regression.R
# =============================================================================

args_full <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args_full, value = TRUE)
if (length(file_arg) < 1) stop("请用 Rscript 运行", call. = FALSE)
this_dir <- dirname(normalizePath(sub("^--file=", "", file_arg[1]), winslash = "/"))
root <- normalizePath(file.path(this_dir, "..", ".."), winslash = "/")
runner <- file.path(root, "runners", "run_analysis.R")
out_root <- file.path(root, "output", "tasks", "framework_v03_p5_regression")
dir.create(out_root, recursive = TRUE, showWarnings = FALSE)

prep_bench <- file.path(root, "scripts", "prep", "prepare_fungi_its_benchmark.R")
prep_fix <- file.path(root, "scripts", "prep", "prepare_fungi_regression_fixtures.R")
if (file.exists(prep_bench) &&
    !file.exists(file.path(root, "data/benchmarks/fungi_its/fungi.fasta"))) {
  suppressWarnings(system2("Rscript", shQuote(prep_bench), stdout = TRUE, stderr = TRUE))
}
if (file.exists(prep_fix)) {
  suppressWarnings(system2("Rscript", shQuote(prep_fix), stdout = TRUE, stderr = TRUE))
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
                     forbid_error_code = FALSE) {
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
  if (!actual_status %in% expect_status) {
    ok <- FALSE
    notes <- c(notes, paste0(
      "status 期望 ", paste(expect_status, collapse = "|"),
      " 实际 ", actual_status
    ))
  }
  if (is.null(result)) {
    ok <- FALSE
    notes <- c(notes, "analysis_result.json 缺失")
  } else {
    has_code <- "error_code" %in% names(result)
    if (isTRUE(forbid_error_code) && has_code) {
      ok <- FALSE
      notes <- c(notes, "success/partial 不应存在 error_code")
    }
    if (!is.null(expect_error_code)) {
      if (!has_code) {
        ok <- FALSE
        notes <- c(notes, "缺少 error_code")
      } else if (!identical(as.character(result$error_code), expect_error_code)) {
        ok <- FALSE
        notes <- c(notes, paste0(
          "error_code 期望 ", expect_error_code,
          " 实际 ", result$error_code
        ))
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
    notes = if (length(notes)) paste(notes, collapse = " | ") else "PASS"
  )
}

# --- plugin contract audit (must include fungi) ---
source(file.path(root, "strategies", "strategy_registry.R"), local = FALSE)
dirs <- source_framework_core()
discover_and_register_plugins(dirs, reset = TRUE)

registered <- list_registered_strategies()
audit_ok <- TRUE
audit_notes <- character()
if (!"fungi" %in% registered) {
  audit_ok <- FALSE
  audit_notes <- c(audit_notes, "fungi 未注册")
} else {
  entry <- get_registered_plugin("fungi")
  tryCatch(
    validate_plugin_contract(entry$env, plugin_path = entry$plugin_path),
    error = function(e) {
      audit_ok <<- FALSE
      audit_notes <<- c(audit_notes, conditionMessage(e))
    }
  )
  st <- tryCatch(entry$get_status(), error = function(...) NA_character_)
  if (!identical(st, "production")) {
    audit_ok <- FALSE
    audit_notes <- c(audit_notes, paste0("status=", st))
  }
}
# also ensure prior plugins still present
for (tp in c("virus", "bacteria")) {
  if (!tp %in% registered) {
    audit_ok <- FALSE
    audit_notes <- c(audit_notes, paste0(tp, " missing"))
  }
}
if (!length(audit_notes)) audit_notes <- paste0("PASS registered=", paste(registered, collapse = ","))

unit_results <- list(
  list(
    case_id = "plugin_contract_audit",
    ok = audit_ok,
    exit_code = if (audit_ok) 0L else 1L,
    status = if (audit_ok) "ok" else "fail",
    error_code = NA_character_,
    notes = paste(audit_notes, collapse = " | ")
  )
)

td <- file.path(root, "test-data", "fungi")
pipeline_cases <- list(
  list(
    case_id = "fungi_valid",
    type = "fungi",
    fasta = file.path(td, "valid", "sequences.fasta"),
    metadata = file.path(td, "valid", "metadata.csv"),
    expect_exit = 0L,
    expect_status = c("success", "partial"),
    forbid_error_code = TRUE
  ),
  list(
    case_id = "fungi_empty",
    type = "fungi",
    fasta = file.path(td, "empty", "empty.fasta"),
    metadata = file.path(td, "valid", "metadata.csv"),
    expect_exit = 1L,
    expect_status = "error",
    expect_error_code = "EMPTY_FASTA"
  ),
  list(
    case_id = "fungi_illegal_dna",
    type = "fungi",
    fasta = file.path(td, "illegal_dna", "sequences.fasta"),
    metadata = file.path(td, "illegal_dna", "metadata.csv"),
    expect_exit = 1L,
    expect_status = "error",
    expect_error_code = "INVALID_DNA"
  ),
  list(
    case_id = "fungi_too_few",
    type = "fungi",
    fasta = file.path(td, "too_few", "sequences.fasta"),
    metadata = file.path(td, "too_few", "metadata.csv"),
    expect_exit = 1L,
    expect_status = "error",
    expect_error_code = "TOO_FEW_SEQUENCE"
  ),
  list(
    case_id = "fungi_tip_mismatch",
    type = "fungi",
    fasta = file.path(td, "tip_mismatch", "sequences.fasta"),
    metadata = file.path(td, "tip_mismatch", "metadata.csv"),
    expect_exit = 1L,
    expect_status = "error",
    expect_error_code = "TIP_METADATA_MISMATCH"
  ),
  list(
    case_id = "unknown_organism",
    type = "protist_unknown_xyz",
    fasta = file.path(td, "valid", "sequences.fasta"),
    metadata = NULL,
    expect_exit = 2L,
    expect_status = "not_implemented",
    expect_error_code = "UNSUPPORTED_ORGANISM"
  )
)

pipeline_results <- lapply(pipeline_cases, function(c) do.call(run_case, c))
results <- c(unit_results, pipeline_results)

summary_path <- file.path(out_root, "summary.json")
jsonlite::write_json(
  list(
    generated_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
    framework = "v0.3-p5",
    cases = lapply(results, function(r) {
      list(
        case_id = r$case_id,
        ok = r$ok,
        exit_code = r$exit_code,
        status = r$status,
        error_code = r$error_code,
        notes = r$notes
      )
    })
  ),
  summary_path,
  auto_unbox = TRUE,
  pretty = TRUE
)

n_pass <- sum(vapply(results, function(r) isTRUE(r$ok), logical(1)))
n_fail <- length(results) - n_pass
message("======== Framework v0.3 P5 regression ========")
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
