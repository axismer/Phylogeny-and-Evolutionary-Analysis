package com.phylo.platform.service.tree;

import java.io.IOException;
import java.nio.file.Path;

import org.springframework.stereotype.Service;

import com.phylo.platform.config.PhyloDataProperties;
import com.phylo.platform.model.DistanceMatrix;
import com.phylo.platform.model.PhylogeneticTree;
import com.phylo.platform.service.matrix.DistanceMatrixCsvReader;
import com.phylo.platform.service.matrix.DistanceMatrixCsvWriter;

/**
 * 系统发育树业务入口：读取距离矩阵 CSV，UPGMA 建树，写出 Newick。
 */
@Service
public class TreeService {

	private final PhyloDataProperties dataProperties;
	private final DistanceMatrixCsvReader csvReader;
	private final UpgmaBuilder upgmaBuilder;
	private final NewickWriter newickWriter;

	public TreeService(
			PhyloDataProperties dataProperties,
			DistanceMatrixCsvReader csvReader,
			UpgmaBuilder upgmaBuilder,
			NewickWriter newickWriter
	) {
		this.dataProperties = dataProperties;
		this.csvReader = csvReader;
		this.upgmaBuilder = upgmaBuilder;
		this.newickWriter = newickWriter;
	}

	/**
	 * 从默认 {@code data/matrix/distance_matrix.csv} 建树并写出 {@code data/tree/tree.nwk}。
	 *
	 * @return Newick 文件绝对路径
	 */
	public Path buildAndWriteFromMatrixFile() throws IOException {
		Path matrixFile = dataProperties.matrixDir().resolve(DistanceMatrixCsvWriter.DEFAULT_FILE_NAME);
		DistanceMatrix matrix = csvReader.read(matrixFile);
		return buildAndWrite(matrix);
	}

	public Path buildAndWrite(DistanceMatrix matrix) throws IOException {
		PhylogeneticTree tree = build(matrix);
		Path output = dataProperties.treeDir().resolve(NewickWriter.DEFAULT_FILE_NAME);
		return newickWriter.write(tree, output);
	}

	public PhylogeneticTree build(DistanceMatrix matrix) {
		return upgmaBuilder.build(matrix);
	}
}
