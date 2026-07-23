# =============================================================================
# prepare_platform_fasta.R
# 将仓库 data/raw/ 下多个单序列 FASTA 合并为 test-data/platform_16s.fasta
# 不修改建树逻辑；仅准备真实测试输入。
# =============================================================================

get_script_dir <- function() {
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)
  if (length(file_arg) > 0) {
    return(dirname(normalizePath(sub("^--file=", "", file_arg[1]))))
  }
  normalizePath(getwd())
}

script_dir <- get_script_dir()
r_root <- normalizePath(file.path(script_dir, ".."), winslash = "/")
raw_dir <- normalizePath(file.path(r_root, "..", "data", "raw"), winslash = "/", mustWork = FALSE)
out_fasta <- file.path(r_root, "test-data", "platform_16s.fasta")

if (!dir.exists(raw_dir)) {
  stop("未找到平台 raw 目录: ", raw_dir)
}

files <- list.files(raw_dir, pattern = "\\.(fasta|fa|fna)$", ignore.case = TRUE, full.names = TRUE)
files <- sort(files)
if (length(files) < 3) {
  stop("raw 中 FASTA 不足 3 个: ", raw_dir)
}

dir.create(dirname(out_fasta), recursive = TRUE, showWarnings = FALSE)

# 物种名：文件名去掉扩展名与末尾 16S
species_from_file <- function(path) {
  base <- sub("\\.[^.]+$", "", basename(path))
  base <- sub("(?i)\\s*16s\\s*$", "", base, perl = TRUE)
  trimws(base)
}

con <- file(out_fasta, open = "wt", encoding = "UTF-8")
on.exit(close(con), add = TRUE)

n_written <- 0L
for (f in files) {
  lines <- readLines(f, warn = FALSE, encoding = "UTF-8")
  if (length(lines) == 0) next

  # 只取文件中第一条序列
  header_idx <- which(startsWith(trimws(lines), ">"))
  if (length(header_idx) == 0) next
  start <- header_idx[[1]]
  end <- if (length(header_idx) >= 2) header_idx[[2]] - 1L else length(lines)
  seq_lines <- lines[(start + 1L):end]
  seq_lines <- seq_lines[!grepl("^\\s*$", seq_lines)]
  seq_lines <- gsub("\\s+", "", seq_lines)
  seq <- paste(seq_lines, collapse = "")
  if (!nzchar(seq)) next

  sp <- species_from_file(f)
  # FASTA 标签避免空格导致部分工具拆分：空格改下划线
  sp_tag <- gsub("\\s+", "_", sp)
  writeLines(paste0(">", sp_tag), con)
  # 每行 70 字符
  chars <- strsplit(toupper(seq), "")[[1]]
  if (length(chars) == 0) next
  chunks <- split(chars, ceiling(seq_along(chars) / 70))
  for (ch in chunks) {
    writeLines(paste(ch, collapse = ""), con)
  }
  n_written <- n_written + 1L
}

if (n_written < 3) {
  stop("合并后序列不足 3 条")
}

message("已写入: ", out_fasta)
message("序列条数: ", n_written)
message("来源目录: ", raw_dir)
