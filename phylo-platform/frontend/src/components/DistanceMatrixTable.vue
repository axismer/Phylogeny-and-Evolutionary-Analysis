<script setup>
defineProps({
  labels: {
    type: Array,
    default: () => [],
  },
  values: {
    type: Array,
    default: () => [],
  },
})

function formatDistance(value) {
  if (value == null || Number.isNaN(value)) {
    return '-'
  }
  if (value === 0) {
    return '0'
  }
  return Number(value).toFixed(4)
}
</script>

<template>
  <div class="matrix-wrap">
    <table class="matrix-table" v-if="labels.length">
      <thead>
        <tr>
          <th class="corner"></th>
          <th v-for="label in labels" :key="'h-' + label">{{ label }}</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="(row, i) in values" :key="'r-' + labels[i]">
          <th>{{ labels[i] }}</th>
          <td
            v-for="(cell, j) in row"
            :key="'c-' + i + '-' + j"
            :class="{ diagonal: i === j }"
          >
            {{ formatDistance(cell) }}
          </td>
        </tr>
      </tbody>
    </table>
    <p v-else class="empty">暂无距离矩阵</p>
  </div>
</template>
