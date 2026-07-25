# =============================================================================
# plot_circular_tree.R
# 环形系统发育树可视化引擎（不修改建树逻辑）
#
# 用法：
#   Rscript plot_circular_tree.R <tree.nwk> <metadata.csv> <output.png>
#
# 优先：ggtree + ggtreeExtra + ggplot2 + ggnewscale
# 回退：ape 布局坐标 + ggplot2 自绘环形树与 Phylum/Age 双注释环
# =============================================================================

suppressPackageStartupMessages({
  library(ape)
  library(ggplot2)
})

.circular_has_ggtree <- FALSE
.circular_ggtree_error <- NULL
tryCatch(
  {
    suppressPackageStartupMessages({
      library(ggtree)
      library(ggtreeExtra)
      library(ggnewscale)
    })
    .circular_has_ggtree <<- TRUE
  },
  error = function(e) {
    .circular_ggtree_error <<- conditionMessage(e)
    message(
      "[警告] ggtree/ggtreeExtra 不可用，将使用 ape+ggplot2 fallback: ",
      .circular_ggtree_error
    )
  }
)

.has_ggnewscale <- requireNamespace("ggnewscale", quietly = TRUE)

# -----------------------------------------------------------------------------
# metadata
# -----------------------------------------------------------------------------

load_and_match_metadata <- function(tree, metadata_file) {
  if (!file.exists(metadata_file)) {
    stop("metadata 文件不存在: ", metadata_file, call. = FALSE)
  }
  meta <- utils::read.csv(metadata_file, stringsAsFactors = FALSE, check.names = FALSE)
  required <- c("name", "Phylum", "Age")
  missing_cols <- setdiff(required, names(meta))
  if (length(missing_cols) > 0) {
    stop("metadata 缺少列: ", paste(missing_cols, collapse = ", "), call. = FALSE)
  }
  meta$name <- as.character(meta$name)
  meta$Phylum <- factor(as.character(meta$Phylum))
  meta$Age <- factor(as.character(meta$Age), levels = unique(as.character(meta$Age)))

  tips <- tree$tip.label
  unmatched <- setdiff(tips, meta$name)
  if (length(unmatched) > 0) {
    stop(
      "metadata$name 未能覆盖全部 tip.label，未匹配示例: ",
      paste(utils::head(unmatched, 5), collapse = ", "),
      call. = FALSE
    )
  }
  meta <- meta[match(tips, meta$name), , drop = FALSE]
  rownames(meta) <- meta$name
  attr(meta, "matched_tips") <- length(tips)
  meta
}

# -----------------------------------------------------------------------------
# ggtree 路径
# -----------------------------------------------------------------------------

plot_circular_tree_ggtree <- function(tree, meta, output_file) {
  meta_df <- as.data.frame(meta)
  rownames(meta_df) <- meta_df$name

  p <- ggtree::ggtree(tree, layout = "circular", size = 0.25, color = "grey40")

  p <- p +
    ggtreeExtra::geom_fruit(
      data = meta_df,
      geom = ggplot2::geom_tile,
      mapping = ggplot2::aes(y = .data$name, fill = .data$Phylum),
      offset = 0.02,
      pwidth = 0.08
    ) +
    ggplot2::scale_fill_brewer(palette = "Set3", name = "Phylum", na.value = "grey80") +
    ggplot2::guides(fill = ggplot2::guide_legend(order = 1, ncol = 1)) +
    ggnewscale::new_scale_fill() +
    ggtreeExtra::geom_fruit(
      data = meta_df,
      geom = ggplot2::geom_tile,
      mapping = ggplot2::aes(y = .data$name, fill = .data$Age),
      offset = 0.02,
      pwidth = 0.08
    ) +
    ggplot2::scale_fill_brewer(palette = "Spectral", name = "Age", na.value = "grey80") +
    ggplot2::guides(fill = ggplot2::guide_legend(order = 2, ncol = 1)) +
    ggplot2::theme(
      legend.position = "left",
      legend.title = ggplot2::element_text(face = "bold", size = 10),
      legend.text = ggplot2::element_text(size = 8),
      plot.margin = ggplot2::margin(10, 10, 10, 10)
    ) +
    ggplot2::labs(title = "Circular phylogenetic tree")

  ggplot2::ggsave(
    filename = output_file,
    plot = p,
    width = 12,
    height = 10,
    dpi = 200,
    bg = "white"
  )
  invisible(output_file)
}

# -----------------------------------------------------------------------------
# fallback 布局
# -----------------------------------------------------------------------------

circular_layout_coords <- function(tree) {
  n_tip <- ape::Ntip(tree)
  n_node <- ape::Nnode(tree)
  n_all <- n_tip + n_node
  ee <- tree$edge
  el <- tree$edge.length
  if (is.null(el)) {
    el <- rep(1, nrow(ee))
  }

  children <- vector("list", n_all)
  for (i in seq_len(nrow(ee))) {
    parent <- ee[i, 1]
    child <- ee[i, 2]
    children[[parent]] <- c(children[[parent]], child)
  }

  root <- n_tip + 1L
  tip_rank <- integer(n_tip)
  k <- 0L
  visit <- function(node) {
    if (node <= n_tip) {
      k <<- k + 1L
      tip_rank[node] <<- k
    } else {
      for (ch in children[[node]]) {
        visit(ch)
      }
    }
  }
  visit(root)

  depth <- numeric(n_all)
  angles <- numeric(n_all)
  open_frac <- 0.08
  span <- 2 * pi * (1 - open_frac)
  for (i in seq_len(n_tip)) {
    angles[i] <- (tip_rank[i] - 1) / n_tip * span
  }

  assign_down <- function(node, parent_depth) {
    depth[node] <<- parent_depth
    kids <- children[[node]]
    if (is.null(kids)) {
      return(invisible(NULL))
    }
    for (ch in kids) {
      idx <- which(ee[, 1] == node & ee[, 2] == ch)
      bl <- if (length(idx) == 1) el[[idx]] else 1
      assign_down(ch, parent_depth + bl)
    }
    if (node > n_tip) {
      angles[node] <<- mean(vapply(kids, function(ch) angles[ch], numeric(1)))
    }
  }
  assign_down(root, 0)

  segs <- vector("list", nrow(ee) * 2L)
  j <- 0L
  for (i in seq_len(nrow(ee))) {
    p <- ee[i, 1]
    c <- ee[i, 2]
    j <- j + 1L
    segs[[j]] <- data.frame(
      x = depth[p] * sin(angles[p]),
      y = depth[p] * cos(angles[p]),
      xend = depth[p] * sin(angles[c]),
      yend = depth[p] * cos(angles[c])
    )
    j <- j + 1L
    segs[[j]] <- data.frame(
      x = depth[p] * sin(angles[c]),
      y = depth[p] * cos(angles[c]),
      xend = depth[c] * sin(angles[c]),
      yend = depth[c] * cos(angles[c])
    )
  }
  seg_df <- do.call(rbind, segs)

  tip_df <- data.frame(
    name = tree$tip.label,
    angle = angles[seq_len(n_tip)],
    depth = depth[seq_len(n_tip)],
    stringsAsFactors = FALSE
  )
  tip_df$x <- tip_df$depth * sin(tip_df$angle)
  tip_df$y <- tip_df$depth * cos(tip_df$angle)
  list(segments = seg_df, tips = tip_df, max_depth = max(depth, na.rm = TRUE))
}

ring_tiles <- function(tip_df, meta, column, r0, r1) {
  n_tip <- nrow(tip_df)
  open_frac <- 0.08
  span <- 2 * pi * (1 - open_frac)
  half <- span / n_tip / 2
  rows <- vector("list", n_tip)
  for (i in seq_len(n_tip)) {
    a <- tip_df$angle[i]
    ts <- seq(a - half * 0.92, a + half * 0.92, length.out = 16)
    xs <- c(r0 * sin(ts), rev(r1 * sin(ts)))
    ys <- c(r0 * cos(ts), rev(r1 * cos(ts)))
    nm <- tip_df$name[i]
    rows[[i]] <- data.frame(
      name = nm,
      value = as.character(meta[nm, column]),
      x = xs,
      y = ys,
      id = paste0(column, "_", i),
      stringsAsFactors = FALSE
    )
  }
  do.call(rbind, rows)
}

plot_circular_tree_fallback <- function(tree, meta, output_file) {
  lay <- circular_layout_coords(tree)
  tips <- lay$tips
  max_d <- max(lay$max_depth, 1e-6)
  gap <- max_d * 0.05
  w <- max_d * 0.09
  r_phy0 <- max_d + gap
  r_phy1 <- r_phy0 + w
  r_age0 <- r_phy1 + gap * 0.6
  r_age1 <- r_age0 + w

  phy_ring <- ring_tiles(tips, meta, "Phylum", r_phy0, r_phy1)
  age_ring <- ring_tiles(tips, meta, "Age", r_age0, r_age1)

  grid_r <- seq(0, max_d, length.out = 5)[-1]
  grid_df <- do.call(rbind, lapply(grid_r, function(rr) {
    th <- seq(0, 2 * pi * 0.92, length.out = 200)
    data.frame(x = rr * sin(th), y = rr * cos(th), r = rr)
  }))

  phy_levels <- levels(meta$Phylum)
  if (is.null(phy_levels)) {
    phy_levels <- unique(as.character(meta$Phylum))
  }
  age_levels <- levels(meta$Age)
  if (is.null(age_levels)) {
    age_levels <- unique(as.character(meta$Age))
  }
  phy_ring$value <- factor(phy_ring$value, levels = phy_levels)
  age_ring$value <- factor(age_ring$value, levels = age_levels)

  p <- ggplot2::ggplot() +
    ggplot2::geom_path(
      data = grid_df,
      mapping = ggplot2::aes(x = .data$x, y = .data$y, group = .data$r),
      color = "grey85",
      linewidth = 0.25
    ) +
    ggplot2::geom_segment(
      data = lay$segments,
      mapping = ggplot2::aes(x = .data$x, y = .data$y, xend = .data$xend, yend = .data$yend),
      color = "grey40",
      linewidth = 0.35
    ) +
    ggplot2::geom_polygon(
      data = phy_ring,
      mapping = ggplot2::aes(x = .data$x, y = .data$y, group = .data$id, fill = .data$value),
      color = NA,
      alpha = 0.95
    ) +
    ggplot2::scale_fill_brewer(
      palette = "Set3",
      name = "Phylum",
      drop = FALSE,
      na.value = "grey80"
    ) +
    ggplot2::guides(fill = ggplot2::guide_legend(order = 1, ncol = 1))

  if (isTRUE(.has_ggnewscale)) {
    p <- p +
      ggnewscale::new_scale_fill() +
      ggplot2::geom_polygon(
        data = age_ring,
        mapping = ggplot2::aes(x = .data$x, y = .data$y, group = .data$id, fill = .data$value),
        color = NA,
        alpha = 0.95
      ) +
      ggplot2::scale_fill_brewer(
        palette = "Spectral",
        name = "Age",
        drop = FALSE,
        na.value = "grey80"
      ) +
      ggplot2::guides(fill = ggplot2::guide_legend(order = 2, ncol = 1))
  } else {
    p <- p +
      ggplot2::geom_polygon(
        data = age_ring,
        mapping = ggplot2::aes(x = .data$x, y = .data$y, group = .data$id, colour = .data$value),
        fill = NA,
        linewidth = 1.4
      ) +
      ggplot2::scale_colour_brewer(palette = "Spectral", name = "Age", drop = FALSE) +
      ggplot2::guides(colour = ggplot2::guide_legend(order = 2, ncol = 1))
  }

  p <- p +
    ggplot2::coord_equal() +
    ggplot2::theme_void() +
    ggplot2::theme(
      legend.position = "left",
      legend.title = ggplot2::element_text(face = "bold", size = 10),
      legend.text = ggplot2::element_text(size = 8),
      plot.title = ggplot2::element_text(hjust = 0.5, face = "bold", size = 12),
      plot.margin = ggplot2::margin(12, 12, 12, 12)
    ) +
    ggplot2::labs(title = "Circular phylogenetic tree")

  ggplot2::ggsave(
    filename = output_file,
    plot = p,
    width = 12,
    height = 10,
    dpi = 200,
    bg = "white"
  )
  invisible(output_file)
}

# -----------------------------------------------------------------------------
# 对外 API
# -----------------------------------------------------------------------------

#' 绘制环形系统发育树
#' @param tree_file Newick 路径
#' @param metadata_file CSV：name,Phylum,Age（name 必须与 tip.label 一致）
#' @param output_file 输出 PNG（如 circular_tree.png）
plot_circular_tree <- function(tree_file, metadata_file, output_file) {
  if (!file.exists(tree_file)) {
    stop("tree 文件不存在: ", tree_file, call. = FALSE)
  }
  tree <- ape::read.tree(tree_file)
  if (is.null(tree$edge.length)) {
    tree$edge.length <- rep(1, nrow(tree$edge))
  }
  meta <- load_and_match_metadata(tree, metadata_file)
  message(
    "matched tips: ", attr(meta, "matched_tips"),
    " | Phylum: ", length(unique(as.character(meta$Phylum))),
    " | Age: ", length(unique(as.character(meta$Age)))
  )

  out_dir <- dirname(output_file)
  if (!dir.exists(out_dir) && nzchar(out_dir) && out_dir != ".") {
    dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  }

  engine <- "fallback"
  if (isTRUE(.circular_has_ggtree)) {
    ok <- tryCatch(
      {
        plot_circular_tree_ggtree(tree, meta, output_file)
        TRUE
      },
      error = function(e) {
        message("[警告] ggtree 绘图失败，改用 fallback: ", conditionMessage(e))
        FALSE
      }
    )
    if (isTRUE(ok)) {
      engine <- "ggtree"
    } else {
      plot_circular_tree_fallback(tree, meta, output_file)
    }
  } else {
    plot_circular_tree_fallback(tree, meta, output_file)
  }

  abs_out <- normalizePath(output_file, winslash = "/", mustWork = FALSE)
  message("engine=", engine, " -> ", abs_out)
  invisible(abs_out)
}

# -----------------------------------------------------------------------------
# CLI
# -----------------------------------------------------------------------------

is_main_rscript <- function() {
  args <- commandArgs(trailingOnly = FALSE)
  any(grepl("^--file=", args))
}

if (is_main_rscript()) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) < 3) {
    message("用法: Rscript plot_circular_tree.R <tree.nwk> <metadata.csv> <output.png>")
    quit(save = "no", status = 1)
  }
  code <- tryCatch(
    {
      plot_circular_tree(args[[1]], args[[2]], args[[3]])
      0L
    },
    error = function(e) {
      message("[错误] ", conditionMessage(e))
      1L
    }
  )
  quit(save = "no", status = code)
}
