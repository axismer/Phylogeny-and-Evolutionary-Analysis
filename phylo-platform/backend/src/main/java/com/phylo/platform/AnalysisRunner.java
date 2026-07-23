package com.phylo.platform;

import java.nio.file.Path;
import java.util.List;

import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.boot.ExitCodeGenerator;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.WebApplicationType;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

import com.phylo.platform.service.fasta.FastaService;
import com.phylo.platform.service.matrix.DistanceMatrixService;
import com.phylo.platform.service.tree.TreeService;

/**
 * 本地一键跑通：raw FASTA → 距离矩阵 → UPGMA → Newick。
 * <p>
 * 默认不随 {@link PhyloPlatformApplication} 启动；请运行本类 {@code main}，
 * 或设置 {@code phylo.analysis.run-on-startup=true}。
 */
@Component
@ConditionalOnProperty(prefix = "phylo.analysis", name = "run-on-startup", havingValue = "true")
public class AnalysisRunner implements ApplicationRunner, ExitCodeGenerator {

	private final FastaService fastaService;
	private final DistanceMatrixService distanceMatrixService;
	private final TreeService treeService;

	private int exitCode = 0;

	public AnalysisRunner(
			FastaService fastaService,
			DistanceMatrixService distanceMatrixService,
			TreeService treeService
	) {
		this.fastaService = fastaService;
		this.distanceMatrixService = distanceMatrixService;
		this.treeService = treeService;
	}

	public static void main(String[] args) {
		System.setProperty("phylo.analysis.run-on-startup", "true");
		SpringApplication app = new SpringApplication(PhyloPlatformApplication.class);
		app.setWebApplicationType(WebApplicationType.NONE);
		System.exit(SpringApplication.exit(app.run(args)));
	}

	@Override
	public void run(ApplicationArguments args) {
		System.out.println("======== Phylo analysis pipeline ========");
		try {
			List<String> rawFiles = fastaService.listRawFileNames();
			int fastaCount = rawFiles.size();

			Path matrixPath = distanceMatrixService.computeAndWriteFromRaw();
			Path treePath = treeService.buildAndWriteFromMatrixFile();

			System.out.println("FASTA读取数量: " + fastaCount);
			System.out.println("distance_matrix.csv: " + matrixPath.toAbsolutePath().normalize());
			System.out.println("tree.nwk: " + treePath.toAbsolutePath().normalize());
			System.out.println("是否成功: true");
			exitCode = 0;
		} catch (Exception ex) {
			exitCode = 1;
			System.out.println("是否成功: false");
			System.out.println("错误: " + ex.getMessage());
			ex.printStackTrace(System.out);
		}
		System.out.println("=========================================");
	}

	@Override
	public int getExitCode() {
		return exitCode;
	}
}
