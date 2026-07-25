# =============================================================================
# bacteria_visualization.R — Bacteria circular tree（独立脚本，不改 virus ggtree）
#
# 用法：
#   Rscript bacteria_visualization.R <tree.nwk> <metadata.csv> <output_dir> [taxonomy_level]
#
# taxonomy_level: phylum|class|order|family|genus|species|taxonomy（默认 taxonomy）
# 若配置了层级但 metadata 无对应列，回退 legacy 列 taxonomy。
#
# metadata 至少：label（或 sample_id）, taxonomy, environment, resistance
# 可选：phylum, class, order, family, genus, species
#
# 输出：
#   circular_tree_final.png / .pdf
#   visualization_report.json
# =============================================================================

suppressPackageStartupMessages({
  library(ape)
  library(ggplot2)
})

.ggtree_ok <- FALSE
.ggtree_fail_reason <- ""
tryCatch(
  {
    suppressPackageStartupMessages({
      library(ggtree)
      library(ggtreeExtra)
      library(ggnewscale)
    })
    .ggtree_ok <<- TRUE
  },
  error = function(e) {
    .ggtree_fail_reason <<- conditionMessage(e)
  }
)

BOOTSTRAP_MIN_DISPLAY <- 70L

TAXONOMY_RANK_COLUMNS <- c("phylum", "class", "order", "family", "genus", "species")
TAXONOMY_LEVELS <- c(TAXONOMY_RANK_COLUMNS, "taxonomy")
# 独立 CLI 缺省 = taxonomy（与 bacteria_annotation 一致；strategy 会传入 yaml 配置）
DEFAULT_TAXONOMY_LEVEL <- "taxonomy"

LAYOUT <- list(
  open_angle = 12,
  ring_width_frac = 0.085,
  ring_gap_frac = 0.035,
  annotation_rings = 3L,
  tree_target_frac = 0.55,
  x_expand_outer = 0.08
)

# 分类调色板（自动按水平截取/循环）
.pal_taxonomy <- c(
  "#4E79A7", "#F28E2B", "#E15759", "#76B7B2", "#59A14F",
  "#EDC948", "#B07AA1", "#FF9DA7", "#9C755F", "#BAB0AC",
  "#1B9E77", "#D95F02", "#7570B3", "#E7298A", "#66A61E",
  "#E6AB02", "#A6761D", "#666666", "#8DD3C7", "#FFFFB3"
)
.pal_environment <- c(
  clinical = "#C44E52",
  soil = "#8C6D31",
  marine = "#4C72B0",
  food = "#55A868",
  aquatic = "#64B5CD",
  thermal = "#DD8452",
  environmental = "#8172B3",
  unknown = "#B0B0B0"
)
.pal_resistance <- c(
  none = "#2CA02C",
  unknown = "#AAAAAA",
  AMR_watch = "#FF7F0E",
  MDR_risk = "#D62728"
)

normalize_taxonomy_level <- function(taxonomy_level = DEFAULT_TAXONOMY_LEVEL) {
  if (is.null(taxonomy_level) || !nzchar(as.character(taxonomy_level)[[1]])) {
    return(DEFAULT_TAXONOMY_LEVEL)
  }
  lvl <- tolower(trimws(as.character(taxonomy_level)[[1]]))
  if (!lvl %in% TAXONOMY_LEVELS) {
    warning(
      "[bacteria-viz] 未知 taxonomy_level=", lvl,
      "；回退 ", DEFAULT_TAXONOMY_LEVEL,
      call. = FALSE
    )
    return(DEFAULT_TAXONOMY_LEVEL)
  }
  lvl
}

resolve_taxonomy_ring_field <- function(meta, taxonomy_level = DEFAULT_TAXONOMY_LEVEL) {
  level <- normalize_taxonomy_level(taxonomy_level)
  cols <- names(meta)
  if (identical(level, "taxonomy")) {
    if (!"taxonomy" %in% cols) stop("metadata 缺少 taxonomy 列", call. = FALSE)
    return(list(requested = level, field = "taxonomy", fallback = FALSE))
  }
  if (level %in% cols) {
    return(list(requested = level, field = level, fallback = FALSE))
  }
  if ("taxonomy" %in% cols) {
    message(
      "[bacteria-viz] taxonomy_level=", level,
      " 列不存在；回退 legacy taxonomy"
    )
    return(list(requested = level, field = "taxonomy", fallback = TRUE))
  }
  stop("metadata 需要列 '", level, "' 或兼容列 'taxonomy'", call. = FALSE)
}

parse_cli <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) < 3) {
    message(
      "用法: Rscript bacteria_visualization.R <tree.nwk> <metadata.csv> <output_dir> [taxonomy_level]"
    )
    stop("缺少参数", call. = FALSE)
  }
  list(
    tree = normalizePath(args[[1]], winslash = "/", mustWork = FALSE),
    metadata = normalizePath(args[[2]], winslash = "/", mustWork = FALSE),
    output = normalizePath(args[[3]], winslash = "/", mustWork = FALSE),
    taxonomy_level = if (length(args) >= 4) args[[4]] else DEFAULT_TAXONOMY_LEVEL
  )
}

categorical_colors <- function(levels_chr, named_pref = NULL, fallback = .pal_taxonomy) {
  levels_chr <- as.character(levels_chr)
  cols <- character(length(levels_chr))
  names(cols) <- levels_chr
  for (i in seq_along(levels_chr)) {
    lv <- levels_chr[[i]]
    if (!is.null(named_pref) && lv %in% names(named_pref)) {
      cols[[i]] <- named_pref[[lv]]
    } else {
      cols[[i]] <- fallback[((i - 1L) %% length(fallback)) + 1L]
    }
  }
  cols
}

load_and_match_metadata <- function(tree, metadata_file, taxonomy_level = DEFAULT_TAXONOMY_LEVEL) {
  if (!file.exists(metadata_file)) {
    stop("metadata 不存在: ", metadata_file, call. = FALSE)
  }
  meta <- utils::read.csv(metadata_file, stringsAsFactors = FALSE, check.names = FALSE)
  if ("sample_id" %in% names(meta) && !"label" %in% names(meta)) {
    meta$label <- as.character(meta$sample_id)
  }
  need <- c("label", "taxonomy", "environment", "resistance")
  missing <- setdiff(need, names(meta))
  if (length(missing) > 0) {
    stop("metadata 缺少列: ", paste(missing, collapse = ", "), call. = FALSE)
  }
  meta$label <- as.character(meta$label)
  fill_cols <- unique(c("taxonomy", "environment", "resistance", TAXONOMY_RANK_COLUMNS))
  for (col in fill_cols) {
    if (col %in% names(meta)) {
      meta[[col]] <- as.character(meta[[col]])
      meta[[col]][is.na(meta[[col]]) | !nzchar(meta[[col]])] <- "unknown"
    }
  }
  resolved <- resolve_taxonomy_ring_field(meta, taxonomy_level = taxonomy_level)
  tips <- as.character(tree$tip.label)
  missing_in_meta <- setdiff(tips, meta$label)
  if (length(missing_in_meta) > 0) {
    stop(
      "label 与 tip.label 未 100% 匹配；缺失: ",
      paste(utils::head(missing_in_meta, 10), collapse = ", "),
      call. = FALSE
    )
  }
  if (anyDuplicated(meta$label) > 0) {
    stop("metadata$label 存在重复", call. = FALSE)
  }
  meta <- meta[match(tips, meta$label), , drop = FALSE]
  if (!identical(as.character(meta$label), tips)) {
    stop("重排后仍未与 tip.label 一致", call. = FALSE)
  }
  rownames(meta) <- meta$label
  attr(meta, "taxonomy_level") <- resolved$requested
  attr(meta, "taxonomy_ring_field") <- resolved$field
  attr(meta, "taxonomy_ring_fallback") <- resolved$fallback
  meta
}

extract_bootstrap_values <- function(tree) {
  if (is.null(tree$node.label) || length(tree$node.label) < 1) {
    return(list(present = FALSE, n_total = 0L, n_display = 0L, n_hidden = 0L))
  }
  vals <- suppressWarnings(as.numeric(tree$node.label))
  ok <- is.finite(vals)
  n_total <- sum(ok)
  n_display <- sum(ok & vals >= BOOTSTRAP_MIN_DISPLAY)
  list(
    present = n_total > 0,
    n_total = as.integer(n_total),
    n_display = as.integer(n_display),
    n_hidden = as.integer(sum(ok & vals < BOOTSTRAP_MIN_DISPLAY))
  )
}

transfer_bootstrap_after_reroot <- function(tree_orig, tree_new) {
  if (is.null(tree_orig$node.label) || length(tree_orig$node.label) < 1) {
    return(tree_new)
  }
  tip_set <- function(tr, node) {
    kids <- tr$edge[tr$edge[, 1] == node, 2]
    out <- character()
    for (ch in kids) {
      if (ch <= length(tr$tip.label)) {
        out <- c(out, tr$tip.label[ch])
      } else {
        out <- c(out, tip_set(tr, ch))
      }
    }
    sort(out)
  }
  bipart_key <- function(tr, node) {
    side_a <- tip_set(tr, node)
    side_b <- sort(setdiff(tr$tip.label, side_a))
    paste(sort(c(
      paste(side_a, collapse = ","),
      paste(side_b, collapse = ",")
    )), collapse = "|")
  }
  ntip_o <- length(tree_orig$tip.label)
  orig_map <- list()
  for (i in seq_along(tree_orig$node.label)) {
    lab <- tree_orig$node.label[[i]]
    node <- ntip_o + i
    key <- bipart_key(tree_orig, node)
    orig_map[[key]] <- lab
  }
  new_labels <- rep("", tree_new$Nnode)
  ntip_n <- length(tree_new$tip.label)
  for (i in seq_len(tree_new$Nnode)) {
    node <- ntip_n + i
    key <- bipart_key(tree_new, node)
    if (!is.null(orig_map[[key]])) {
      new_labels[[i]] <- orig_map[[key]]
    }
  }
  tree_new$node.label <- new_labels
  tree_new
}

build_bootstrap_labels <- function(tree_draw, layout_data) {
  if (is.null(tree_draw$node.label)) {
    return(NULL)
  }
  ntip <- length(tree_draw$tip.label)
  rows <- list()
  for (i in seq_along(tree_draw$node.label)) {
    v <- suppressWarnings(as.numeric(tree_draw$node.label[[i]]))
    if (!is.finite(v) || v < BOOTSTRAP_MIN_DISPLAY) next
    node_id <- ntip + i
    hit <- layout_data[layout_data$node == node_id, , drop = FALSE]
    if (nrow(hit) < 1) next
    rows[[length(rows) + 1]] <- data.frame(
      node = node_id,
      x = hit$x[[1]],
      y = hit$y[[1]],
      bs_label = as.character(as.integer(round(v))),
      stringsAsFactors = FALSE
    )
  }
  if (!length(rows)) return(NULL)
  do.call(rbind, rows)
}

choose_scale_width <- function(edge_length, max_depth) {
  bl <- edge_length[is.finite(edge_length) & edge_length > 0]
  if (!length(bl)) return(signif(max_depth / 5, 2))
  candidates <- c(0.001, 0.002, 0.005, 0.01, 0.02, 0.05, 0.1, 0.2, 0.5)
  target <- max_depth / 5
  candidates[which.min(abs(candidates - target))]
}

save_plot <- function(p, path, width = 12, height = 11, dpi = 300, use_pdf = FALSE) {
  if (isTRUE(use_pdf)) {
    ggplot2::ggsave(path, plot = p, width = width, height = height, device = grDevices::pdf)
  } else {
    ggplot2::ggsave(path, plot = p, width = width, height = height, dpi = dpi)
  }
  normalizePath(path, winslash = "/", mustWork = FALSE)
}

#' Bacteria circular 可视化主函数
plot_bacteria_circular <- function(tree_file,
                                   metadata_file,
                                   output_dir,
                                   taxonomy_level = DEFAULT_TAXONOMY_LEVEL) {
  if (!isTRUE(.ggtree_ok)) {
    stop("ggtree 不可用: ", .ggtree_fail_reason, call. = FALSE)
  }
  if (!file.exists(tree_file)) {
    stop("tree 不存在: ", tree_file, call. = FALSE)
  }
  tree <- ape::read.tree(tree_file)
  if (is.null(tree$edge.length) || all(!is.finite(tree$edge.length))) {
    stop("tree.nwk 缺少有效 branch length", call. = FALSE)
  }

  tax_level <- normalize_taxonomy_level(taxonomy_level)
  message("[bacteria-viz] tips=", length(tree$tip.label), " taxonomy_level=", tax_level)
  tree_draw <- tree
  if (requireNamespace("phangorn", quietly = TRUE)) {
    tree_draw <- tryCatch(
      {
        tr <- phangorn::midpoint(tree)
        tr <- transfer_bootstrap_after_reroot(tree, tr)
        ape::ladderize(tr, right = FALSE)
      },
      error = function(e) ape::ladderize(tree, right = FALSE)
    )
  } else {
    tree_draw <- ape::ladderize(tree, right = FALSE)
  }

  meta <- load_and_match_metadata(tree_draw, metadata_file, taxonomy_level = tax_level)
  tax_field <- attr(meta, "taxonomy_ring_field")
  if (is.null(tax_field) || !nzchar(tax_field)) tax_field <- "taxonomy"
  tax_fallback <- isTRUE(attr(meta, "taxonomy_ring_fallback"))

  meta_df <- as.data.frame(meta)
  rownames(meta_df) <- meta_df$label
  meta_df[[tax_field]] <- factor(
    as.character(meta_df[[tax_field]]),
    levels = sort(unique(as.character(meta_df[[tax_field]])))
  )
  meta_df$environment <- factor(meta_df$environment, levels = sort(unique(meta_df$environment)))
  meta_df$resistance <- factor(meta_df$resistance, levels = sort(unique(meta_df$resistance)))
  meta_df$annot_x <- 1L

  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  }

  p_probe <- ggtree(
    tree_draw,
    layout = "fan",
    open.angle = LAYOUT$open_angle,
    branch.length = "branch.length"
  )
  tip_x <- p_probe$data$x[p_probe$data$isTip %in% TRUE]
  max_depth <- max(tip_x, na.rm = TRUE)

  ring_width_frac <- LAYOUT$ring_width_frac
  ring_gap_frac <- LAYOUT$ring_gap_frac
  annot_span_frac <- LAYOUT$annotation_rings * ring_width_frac +
    LAYOUT$annotation_rings * ring_gap_frac
  fill_ratio <- 1 / (1 + annot_span_frac)
  if (fill_ratio < LAYOUT$tree_target_frac) {
    budget_frac <- (1 / LAYOUT$tree_target_frac) - 1
    gap_ratio <- ring_gap_frac / ring_width_frac
    ring_width_frac <- budget_frac / (LAYOUT$annotation_rings * (1 + gap_ratio))
    ring_gap_frac <- ring_width_frac * gap_ratio
    annot_span_frac <- LAYOUT$annotation_rings * ring_width_frac +
      LAYOUT$annotation_rings * ring_gap_frac
  }
  ring_width <- max_depth * ring_width_frac
  x_outer_expand <- LAYOUT$x_expand_outer + annot_span_frac
  scale_w <- choose_scale_width(tree_draw$edge.length, max_depth)

  tip_ext <- p_probe$data[p_probe$data$isTip %in% TRUE, c("x", "y", "label"), drop = FALSE]
  tip_ext$xend <- max_depth

  tax_cols <- categorical_colors(levels(meta_df[[tax_field]]), fallback = .pal_taxonomy)
  env_cols <- categorical_colors(
    levels(meta_df$environment),
    named_pref = .pal_environment,
    fallback = .pal_taxonomy
  )
  res_cols <- categorical_colors(
    levels(meta_df$resistance),
    named_pref = .pal_resistance,
    fallback = .pal_taxonomy
  )

  bs_lab <- build_bootstrap_labels(tree_draw, p_probe$data)
  legend_tax <- if (identical(tax_field, "taxonomy")) "taxonomy" else tax_field

  p <- ggtree(
    tree_draw,
    layout = "fan",
    open.angle = LAYOUT$open_angle,
    branch.length = "branch.length",
    color = "grey15",
    linewidth = 0.45
  ) +
    geom_segment(
      data = tip_ext,
      aes(x = x, xend = xend, y = y, yend = y),
      inherit.aes = FALSE,
      color = "grey82",
      linewidth = 0.18,
      linetype = "dotted"
    )

  if (!is.null(bs_lab) && nrow(bs_lab) > 0) {
    p <- p +
      geom_text(
        data = bs_lab,
        aes(x = x, y = y, label = bs_label),
        inherit.aes = FALSE,
        size = 1.55,
        color = "grey10",
        nudge_x = max_depth * 0.008
      )
  }

  # Ring 1: taxonomy_level 所选字段（缺列时为 taxonomy）
  p <- p +
    geom_fruit(
      data = meta_df,
      geom = geom_tile,
      mapping = aes(y = label, x = annot_x, fill = .data[[tax_field]]),
      offset = ring_gap_frac,
      pwidth = ring_width_frac,
      width = ring_width,
      color = NA,
      alpha = 0.95
    ) +
    scale_fill_manual(name = legend_tax, values = tax_cols, drop = FALSE) +
    guides(fill = guide_legend(order = 1, ncol = 1, keywidth = grid::unit(0.32, "cm"),
                               keyheight = grid::unit(0.32, "cm"))) +
    new_scale_fill() +
    # Ring 2: environment
    geom_fruit(
      data = meta_df,
      geom = geom_tile,
      mapping = aes(y = label, x = annot_x, fill = environment),
      offset = ring_gap_frac,
      pwidth = ring_width_frac,
      width = ring_width,
      color = NA,
      alpha = 0.95
    ) +
    scale_fill_manual(name = "environment", values = env_cols, drop = FALSE) +
    guides(fill = guide_legend(order = 2, ncol = 1, keywidth = grid::unit(0.32, "cm"),
                               keyheight = grid::unit(0.32, "cm"))) +
    new_scale_fill() +
    # Ring 3: resistance
    geom_fruit(
      data = meta_df,
      geom = geom_tile,
      mapping = aes(y = label, x = annot_x, fill = resistance),
      offset = ring_gap_frac,
      pwidth = ring_width_frac,
      width = ring_width,
      color = NA,
      alpha = 0.95
    ) +
    scale_fill_manual(name = "resistance", values = res_cols, drop = FALSE) +
    guides(fill = guide_legend(order = 3, ncol = 1, keywidth = grid::unit(0.32, "cm"),
                               keyheight = grid::unit(0.32, "cm"))) +
    scale_x_continuous(expand = expansion(mult = c(0.02, x_outer_expand))) +
    theme(
      legend.position = "right",
      legend.title = element_text(face = "bold", size = 8.5),
      legend.text = element_text(size = 6.8),
      plot.title = element_text(hjust = 0.5, face = "bold", size = 12),
      plot.margin = margin(12, 6, 6, 6)
    ) +
    labs(title = "Bacteria 16S circular tree")

  p <- p +
    labs(caption = paste0("scale bar ≈ ", scale_w, " substitutions/site; real branch lengths"))

  png_path <- file.path(output_dir, "circular_tree_final.png")
  pdf_path <- file.path(output_dir, "circular_tree_final.pdf")
  save_plot(p, png_path, use_pdf = FALSE)
  save_plot(p, pdf_path, use_pdf = TRUE)

  report <- list(
    organism_type = "bacteria",
    tip_count = length(tree$tip.label),
    tree_file = normalizePath(tree_file, winslash = "/", mustWork = FALSE),
    taxonomy_level = tax_level,
    taxonomy_ring_field = tax_field,
    taxonomy_ring_fallback = tax_fallback,
    annotation_rings = c(tax_field, "environment", "resistance"),
    annotation_method = "geom_fruit",
    annotation_geom = "geom_tile",
    png = basename(png_path),
    pdf = basename(pdf_path),
    scale_width = scale_w,
    status = "success"
  )
  if (requireNamespace("jsonlite", quietly = TRUE)) {
    jsonlite::write_json(
      report,
      file.path(output_dir, "visualization_report.json"),
      auto_unbox = TRUE,
      pretty = TRUE
    )
  }
  message("[bacteria-viz] wrote ", png_path, " ring1=", tax_field)
  list(png = png_path, pdf = pdf_path, report = report)
}

is_main_rscript <- function() {
  args <- commandArgs(trailingOnly = FALSE)
  f <- grep("^--file=", args, value = TRUE)
  if (length(f) < 1) return(FALSE)
  grepl("bacteria_visualization\\.R$", sub("^--file=", "", f[[1]]), ignore.case = TRUE)
}

if (is_main_rscript()) {
  exit_code <- tryCatch(
    {
      opts <- parse_cli()
      plot_bacteria_circular(
        opts$tree,
        opts$metadata,
        opts$output,
        taxonomy_level = opts$taxonomy_level
      )
      0L
    },
    error = function(e) {
      message("ERROR: ", conditionMessage(e))
      1L
    }
  )
  quit(save = "no", status = exit_code)
}
