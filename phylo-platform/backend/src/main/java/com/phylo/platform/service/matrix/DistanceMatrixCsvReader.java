package com.phylo.platform.service.matrix;

import java.io.BufferedReader;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.Objects;

import org.springframework.stereotype.Component;

import com.phylo.platform.model.DistanceMatrix;

/**
 * 从 CSV 读取 {@link DistanceMatrix}（格式与 {@link DistanceMatrixCsvWriter} 一致）。
 */
@Component
public class DistanceMatrixCsvReader {

	public DistanceMatrix read(Path csvFile) throws IOException {
		Objects.requireNonNull(csvFile, "csvFile");
		if (!Files.isRegularFile(csvFile)) {
			throw new IOException("距离矩阵文件不存在: " + csvFile);
		}

		try (BufferedReader reader = Files.newBufferedReader(csvFile, StandardCharsets.UTF_8)) {
			String headerLine = reader.readLine();
			if (headerLine == null || headerLine.isBlank()) {
				throw new IOException("距离矩阵 CSV 为空: " + csvFile);
			}

			List<String> headerFields = parseCsvLine(headerLine);
			if (headerFields.isEmpty() || !headerFields.get(0).isEmpty()) {
				throw new IOException("CSV 首行应以空角单元格开头（,Label1,Label2,...）");
			}
			List<String> labels = new ArrayList<>(headerFields.subList(1, headerFields.size()));
			int n = labels.size();
			if (n == 0) {
				throw new IOException("CSV 未包含任何物种标签");
			}

			double[][] values = new double[n][n];
			for (int i = 0; i < n; i++) {
				String line = reader.readLine();
				if (line == null) {
					throw new IOException("CSV 数据行不足，期望 " + n + " 行");
				}
				List<String> fields = parseCsvLine(line);
				if (fields.size() != n + 1) {
					throw new IOException("第 " + (i + 2) + " 行列数不正确: " + fields.size());
				}
				if (!labels.get(i).equals(fields.get(0))) {
					throw new IOException("行标签与表头不一致: 期望 " + labels.get(i) + "，实际 " + fields.get(0));
				}
				for (int j = 0; j < n; j++) {
					values[i][j] = Double.parseDouble(fields.get(j + 1));
				}
			}

			return new DistanceMatrix(labels, values);
		}
	}

	/**
	 * 解析一行 CSV，支持双引号转义字段。
	 */
	static List<String> parseCsvLine(String line) {
		List<String> fields = new ArrayList<>();
		StringBuilder current = new StringBuilder();
		boolean inQuotes = false;
		for (int i = 0; i < line.length(); i++) {
			char c = line.charAt(i);
			if (inQuotes) {
				if (c == '"') {
					if (i + 1 < line.length() && line.charAt(i + 1) == '"') {
						current.append('"');
						i++;
					} else {
						inQuotes = false;
					}
				} else {
					current.append(c);
				}
			} else if (c == '"') {
				inQuotes = true;
			} else if (c == ',') {
				fields.add(current.toString());
				current.setLength(0);
			} else {
				current.append(c);
			}
		}
		fields.add(current.toString());
		return fields;
	}
}
