package com.phylo.platform.service.tree;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Locale;
import java.util.Objects;

import org.springframework.stereotype.Component;

import com.phylo.platform.model.PhylogeneticTree;
import com.phylo.platform.model.TreeNode;

/**
 * 将系统发育树写为 Newick 格式。
 * <p>
 * 根节点不输出 branch length，例如 {@code ((A:0.1,B:0.1):0.2,C:0.3);}。
 */
@Component
public class NewickWriter {

	public static final String DEFAULT_FILE_NAME = "tree.nwk";

	public String toNewick(PhylogeneticTree tree) {
		Objects.requireNonNull(tree, "tree");
		return toNewick(tree.root(), true) + ";";
	}

	public Path write(PhylogeneticTree tree, Path outputFile) throws IOException {
		Objects.requireNonNull(outputFile, "outputFile");
		Path parent = outputFile.getParent();
		if (parent != null) {
			Files.createDirectories(parent);
		}
		String newick = toNewick(tree);
		Files.writeString(outputFile, newick, StandardCharsets.UTF_8);
		return outputFile;
	}

	private String toNewick(TreeNode node, boolean isRoot) {
		if (node.isLeaf()) {
			String body = formatLabel(node.getLabel());
			if (isRoot) {
				return body;
			}
			return body + ":" + formatLength(node.getBranchLength());
		}

		String left = toNewick(node.getLeft(), false);
		String right = toNewick(node.getRight(), false);
		String body = "(" + left + "," + right + ")";
		if (isRoot) {
			return body;
		}
		return body + ":" + formatLength(node.getBranchLength());
	}

	private static String formatLabel(String label) {
		if (label == null) {
			return "";
		}
		boolean needsQuote = false;
		for (int i = 0; i < label.length(); i++) {
			char c = label.charAt(i);
			if (Character.isWhitespace(c) || c == '(' || c == ')' || c == ':' || c == ',' || c == ';' || c == '\'') {
				needsQuote = true;
				break;
			}
		}
		if (!needsQuote) {
			return label;
		}
		return "'" + label.replace("'", "''") + "'";
	}

	private static String formatLength(double length) {
		if (length == 0.0) {
			return "0";
		}
		return String.format(Locale.US, "%.6f", length).replaceAll("0+$", "").replaceAll("\\.$", "");
	}
}
