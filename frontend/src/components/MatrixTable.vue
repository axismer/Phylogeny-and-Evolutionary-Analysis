<template>
  <div class="matrix-table card" v-if="matrix">
    <h3>📐 距离矩阵 <span class="size-badge">{{ matrix.names.length }} × {{ matrix.names.length }}</span></h3>
    <div class="table-wrapper">
      <table>
        <thead>
          <tr>
            <th></th>
            <th v-for="name in matrix.names" :key="name">{{ name }}</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="(row, i) in matrix.values" :key="i">
            <td class="row-header">{{ matrix.names[i] }}</td>
            <td v-for="(val, j) in row" :key="j" :class="{ diagonal: i === j, highlight: val > 0 && val === maxInRow(row, i) }">
              {{ val.toFixed(4) }}
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>

<script setup>
const props = defineProps({
  matrix: {
    type: Object,
    default: null
  }
})

function maxInRow(row, diagIdx) {
  let max = 0
  row.forEach((val, j) => {
    if (j !== diagIdx && val > max) max = val
  })
  return max
}
</script>

<style scoped>
.matrix-table {
  margin-top: 0;
}

.card {
  background: white;
  border: 1px solid #e8e8e8;
  border-radius: 10px;
  padding: 20px;
  margin-bottom: 20px;
}

h3 {
  margin-bottom: 12px;
  color: #333;
  display: flex;
  align-items: center;
  gap: 10px;
}

.size-badge {
  font-size: 12px;
  background: #fff3e0;
  color: #e65100;
  padding: 2px 10px;
  border-radius: 12px;
  font-weight: normal;
}

.table-wrapper {
  overflow-x: auto;
}

table {
  border-collapse: collapse;
  font-size: 13px;
  font-family: 'Courier New', monospace;
}

th, td {
  padding: 8px 12px;
  border: 1px solid #e0e0e0;
  text-align: center;
}

th {
  background: #f5f5f5;
  font-weight: bold;
  white-space: nowrap;
}

.row-header {
  background: #f5f5f5;
  font-weight: bold;
  white-space: nowrap;
}

.diagonal {
  background: #f9f9f9;
  color: #999;
}

.highlight {
  background: #fff8e1;
  color: #e65100;
  font-weight: bold;
}
</style>
