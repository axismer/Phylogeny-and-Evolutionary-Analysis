<script setup>
import TreeBranch from './TreeBranch.vue'

defineProps({
  node: {
    type: Object,
    required: true,
  },
  isRoot: {
    type: Boolean,
    default: false,
  },
})

function formatLength(length) {
  if (length == null || Number.isNaN(length)) {
    return ''
  }
  return Number(length).toFixed(4)
}
</script>

<template>
  <div class="branch" :class="{ root: isRoot, leaf: !node.children?.length }">
    <div v-if="node.children?.length" class="fork">
      <TreeBranch
        v-for="(child, index) in node.children"
        :key="index"
        :node="child"
      />
    </div>
    <div class="edge">
      <span v-if="!isRoot && node.length != null" class="len">{{ formatLength(node.length) }}</span>
      <span v-if="node.name" class="label">{{ node.name }}</span>
      <span v-else-if="!node.children?.length" class="label muted">?</span>
    </div>
  </div>
</template>
