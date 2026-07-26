#!/usr/bin/env Rscript
# =============================================================================
# PhyloPlatform - R 环境检查脚本
# 用法: Rscript scripts/check_environment.R
# =============================================================================

cat("========================================\n")
cat(" PhyloPlatform 环境检查\n")
cat("========================================\n\n")

errors <- 0
warnings <- 0

# --- 1. R 版本检查 ---
cat("[1/5] R 版本\n")
cat(sprintf("  当前: %s\n", R.version.string))

r_ver <- getRversion()
if (r_ver >= "4.3.0") {
  cat("  [OK] R >= 4.3.x\n")
} else {
  cat("  [FAIL] 需要 R >= 4.3.x\n")
  errors <- errors + 1
}

# --- 2. Bioconductor 版本 ---
cat("\n[2/5] Bioconductor\n")
if (requireNamespace("BiocManager", quietly = TRUE)) {
  bioc_ver <- BiocManager::version()
  cat(sprintf("  BiocManager: %s\n", bioc_ver))
  if (bioc_ver >= "3.18") {
    cat("  [OK] Bioconductor >= 3.18\n")
  } else {
    cat("  [WARN] 推荐 Bioconductor >= 3.18\n")
    warnings <- warnings + 1
  }
} else {
  cat("  [FAIL] BiocManager 未安装\n")
  cat("  运行: install.packages('BiocManager')\n")
  errors <- errors + 1
}

# --- 3. R 包检查 ---
cat("\n[3/5] R 包\n")

check_package <- function(pkg, source = "CRAN") {
  if (requireNamespace(pkg, quietly = TRUE)) {
    ver <- as.character(packageVersion(pkg))
    cat(sprintf("  [OK] %-15s %s\n", pkg, ver))
    return(TRUE)
  } else {
    cat(sprintf("  [FAIL] %-15s 未安装 (%s)\n", pkg, source))
    return(FALSE)
  }
}

cran_pkgs <- c("ape", "phangorn", "ggplot2", "dplyr", "readr",
               "tidyr", "yaml", "jsonlite", "stringr", "purrr",
               "optparse", "glue")

bioc_pkgs <- c("Biostrings", "ggtree", "treeio", "tidytree", "ggtreeExtra")

cat("  --- CRAN 包 ---\n")
for (p in cran_pkgs) {
  if (!check_package(p, "CRAN")) errors <- errors + 1
}

cat("  --- Bioconductor 包 ---\n")
for (p in bioc_pkgs) {
  if (!check_package(p, "Bioconductor")) errors <- errors + 1
}

# --- 4. 外部工具检查 ---
cat("\n[4/5] 外部工具\n")

check_command <- function(cmd, name) {
  result <- tryCatch({
    out <- system(cmd, intern = TRUE, ignore.stderr = TRUE)
    cat(sprintf("  [OK] %-10s %s\n", name, out[1]))
    TRUE
  }, error = function(e) {
    cat(sprintf("  [FAIL] %-10s 未找到\n", name))
    FALSE
  }, warning = function(w) {
    cat(sprintf("  [FAIL] %-10s 未找到\n", name))
    FALSE
  })
  return(result)
}

if (!check_command("mafft --version", "MAFFT")) {
  cat("         安装: conda install -c bioconda mafft\n")
  errors <- errors + 1
}

if (!check_command("git --version", "Git")) {
  errors <- errors + 1
}

# --- 5. 输出能力检查 ---
cat("\n[5/5] 图形输出能力\n")

# PNG
png_ok <- tryCatch({
  tf <- tempfile(fileext = ".png")
  png(tf, width = 480, height = 480)
  plot(1)
  dev.off()
  file.exists(tf)
}, error = function(e) FALSE)

if (png_ok) {
  cat("  [OK] PNG 输出\n")
} else {
  cat("  [FAIL] PNG 输出不可用\n")
  errors <- errors + 1
}

# PDF
pdf_ok <- tryCatch({
  tf <- tempfile(fileext = ".pdf")
  pdf(tf)
  plot(1)
  dev.off()
  file.exists(tf)
}, error = function(e) FALSE)

if (pdf_ok) {
  cat("  [OK] PDF 输出\n")
} else {
  cat("  [FAIL] PDF 输出不可用\n")
  errors <- errors + 1
}

# --- 汇总 ---
cat("\n========================================\n")
cat(" 检查结果汇总\n")
cat("========================================\n")
cat(sprintf("  错误: %d\n", errors))
cat(sprintf("  警告: %d\n", warnings))

if (errors == 0) {
  cat("\n  ✓ 环境检查通过，可以运行 PhyloPipeline!\n")
} else {
  cat(sprintf("\n  ✗ 有 %d 项未通过，请先修复。\n", errors))
  cat("  运行安装脚本: Rscript scripts/install_dependencies.R\n")
}
cat("========================================\n")

# 返回退出码
if (errors > 0) quit(status = 1)
