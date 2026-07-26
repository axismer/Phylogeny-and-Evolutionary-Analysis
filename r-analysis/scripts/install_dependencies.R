#!/usr/bin/env Rscript
# =============================================================================
# PhyloPlatform - R 依赖一键安装脚本
# 用法: Rscript scripts/install_dependencies.R
# =============================================================================

cat("========================================\n")
cat(" PhyloPlatform R 依赖安装\n")
cat("========================================\n\n")

# --- 0. 设置用户可写的包安装目录 ---
user_lib <- file.path(Sys.getenv("LOCALAPPDATA"), "R", "win-library",
                      paste(R.version$major, substr(R.version$minor, 1, 1), sep = "."))
if (!dir.exists(user_lib)) dir.create(user_lib, recursive = TRUE)
.libPaths(c(user_lib, .libPaths()))
cat(sprintf("包安装目录: %s\n\n", user_lib))

# --- 1. CRAN 包 ---
cran_packages <- c(
  "ape",
  "phangorn",
  "ggplot2",
  "dplyr",
  "readr",
  "tidyr",
  "yaml",
  "jsonlite",
  "stringr",
  "purrr",
  "optparse",
  "glue"
)

cat("[1/3] 安装 CRAN 包...\n")
installed <- rownames(installed.packages())

for (p in cran_packages) {
  if (!p %in% installed) {
    cat(sprintf("  安装: %s\n", p))
    install.packages(p, repos = "https://cloud.r-project.org")
  } else {
    cat(sprintf("  已存在: %s (%s)\n", p, as.character(packageVersion(p))))
  }
}

# --- 2. Bioconductor ---
cat("\n[2/3] 安装 Bioconductor 包...\n")

if (!requireNamespace("BiocManager", quietly = TRUE)) {
  cat("  安装 BiocManager...\n")
  install.packages("BiocManager", repos = "https://cloud.r-project.org")
}

cat(sprintf("  BiocManager 版本: %s\n", as.character(BiocManager::version())))

bioc_packages <- c(
  "Biostrings",
  "ggtree",
  "treeio",
  "tidytree",
  "ggtreeExtra"
)

for (p in bioc_packages) {
  if (!requireNamespace(p, quietly = TRUE)) {
    cat(sprintf("  安装: %s\n", p))
    BiocManager::install(p, update = FALSE, ask = FALSE)
  } else {
    cat(sprintf("  已存在: %s (%s)\n", p, as.character(packageVersion(p))))
  }
}

# --- 3. 验证 ---
cat("\n[3/3] 验证安装...\n")

all_packages <- c(cran_packages, bioc_packages)
failed <- c()

for (p in all_packages) {
  if (requireNamespace(p, quietly = TRUE)) {
    cat(sprintf("  [OK] %s (%s)\n", p, as.character(packageVersion(p))))
  } else {
    cat(sprintf("  [FAIL] %s\n", p))
    failed <- c(failed, p)
  }
}

cat("\n========================================\n")
if (length(failed) == 0) {
  cat(" 所有 R 依赖安装成功!\n")
} else {
  cat(sprintf(" 以下包安装失败: %s\n", paste(failed, collapse = ", ")))
  cat(" 请检查网络连接或手动安装。\n")
}
cat("========================================\n")
