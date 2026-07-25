# =============================================================================
# ggtree_visualization.R
# 论文级 Circular phylogenetic tree（真实 branch length + 距离环 + bootstrap）
#
# 用法：
#   Rscript ggtree_visualization.R <tree.nwk> <metadata.csv> <output_dir>
#
# 输入：
#   tree.nwk          — 保留真实 edge.length（禁止 cladogram）；可读 node.label bootstrap
#   metadata.csv      — label, Country, Year
#                       （兼容旧列名 Phylum→Country, Age→Year）
#
# 输出：
#   circular_tree_final.png  (300 dpi)
#   circular_tree_final.pdf  (矢量)
#   visualization_report.json
#
# 约束：
#   - 不改写磁盘 tree.nwk（midpoint root 仅用于绘图）
#   - 不伪造 bootstrap；仅显示 tree 中真实 node.label 且 >= 70
# =============================================================================

suppressPackageStartupMessages({
  library(ape)
  library(ggplot2)
  library(grid)
})

.ggtree_ok <- FALSE
.ggtree_fail_reason <- NULL

tryCatch(
  {
    suppressPackageStartupMessages({
      library(treeio)
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

# -----------------------------------------------------------------------------
# 论文级颜色体系
# Country：固定离散色（高区分度；刻意避开 Year 冷蓝→暖红主轴）
# Year：按数值连续映射（非 factor）
# -----------------------------------------------------------------------------

COUNTRY_COLORS <- c(
  # 论文级固定离散色：高区分度；刻意避开 Year 冷蓝→暖红主轴
  Americas = "#1B9E77", # teal green
  Asia     = "#7570B3", # muted indigo-violet
  Europe   = "#E6AB02", # gold
  Oceania  = "#A6761D", # brown
  Africa   = "#66A61E", # olive (可选扩展)
  # 兼容旧细菌门着色
  Actinomycetota    = "#1B9E77",
  Bacillota         = "#D95F02",
  Bacteroidota      = "#7570B3",
  Pseudomonadota    = "#A6761D",
  Cyanobacteriota   = "#66A61E",
  Spirochaetota     = "#E6AB02",
  Verrucomicrobiota = "#E7298A",
  Planctomycetota   = "#666666",
  Campylobacterota  = "#1F78B4"
)

# Year 连续渐变：early 冷色 → mid 黄 → recent 暖色（避免经白色中点）
YEAR_GRADIENT <- c(
  "#313695", # deep cold blue
  "#4575B4",
  "#74ADD1",
  "#ABD9E9",
  "#FEE090", # mid warm yellow
  "#FDAE61",
  "#F46D43",
  "#D73027",
  "#A50026"  # deep warm red
)

YEAR_LIMITS_DESIGN <- c(2007, 2024)

# 布局：真实 root→tip 比例（禁止 center crop）；外侧 Country + Year annotation ring
# ring_*_frac → geom_fruit 的 pwidth/offset（相对 tree x-range）
# ring_width（绝对）→ geom_tile(width=)，浅树必须用绝对值否则色块盖住整树
LAYOUT <- list(
  open_angle = 12,           # fan opening for distance labels
  ring_width_frac = 0.10,    # Country / Year tile ring thickness
  ring_gap_frac = 0.04,      # gap: tips→Country, Country→Year
  annotation_rings = 2L,
  x_expand_outer = 0.06,     # outer expand beyond fruit layers
  tree_target_frac = 0.78    # tree radius / (tree + annotation) fill target
)

BOOTSTRAP_MIN_DISPLAY <- 70

# -----------------------------------------------------------------------------
# metadata：Country / Year（兼容 Phylum / Age）
# -----------------------------------------------------------------------------

normalize_metadata_columns <- function(meta) {
  if ("Country" %in% names(meta) && "Year" %in% names(meta)) {
    return(meta)
  }
  if ("Phylum" %in% names(meta) && "Age" %in% names(meta)) {
    message("[兼容] 将 metadata 列 Phylum→Country, Age→Year")
    meta$Country <- meta$Phylum
    meta$Year <- meta$Age
    return(meta)
  }
  stop("metadata 需要列 label,Country,Year（或兼容 label,Phylum,Age）", call. = FALSE)
}

strict_match_and_reorder <- function(tree, metadata_file) {
  if (!file.exists(metadata_file)) {
    stop("metadata 文件不存在: ", metadata_file, call. = FALSE)
  }

  meta <- utils::read.csv(metadata_file, stringsAsFactors = FALSE, check.names = FALSE)
  if (!"label" %in% names(meta)) {
    stop("metadata 缺少列: label", call. = FALSE)
  }
  meta <- normalize_metadata_columns(meta)

  meta$label <- as.character(meta$label)
  meta$Country <- as.character(meta$Country)
  meta$Year_raw <- as.character(meta$Year)
  meta$Year_num <- suppressWarnings(as.numeric(meta$Year_raw))
  tips <- as.character(tree$tip.label)

  message("========== 严格匹配检查 ==========")
  missing_in_meta <- setdiff(tips, meta$label)
  n_match <- length(intersect(tips, meta$label))
  message("tree tip数量    : ", length(tips))
  message("metadata数量    : ", nrow(meta))
  message("匹配数量        : ", n_match)
  message("missing labels  : ", if (length(missing_in_meta) == 0) {
    "无"
  } else {
    paste(missing_in_meta, collapse = ", ")
  })

  if (length(missing_in_meta) > 0) {
    stop("label 与 tip.label 未 100% 匹配；缺失: ",
         paste(missing_in_meta, collapse = ", "), call. = FALSE)
  }
  if (anyDuplicated(meta$label) > 0) {
    stop("metadata$label 存在重复值", call. = FALSE)
  }

  if (!identical(meta$label, tips)) {
    message("[重排] 按 tree$tip.label 重排 metadata")
    meta <- meta[match(tips, meta$label), , drop = FALSE]
  }
  if (!identical(meta$label, tips)) {
    stop("重排后仍未与 tip.label 100% 一致", call. = FALSE)
  }
  message("100% 匹配       : YES")
  message("==================================")

  rownames(meta) <- meta$label
  c_in <- unique(meta$Country)
  unknown_c <- setdiff(c_in, names(COUNTRY_COLORS))
  if (length(unknown_c) > 0) {
    message("[警告] Country 不在颜色字典中: ", paste(unknown_c, collapse = ", "))
  }
  if (anyNA(meta$Year_num)) {
    message("[警告] 部分 Year 无法解析为数值，连续色将忽略这些 tip")
  }
  meta$Country <- factor(
    meta$Country,
    levels = c(intersect(names(COUNTRY_COLORS), c_in), unknown_c)
  )
  meta
}

# -----------------------------------------------------------------------------
# bootstrap 提取（真实 node.label；不伪造）
# -----------------------------------------------------------------------------

extract_bootstrap_values <- function(tree) {
  if (is.null(tree$node.label) || length(tree$node.label) < 1) {
    return(list(
      present = FALSE,
      values = numeric(0),
      n_total = 0L,
      n_display = 0L,
      n_hidden = 0L
    ))
  }
  vals <- suppressWarnings(as.numeric(tree$node.label))
  # 若像 0–1 比例，转为百分比
  if (any(is.finite(vals)) && max(vals, na.rm = TRUE) <= 1.0001) {
    vals <- vals * 100
  }
  finite <- vals[is.finite(vals)]
  n_disp <- sum(finite >= BOOTSTRAP_MIN_DISPLAY)
  n_hide <- sum(finite < BOOTSTRAP_MIN_DISPLAY)
  list(
    present = length(finite) > 0,
    values = vals,
    n_total = length(finite),
    n_display = as.integer(n_disp),
    n_hidden = as.integer(n_hide)
  )
}

#' midpoint 后按无序 bipartition 回传 bootstrap（避免有向 clade 丢失）
transfer_bootstrap_after_reroot <- function(tree_orig, tree_new) {
  bs_info <- extract_bootstrap_values(tree_orig)
  if (!isTRUE(bs_info$present)) {
    return(tree_new)
  }

  desc_tips <- function(tr, node) {
    children <- tr$edge[tr$edge[, 1] == node, 2]
    out <- character(0)
    for (ch in children) {
      if (ch <= length(tr$tip.label)) {
        out <- c(out, tr$tip.label[ch])
      } else {
        out <- c(out, desc_tips(tr, ch))
      }
    }
    sort(unique(out))
  }

  bipart_key <- function(tr, node) {
    side_a <- desc_tips(tr, node)
    side_b <- sort(setdiff(tr$tip.label, side_a))
    if (length(side_a) < 1 || length(side_b) < 1) return(NA_character_)
    a <- paste(side_a, collapse = "|")
    b <- paste(side_b, collapse = "|")
    if (a <= b) paste(a, b, sep = "||") else paste(b, a, sep = "||")
  }

  orig_map <- list()
  ntip_o <- length(tree_orig$tip.label)
  for (i in seq_len(tree_orig$Nnode)) {
    lab <- tree_orig$node.label[[i]]
    v <- suppressWarnings(as.numeric(lab))
    if (!is.finite(v)) next
    if (v <= 1.0001) v <- v * 100
    key <- bipart_key(tree_orig, ntip_o + i)
    if (is.na(key)) next
    orig_map[[key]] <- as.character(as.integer(round(v)))
  }

  new_labels <- rep("", tree_new$Nnode)
  ntip_n <- length(tree_new$tip.label)
  for (i in seq_len(tree_new$Nnode)) {
    key <- bipart_key(tree_new, ntip_n + i)
    if (!is.na(key) && !is.null(orig_map[[key]])) {
      new_labels[[i]] <- orig_map[[key]]
    }
  }
  tree_new$node.label <- new_labels
  tree_new
}

# -----------------------------------------------------------------------------
# 等距遗传距离同心圆（按 max depth 自动 5–8 圈）
# -----------------------------------------------------------------------------

compute_distance_rings <- function(max_depth, n_min = 5L, n_max = 8L) {
  if (!is.finite(max_depth) || max_depth <= 0) {
    rings <- seq_len(n_min) * 0.005
    return(list(step = 0.005, rings = rings, n = length(rings)))
  }

  nice_step <- function(raw) {
    if (!is.finite(raw) || raw <= 0) return(0.005)
    exp10 <- floor(log10(raw))
    frac <- raw / (10^exp10)
    nice_frac <- if (frac <= 1) 1 else if (frac <= 2) 2 else if (frac <= 5) 5 else 10
    nice_frac * 10^exp10
  }

  # 优先 6 圈，再按 nice step 收敛到 5–8
  best <- NULL
  for (n_try in c(6L, 5L, 7L, 8L)) {
    step <- nice_step(max_depth / n_try)
    rings <- seq(step, by = step, length.out = 30)
    rings <- rings[rings <= max_depth * 0.985]
    if (length(rings) >= n_min && length(rings) <= n_max) {
      best <- list(step = step, rings = rings, n = length(rings))
      break
    }
  }
  if (is.null(best)) {
    n <- n_min
    step <- max_depth / n
    rings <- as.numeric(seq(step, max_depth * 0.985, length.out = n))
    best <- list(step = step, rings = rings, n = length(rings))
  }
  best
}

choose_scale_width <- function(edge_lengths, max_depth) {
  mx <- max(edge_lengths, na.rm = TRUE)
  cand <- c(0.05, 0.02, 0.01, 0.005, 0.002, 0.001, 0.0005)
  hit <- cand[cand <= max(mx, max_depth) * 0.35 & cand > 0]
  if (length(hit) > 0) {
    return(hit[[1]])
  }
  signif(max(mx, max_depth) / 5, 1)
}

print_distance_diagnostics <- function(tree, max_depth, rings) {
  bl <- tree$edge.length
  message("========== 遗传距离诊断 ==========")
  message("tree最大branch length : ", format(max(bl, na.rm = TRUE), digits = 6, scientific = FALSE))
  message("tree平均branch length : ", format(mean(bl, na.rm = TRUE), digits = 6, scientific = FALSE))
  message("tree最小branch length : ", format(min(bl, na.rm = TRUE), digits = 6, scientific = FALSE))
  message("root-to-tip 最大深度  : ", format(max_depth, digits = 6, scientific = FALSE))
  message("distance ring数量     : ", length(rings))
  message("每个ring对应距离值    : ", paste(format(rings, digits = 4, scientific = FALSE), collapse = ", "))
  message("单位                  : substitutions/site")
  message("==================================")
}

print_layout_summary <- function(metrics) {
  message("========== 布局参数 ==========")
  message(sprintf("tree radius (true root→tip) : %.6f", metrics$tree_radius))
  message(sprintf("annotation radius (outer)   : %.6f", metrics$annotation_radius))
  message(sprintf("tree / outer fill ratio     : %.3f", metrics$tree_fill_ratio))
  message(sprintf("center crop                 : DISABLED (x_min=0)"))
  message(sprintf("ring width (absolute)       : %.6f", metrics$ring_width))
  message(sprintf("ring gap (absolute)         : %.6f", metrics$ring_gap))
  message(sprintf("branch length scale (bar)   : %.6f", metrics$scale_width))
  message(sprintf("x expand outer              : %.3f", metrics$x_expand_outer))
  message(sprintf("open.angle                  : %s", metrics$open_angle))
  message("annotation: geom_fruit(geom_tile) ×2 — Country (inner) + Year (outer)")
  message("======================================")
}

#' 在图片左上角叠加 Evolutionary distance 比例尺
draw_distance_scale_overlay <- function(scale_w) {
  label <- format(scale_w, scientific = FALSE, trim = TRUE)
  grid::grid.text(
    "Evolutionary distance",
    x = grid::unit(0.02, "npc"),
    y = grid::unit(0.975, "npc"),
    just = c("left", "top"),
    gp = grid::gpar(fontsize = 11, fontface = "bold", col = "grey10")
  )
  x0 <- 0.02
  x1 <- 0.12
  y <- 0.915
  grid::grid.lines(
    x = grid::unit(c(x0, x1), "npc"),
    y = grid::unit(c(y, y), "npc"),
    gp = grid::gpar(lwd = 1.8, col = "black", lineend = "butt")
  )
  grid::grid.lines(
    x = grid::unit(c(x0, x0), "npc"),
    y = grid::unit(c(y - 0.01, y + 0.01), "npc"),
    gp = grid::gpar(lwd = 1.8, col = "black")
  )
  grid::grid.lines(
    x = grid::unit(c(x1, x1), "npc"),
    y = grid::unit(c(y - 0.01, y + 0.01), "npc"),
    gp = grid::gpar(lwd = 1.8, col = "black")
  )
  grid::grid.text(
    paste0(label, " substitutions/site"),
    x = grid::unit(x0, "npc"),
    y = grid::unit(0.875, "npc"),
    just = c("left", "top"),
    gp = grid::gpar(fontsize = 9, col = "grey25")
  )
}

save_circular_with_scale <- function(p, path, scale_w, width = 11, height = 10,
                                     dpi = NULL, use_pdf = FALSE) {
  if (isTRUE(use_pdf)) {
    grDevices::pdf(path, width = width, height = height, bg = "white", useDingbats = FALSE)
  } else {
    grDevices::png(
      path,
      width = width,
      height = height,
      units = "in",
      res = dpi,
      bg = "white"
    )
  }
  on.exit(grDevices::dev.off(), add = TRUE)
  print(p)
  draw_distance_scale_overlay(scale_w)
  invisible(path)
}

write_visualization_report <- function(path, payload) {
  if (requireNamespace("jsonlite", quietly = TRUE)) {
    jsonlite::write_json(payload, path = path, auto_unbox = TRUE, pretty = TRUE)
  } else {
    esc <- function(x) {
      x <- gsub("\\\\", "\\\\\\\\", as.character(x), perl = TRUE)
      x <- gsub("\"", "\\\\\"", x, perl = TRUE)
      x
    }
    lines <- c(
      "{",
      paste0('  "tip_count": ', as.integer(payload$tip_count), ","),
      paste0('  "bootstrap_present": ', if (isTRUE(payload$bootstrap_present)) "true" else "false", ","),
      paste0('  "bootstrap_displayed": ', as.integer(payload$bootstrap_displayed), ","),
      paste0('  "tree_file": "', esc(payload$tree_file), '",'),
      paste0('  "status": "success"'),
      "}"
    )
    writeLines(lines, con = path, useBytes = FALSE)
  }
  invisible(path)
}

build_bootstrap_labels <- function(tree_draw, layout_data) {
  bs_draw <- extract_bootstrap_values(tree_draw)
  if (!isTRUE(bs_draw$present)) {
    return(list(info = bs_draw, labels = NULL))
  }
  d_nodes <- layout_data[!layout_data$isTip %in% TRUE, , drop = FALSE]
  ntip <- length(tree_draw$tip.label)
  d_nodes$bs_value <- NA_real_
  for (i in seq_along(tree_draw$node.label)) {
    nid <- ntip + i
    idx <- which(d_nodes$node == nid)
    if (length(idx) != 1) next
    v <- suppressWarnings(as.numeric(tree_draw$node.label[[i]]))
    if (!is.finite(v)) next
    if (v <= 1.0001) v <- v * 100
    d_nodes$bs_value[idx] <- v
  }
  bs_lab <- d_nodes[
    is.finite(d_nodes$bs_value) & d_nodes$bs_value >= BOOTSTRAP_MIN_DISPLAY,
    c("x", "y", "bs_value"),
    drop = FALSE
  ]
  if (nrow(bs_lab) < 1) {
    return(list(info = bs_draw, labels = NULL))
  }
  bs_lab$bs_label <- as.character(as.integer(round(bs_lab$bs_value)))
  list(info = bs_draw, labels = bs_lab)
}

# -----------------------------------------------------------------------------
# 绘图
# -----------------------------------------------------------------------------

#' 论文级 circular phylogenetic tree
plot_circular_ggtree <- function(tree_file, metadata_file, output_dir) {
  if (!isTRUE(.ggtree_ok)) {
    stop(
      "ggtree 不可用，已中止（不使用 ape fallback）。原因: ",
      .ggtree_fail_reason,
      call. = FALSE
    )
  }
  if (!file.exists(tree_file)) {
    stop("tree 文件不存在: ", tree_file, call. = FALSE)
  }

  tree <- ape::read.tree(tree_file)
  if (is.null(tree$edge.length) || all(!is.finite(tree$edge.length))) {
    stop("tree.nwk 缺少有效 branch length；拒绝 cladogram/等长枝", call. = FALSE)
  }
  if (length(unique(round(tree$edge.length, 10))) == 1 &&
      abs(unique(tree$edge.length)[1] - 1) < 1e-12) {
    message("[警告] 所有 edge.length 均为 1，请确认并非等长 cladogram")
  }

  tree_file_norm <- normalizePath(tree_file, winslash = "/", mustWork = FALSE)
  message("[输入] tree.nwk = ", tree_file_norm)
  message("[输入] tip count = ", length(tree$tip.label))

  bs_disk <- extract_bootstrap_values(tree)
  if (isTRUE(bs_disk$present)) {
    message(
      "[bootstrap] tree.nwk 含支持度: n=", bs_disk$n_total,
      "；显示 >=", BOOTSTRAP_MIN_DISPLAY, ": ", bs_disk$n_display,
      "；隐藏 <", BOOTSTRAP_MIN_DISPLAY, ": ", bs_disk$n_hidden
    )
  } else {
    message("[bootstrap] tree.nwk 无 node.label / 支持度；图中不显示（不伪造）")
    message("[bootstrap] 请用 bootstrap=100 的 phylogenetic_tree.R 重新建树后重跑本脚本")
  }

  # 仅用于绘图：midpoint root + ladderize（不改写磁盘 tree.nwk）
  tree_draw <- tree
  if (requireNamespace("phangorn", quietly = TRUE)) {
    tree_draw <- tryCatch(
      {
        tr <- phangorn::midpoint(tree)
        tr <- transfer_bootstrap_after_reroot(tree, tr)
        tr <- ape::ladderize(tr, right = FALSE)
        message("[显示] midpoint root + ladderize 已应用于绘图树（未改写 tree.nwk）")
        tr
      },
      error = function(e) {
        message("[警告] midpoint root 失败，使用原树: ", conditionMessage(e))
        ape::ladderize(tree, right = FALSE)
      }
    )
  } else {
    message("[警告] phangorn 不可用，跳过 midpoint root")
    tree_draw <- ape::ladderize(tree, right = FALSE)
  }

  meta <- strict_match_and_reorder(tree_draw, metadata_file)
  meta_df <- as.data.frame(meta)
  rownames(meta_df) <- meta_df$label

  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  }

  # --- 探测真实深度（真实 branch length；禁止 center crop）---
  p_probe <- ggtree(
    tree_draw,
    layout = "fan",
    open.angle = LAYOUT$open_angle,
    branch.length = "branch.length"
  )
  tip_x <- p_probe$data$x[p_probe$data$isTip %in% TRUE]
  max_depth <- max(tip_x, na.rm = TRUE)
  min_tip_depth <- min(tip_x, na.rm = TRUE)
  x_min_display <- 0
  message("[布局] center crop DISABLED — 保留真实 root→tip 比例 (x_min=0)")

  ring_info <- compute_distance_rings(max_depth)
  rings <- ring_info$rings
  rings_vis <- rings[rings > 0]
  if (length(rings_vis) < 5L) {
    rings_vis <- as.numeric(seq(
      max_depth / 6,
      max_depth * 0.98,
      length.out = 6L
    ))
    ring_info <- list(
      step = if (length(rings_vis) > 1) diff(rings_vis)[1] else max_depth / 6,
      rings = rings_vis,
      n = length(rings_vis)
    )
  }
  scale_w <- choose_scale_width(tree_draw$edge.length, max_depth)
  print_distance_diagnostics(tree_draw, max_depth, rings_vis)
  message(
    "root-to-tip 深度范围 : ",
    format(min_tip_depth, digits = 4), " – ", format(max_depth, digits = 4),
    " (median=", format(stats::median(tip_x), digits = 4), ")"
  )

  # 布局：外侧两层 geom_fruit tile ring
  # 注意：ggtreeExtra 的 pwidth / offset 均为相对 tree x-range 的比例
  ring_width_frac <- LAYOUT$ring_width_frac
  ring_gap_frac <- LAYOUT$ring_gap_frac
  annot_span_frac <- LAYOUT$annotation_rings * ring_width_frac +
    LAYOUT$annotation_rings * ring_gap_frac
  fill_ratio <- 1 / (1 + annot_span_frac)
  if (fill_ratio < LAYOUT$tree_target_frac) {
    # 压缩环宽，使树主体占比达到目标
    budget_frac <- (1 / LAYOUT$tree_target_frac) - 1
    gap_ratio <- ring_gap_frac / ring_width_frac
    ring_width_frac <- budget_frac / (LAYOUT$annotation_rings * (1 + gap_ratio))
    ring_gap_frac <- ring_width_frac * gap_ratio
    annot_span_frac <- LAYOUT$annotation_rings * ring_width_frac +
      LAYOUT$annotation_rings * ring_gap_frac
    fill_ratio <- 1 / (1 + annot_span_frac)
  }
  ring_width <- max_depth * ring_width_frac
  ring_gap <- max_depth * ring_gap_frac
  tree_radius <- max_depth
  annotation_radius <- max_depth * (1 + annot_span_frac)

  layout_metrics <- list(
    tree_radius = unname(tree_radius),
    annotation_radius = unname(annotation_radius),
    tree_fill_ratio = unname(fill_ratio),
    center_crop = 0,
    ring_width = unname(ring_width),
    ring_gap = unname(ring_gap),
    ring_width_frac = unname(ring_width_frac),
    ring_gap_frac = unname(ring_gap_frac),
    scale_width = scale_w,
    open_angle = LAYOUT$open_angle,
    x_expand_outer = LAYOUT$x_expand_outer
  )
  print_layout_summary(layout_metrics)

  tip_ext <- p_probe$data[p_probe$data$isTip %in% TRUE, c("x", "y", "label"), drop = FALSE]
  tip_ext$xend <- max_depth

  # geom_fruit 单列 tile：width 必须是 tree-x 绝对单位（≈ ring_width）
  # 若把相对 pwidth 直接当作 width，浅树会把整棵树盖成色盘
  meta_df$annot_x <- 1L

  country_present <- intersect(names(COUNTRY_COLORS), levels(meta_df$Country))
  country_vals <- COUNTRY_COLORS[country_present]

  year_finite <- meta_df$Year_num[is.finite(meta_df$Year_num)]
  if (length(year_finite) < 1) {
    stop("metadata$Year 无法解析为数值，无法做连续时间色带", call. = FALSE)
  }
  year_data_rng <- range(year_finite, na.rm = TRUE)
  # 论文色带：以 2007–2024 为设计轴；数据超出则扩展 limits（数值连续映射）
  year_lim <- c(
    min(YEAR_LIMITS_DESIGN[1], year_data_rng[1]),
    max(YEAR_LIMITS_DESIGN[2], year_data_rng[2])
  )

  message(
    "annotation method = geom_fruit(geom_tile); rings = ",
    LAYOUT$annotation_rings,
    " (Country inner, Year outer)"
  )
  message(
    "annotation pwidth(frac)=", format(ring_width_frac, digits = 4),
    " abs≈", format(ring_width, digits = 4),
    " (~", round(100 * ring_width_frac, 1), "% of tree depth each)"
  )
  message(
    "Year continuous scale limits: ", year_lim[1], " → ", year_lim[2],
    " (cool → warm, numeric; design ", YEAR_LIMITS_DESIGN[1], "–", YEAR_LIMITS_DESIGN[2], ")"
  )

  bs_pack <- build_bootstrap_labels(tree_draw, p_probe$data)
  bs_draw <- bs_pack$info
  bs_lab <- bs_pack$labels
  if (!is.null(bs_lab)) {
    message("[bootstrap] 将标注节点数: ", nrow(bs_lab),
            " / 可用 ", bs_draw$n_total)
  } else if (isTRUE(bs_draw$present)) {
    message("[bootstrap] 无节点达到显示阈值 ", BOOTSTRAP_MIN_DISPLAY)
  }

  ring_lab_df <- data.frame(
    x = rings_vis,
    y = 0.35,
    lab = format(signif(rings_vis, 3), scientific = FALSE, trim = TRUE),
    stringsAsFactors = FALSE
  )

  # ggtreeExtra 的 pwidth/offset 相对 tree x-range；勿用过紧 limits 裁掉 fruit
  # 外圈留白用 expand，避免 hard limits 触发 “Removed N rows” 把 annotation ring 删光
  x_outer_expand <- LAYOUT$x_expand_outer + annot_span_frac

  # 结构：distance circles → tree (+ bootstrap) → Country ring → Year ring
  # 禁止用 geom_point / geom_tippoint / geom_nodepoint 表示 Country 或 Year
  p <- ggtree(
    tree_draw,
    layout = "fan",
    open.angle = LAYOUT$open_angle,
    branch.length = "branch.length",
    color = "grey15",
    linewidth = 0.50
  ) +
    geom_vline(
      xintercept = rings_vis,
      color = "grey72",
      linewidth = 0.26,
      linetype = "solid"
    ) +
    geom_text(
      data = ring_lab_df,
      aes(x = x, y = y, label = lab),
      inherit.aes = FALSE,
      size = 2.05,
      color = "grey35",
      fontface = "plain"
    ) +
    geom_segment(
      data = tip_ext,
      aes(x = x, xend = xend, y = y, yend = y),
      inherit.aes = FALSE,
      color = "grey82",
      linewidth = 0.20,
      linetype = "dotted"
    )

  if (!is.null(bs_lab) && nrow(bs_lab) > 0) {
    p <- p +
      geom_text(
        data = bs_lab,
        aes(x = x, y = y, label = bs_label),
        inherit.aes = FALSE,
        size = 1.65,
        color = "grey5",
        fontface = "plain",
        nudge_x = max_depth * 0.008
      )
  }

  p <- p +
    geom_fruit(
      data = meta_df,
      geom = geom_tile,
      mapping = aes(y = label, x = annot_x, fill = Country),
      offset = ring_gap_frac,
      pwidth = ring_width_frac,
      width = ring_width,
      color = NA,
      alpha = 0.95
    ) +
    scale_fill_manual(
      name = "Country",
      values = country_vals,
      breaks = names(country_vals),
      na.value = "grey80",
      drop = TRUE
    ) +
    guides(fill = guide_legend(
      order = 1, ncol = 1,
      override.aes = list(alpha = 1),
      keywidth = unit(0.35, "cm"),
      keyheight = unit(0.35, "cm")
    )) +
    new_scale_fill() +
    geom_fruit(
      data = meta_df,
      geom = geom_tile,
      mapping = aes(y = label, x = annot_x, fill = Year_num),
      offset = ring_gap_frac,
      pwidth = ring_width_frac,
      width = ring_width,
      color = NA,
      alpha = 0.95
    ) +
    scale_fill_gradientn(
      name = "Year",
      colours = YEAR_GRADIENT,
      limits = year_lim,
      na.value = "grey80",
      guide = guide_colorbar(
        order = 2,
        barwidth = unit(0.35, "cm"),
        barheight = unit(3.2, "cm"),
        title.position = "top"
      )
    ) +
    scale_x_continuous(
      expand = expansion(mult = c(0.02, x_outer_expand))
    ) +
    theme(
      legend.position = "right",
      legend.title = element_text(face = "bold", size = 9),
      legend.text = element_text(size = 7.5),
      legend.margin = margin(0, 0, 0, 0),
      legend.box.margin = margin(0, 0, 0, 0),
      plot.title = element_text(hjust = 0.5, face = "bold", size = 13),
      plot.margin = margin(18, 6, 6, 6)
    ) +
    labs(title = "Circular phylogenetic tree")

  message("scale bar width = ", scale_w, " substitutions/site")
  message("annotation: Country (inner ring, geom_fruit+geom_tile) + Year (outer ring)")
  message(
    "distance rings: Evolutionary distance (substitutions/site); n=",
    length(rings_vis)
  )

  png_path <- file.path(output_dir, "circular_tree_final.png")
  pdf_path <- file.path(output_dir, "circular_tree_final.pdf")
  report_path <- file.path(output_dir, "visualization_report.json")

  save_circular_with_scale(
    p, png_path, scale_w,
    width = 11, height = 10, dpi = 300, use_pdf = FALSE
  )
  save_circular_with_scale(
    p, pdf_path, scale_w,
    width = 11, height = 10, use_pdf = TRUE
  )

  bl <- tree_draw$edge.length
  country_map <- as.list(country_vals)
  report <- list(
    tip_count = length(tree$tip.label),
    tree_file = tree_file_norm,
    tree_from_real_nwk = TRUE,
    midpoint_root_display_only = TRUE,
    annotation_method = "geom_fruit",
    annotation_geom = "geom_tile",
    annotation_count = as.integer(LAYOUT$annotation_rings),
    annotation_rings = c("Country", "Year"),
    center_crop = FALSE,
    branch_length = list(
      min = unname(min(bl, na.rm = TRUE)),
      max = unname(max(bl, na.rm = TRUE)),
      mean = unname(mean(bl, na.rm = TRUE)),
      median = unname(stats::median(bl, na.rm = TRUE)),
      unit = "substitutions/site"
    ),
    root_to_tip_depth = list(
      min = unname(min_tip_depth),
      max = unname(max_depth),
      median = unname(stats::median(tip_x, na.rm = TRUE))
    ),
    layout = list(
      metrics = layout_metrics,
      branch_length_scale = scale_w,
      center_crop = FALSE,
      note = "Real edge.length preserved; no center crop; metadata via geom_fruit(geom_tile) rings"
    ),
    distance_rings = list(
      values = rings_vis,
      step = ring_info$step,
      count = length(rings_vis),
      label = "Evolutionary distance",
      unit = "substitutions/site"
    ),
    bootstrap = list(
      present = isTRUE(bs_draw$present),
      threshold = BOOTSTRAP_MIN_DISPLAY,
      n_total = bs_draw$n_total,
      n_displayed = if (is.null(bs_lab)) 0L else nrow(bs_lab),
      n_hidden_below_threshold = bs_draw$n_hidden
    ),
    metadata_fields = c("label", "Country", "Year"),
    color_mapping = list(
      Country = country_map,
      Year = list(
        type = "continuous",
        gradient = YEAR_GRADIENT,
        limits = year_lim,
        data_range = year_data_rng,
        design_reference = YEAR_LIMITS_DESIGN,
        mapping = "numeric Year → cool(early) to warm(recent)"
      )
    ),
    outputs = list(
      png = normalizePath(png_path, winslash = "/", mustWork = FALSE),
      pdf = normalizePath(pdf_path, winslash = "/", mustWork = FALSE),
      dpi_png = 300L
    ),
    status = "success"
  )
  report$bootstrap_present <- report$bootstrap$present
  report$bootstrap_displayed <- report$bootstrap$n_displayed
  write_visualization_report(report_path, report)

  message("engine=ggtree layout=fan branch.length=real annotation=geom_fruit")
  message("PNG (300dpi) -> ", report$outputs$png)
  message("PDF (vector) -> ", report$outputs$pdf)
  message("report       -> ", normalizePath(report_path, winslash = "/", mustWork = FALSE))
  invisible(list(
    png = png_path,
    pdf = pdf_path,
    report = report_path,
    plot = p,
    rings = rings_vis,
    scale_width = scale_w,
    max_depth = max_depth,
    annotation_width = ring_width,
    metrics = layout_metrics
  ))
}

# -----------------------------------------------------------------------------
# 失败记录
# -----------------------------------------------------------------------------

write_ggtree_failure_log <- function(output_dir, reason) {
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  }
  log_path <- file.path(output_dir, "ggtree_install_failure.txt")
  lines <- c(
    paste0("timestamp: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
    "module: ggtree_visualization.R",
    "status: FAILED",
    "note: 未启用 ape fallback；请修复 ggtree 环境后重试。",
    paste0("reason: ", reason),
    paste0("R.version: ", R.version.string)
  )
  writeLines(lines, log_path, useBytes = TRUE)
  message("[错误] 失败原因已写入: ", normalizePath(log_path, winslash = "/", mustWork = FALSE))
  invisible(log_path)
}

# -----------------------------------------------------------------------------
# CLI
# -----------------------------------------------------------------------------

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) < 3) {
    message("用法: Rscript ggtree_visualization.R <tree.nwk> <metadata.csv> <output_dir>")
    quit(save = "no", status = 1)
  }

  tree_file <- args[[1]]
  metadata_file <- args[[2]]
  output_dir <- args[[3]]

  if (!isTRUE(.ggtree_ok)) {
    write_ggtree_failure_log(output_dir, .ggtree_fail_reason)
    quit(save = "no", status = 2)
  }

  code <- tryCatch(
    {
      plot_circular_ggtree(tree_file, metadata_file, output_dir)
      0L
    },
    error = function(e) {
      message("[错误] ", conditionMessage(e))
      write_ggtree_failure_log(output_dir, conditionMessage(e))
      1L
    }
  )
  quit(save = "no", status = code)
}
