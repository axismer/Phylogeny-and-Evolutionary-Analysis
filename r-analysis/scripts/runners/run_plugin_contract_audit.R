# =============================================================================
# run_plugin_contract_audit.R — 审计 strategies/*/plugin.R 契约（Framework v0.3 P4）
#
# 用法：Rscript scripts/runners/run_plugin_contract_audit.R
# 输出：
#   docs/plugin_contract_audit_report.md
#   output/tasks/plugin_contract_audit/summary.json
# =============================================================================

args_full <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args_full, value = TRUE)
if (length(file_arg) < 1) stop("请用 Rscript 运行", call. = FALSE)
this_dir <- dirname(normalizePath(sub("^--file=", "", file_arg[1]), winslash = "/"))
root <- normalizePath(file.path(this_dir, "..", ".."), winslash = "/")

source(file.path(root, "strategies", "strategy_registry.R"), local = FALSE)
dirs <- source_framework_core()
discover_and_register_plugins(dirs, reset = TRUE)

out_dir <- file.path(root, "output", "tasks", "plugin_contract_audit")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
report_md <- file.path(root, "docs", "plugin_contract_audit_report.md")

expected_types <- c("virus", "bacteria", "archaea", "eukaryote", "fungi")
expected_status <- list(
  virus = "production",
  bacteria = "production",
  archaea = "stub",
  eukaryote = "stub",
  fungi = "production"
)

audit_one <- function(type) {
  notes <- character()
  ok <- TRUE
  entry <- get_registered_plugin(type)
  if (is.null(entry)) {
    return(list(
      organism_type = type,
      ok = FALSE,
      status = NA_character_,
      contract = "MISSING",
      notes = "plugin 未注册"
    ))
  }

  # Re-validate contract from stored env
  tryCatch(
    validate_plugin_contract(entry$env, plugin_path = entry$plugin_path %||% ""),
    error = function(e) {
      ok <<- FALSE
      notes <<- c(notes, paste0("contract: ", conditionMessage(e)))
    }
  )

  st <- tryCatch(as.character(entry$get_status())[[1]], error = function(...) NA_character_)
  exp_st <- expected_status[[type]]
  if (!identical(st, exp_st)) {
    ok <- FALSE
    notes <- c(notes, paste0("status 期望 ", exp_st, " 实际 ", st))
  }

  schema <- tryCatch(entry$get_metadata_schema(), error = function(e) {
    ok <<- FALSE
    notes <<- c(notes, paste0("schema: ", conditionMessage(e)))
    NULL
  })
  if (!is.null(schema) && !is.list(schema$extra_columns) && !is.character(schema$extra_columns)) {
    ok <- FALSE
    notes <- c(notes, "schema$extra_columns 缺失或类型不对")
  }

  cfg <- tryCatch(entry$get_default_config(), error = function(e) {
    ok <<- FALSE
    notes <<- c(notes, paste0("config: ", conditionMessage(e)))
    NULL
  })
  if (!is.null(cfg)) {
    for (k in c("tree", "distance", "visualization")) {
      if (!is.list(cfg[[k]])) {
        ok <- FALSE
        notes <- c(notes, paste0("default_config 缺少 list 字段: ", k))
      }
    }
  }

  # Compare schema extras to TYPE_EXTRA_COLUMNS fallback when available
  if (exists("TYPE_EXTRA_COLUMNS") && !is.null(schema) &&
      !is.null(TYPE_EXTRA_COLUMNS[[type]])) {
    fb <- as.character(TYPE_EXTRA_COLUMNS[[type]])
    pl <- as.character(schema$extra_columns)
    if (!identical(sort(fb), sort(pl))) {
      ok <- FALSE
      notes <- c(notes, paste0(
        "extra_columns 与 TYPE_EXTRA_COLUMNS fallback 不一致: plugin=",
        paste(pl, collapse = ","), " fallback=", paste(fb, collapse = ",")
      ))
    }
  }

  list(
    organism_type = type,
    ok = ok,
    status = st,
    plugin_path = as.character(entry$plugin_path %||% ""),
    contract = if (ok) "VALID" else "INVALID",
    notes = if (length(notes)) paste(notes, collapse = " | ") else "PASS"
  )
}

`%||%` <- function(a, b) {
  if (is.null(a) || (length(a) == 1 && is.na(a))) b else a
}

registered <- list_registered_strategies()
discovery_ok <- all(expected_types %in% registered)
rows <- lapply(expected_types, audit_one)
n_pass <- sum(vapply(rows, function(r) isTRUE(r$ok), logical(1)))
n_fail <- length(rows) - n_pass
overall_ok <- isTRUE(discovery_ok) && n_fail == 0L

# Write markdown report
lines <- c(
  "# Plugin Contract Audit Report",
  "",
  paste0("> Framework v0.3 P4  "),
  paste0("> generated_at: ", format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"), "  "),
  paste0("> overall: **", if (overall_ok) "PASS" else "FAIL", "**"),
  "",
  "## Discovery",
  "",
  paste0("- registered: `", paste(registered, collapse = "`, `"), "`"),
  paste0("- expected: `", paste(expected_types, collapse = "`, `"), "`"),
  paste0("- discovery_ok: ", discovery_ok),
  "",
  "## Per-plugin contract",
  "",
  "| organism_type | status | contract | path | notes |",
  "|---------------|--------|----------|------|-------|"
)
for (r in rows) {
  lines <- c(lines, sprintf(
    "| %s | %s | %s | `%s` | %s |",
    r$organism_type,
    r$status %||% "",
    r$contract,
    r$plugin_path %||% "",
    r$notes
  ))
}
lines <- c(
  lines,
  "",
  "## Checks performed",
  "",
  "1. `validate_plugin_contract` on plugin env",
  "2. `get_status()` matches expected (production vs stub)",
  "3. `get_metadata_schema()` / `get_default_config()` shape",
  "4. `extra_columns` vs `TYPE_EXTRA_COLUMNS` fallback alignment",
  "",
  "## Summary",
  "",
  paste0("- passed: ", n_pass, " / ", length(rows)),
  paste0("- failed: ", n_fail),
  ""
)
writeLines(lines, report_md, useBytes = FALSE)

payload <- list(
  generated_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
  overall_ok = overall_ok,
  discovery_ok = discovery_ok,
  registered = registered,
  cases = lapply(rows, function(r) {
    list(
      organism_type = r$organism_type,
      ok = r$ok,
      status = r$status,
      contract = r$contract,
      plugin_path = r$plugin_path,
      notes = r$notes
    )
  })
)
jsonlite::write_json(
  payload,
  file.path(out_dir, "summary.json"),
  auto_unbox = TRUE,
  pretty = TRUE
)

message("======== Plugin contract audit ========")
for (r in rows) {
  message(sprintf(
    "[%s] %s status=%s | %s",
    if (isTRUE(r$ok)) "PASS" else "FAIL",
    r$organism_type, r$status %||% "?", r$notes
  ))
}
message(sprintf("Report: %s", report_md))
message(sprintf("Passed %d / %d", n_pass, length(rows)))
quit(save = "no", status = if (overall_ok) 0 else 1)
