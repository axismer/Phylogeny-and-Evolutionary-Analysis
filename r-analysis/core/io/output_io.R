# =============================================================================
# output_io.R — 公共 Output IO 薄包装（Framework v0.3 P2）
#
# 禁止重新实现 JSON writer；最终委托 core/result_writer.R。
# =============================================================================

#' 安全写出 JSON（UTF-8）；分析成功结果请用 write_analysis_output
#'
#' @param obj R 对象
#' @param path 目标路径
safe_write_json <- function(obj, path) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("safe_write_json: 需要 jsonlite", call. = FALSE)
  }
  dir_out <- dirname(path)
  if (!dir.exists(dir_out) && nzchar(dir_out) && !identical(dir_out, ".")) {
    dir.create(dir_out, recursive = TRUE, showWarnings = FALSE)
  }
  txt <- jsonlite::toJSON(
    obj,
    auto_unbox = TRUE,
    pretty = TRUE,
    null = "null",
    force = TRUE
  )
  con <- file(path, open = "wb")
  on.exit(close(con), add = TRUE)
  writeBin(charToRaw(paste0(enc2utf8(as.character(txt)), "\n")), con)
  invisible(normalizePath(path, winslash = "/", mustWork = FALSE))
}

#' 写出 analysis_result.json（委托 write_analysis_result）
#'
#' success/partial 无 error_code 契约由 result_writer 保证。
write_analysis_output <- function(result, output_dir, filename = "analysis_result.json") {
  if (!exists("write_analysis_result", mode = "function")) {
    stop(
      "write_analysis_output: write_analysis_result 未加载（需要 core/result_writer.R）",
      call. = FALSE
    )
  }
  write_analysis_result(result, output_dir, filename = filename)
}
