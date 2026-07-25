package com.phylo.platform.controller;

import java.io.IOException;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.phylo.platform.config.PhyloDataProperties;
import com.phylo.platform.dto.FastaRecordSummary;
import com.phylo.platform.model.FastaRecord;
import com.phylo.platform.service.fasta.FastaService;

@RestController
@RequestMapping("/api")
public class SequenceController {

	private final FastaService fastaService;
	private final PhyloDataProperties dataProperties;

	public SequenceController(FastaService fastaService, PhyloDataProperties dataProperties) {
		this.fastaService = fastaService;
		this.dataProperties = dataProperties;
	}

	@GetMapping("/health")
	public Map<String, String> health() {
		return Map.of(
				"status", "UP",
				"dataRoot", dataProperties.rootPath().toString()
		);
	}

	@GetMapping("/sequences/raw")
	public Map<String, List<String>> listRaw() throws IOException {
		return Map.of("files", fastaService.listRawFileNames());
	}

	@GetMapping("/sequences/parse")
	public Map<String, List<FastaRecordSummary>> parse(
			@RequestParam(required = false) String files
	) throws IOException {
		List<FastaRecord> records = fastaService.parseFilesFromQuery(files);
		List<FastaRecordSummary> summaries = records.stream()
				.map(r -> new FastaRecordSummary(
						r.sourceFile(),
						r.index(),
						r.speciesName(),
						r.header(),
						r.length()))
				.toList();
		return Map.of("records", summaries);
	}

	@ExceptionHandler(IOException.class)
	public ResponseEntity<Map<String, String>> handleIo(IOException ex) {
		Map<String, String> body = new HashMap<>();
		body.put("error", "IO 错误");
		body.put("detail", ex.getMessage());
		return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(body);
	}

}
