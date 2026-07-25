# =============================================================================
# run_framework_v03_p3_regression.R — Framework v0.3 P3 Plugin Registry
#
# 用法：Rscript scripts/runners/run_framework_v03_p3_regression.R
# =============================================================================

args_full <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args_full, value = TRUE)
if (length(file_arg) < 1) stop("请用 Rscript 运行", call. = FALSE)
this_dir <- dirname(normalizePath(sub("^--file=", "", file_arg[1]), winslash = "/"))
root <- normalizePath(file.path(this_dir, "..", ".."), winslash = "/")
runner <- file.path(root, "runners", "run_analysis.R")
out_root <- file.path(root, "output", "tasks", "framework_v03_p3_regression")
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
    error_message = if (is.null(result)) "" else as.character(result$error_message %||% ""),
    notes = if (length(notes)) paste(notes, collapse = " | ") else "PASS"
  )
}

# --- in-process plugin contract / duplicate tests ---
source(file.path(root, "strategies", "strategy_registry.R"), local = FALSE)
dirs <- source_framework_core()
discover_and_register_plugins(dirs, reset = TRUE)

plugin_load_ok <- TRUE
plugin_load_notes <- "PASS"
registered <- list_registered_strategies()
need <- c("virus", "bacteria", "archaea", "eukaryote")
if (!all(need %in% registered)) {
  plugin_load_ok <- FALSE
  plugin_load_notes <- paste0(
    "已注册缺少: ", paste(setdiff(need, registered), collapse = ","),
    " 实际=", paste(registered, collapse = ",")
  )
} else {
  vstat <- get_registered_plugin("virus")$get_status()
  bstat <- get_registered_plugin("bacteria")$get_status()
  astat <- get_registered_plugin("archaea")$get_status()
  if (!identical(vstat, "production") || !identical(bstat, "production") ||
      !identical(astat, "stub")) {
    plugin_load_ok <- FALSE
    plugin_load_notes <- paste0(
      "status 不符 virus=", vstat, " bacteria=", bstat, " archaea=", astat
    )
  }
}

# invalid contract
invalid_ok <- FALSE
invalid_code <- NA_character_
invalid_notes <- ""
bad_env <- new.env(parent = emptyenv())
bad_env$get_organism_type <- function() "broken"
tryCatch(
  {
    validate_plugin_contract(bad_env, plugin_path = "invalid_test")
    invalid_notes <- "应抛 PLUGIN_CONTRACT_INVALID"
  },
  error = function(e) {
    invalid_code <<- extract_error_code(e, default = "")
    if (identical(invalid_code, "PLUGIN_CONTRACT_INVALID")) {
      invalid_ok <<- TRUE
      invalid_notes <<- "PASS"
    } else {
      invalid_notes <<- paste0("code=", invalid_code, " msg=", conditionMessage(e))
    }
  }
)

# duplicate type
dup_ok <- FALSE
dup_code <- NA_character_
dup_notes <- ""
dup_env <- new.env(parent = globalenv())
dup_env$get_organism_type <- function() "virus"
dup_env$get_status <- function() "production"
dup_env$get_metadata_schema <- function() {
  list(organism_type = "virus", extra_columns = character())
}
dup_env$get_default_config <- function() list(tree = list())
dup_env$get_strategy <- function() stop("should not run")
tryCatch(
  {
    validate_plugin_contract(dup_env, plugin_path = "dup_test")
    manifest <- build_plugin_manifest(dup_env, "dup_test/plugin.R")
    register_plugin_manifest(manifest, overwrite = FALSE)
    dup_notes <- "应抛 PLUGIN_DUPLICATE_TYPE"
  },
  error = function(e) {
    dup_code <<- extract_error_code(e, default = "")
    if (identical(dup_code, "PLUGIN_DUPLICATE_TYPE")) {
      dup_ok <<- TRUE
      dup_notes <<- "PASS"
    } else {
      dup_notes <<- paste0("code=", dup_code, " msg=", conditionMessage(e))
    }
  }
)

unit_results <- list(
  list(
    case_id = "plugin_discovery",
    ok = plugin_load_ok,
    exit_code = if (plugin_load_ok) 0L else 1L,
    status = if (plugin_load_ok) "ok" else "fail",
    error_code = NA_character_,
    error_message = "",
    notes = plugin_load_notes
  ),
  list(
    case_id = "plugin_contract_invalid",
    ok = invalid_ok,
    exit_code = if (invalid_ok) 0L else 1L,
    status = if (invalid_ok) "ok" else "fail",
    error_code = invalid_code,
    error_message = "",
    notes = invalid_notes
  ),
  list(
    case_id = "plugin_duplicate_type",
    ok = dup_ok,
    exit_code = if (dup_ok) 0L else 1L,
    status = if (dup_ok) "ok" else "fail",
    error_code = dup_code,
    error_message = "",
    notes = dup_notes
  )
)

virus_fasta <- file.path(root, "test-data", "virus", "valid", "sequences.fasta")
virus_meta <- file.path(root, "test-data", "virus", "valid", "metadata.csv")
bact_fasta <- file.path(root, "test-data", "bacteria", "valid", "valid.fasta")
bact_meta <- file.path(root, "test-data", "bacteria", "valid", "metadata.csv")

pipeline_cases <- list(
  list(
    case_id = "virus_plugin_valid",
    type = "virus",
    fasta = virus_fasta,
    metadata = virus_meta,
    expect_exit = 0L,
    expect_status = c("success", "partial"),
    forbid_error_code = TRUE
  ),
  list(
    case_id = "bacteria_plugin_valid",
    type = "bacteria",
    fasta = bact_fasta,
    metadata = bact_meta,
    expect_exit = 0L,
    expect_status = c("success", "partial"),
    forbid_error_code = TRUE
  ),
  list(
    case_id = "archaea_plugin_stub",
    type = "archaea",
    fasta = virus_fasta,
    metadata = NULL,
    expect_exit = 2L,
    expect_status = "not_implemented",
    expect_error_code = "UNSUPPORTED_ORGANISM"
  ),
  list(
    case_id = "unknown_organism",
    type = "fungi_unknown_xyz",
    fasta = virus_fasta,
    metadata = NULL,
    expect_exit = 2L,
    expect_status = "not_implemented",
    expect_error_code = "UNSUPPORTED_ORGANISM"
  )
)

pipeline_results <- lapply(pipeline_cases, function(c) do.call(run_case, c))
results <- c(unit_results, pipeline_results)

summary_path <- file.path(out_root, "summary.json")
payload <- list(
  generated_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
  framework = "v0.3-p3",
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
message("======== Framework v0.3 P3 regression ========")
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
