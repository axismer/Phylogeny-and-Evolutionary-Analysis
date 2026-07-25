package com.phylo.platform.service.matrix;

import java.io.BufferedWriter;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import java.util.Locale;
import java.util.Objects;

import org.springframework.stereotype.Component;

import com.phylo.platform.model.DistanceMatrix;

/**
 * 将 {@link DistanceMatrix} 写入 CSV 文件。
 * <p>
 * 格式示例：
 * <pre>
 * ,Species1,Species2
 * Species1,0,0.12
 * Species2,0.12,0
 * </pre>
 */
@Component
public class DistanceMatrixCsvWriter {

	public static final String DEFAULT_FILE_NAME = "distance_matrix.csv";

	public Path write(DistanceMatrix matrix, Path outputFile) throws IOException {
		Objects.requireNonNull(matrix, "matrix");
		Objects.requireNonNull(outputFile, "outputFile");

		Path parent = outputFile.getParent();
		if (parent != null) {
			Files.createDirectories(parent);
		}

		List<String> labels = matrix.labels();
		double[][] values = matrix.values();
		int n = matrix.size();

		try (BufferedWriter writer = Files.newBufferedWriter(outputFile, StandardCharsets.UTF_8)) {
			writer.write("");
			for (String label : labels) {
				writer.write(',');
				writer.write(escapeCsvField(label));
			}
			writer.newLine();

			for (int i = 0; i < n; i++) {
				writer.write(escapeCsvField(labels.get(i)));
				for (int j = 0; j < n; j++) {
					writer.write(',');
					writer.write(formatDistance(values[i][j]));
				}
				writer.newLine();
			}
		}
		return outputFile;
	}

	private static String formatDistance(double value) {
		if (value == 0.0) {
			return "0";
		}
		return String.format(Locale.US, "%.6f", value).replaceAll("0+$", "").replaceAll("\\.$", "");
	}

	/**
	 * 简单 CSV 转义：含逗号/引号/换行时用双引号包裹。
	 */
	private static String escapeCsvField(String field) {
		if (field.indexOf(',') >= 0 || field.indexOf('"') >= 0 || field.indexOf('\n') >= 0) {
			return '"' + field.replace("\"", "\"\"") + '"';
		}
		return field;
	}
}
