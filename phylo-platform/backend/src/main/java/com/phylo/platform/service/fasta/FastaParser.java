package com.phylo.platform.service.fasta;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.Reader;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

import org.springframework.stereotype.Component;

import com.phylo.platform.model.FastaRecord;

/**
 * 将 FASTA 文本解析为 {@link FastaRecord} 列表。
 * <p>
 * 支持标准格式：{@code >} 开头的描述行，后续非空行拼接为序列（忽略空白）。
 */
@Component
public class FastaParser {

	public List<FastaRecord> parseFile(Path file) throws IOException {
		String sourceFile = file.getFileName().toString();
		String speciesFromFileName = speciesNameFromFileName(sourceFile);
		try (Reader reader = Files.newBufferedReader(file, StandardCharsets.UTF_8)) {
			return parse(reader, sourceFile, speciesFromFileName);
		}
	}

	public List<FastaRecord> parse(Reader input, String sourceFile, String defaultSpeciesName) throws IOException {
		List<FastaRecord> records = new ArrayList<>();
		BufferedReader reader = input instanceof BufferedReader br ? br : new BufferedReader(input);

		String header = null;
		StringBuilder sequence = new StringBuilder();
		int index = 0;

		String line;
		while ((line = reader.readLine()) != null) {
			line = line.trim();
			if (line.isEmpty()) {
				continue;
			}
			if (line.startsWith(">")) {
				if (header != null) {
					records.add(buildRecord(sourceFile, index++, defaultSpeciesName, header, sequence.toString()));
					sequence.setLength(0);
				}
				header = line.substring(1).trim();
			} else {
				if (header == null) {
					throw new IOException("序列行出现在描述行之前: " + sourceFile);
				}
				sequence.append(line.replaceAll("\\s+", ""));
			}
		}

		if (header != null) {
			records.add(buildRecord(sourceFile, index, defaultSpeciesName, header, sequence.toString()));
		}

		return records;
	}

	private FastaRecord buildRecord(
			String sourceFile,
			int index,
			String defaultSpeciesName,
			String header,
			String sequence
	) {
		String speciesName = index == 0
				? defaultSpeciesName
				: defaultSpeciesName + " [" + (index + 1) + "]";
		return new FastaRecord(sourceFile, index, speciesName, header, sequence.toUpperCase(Locale.ROOT));
	}

	/**
	 * 从文件名推断展示用物种名，例如 {@code E.coli16S.fasta} → {@code E.coli}。
	 */
	public static String speciesNameFromFileName(String fileName) {
		String base = fileName;
		int dot = base.lastIndexOf('.');
		if (dot > 0) {
			base = base.substring(0, dot);
		}
		base = base.replaceAll("(?i)\\s*16s\\s*$", "").trim();
		return base.isEmpty() ? fileName : base;
	}

}
