package com.phylo.platform.service.matrix;

import static org.junit.jupiter.api.Assertions.assertEquals;

import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import com.phylo.platform.model.DistanceMatrix;

class DistanceMatrixCsvReaderTest {

	private final DistanceMatrixCsvReader reader = new DistanceMatrixCsvReader();
	private final DistanceMatrixCsvWriter writer = new DistanceMatrixCsvWriter();

	@Test
	void readsWrittenCsvRoundTrip(@TempDir Path tempDir) throws Exception {
		DistanceMatrix original = new DistanceMatrix(
				List.of("A", "B", "C"),
				new double[][] {
						{0.0, 0.2, 0.6},
						{0.2, 0.0, 0.6},
						{0.6, 0.6, 0.0}
				}
		);
		Path file = tempDir.resolve("distance_matrix.csv");
		writer.write(original, file);

		DistanceMatrix loaded = reader.read(file);
		assertEquals(original.labels(), loaded.labels());
		assertEquals(3, loaded.size());
		assertEquals(0.2, loaded.values()[0][1], 1e-12);
		assertEquals(0.6, loaded.values()[0][2], 1e-12);
		assertEquals(0.6, loaded.values()[1][2], 1e-12);
	}

	@Test
	void readsQuotedSpeciesNames(@TempDir Path tempDir) throws Exception {
		Path file = tempDir.resolve("m.csv");
		Files.writeString(file, """
				,"Bacillus subtilis",E.coli
				"Bacillus subtilis",0,0.15
				E.coli,0.15,0
				""");

		DistanceMatrix matrix = reader.read(file);
		assertEquals(List.of("Bacillus subtilis", "E.coli"), matrix.labels());
		assertEquals(0.15, matrix.values()[0][1], 1e-12);
	}
}
