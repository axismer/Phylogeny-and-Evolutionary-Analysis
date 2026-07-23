package com.phylo.platform.service.matrix;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

import java.util.List;

import org.junit.jupiter.api.Test;

import com.phylo.platform.model.DistanceMatrix;

class PDistanceCalculatorTest {

	private final PDistanceCalculator calculator = new PDistanceCalculator();

	@Test
	void case1_acgtVsAcct_isQuarter() {
		assertEquals(0.25, calculator.pDistance("ACGT", "ACCT"), 1e-12);
	}

	@Test
	void case2_identicalSequences_isZero() {
		assertEquals(0.0, calculator.pDistance("ACGTACGT", "ACGTACGT"), 1e-12);
	}

	@Test
	void case3_differentLengths_truncateThenDistance() {
		/*
		 * 该截断策略仅用于MVP版本测试，正式系统后续将接入MSA模块。
		 * 短序列 ACGT；长序列 ACCTXXXX → 截断为 ACCT → 与 ACGT 距离 0.25。
		 */
		List<String> truncated = DistanceMatrixService.truncateToMinLength(List.of(
				"ACGT",
				"ACCTXXXX"
		));
		assertEquals(List.of("ACGT", "ACCT"), truncated);
		assertEquals(0.25, calculator.pDistance(truncated.get(0), truncated.get(1)), 1e-12);
	}

	@Test
	void ignoresCaseAndSkipsN() {
		// 可比位点: A-A, C-C, T-G → 2 相同 1 不同 → 1/3
		assertEquals(1.0 / 3.0, calculator.pDistance("AcNt", "acNg"), 1e-12);
	}

	@Test
	void noComparableSites_throws() {
		assertThrows(IllegalArgumentException.class, () -> calculator.pDistance("NNNN", "AAAA"));
	}

	@Test
	void buildMatrix_isSymmetricWithZeroDiagonal() {
		DistanceMatrix matrix = calculator.buildMatrix(
				List.of("A", "B", "C"),
				List.of("AAAA", "AAAT", "TTTT")
		);
		assertEquals(3, matrix.size());
		assertEquals(0.0, matrix.values()[0][0], 1e-12);
		assertEquals(0.0, matrix.values()[1][1], 1e-12);
		assertEquals(0.0, matrix.values()[2][2], 1e-12);
		assertEquals(matrix.values()[0][1], matrix.values()[1][0], 1e-12);
		assertEquals(matrix.values()[0][2], matrix.values()[2][0], 1e-12);
		assertEquals(0.25, matrix.values()[0][1], 1e-12);
	}
}
