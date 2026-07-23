package com.phylo.platform.service.fasta;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.io.StringReader;
import java.util.List;

import org.junit.jupiter.api.Test;

import com.phylo.platform.model.FastaRecord;

class FastaParserTest {

	private final FastaParser parser = new FastaParser();

	@Test
	void parsesMultiLineSequence() throws Exception {
		String fasta = """
				>NR_1 test organism
				ACGT
				acgt
				>second record
				NNNN
				""";
		List<FastaRecord> records = parser.parse(new StringReader(fasta), "demo.fasta", "Demo species");

		assertEquals(2, records.size());
		assertEquals("Demo species", records.get(0).speciesName());
		assertEquals("ACGTACGT", records.get(0).sequence());
		assertEquals("Demo species [2]", records.get(1).speciesName());
		assertEquals("NNNN", records.get(1).sequence());
	}

	@Test
	void speciesNameFromFileNameStripsSuffix() {
		assertEquals("E.coli", FastaParser.speciesNameFromFileName("E.coli16S.fasta"));
		assertEquals("Bacillus subtilis", FastaParser.speciesNameFromFileName("Bacillus subtilis16S.fasta"));
	}

}
