package com.phylo.platform.config;

import java.nio.file.Path;
import java.nio.file.Paths;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "phylo.data")
public class PhyloDataProperties {

	/**
	 * 平台 data 目录（包含 raw、aligned、matrix、tree）。
	 */
	private String root = "../data";

	public String getRoot() {
		return root;
	}

	public void setRoot(String root) {
		this.root = root;
	}

	public Path rootPath() {
		return Paths.get(root).toAbsolutePath().normalize();
	}

	public Path rawDir() {
		return rootPath().resolve("raw");
	}

	public Path alignedDir() {
		return rootPath().resolve("aligned");
	}

	public Path matrixDir() {
		return rootPath().resolve("matrix");
	}

	public Path treeDir() {
		return rootPath().resolve("tree");
	}

}
