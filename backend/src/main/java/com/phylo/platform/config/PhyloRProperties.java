package com.phylo.platform.config;

import java.nio.file.Path;
import java.nio.file.Paths;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * Rscript / Framework CLI 调用配置（路径相对于 backend 工作目录）。
 */
@ConfigurationProperties(prefix = "phylo.r")
public class PhyloRProperties {

	/**
	 * Rscript 可执行文件（PATH 中的命令名，或绝对路径）。
	 */
	private String rscript = "Rscript";

	/**
	 * r-analysis 根目录（ProcessBuilder 工作目录固定为此路径）。
	 */
	private String root = "../r-analysis";

	/**
	 * Framework 入口脚本（相对 {@link #root}，或绝对路径）。
	 */
	private String script = "runners/run_analysis.R";

	/**
	 * 单次分析超时（秒）。
	 */
	private long timeoutSeconds = 600;

	public String getRscript() {
		return rscript;
	}

	public void setRscript(String rscript) {
		this.rscript = rscript;
	}

	public String getRoot() {
		return root;
	}

	public void setRoot(String root) {
		this.root = root;
	}

	public String getScript() {
		return script;
	}

	public void setScript(String script) {
		this.script = script;
	}

	public long getTimeoutSeconds() {
		return timeoutSeconds;
	}

	public void setTimeoutSeconds(long timeoutSeconds) {
		this.timeoutSeconds = timeoutSeconds;
	}

	public Path rootPath() {
		return Paths.get(root).toAbsolutePath().normalize();
	}

	public Path scriptPath() {
		Path scriptPath = Paths.get(script);
		if (scriptPath.isAbsolute()) {
			return scriptPath.normalize();
		}
		return rootPath().resolve(scriptPath).normalize();
	}
}
