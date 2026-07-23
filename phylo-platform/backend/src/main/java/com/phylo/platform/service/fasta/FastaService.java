package com.phylo.platform.service.fasta;

import java.io.IOException;
import java.nio.file.DirectoryStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Locale;
import java.util.stream.Collectors;

import org.springframework.stereotype.Service;

import com.phylo.platform.config.PhyloDataProperties;
import com.phylo.platform.model.FastaRecord;

/**
 * 读取 {@code data/raw} 下的 FASTA 文件并解析为序列记录。
 */
@Service
public class FastaService {

	private final PhyloDataProperties dataProperties;
	private final FastaParser fastaParser;

	public FastaService(PhyloDataProperties dataProperties, FastaParser fastaParser) {
		this.dataProperties = dataProperties;
		this.fastaParser = fastaParser;
	}

	public Path rawDirectory() {
		return dataProperties.rawDir();
	}

	public List<String> listRawFileNames() throws IOException {
		Path rawDir = rawDirectory();
		if (!Files.isDirectory(rawDir)) {
			throw new IOException("raw 目录不存在: " + rawDir);
		}
		List<String> names = new ArrayList<>();
		try (DirectoryStream<Path> stream = Files.newDirectoryStream(rawDir)) {
			for (Path entry : stream) {
				if (Files.isRegularFile(entry) && isFastaFile(entry.getFileName().toString())) {
					names.add(entry.getFileName().toString());
				}
			}
		}
		names.sort(String.CASE_INSENSITIVE_ORDER);
		return names;
	}

	public List<FastaRecord> parseAllRawFiles() throws IOException {
		return parseFiles(listRawFileNames());
	}

	public List<FastaRecord> parseFiles(List<String> fileNames) throws IOException {
		List<FastaRecord> all = new ArrayList<>();
		for (String name : fileNames) {
			Path file = rawDirectory().resolve(name).normalize();
			if (!file.startsWith(rawDirectory())) {
				throw new IOException("非法文件路径: " + name);
			}
			if (!Files.isRegularFile(file)) {
				throw new IOException("文件不存在: " + name);
			}
			all.addAll(fastaParser.parseFile(file));
		}
		all.sort(Comparator.comparing(FastaRecord::sourceFile).thenComparingInt(FastaRecord::index));
		return all;
	}

	public List<FastaRecord> parseFilesFromQuery(String filesQuery) throws IOException {
		if (filesQuery == null || filesQuery.isBlank()) {
			return parseAllRawFiles();
		}
		List<String> names = List.of(filesQuery.split(",")).stream()
				.map(String::trim)
				.filter(s -> !s.isEmpty())
				.collect(Collectors.toList());
		return parseFiles(names);
	}

	private static boolean isFastaFile(String fileName) {
		String lower = fileName.toLowerCase(Locale.ROOT);
		return lower.endsWith(".fasta") || lower.endsWith(".fa") || lower.endsWith(".fna");
	}

}
