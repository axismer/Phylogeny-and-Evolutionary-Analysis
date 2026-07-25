# =============================================================================
# fungi_strategy.R — FungiPhyloStrategy（ITS DNA；Framework v0.3 P5）
#
# 建树：委托 engine/phylogenetic_tree.R（不修改 engine）
# 可视化：strategies/fungi/fungi_visualization.R
# 仅通过 strategies/fungi/ 扩展；不改 virus/bacteria
# =============================================================================

create_fungi_strategy <- function() {
  dirs <- .get_framework_dirs()
  ann_file <- file.path(dirs$strategies, "fungi", "fungi_annotation.R")
  if (!exists("fungi_annotation_config", mode = "function") && file.exists(ann_file)) {
    source(ann_file, local = FALSE)
  }

  DNA_IUPAC <- "ACGTURYSWKMBDHVN"

  validate_input <- function(ctx) {
    if (exists("validate_fasta_basic", mode = "function")) {
      validate_fasta_basic(
        ctx$fasta_path,
        message_prefix = "FungiStrategy",
        empty_message = "FungiStrategy: FASTA 为空（无序列记录）",
        require_header = "first"
      )
    } else {
      if (is.null(ctx$fasta_path) || !nzchar(ctx$fasta_path)) {
        raise_framework_error("EMPTY_FASTA", "FungiStrategy: 缺少 --fasta")
      }
      if (!file.exists(ctx$fasta_path)) {
        raise_framework_error(
          "EMPTY_FASTA",
          paste0("FungiStrategy: FASTA 不存在: ", ctx$fasta_path)
        )
      }
    }

    recs <- if (exists("read_fasta", mode = "function")) {
      read_fasta(ctx$fasta_path)
    } else {
      raise_framework_error("EMPTY_FASTA", "FungiStrategy: read_fasta 未加载")
    }
    n <- length(recs$ids)
    if (n < 1) {
      raise_framework_error("EMPTY_FASTA", "FungiStrategy: FASTA 为空（无序列记录）")
    }
    if (n < 3) {
      raise_framework_error(
        "TOO_FEW_SEQUENCE",
        paste0("FungiStrategy: ITS 分析至少需要 3 条序列，当前: ", n)
      )
    }

    bad_chars <- character()
    for (i in seq_len(n)) {
      s <- gsub("[^A-Z]", "", recs$seqs[[i]])
      extra <- unique(strsplit(gsub(paste0("[", DNA_IUPAC, "]"), "", s), "")[[1]])
      if (length(extra)) bad_chars <- unique(c(bad_chars, extra))
    }
    if (length(bad_chars)) {
      raise_framework_error(
        "INVALID_DNA",
        paste0(
          "FungiStrategy: ITS DNA 字符合法性失败，发现: ",
          paste(bad_chars, collapse = ",")
        )
      )
    }
    invisible(list(sequence_count = n, marker = "ITS"))
  }

  parse_metadata <- function(ctx) {
    if (exists("require_metadata_argument", mode = "function")) {
      require_metadata_argument(
        ctx$metadata_path,
        message = "FungiStrategy: 要求提供 --metadata"
      )
    } else if (is.null(ctx$metadata_path) || !nzchar(ctx$metadata_path)) {
      raise_framework_error(
        "MISSING_METADATA_ARGUMENT",
        "FungiStrategy: 要求提供 --metadata"
      )
    }

    meta <- if (exists("read_metadata", mode = "function")) {
      read_metadata(ctx$metadata_path, message_prefix = "FungiStrategy")
    } else {
      raise_framework_error(
        "METADATA_FILE_NOT_FOUND",
        "FungiStrategy: read_metadata 未加载"
      )
    }

    assert_fungi_metadata_columns(meta)

    if (exists("validate_metadata", mode = "function")) {
      if (!"organism_type" %in% names(meta)) {
        meta$organism_type <- "fungi"
      }
      tryCatch(
        validate_metadata(meta, organism_type = "fungi", strict = TRUE),
        error = function(e) {
          raise_framework_error("MISSING_METADATA_FIELDS", conditionMessage(e))
        }
      )
    }
    meta
  }

  tree_params <- function(ctx) {
    params <- default_tree_params("fungi")
    params$marker <- "ITS"
    cfg <- ctx$config$strategies$fungi$tree
    if (is.list(cfg)) {
      for (nm in names(cfg)) params[[nm]] <- cfg[[nm]]
    }
    params
  }

  annotation_config <- function(ctx) {
    fungi_annotation_config(ctx)
  }

  output_spec <- function(ctx) {
    default_output_spec("fungi")
  }

  invoke_fungi_viz <- function(tree_path, metadata_path, output_dir, rscript, r_root) {
    script <- file.path(r_root, "strategies", "fungi", "fungi_visualization.R")
    if (!file.exists(script)) {
      raise_framework_error(
        "VISUALIZATION_FAILED",
        paste0("找不到 fungi_visualization.R: ", script)
      )
    }
    out <- system2(
      rscript,
      args = c(
        shQuote(script),
        shQuote(tree_path),
        shQuote(metadata_path),
        shQuote(output_dir)
      ),
      stdout = TRUE,
      stderr = TRUE
    )
    status <- attr(out, "status")
    if (is.null(status)) status <- 0L
    list(exit_code = as.integer(status), log = out, script = script)
  }

  run <- function(ctx) {
    run_strategy_pipeline(list(organism_type = "fungi"), ctx, function(ctx, helpers) {
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
          paste0("FungiStrategy: 建树失败（exit=", tree_res$exit_code, "）"),
          error_code = "TREE_BUILD_FAILED",
          tree = spec$tree_file
        )
      }

      mapped <- map_fungi_metadata_for_viz(meta)
      meta_out_path <- file.path(ctx$output_dir, spec$metadata)
      utils::write.csv(mapped, meta_out_path, row.names = FALSE, fileEncoding = "UTF-8")
      metadata_out <- spec$metadata

      tree_path <- file.path(ctx$output_dir, spec$tree_file)
      if (file.exists(tree_path)) {
        helpers$assert_tips(
          tree = tree_path,
          metadata = mapped,
          id_column = "label",
          message_prefix = "FungiStrategy: metadata sample_id/label 与 tree tip 不匹配，缺失: ",
          tree_file = spec$tree_file,
          metadata_file = metadata_out
        )
      }

      visualization_out <- ""
      viz_res <- invoke_fungi_viz(
        tree_path = tree_path,
        metadata_path = meta_out_path,
        output_dir = ctx$output_dir,
        rscript = rscript,
        r_root = r_root
      )
      if (viz_res$exit_code == 0L &&
          file.exists(file.path(ctx$output_dir, spec$visualization))) {
        visualization_out <- spec$visualization
      } else {
        warning(
          "FungiStrategy: 可视化失败或未产出 ", spec$visualization,
          "（exit=", viz_res$exit_code, "）",
          call. = FALSE
        )
      }

      ring_fields <- c("taxonomy", "host")
      final_status <- if (nzchar(visualization_out)) "success" else "partial"
      legacy_json <- file.path(ctx$output_dir, "analysis_result.json")
      if (file.exists(legacy_json) && requireNamespace("jsonlite", quietly = TRUE)) {
        legacy <- jsonlite::fromJSON(legacy_json)
        result <- upgrade_legacy_result(
          legacy,
          organism_type = "fungi",
          visualization = visualization_out,
          metadata = metadata_out,
          status = final_status
        )
        result$input <- fasta_base
        result$statistics$annotation_rings <- ring_fields
        result$statistics$marker <- "ITS"
        result$statistics$method <- params$method
        result$statistics$model <- params$model
      } else {
        result <- build_analysis_result(
          status = final_status,
          organism_type = "fungi",
          input = fasta_base,
          tree = spec$tree_file,
          visualization = visualization_out,
          metadata = metadata_out,
          statistics = list(
            method = params$method,
            model = params$model,
            annotation_rings = ring_fields,
            marker = "ITS"
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
    organism_type = "fungi",
    validate_input = validate_input,
    parse_metadata = parse_metadata,
    tree_params = tree_params,
    annotation_config = annotation_config,
    output_spec = output_spec,
    run = run
  )
}
