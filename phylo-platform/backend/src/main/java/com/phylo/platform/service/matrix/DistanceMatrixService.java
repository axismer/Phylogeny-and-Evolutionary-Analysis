package com.phylo.platform.service.matrix;

import java.io.IOException;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import org.springframework.stereotype.Service;

import com.phylo.platform.config.PhyloDataProperties;
import com.phylo.platform.model.DistanceMatrix;
import com.phylo.platform.model.FastaRecord;
import com.phylo.platform.service.fasta.FastaService;

/**
 * 距离矩阵业务入口：从 raw FASTA 读取序列，计算 p-distance，写出 CSV。
 */
@Service
public class DistanceMatrixService {

	private final FastaService fastaService;
	private final PhyloDataProperties dataProperties;
	private final PDistanceCalculator calculator;
	private final DistanceMatrixCsvWriter csvWriter;

	public DistanceMatrixService(
			FastaService fastaService,
			PhyloDataProperties dataProperties,
			PDistanceCalculator calculator,
			DistanceMatrixCsvWriter csvWriter
	) {
		this.fastaService = fastaService;
		this.dataProperties = dataProperties;
		this.calculator = calculator;
		this.csvWriter = csvWriter;
	}

	/**
	 * 使用 {@code data/raw} 下全部 FASTA，生成 {@code data/matrix/distance_matrix.csv}。
	 *
	 * @return 写出的 CSV 绝对路径
	 */
	public Path computeAndWriteFromRaw() throws IOException {
		List<FastaRecord> records = fastaService.parseAllRawFiles();
		return computeAndWrite(records);
	}

	/**
	 * 对给定记录计算距离矩阵并写出默认输出文件。
	 */
	public Path computeAndWrite(List<FastaRecord> records) throws IOException {
		DistanceMatrix matrix = computeMatrix(records);
		Path output = dataProperties.matrixDir().resolve(DistanceMatrixCsvWriter.DEFAULT_FILE_NAME);
		return csvWriter.write(matrix, output);
	}

	/**
	 * 从 FASTA 记录构建距离矩阵（每文件取第一条序列，必要时截断至最短长度）。
	 */
	public DistanceMatrix computeMatrix(List<FastaRecord> records) {
		List<FastaRecord> taxa = selectFirstRecordPerFile(records);
		if (taxa.size() < 2) {
			throw new IllegalArgumentException("至少需要 2 个物种才能计算距离矩阵，当前: " + taxa.size());
		}

		List<String> labels = new ArrayList<>(taxa.size());
		List<String> sequences = new ArrayList<>(taxa.size());
		for (FastaRecord record : taxa) {
			labels.add(record.speciesName());
			sequences.add(record.sequence());
		}

		/*
		 * 该截断策略仅用于MVP版本测试，正式系统后续将接入MSA模块。
		 */
		List<String> truncated = truncateToMinLength(sequences);
		return calculator.buildMatrix(labels, truncated);
	}

	/**
	 * 一个 FASTA 文件代表一个物种；默认取该文件中的第一条序列（index == 0）。
	 */
	static List<FastaRecord> selectFirstRecordPerFile(List<FastaRecord> records) {
		Map<String, FastaRecord> firstByFile = new LinkedHashMap<>();
		for (FastaRecord record : records) {
			firstByFile.putIfAbsent(record.sourceFile(), record);
		}
		return new ArrayList<>(firstByFile.values());
	}

	/**
	 * 找到最短序列长度 N，截取所有序列的前 N 个碱基，形成共同可比区域。
	 * <p>
	 * 该截断策略仅用于MVP版本测试，正式系统后续将接入MSA模块。
	 */
	static List<String> truncateToMinLength(List<String> sequences) {
		if (sequences == null || sequences.isEmpty()) {
			throw new IllegalArgumentException("序列列表为空，无法截断");
		}
		int minLength = Integer.MAX_VALUE;
		for (String seq : sequences) {
			if (seq == null || seq.isEmpty()) {
				throw new IllegalArgumentException("存在空序列，无法计算距离矩阵");
			}
			minLength = Math.min(minLength, seq.length());
		}
		List<String> truncated = new ArrayList<>(sequences.size());
		for (String seq : sequences) {
			truncated.add(seq.substring(0, minLength));
		}
		return truncated;
	}
}
