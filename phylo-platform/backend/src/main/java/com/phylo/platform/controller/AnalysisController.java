package com.phylo.platform.controller;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.HashMap;
import java.util.Map;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.phylo.platform.config.PhyloDataProperties;
import com.phylo.platform.dto.AnalysisRunResponse;
import com.phylo.platform.dto.DistanceMatrixResponse;
import com.phylo.platform.dto.TreeResponse;
import com.phylo.platform.model.DistanceMatrix;
import com.phylo.platform.service.matrix.DistanceMatrixCsvReader;
import com.phylo.platform.service.matrix.DistanceMatrixCsvWriter;
import com.phylo.platform.service.matrix.DistanceMatrixService;
import com.phylo.platform.service.tree.NewickWriter;
import com.phylo.platform.service.tree.TreeService;

/**
 * 分析流水线 REST 接口：触发计算、查询矩阵与 Newick。
 */
@RestController
@RequestMapping("/api/analysis")
public class AnalysisController {

	private final DistanceMatrixService distanceMatrixService;
	private final TreeService treeService;
	private final DistanceMatrixCsvReader csvReader;
	private final PhyloDataProperties dataProperties;

	public AnalysisController(
			DistanceMatrixService distanceMatrixService,
			TreeService treeService,
			DistanceMatrixCsvReader csvReader,
			PhyloDataProperties dataProperties
	) {
		this.distanceMatrixService = distanceMatrixService;
		this.treeService = treeService;
		this.csvReader = csvReader;
		this.dataProperties = dataProperties;
	}

	@PostMapping("/run")
	public AnalysisRunResponse run() throws IOException {
		distanceMatrixService.computeAndWriteFromRaw();
		treeService.buildAndWriteFromMatrixFile();
		return new AnalysisRunResponse("success", "analysis completed");
	}

	@GetMapping("/matrix")
	public DistanceMatrixResponse matrix() throws IOException {
		Path file = dataProperties.matrixDir().resolve(DistanceMatrixCsvWriter.DEFAULT_FILE_NAME);
		if (!Files.isRegularFile(file)) {
			throw new IOException("距离矩阵文件不存在，请先执行 POST /api/analysis/run: " + file);
		}
		DistanceMatrix matrix = csvReader.read(file);
		return new DistanceMatrixResponse(matrix.labels(), matrix.values());
	}

	@GetMapping("/tree")
	public TreeResponse tree() throws IOException {
		Path file = dataProperties.treeDir().resolve(NewickWriter.DEFAULT_FILE_NAME);
		if (!Files.isRegularFile(file)) {
			throw new IOException("系统树文件不存在，请先执行 POST /api/analysis/run: " + file);
		}
		String newick = Files.readString(file, StandardCharsets.UTF_8).trim();
		return new TreeResponse(newick);
	}

	@ExceptionHandler(IOException.class)
	public ResponseEntity<Map<String, String>> handleIo(IOException ex) {
		Map<String, String> body = new HashMap<>();
		body.put("error", "IO 错误");
		body.put("detail", ex.getMessage());
		return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(body);
	}

	@ExceptionHandler(IllegalArgumentException.class)
	public ResponseEntity<Map<String, String>> handleIllegalArgument(IllegalArgumentException ex) {
		Map<String, String> body = new HashMap<>();
		body.put("error", "参数错误");
		body.put("detail", ex.getMessage());
		return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(body);
	}
}
