<script setup>
import { computed } from 'vue'
import { parseNewick, collectLeaves } from '../utils/newick.js'
import TreeBranch from './TreeBranch.vue'

const props = defineProps({
  newick: {
    type: String,
    default: '',
  },
})

const tree = computed(() => {
  if (!props.newick) {
    return null
  }
  try {
    return parseNewick(props.newick)
  } catch {
    return null
  }
})

const leafCount = computed(() => (tree.value ? collectLeaves(tree.value).length : 0))
</script>

<template>
  <div class="tree-panel">
    <p v-if="!newick" class="empty">暂无系统发育树</p>
    <template v-else-if="tree">
      <p class="tree-meta">叶节点数：{{ leafCount }}</p>
      <div class="tree-canvas">
        <TreeBranch :node="tree" :is-root="true" />
      </div>
      <details class="newick-raw">
        <summary>Newick 原文</summary>
        <code>{{ newick }}</code>
      </details>
    </template>
    <p v-else class="empty error">Newick 解析失败</p>
  </div>
</template>
