# =============================================================================
# error_codes.R — Framework v0.3 P1 统一错误码
#
# success / partial：禁止出现 error_code 键
# error：必须含 error_code + error_message
# not_implemented：error_code = UNSUPPORTED_ORGANISM
# =============================================================================

FRAMEWORK_ERROR_CODES <- c(
  "EMPTY_FASTA",
  "INVALID_DNA",
  "TOO_FEW_SEQUENCE",
  "MISSING_METADATA_ARGUMENT",
  "METADATA_FILE_NOT_FOUND",
  "MISSING_METADATA_FIELDS",
  "TIP_METADATA_MISMATCH",
  "TREE_BUILD_FAILED",
  "VISUALIZATION_FAILED",
  "UNSUPPORTED_ORGANISM",
  # v0.3 P3 plugin registry
  "PLUGIN_NOT_FOUND",
  "PLUGIN_LOAD_FAILED",
  "PLUGIN_CONTRACT_INVALID",
  "PLUGIN_DUPLICATE_TYPE"
)

#' 构造带 error_code 的 condition（供 stop() 抛出）
framework_error <- function(error_code, message) {
  error_code <- as.character(error_code)[[1]]
  message <- paste(as.character(message), collapse = " ")
  structure(
    list(message = message, call = NULL, error_code = error_code),
    class = c("framework_error", "error", "condition")
  )
}

#' 抛出框架错误（替代裸 stop("...") 的业务失败路径）
raise_framework_error <- function(error_code, message) {
  stop(framework_error(error_code, message))
}

#' 从 condition / 字符消息提取 error_code
extract_error_code <- function(e, default = "") {
  if (inherits(e, "framework_error") && !is.null(e$error_code)) {
    return(as.character(e$error_code)[[1]])
  }
  if (is.list(e) && !is.null(e$error_code)) {
    return(as.character(e$error_code)[[1]])
  }
  msg <- if (inherits(e, "condition")) {
    conditionMessage(e)
  } else {
    paste(as.character(e), collapse = " ")
  }
  map_error_message_to_code(msg, default = default)
}

#' 启发式映射（兜底；优先使用 raise_framework_error）
map_error_message_to_code <- function(message, default = "") {
  msg <- paste(as.character(message), collapse = " ")
  if (!nzchar(msg)) return(default)
  if (grepl("未知\\s*--type|未知 organism|UNSUPPORTED_ORGANISM|not_implemented", msg, ignore.case = TRUE, perl = TRUE)) {
    return("UNSUPPORTED_ORGANISM")
  }
  if (grepl("FASTA 为空|empty fasta|无序列记录", msg, ignore.case = TRUE, perl = TRUE)) {
    return("EMPTY_FASTA")
  }
  if (grepl("DNA 字符合法性|INVALID_DNA|非法.*碱基", msg, ignore.case = TRUE, perl = TRUE)) {
    return("INVALID_DNA")
  }
  if (grepl("至少需要\\s*3|TOO_FEW|条序列，当前", msg, ignore.case = TRUE, perl = TRUE)) {
    return("TOO_FEW_SEQUENCE")
  }
  if (grepl("要求提供\\s*--metadata|缺少\\s*--metadata|MISSING_METADATA_ARGUMENT", msg, ignore.case = TRUE, perl = TRUE)) {
    return("MISSING_METADATA_ARGUMENT")
  }
  if (grepl("metadata 不存在|METADATA_FILE_NOT_FOUND", msg, ignore.case = TRUE, perl = TRUE)) {
    return("METADATA_FILE_NOT_FOUND")
  }
  if (grepl("缺少必需列|缺少.*扩展列|MISSING_METADATA_FIELDS|metadata 需要", msg, ignore.case = TRUE, perl = TRUE)) {
    return("MISSING_METADATA_FIELDS")
  }
  if (grepl("tip 不匹配|missing tips|TIP_METADATA_MISMATCH|与 tree tip 不匹配", msg, ignore.case = TRUE, perl = TRUE)) {
    return("TIP_METADATA_MISMATCH")
  }
  if (grepl("建树失败|TREE_BUILD_FAILED", msg, ignore.case = TRUE, perl = TRUE)) {
    return("TREE_BUILD_FAILED")
  }
  if (grepl("可视化失败|VISUALIZATION_FAILED", msg, ignore.case = TRUE, perl = TRUE)) {
    return("VISUALIZATION_FAILED")
  }
  if (grepl("PLUGIN_DUPLICATE_TYPE|duplicate plugin|重复.*plugin|重复.*type", msg, ignore.case = TRUE, perl = TRUE)) {
    return("PLUGIN_DUPLICATE_TYPE")
  }
  if (grepl("PLUGIN_CONTRACT_INVALID|plugin contract|契约无效", msg, ignore.case = TRUE, perl = TRUE)) {
    return("PLUGIN_CONTRACT_INVALID")
  }
  if (grepl("PLUGIN_LOAD_FAILED|plugin 加载失败|加载 plugin 失败", msg, ignore.case = TRUE, perl = TRUE)) {
    return("PLUGIN_LOAD_FAILED")
  }
  if (grepl("PLUGIN_NOT_FOUND|plugin 不存在|未找到 plugin", msg, ignore.case = TRUE, perl = TRUE)) {
    return("PLUGIN_NOT_FOUND")
  }
  if (grepl("FASTA 格式无效|首行应以", msg, ignore.case = TRUE, perl = TRUE)) {
    # 空文件也会先命中格式无效；EMPTY 优先已在上面
    return("EMPTY_FASTA")
  }
  default
}

#' 规范化 error_code；非法值警告后原样返回（仍写出）
normalize_error_code <- function(error_code, status = "error") {
  code <- if (is.null(error_code) || length(error_code) < 1) {
    ""
  } else {
    as.character(error_code)[[1]]
  }
  if (identical(status, "not_implemented")) {
    if (!nzchar(code)) code <- "UNSUPPORTED_ORGANISM"
    return(code)
  }
  if (identical(status, "error") && !nzchar(code)) {
    return("")
  }
  if (nzchar(code) && !code %in% FRAMEWORK_ERROR_CODES) {
    warning("未知 error_code: ", code, call. = FALSE)
  }
  code
}
