package com.phylo.platform.service.task;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.nio.file.Path;
import java.nio.file.Paths;

import org.junit.jupiter.api.Test;

class TaskPathSecurityTest {

	@Test
	void newTaskId_isUuid() {
		assertTrue(TaskPathSecurity.isValidTaskId(TaskPathSecurity.newTaskId()));
	}

	@Test
	void sanitize_stripsPathAndDots() {
		assertEquals("evil.fasta", TaskPathSecurity.sanitizeOriginalFilename("../evil.fasta"));
		assertEquals("", TaskPathSecurity.sanitizeOriginalFilename(".."));
		assertEquals("b.fasta", TaskPathSecurity.sanitizeOriginalFilename("a/b.fasta"));
		assertEquals("seq_1.fa", TaskPathSecurity.sanitizeOriginalFilename("seq 1.fa"));
	}

	@Test
	void resolveTaskDir_rejectsTraversalAndInvalidId() {
		Path base = Paths.get("tmp", "tasks").toAbsolutePath().normalize();
		assertNull(TaskPathSecurity.resolveTaskDir(base, "../not-a-uuid"));
		assertNull(TaskPathSecurity.resolveTaskDir(base, "not-uuid"));
		String id = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee";
		Path resolved = TaskPathSecurity.resolveTaskDir(base, id);
		assertNotNull(resolved);
		assertTrue(resolved.startsWith(base));
		assertEquals(id, resolved.getFileName().toString());
	}

	@Test
	void requireUnder_throwsOnEscape() {
		Path base = Paths.get("tmp", "tasks", "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")
				.toAbsolutePath().normalize();
		Path outside = base.getParent().resolve("other-task").resolve("sequences.fasta");
		assertThrows(SecurityException.class, () -> TaskPathSecurity.requireUnder(base, outside));
	}

	@Test
	void extensionAllowlists() {
		assertTrue(TaskPathSecurity.isAllowedFastaExtension("x.fasta"));
		assertTrue(TaskPathSecurity.isAllowedFastaExtension("x.fa"));
		assertFalse(TaskPathSecurity.isAllowedFastaExtension("x.exe"));
		assertTrue(TaskPathSecurity.isAllowedMetadataExtension("m.csv"));
		assertFalse(TaskPathSecurity.isAllowedMetadataExtension("m.tsv"));
	}
}
