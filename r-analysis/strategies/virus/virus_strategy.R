# =============================================================================
# virus_strategy.R — VirusPhyloStrategy（Framework v0.2 / v0.3 P2）
#
# 生物学逻辑：校验、metadata、建树委托、annotation、可视化。
# 系统级错误处理 / tip 校验 / error JSON → core/strategy_runner.R + tip_validator.R
# FASTA/metadata/output IO → core/io/*（旧本地解析保留为 deprecated fallback）
# 不复制建树算法：委托 engine/phylogenetic_tree.R（及可选 ggtree）。
# =============================================================================

create_virus_strategy <- function() {
  dirs <- .get_framework_dirs()
  ann_file <- file.path(dirs$strategies, "virus", "virus_annotation.R")
  if (!exists("virus_annotation_config", mode = "function") && file.exists(ann_file)) {
    source(ann_file, local = FALSE)
  }

  DNA_IUPAC <- "ACGTURYSWKMBDHVN"

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
        message_prefix = "VirusStrategy",
        require_header = "first"
      )
    } else {
      if (is.null(ctx$fasta_path) || !nzchar(ctx$fasta_path)) {
        raise_framework_error("EMPTY_FASTA", "VirusStrategy: 缺少 --fasta")
      }
      if (!file.exists(ctx$fasta_path)) {
        raise_framework_error(
          "EMPTY_FASTA",
          paste0("VirusStrategy: FASTA 不存在: ", ctx$fasta_path)
        )
      }
      lines <- tryCatch(
        readLines(ctx$fasta_path, warn = FALSE, encoding = "UTF-8"),
        error = function(e) character()
      )
      finfo <- file.info(ctx$fasta_path)
      if (isTRUE(finfo$size == 0) || length(lines) == 0L ||
          !any(nzchar(trimws(lines)))) {
        raise_framework_error("EMPTY_FASTA", "VirusStrategy: FASTA 为空（无序列记录）")
      }
      if (!startsWith(lines[[1]], ">")) {
        raise_framework_error(
          "EMPTY_FASTA",
          "VirusStrategy: FASTA 格式无效（首行应以 > 开头）"
        )
      }
    }

    recs <- read_fasta_records(ctx$fasta_path)
    n <- length(recs$ids)
    if (n < 1) {
      raise_framework_error("EMPTY_FASTA", "VirusStrategy: FASTA 为空（无序列记录）")
    }
    if (n < 3) {
      raise_framework_error(
        "TOO_FEW_SEQUENCE",
        paste0("VirusStrategy: 至少需要 3 条序列，当前: ", n)
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
          "VirusStrategy: DNA 字符合法性失败，发现: ",
          paste(bad_chars, collapse = ",")
        )
      )
    }
    invisible(list(sequence_count = n))
  }

  #' 兼容统一 schema 与 legacy（label/Country/Year）metadata
  parse_metadata <- function(ctx) {
    if (is.null(ctx$metadata_path) || !nzchar(ctx$metadata_path)) {
      return(NULL)
    }
    if (exists("read_metadata", mode = "function")) {
      meta <- read_metadata(ctx$metadata_path, message_prefix = "VirusStrategy")
    } else {
      if (!file.exists(ctx$metadata_path)) {
        raise_framework_error(
          "METADATA_FILE_NOT_FOUND",
          paste0("VirusStrategy: metadata 不存在: ", ctx$metadata_path)
        )
      }
      meta <- utils::read.csv(
        ctx$metadata_path,
        stringsAsFactors = FALSE,
        check.names = FALSE
      )
    }
    has_unified <- all(c("sample_id", "organism_type") %in% names(meta))
    has_legacy <- "label" %in% names(meta) || "sample_id" %in% names(meta)
    if (has_unified && exists("validate_metadata", mode = "function")) {
      validate_metadata(meta, organism_type = "virus", strict = FALSE)
    } else if (!has_legacy) {
      raise_framework_error(
        "MISSING_METADATA_FIELDS",
        "VirusStrategy: metadata 需要 label 或 sample_id（legacy 或统一 schema）"
      )
    }
    meta
  }

  tree_params <- function(ctx) {
    params <- default_tree_params("virus")
    cfg <- ctx$config$strategies$virus$tree
    if (is.list(cfg)) {
      for (nm in names(cfg)) params[[nm]] <- cfg[[nm]]
    }
    params
  }

  annotation_config <- function(ctx) {
    virus_annotation_config(ctx)
  }

  output_spec <- function(ctx) {
    default_output_spec("virus")
  }

  run <- function(ctx) {
    run_strategy_pipeline(list(organism_type = "virus"), ctx, function(ctx, helpers) {
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
            paste0("VirusStrategy: 建树失败（exit=", tree_res$exit_code, "）"),
            error_code = "TREE_BUILD_FAILED",
            tree = spec$tree_file
          )
        }

        metadata_out <- ""
        legacy_meta_path <- file.path(ctx$output_dir, spec$metadata)
        mapped <- NULL
        if (!is.null(meta)) {
          mapped <- map_virus_metadata_for_legacy_viz(meta)
          if (!"label" %in% names(mapped)) {
            helpers$fail(
              "VirusStrategy: metadata 映射后缺少 label",
              error_code = "MISSING_METADATA_FIELDS",
              tree = spec$tree_file
            )
          }
        utils::write.csv(mapped, legacy_meta_path, row.names = FALSE)
        metadata_out <- spec$metadata
      } else if (file.exists(legacy_meta_path)) {
        metadata_out <- spec$metadata
        mapped <- utils::read.csv(legacy_meta_path, stringsAsFactors = FALSE, check.names = FALSE)
      }

      tree_path <- file.path(ctx$output_dir, spec$tree_file)

      if (!is.null(mapped) && file.exists(tree_path)) {
        helpers$assert_tips(
          tree = tree_path,
          metadata = mapped,
          id_column = "label",
          message_prefix = "VirusStrategy: metadata label/sample_id 与 tree tip 不匹配，缺失: ",
          tree_file = spec$tree_file,
          metadata_file = metadata_out
        )
      }

      visualization_out <- ""
      if (nzchar(metadata_out) && file.exists(tree_path) && file.exists(legacy_meta_path)) {
        viz_res <- invoke_legacy_ggtree_viz(
          tree_path = tree_path,
          metadata_path = legacy_meta_path,
          output_dir = ctx$output_dir,
          rscript = rscript,
          r_root = r_root
        )
        if (viz_res$exit_code == 0L &&
            file.exists(file.path(ctx$output_dir, spec$visualization))) {
          visualization_out <- spec$visualization
        } else {
          warning(
            "VirusStrategy: 可视化失败或未产出 ", spec$visualization,
            "（exit=", viz_res$exit_code, "）",
            call. = FALSE
          )
        }
      }

      final_status <- "success"
      if (nzchar(metadata_out) && !nzchar(visualization_out)) {
        final_status <- "partial"
      }

      legacy_json <- file.path(ctx$output_dir, "analysis_result.json")
      ring_fields <- tryCatch(
        vapply(ann$rings, function(r) r$field, character(1)),
        error = function(...) character(0)
      )
      if (file.exists(legacy_json) && requireNamespace("jsonlite", quietly = TRUE)) {
        legacy <- jsonlite::fromJSON(legacy_json)
        result <- upgrade_legacy_result(
          legacy,
          organism_type = "virus",
          visualization = visualization_out,
          metadata = metadata_out,
          status = final_status
        )
        result$input <- fasta_base
        if (length(ring_fields)) {
          result$statistics$annotation_rings <- ring_fields
        }
        result$statistics$method <- params$method
        result$statistics$model <- params$model
      } else {
        result <- build_analysis_result(
          status = final_status,
          organism_type = "virus",
          input = fasta_base,
          tree = spec$tree_file,
          visualization = visualization_out,
          metadata = metadata_out,
          statistics = list(
            method = params$method,
            model = params$model,
            annotation_rings = ring_fields
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
    organism_type = "virus",
    validate_input = validate_input,
    parse_metadata = parse_metadata,
    tree_params = tree_params,
    annotation_config = annotation_config,
    output_spec = output_spec,
    run = run
  )
}
