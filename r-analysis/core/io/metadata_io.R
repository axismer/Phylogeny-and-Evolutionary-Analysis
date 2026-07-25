# =============================================================================
# metadata_io.R — 公共 Metadata IO（Framework v0.3 P2）
#
# 职责：参数检查、路径可读、CSV 读取。
# Schema / 列校验仍由 metadata/metadata_validator.R 负责。
# 禁止覆盖 validate_metadata_file()。
# =============================================================================

#' 要求已提供 metadata 路径参数
#'
#' @param path metadata 路径（可为 NULL）
#' @param message 完整错误消息；默认通用文案
#' @return invisible(path)；缺失 → MISSING_METADATA_ARGUMENT
require_metadata_argument <- function(path, message = NULL) {
  if (is.null(path) || !nzchar(as.character(path)[[1]])) {
    msg <- if (!is.null(message) && nzchar(as.character(message)[[1]])) {
      as.character(message)[[1]]
    } else {
      "缺少 --metadata"
    }
    raise_framework_error("MISSING_METADATA_ARGUMENT", msg)
  }
  invisible(as.character(path)[[1]])
}

#' 确认 metadata 文件存在且可读（不做 schema 校验）
#'
#' @param path metadata 路径
#' @param message_prefix 消息前缀，如 "BacteriaStrategy"
#' @return invisible(path)；不存在 → METADATA_FILE_NOT_FOUND
ensure_metadata_readable <- function(path, message_prefix = "") {
  path <- as.character(path)[[1]]
  if (!file.exists(path)) {
    prefix <- if (nzchar(as.character(message_prefix)[[1]])) {
      paste0(as.character(message_prefix)[[1]], ": ")
    } else {
      ""
    }
    raise_framework_error(
      "METADATA_FILE_NOT_FOUND",
      paste0(prefix, "metadata 不存在: ", path)
    )
  }
  # 可读性探测（打开失败也视为不可用）
  ok <- tryCatch(
    {
      con <- file(path, open = "r", encoding = "UTF-8")
      close(con)
      TRUE
    },
    error = function(e) FALSE
  )
  if (!isTRUE(ok)) {
    prefix <- if (nzchar(as.character(message_prefix)[[1]])) {
      paste0(as.character(message_prefix)[[1]], ": ")
    } else {
      ""
    }
    raise_framework_error(
      "METADATA_FILE_NOT_FOUND",
      paste0(prefix, "metadata 不可读: ", path)
    )
  }
  invisible(path)
}

#' 读取 metadata CSV（不做 schema 校验）
#'
#' @param path metadata 路径
#' @param message_prefix 用于不存在时的消息前缀
#' @return data.frame；失败 → METADATA_FILE_NOT_FOUND
read_metadata <- function(path, message_prefix = "") {
  ensure_metadata_readable(path, message_prefix = message_prefix)
  meta <- tryCatch(
    utils::read.csv(
      path,
      stringsAsFactors = FALSE,
      check.names = FALSE
    ),
    error = function(e) {
      prefix <- if (nzchar(as.character(message_prefix)[[1]])) {
        paste0(as.character(message_prefix)[[1]], ": ")
      } else {
        ""
      }
      raise_framework_error(
        "METADATA_FILE_NOT_FOUND",
        paste0(prefix, "metadata 读取失败: ", path, " — ", conditionMessage(e))
      )
    }
  )
  meta
}
