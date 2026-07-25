package com.phylo.platform.service.task;

import java.nio.file.Path;
import java.util.UUID;
import java.util.regex.Pattern;

/**
 * 任务目录路径解析与安全校验（UUID 隔离，禁止路径穿越）。
 */
public final class TaskPathSecurity {

	private static final Pattern UUID_PATTERN = Pattern.compile(
			"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"
	);

	public static final String SEQUENCES_FASTA = "sequences.fasta";
	public static final String METADATA_CSV = "metadata.csv";
	public static final String TASK_STATE_JSON = "task_state.json";

	private TaskPathSecurity() {
	}

	public static String newTaskId() {
		return UUID.randomUUID().toString();
	}

	public static boolean isValidTaskId(String taskId) {
		return taskId != null && UUID_PATTERN.matcher(taskId).matches();
	}

	/**
	 * 清理上传原始文件名：去路径、禁止 {@code ..}、仅保留安全字符。
	 * 存储时仍强制使用固定名 {@link #SEQUENCES_FASTA} / {@link #METADATA_CSV}。
	 */
	public static String sanitizeOriginalFilename(String original) {
		if (original == null || original.isBlank()) {
			return "";
		}
		String name = original.replace('\\', '/');
		int slash = name.lastIndexOf('/');
		if (slash >= 0) {
			name = name.substring(slash + 1);
		}
		if (name.contains("..") || name.isBlank()) {
			return "";
		}
		String cleaned = name.replaceAll("[^A-Za-z0-9._-]", "_");
		if (cleaned.contains("..") || cleaned.startsWith(".")) {
			return "";
		}
		return cleaned;
	}

	public static String extensionOf(String filename) {
		String name = sanitizeOriginalFilename(filename);
		int dot = name.lastIndexOf('.');
		if (dot < 0 || dot == name.length() - 1) {
			return "";
		}
		return name.substring(dot + 1).toLowerCase();
	}

	public static boolean isAllowedFastaExtension(String filename) {
		String ext = extensionOf(filename);
		return ext.equals("fasta") || ext.equals("fa") || ext.equals("fna") || ext.equals("fas") || ext.equals("txt");
	}

	public static boolean isAllowedMetadataExtension(String filename) {
		return extensionOf(filename).equals("csv");
	}

	/**
	 * 将 taskId 解析到 base 下的子目录；若越界或非法则返回 null。
	 */
	public static Path resolveTaskDir(Path baseDir, String taskId) {
		if (baseDir == null || !isValidTaskId(taskId)) {
			return null;
		}
		Path base = baseDir.toAbsolutePath().normalize();
		Path resolved = base.resolve(taskId).normalize();
		if (!resolved.startsWith(base)) {
			return null;
		}
		return resolved;
	}

	public static Path requireUnder(Path baseDir, Path candidate) {
		Path base = baseDir.toAbsolutePath().normalize();
		Path path = candidate.toAbsolutePath().normalize();
		if (!path.startsWith(base)) {
			throw new SecurityException("path escapes task root: " + path);
		}
		return path;
	}
}
