# =============================================================================
# bacteria_strategy.R — BacteriaPhyloStrategy（Framework v0.2 / v0.3 P2）
#
# 建树：委托 engine/phylogenetic_tree.R（不复制算法）
# 可视化：strategies/bacteria/bacteria_visualization.R
# 系统级错误处理 / tip 校验 → core/strategy_runner.R + tip_validator.R
# FASTA/metadata/output IO → core/io/*（旧本地解析保留为 deprecated fallback）
# =============================================================================

create_bacteria_strategy <- function() {
  dirs <- .get_framework_dirs()
  ann_file <- file.path(dirs$strategies, "bacteria", "bacteria_annotation.R")
  if (!exists("bacteria_annotation_config", mode = "function") && file.exists(ann_file)) {
    source(ann_file, local = FALSE)
  }

  DNA_IUPAC <- "ACGTURYSWKMBDHVN"
  LEN_WARN_MIN <- 200L
  LEN_WARN_MAX <- 2500L
  LEN_16S_LO <- 1200L
  LEN_16S_HI <- 1700L

  # ---------------------------------------------------------------------------
  # DEPRECATED FALLBACK (P2) — 勿删（P4 明确保留）
  # 生产路径：core/io/fasta_io.R::read_fasta
  # 本函数仅当 read_fasta 未加载时使用；逻辑须与 read_fasta 逐行一致
  # 未来迁移：全套回归长期绿且无旁路 source 后，可删本地副本（见 docs/deprecated_components.md）
  # ---------------------------------------------------------------------------
  .read_fasta_records_deprecated <- function(fasta_path) {
    lines <- readLines(fasta_path, warn = FALSE, encoding = "UTF-8")
    ids <- character()
    seqs <- character()
    cur_id <- NULL
    cur <- character()
    flush <- function() {
      if (is.null(cur_id)) return()
      ids <<- c(ids, cur_id)
      seqs <<- c(seqs, toupper(paste(cur, collapse = "")))
    }
    for (ln in lines) {
      if (!nzchar(trimws(ln))) next
      if (startsWith(ln, ">")) {
        flush()
        cur_id <- sub("^>\\s*", "", ln)
        cur_id <- strsplit(cur_id, "\\s+")[[1]][[1]]
        cur <- character()
      } else {
        cur <- c(cur, gsub("\\s+", "", ln))
      }
    }
    flush()
    list(ids = ids, seqs = seqs)
  }

  read_fasta_records <- function(fasta_path) {
    if (exists("read_fasta", mode = "function")) {
      return(read_fasta(fasta_path))
    }
    .read_fasta_records_deprecated(fasta_path)
  }

  validate_input <- function(ctx) {
    if (exists("validate_fasta_basic", mode = "function")) {
      validate_fasta_basic(
        ctx$fasta_path,
        message_prefix = "BacteriaStrategy",
        empty_message = paste0(
          "BacteriaStrategy: FASTA 为空（无序列记录）；至少需要 3 条序列，当前: 0"
        ),
        require_header = "none"
      )
    } else {
      if (is.null(ctx$fasta_path) || !nzchar(ctx$fasta_path)) {
        raise_framework_error("EMPTY_FASTA", "BacteriaStrategy: 缺少 --fasta")
      }
      if (!file.exists(ctx$fasta_path)) {
        raise_framework_error(
          "EMPTY_FASTA",
          paste0("BacteriaStrategy: FASTA 不存在: ", ctx$fasta_path)
        )
      }
      finfo <- file.info(ctx$fasta_path)
      lines_probe <- tryCatch(
        readLines(ctx$fasta_path, warn = FALSE, encoding = "UTF-8"),
        error = function(e) character()
      )
      if (isTRUE(finfo$size == 0) || length(lines_probe) == 0L ||
          !any(nzchar(trimws(lines_probe)))) {
        raise_framework_error(
          "EMPTY_FASTA",
          "BacteriaStrategy: FASTA 为空（无序列记录）；至少需要 3 条序列，当前: 0"
        )
      }
    }

    recs <- read_fasta_records(ctx$fasta_path)
    n <- length(recs$ids)
    if (n < 1) {
      raise_framework_error(
        "EMPTY_FASTA",
        "BacteriaStrategy: FASTA 为空（无序列记录）；至少需要 3 条序列，当前: 0"
      )
    }
    if (n < 3) {
      raise_framework_error(
        "TOO_FEW_SEQUENCE",
        paste0("BacteriaStrategy: 至少需要 3 条序列，当前: ", n)
      )
    }

    bad_chars <- character()
    lens <- integer(n)
    for (i in seq_len(n)) {
      s <- gsub("[^A-Z]", "", recs$seqs[[i]])
      lens[[i]] <- nchar(s)
      extra <- unique(strsplit(gsub(paste0("[", DNA_IUPAC, "]"), "", s), "")[[1]])
      if (length(extra)) {
        bad_chars <- unique(c(bad_chars, extra))
      }
    }
    if (length(bad_chars)) {
      raise_framework_error(
        "INVALID_DNA",
        paste0(
          "BacteriaStrategy: DNA 字符合法性失败，发现: ",
          paste(bad_chars, collapse = ",")
        )
      )
    }

    if (any(lens < 50L)) {
      raise_framework_error(
        "TOO_FEW_SEQUENCE",
        "BacteriaStrategy: 存在过短序列（<50 bp）"
      )
    }
    if (any(lens < LEN_WARN_MIN) || any(lens > LEN_WARN_MAX)) {
      warning(
        "BacteriaStrategy: 部分序列长度超出常见范围 [",
        LEN_WARN_MIN, ",", LEN_WARN_MAX, "] bp；",
        "min=", min(lens), " max=", max(lens),
        call. = FALSE
      )
    }

    med <- stats::median(lens)
    if (med < LEN_16S_LO || med > LEN_16S_HI) {
      warning(
        "BacteriaStrategy: 序列中位长度 ", med,
        " bp，不完全落在典型 16S 区间 [", LEN_16S_LO, ",", LEN_16S_HI,
        "]；继续分析（不强制 16S 分类）。",
        call. = FALSE
      )
    } else {
      message(
        "[BacteriaStrategy] 16S 长度启发式通过（median=", med,
        " bp）；未做物种分类鉴定。"
      )
    }

    invisible(list(sequence_count = n, lengths = lens))
  }

  parse_metadata <- function(ctx) {
    if (exists("require_metadata_argument", mode = "function")) {
      require_metadata_argument(
        ctx$metadata_path,
        message = "BacteriaStrategy: 第一版要求提供 --metadata"
      )
    } else if (is.null(ctx$metadata_path) || !nzchar(ctx$metadata_path)) {
      raise_framework_error(
        "MISSING_METADATA_ARGUMENT",
        "BacteriaStrategy: 第一版要求提供 --metadata"
      )
    }

    if (exists("read_metadata", mode = "function")) {
      meta <- read_metadata(ctx$metadata_path, message_prefix = "BacteriaStrategy")
    } else {
      if (!file.exists(ctx$metadata_path)) {
        raise_framework_error(
          "METADATA_FILE_NOT_FOUND",
          paste0("BacteriaStrategy: metadata 不存在: ", ctx$metadata_path)
        )
      }
      meta <- utils::read.csv(
        ctx$metadata_path,
        stringsAsFactors = FALSE,
        check.names = FALSE
      )
    }
    tryCatch(
      assert_bacteria_metadata_columns(meta),
      error = function(e) {
        raise_framework_error("MISSING_METADATA_FIELDS", conditionMessage(e))
      }
    )
    if (exists("validate_metadata_file", mode = "function")) {
      if (!"organism_type" %in% names(meta)) {
        meta$organism_type <- "bacteria"
      }
      tryCatch(
        validate_metadata(meta, organism_type = "bacteria", strict = TRUE),
        error = function(e) {
          raise_framework_error("MISSING_METADATA_FIELDS", conditionMessage(e))
        }
      )
    }
    meta
  }

  tree_params <- function(ctx) {
    params <- default_tree_params("bacteria")
    params$legacy_engine <- "engine/phylogenetic_tree.R"
    params$status <- "production_via_legacy_engine"
    cfg <- ctx$config$strategies$bacteria$tree
    if (is.list(cfg)) {
      for (nm in names(cfg)) params[[nm]] <- cfg[[nm]]
    }
    params
  }

  annotation_config <- function(ctx) {
    bacteria_annotation_config(ctx)
  }

  output_spec <- function(ctx) {
    default_output_spec("bacteria")
  }

  invoke_bacteria_viz <- function(tree_path,
                                  metadata_path,
                                  output_dir,
                                  rscript,
                                  r_root,
                                  taxonomy_level = BACTERIA_DEFAULT_TAXONOMY_LEVEL) {
    script <- file.path(r_root, "strategies", "bacteria", "bacteria_visualization.R")
    if (!file.exists(script)) {
      stop("找不到 bacteria_visualization.R: ", script, call. = FALSE)
    }
    out <- system2(
      rscript,
      args = c(
        shQuote(script),
        shQuote(tree_path),
        shQuote(metadata_path),
        shQuote(output_dir),
        shQuote(as.character(taxonomy_level)[[1]])
      ),
      stdout = TRUE,
      stderr = TRUE
    )
    status <- attr(out, "status")
    if (is.null(status)) status <- 0L
    list(exit_code = as.integer(status), log = out, script = script)
  }

  run <- function(ctx) {
    run_strategy_pipeline(list(organism_type = "bacteria"), ctx, function(ctx, helpers) {
      validate_input(ctx)
      meta <- parse_metadata(ctx)
      params <- tree_params(ctx)
      spec <- output_spec(ctx)
      ann <- annotation_config(ctx)
      fasta_base <- helpers$input_basename()

      rscript <- if (!is.null(ctx$extras$rscript)) ctx$extras$rscript else "Rscript"
      r_root <- if (!is.null(ctx$extras$r_root)) ctx$extras$r_root else dirs$root

      tree_res <- invoke_legacy_tree_engine(
        fasta_path = ctx$fasta_path,
        output_dir = ctx$output_dir,
        rscript = rscript,
        r_root = r_root
      )
        if (tree_res$exit_code != 0L) {
          helpers$fail(
            paste0("BacteriaStrategy: 建树失败（exit=", tree_res$exit_code, "）"),
            error_code = "TREE_BUILD_FAILED",
            tree = spec$tree_file
          )
        }

      tax_level <- ann$taxonomy_level %||% resolve_bacteria_taxonomy_level(ctx)
      mapped <- map_bacteria_metadata_for_viz(meta, taxonomy_level = tax_level)
      tax_ring_field <- attr(mapped, "taxonomy_ring_field")
      if (is.null(tax_ring_field) || !nzchar(tax_ring_field)) {
        tax_ring_field <- "taxonomy"
      }
      meta_out_path <- file.path(ctx$output_dir, spec$metadata)
      utils::write.csv(mapped, meta_out_path, row.names = FALSE, fileEncoding = "UTF-8")
      metadata_out <- spec$metadata

      tree_path <- file.path(ctx$output_dir, spec$tree_file)
      if (file.exists(tree_path)) {
        helpers$assert_tips(
          tree = tree_path,
          metadata = mapped,
          id_column = "label",
          message_prefix = "BacteriaStrategy: metadata sample_id/label 与 tree tip 不匹配，缺失: ",
          tree_file = spec$tree_file,
          metadata_file = metadata_out
        )
      }

      visualization_out <- ""
      viz_res <- invoke_bacteria_viz(
        tree_path = tree_path,
        metadata_path = meta_out_path,
        output_dir = ctx$output_dir,
        rscript = rscript,
        r_root = r_root,
        taxonomy_level = tax_level
      )
      if (viz_res$exit_code == 0L &&
          file.exists(file.path(ctx$output_dir, spec$visualization))) {
        visualization_out <- spec$visualization
      } else {
        warning(
          "BacteriaStrategy: 可视化失败或未产出 ", spec$visualization,
          "（exit=", viz_res$exit_code, "）",
          call. = FALSE
        )
      }

      ring_fields <- c(tax_ring_field, "environment", "resistance")
      final_status <- if (nzchar(visualization_out)) "success" else "partial"
      legacy_json <- file.path(ctx$output_dir, "analysis_result.json")
      if (file.exists(legacy_json) && requireNamespace("jsonlite", quietly = TRUE)) {
        legacy <- jsonlite::fromJSON(legacy_json)
        result <- upgrade_legacy_result(
          legacy,
          organism_type = "bacteria",
          visualization = visualization_out,
          metadata = metadata_out,
          status = final_status
        )
        result$input <- fasta_base
        result$statistics$annotation_rings <- ring_fields
        result$statistics$taxonomy_level <- tax_level
        result$statistics$taxonomy_ring_field <- tax_ring_field
        result$statistics$method <- params$method
        result$statistics$model <- params$model
      } else {
        result <- build_analysis_result(
          status = final_status,
          organism_type = "bacteria",
          input = fasta_base,
          tree = spec$tree_file,
          visualization = visualization_out,
          metadata = metadata_out,
          statistics = list(
            method = params$method,
            model = params$model,
            annotation_rings = ring_fields,
            taxonomy_level = tax_level,
            taxonomy_ring_field = tax_ring_field
          ),
          error_message = ""
        )
      }

      if (exists("write_analysis_output", mode = "function")) {
        write_analysis_output(result, ctx$output_dir)
      } else {
        write_analysis_result(result, ctx$output_dir)
      }
      result
    })
  }

  new_phylo_strategy(
    organism_type = "bacteria",
    validate_input = validate_input,
    parse_metadata = parse_metadata,
    tree_params = tree_params,
    annotation_config = annotation_config,
    output_spec = output_spec,
    run = run
  )
}
