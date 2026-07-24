<template>
  <div class="analysis-page">
    <div class="page-header">
      <h1>🌳 系统发育分析</h1>
      <p>多物种序列比对 · 距离矩阵热图 · PCoA 分析 · 环形进化树</p>
    </div>

    <!-- 分析配置 -->
    <div class="card config-section">
      <h3>分析配置</h3>
      <div class="config-form">
        <div class="config-row">
          <div class="config-item">
            <label>数据集</label>
            <select v-model="selectedDid" class="select-input">
              <option value="">选择数据集</option>
              <option v-for="ds in datasets" :key="ds.did" :value="ds.did">{{ ds.dname }}</option>
            </select>
          </div>
          <div class="config-item">
            <label>建树方法</label>
            <select v-model="method" class="select-input">
              <option value="nj">Neighbor-Joining (NJ)</option>
              <option value="upgma">UPGMA</option>
            </select>
          </div>
          <button class="btn-primary" @click="runAnalysis" :disabled="analyzing || !selectedDid">
            {{ analyzing ? '分析中...' : '🚀 开始分析' }}
          </button>
        </div>
      </div>
    </div>

    <!-- 错误提示 -->
    <div v-if="error" class="error-box">⚠️ {{ error }}</div>

    <!-- 分析结果 -->
    <div v-if="result" class="results">
      <!-- 序列信息 -->
      <div class="card">
        <h3>📋 序列信息 <span class="badge">{{ result.sequences?.length }} 个物种</span></h3>
        <div v-if="result.selectionInfo" class="selection-info">
          <p v-for="(info, i) in result.selectionInfo" :key="i" class="sel-item">✓ {{ info }}</p>
        </div>
        <div class="seq-tags">
          <span v-for="seq in result.sequences" :key="seq.name" class="seq-tag">
            {{ seq.name }} ({{ seq.length }}bp)
          </span>
        </div>
        <p class="method-info">方法: <strong>{{ result.method }}</strong></p>
      </div>

      <!-- 可视化切换 -->
      <div class="viz-tabs">
        <button :class="['vtab', { active: vizTab === 'heatmap' }]" @click="vizTab = 'heatmap'">🔥 距离矩阵热图</button>
        <button :class="['vtab', { active: vizTab === 'pcoa' }]" @click="vizTab = 'pcoa'">📈 PCoA 图</button>
        <button :class="['vtab', { active: vizTab === 'tree' }]" @click="vizTab = 'tree'">🌳 环形进化树</button>
      </div>

      <!-- 热图 -->
      <div v-show="vizTab === 'heatmap'" class="card viz-card">
        <div ref="heatmapRef" class="chart-container"></div>
      </div>

      <!-- PCoA -->
      <div v-show="vizTab === 'pcoa'" class="card viz-card">
        <div ref="pcoaRef" class="chart-container"></div>
      </div>

      <!-- 环形树 -->
      <div v-show="vizTab === 'tree'" class="card viz-card">
        <div ref="treeRef" class="chart-container tree-chart"></div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, watch, nextTick, onBeforeUnmount } from 'vue'
import * as echarts from 'echarts'
import { getDatasets, analyzeDataset } from '../api'

const datasets = ref([])
const selectedDid = ref('')
const method = ref('nj')
const analyzing = ref(false)
const error = ref('')
const result = ref(null)
const vizTab = ref('heatmap')

const heatmapRef = ref(null)
const pcoaRef = ref(null)
const treeRef = ref(null)

let heatmapChart = null
let pcoaChart = null
let treeChart = null

onMounted(async () => {
  try {
    const res = await getDatasets()
    datasets.value = res.data
  } catch (e) { /* ignore */ }
})

async function runAnalysis() {
  if (!selectedDid.value) return
  analyzing.value = true
  error.value = ''
  result.value = null
  try {
    const res = await analyzeDataset(selectedDid.value, method.value)
    result.value = res.data
    await nextTick()
    renderAll()
  } catch (e) {
    error.value = e.response?.data?.error || '分析失败，请检查数据集'
  } finally {
    analyzing.value = false
  }
}

function renderAll() {
  renderHeatmap()
  renderPCoA()
  renderCircularTree()
}

// ===== 热图 =====
function renderHeatmap() {
  if (!heatmapRef.value || !result.value?.distanceMatrix) return
  if (!heatmapChart) heatmapChart = echarts.init(heatmapRef.value)

  const { names, values } = result.value.distanceMatrix
  const data = []
  let maxVal = 0
  for (let i = 0; i < names.length; i++) {
    for (let j = 0; j < names.length; j++) {
      data.push([j, i, values[i][j]])
      if (values[i][j] > maxVal) maxVal = values[i][j]
    }
  }

  heatmapChart.setOption({
    tooltip: {
      formatter: p => `${names[p.value[1]]} vs ${names[p.value[0]]}<br/>距离: ${p.value[2].toFixed(4)}`
    },
    grid: { top: 60, bottom: 80, left: 120, right: 40 },
    xAxis: { type: 'category', data: names, axisLabel: { rotate: 35, fontSize: 11 }, splitArea: { show: true } },
    yAxis: { type: 'category', data: names, axisLabel: { fontSize: 11 }, splitArea: { show: true } },
    visualMap: {
      min: 0, max: maxVal, calculable: true, orient: 'horizontal',
      left: 'center', bottom: 10,
      inRange: { color: ['#f7fbff', '#deebf7', '#c6dbef', '#9ecae1', '#6baed6', '#4292c6', '#2171b5', '#084594'] }
    },
    series: [{
      type: 'heatmap', data, label: { show: names.length <= 10, fontSize: 10, formatter: p => p.value[2].toFixed(3) },
      emphasis: { itemStyle: { shadowBlur: 10, shadowColor: 'rgba(0,0,0,0.3)' } }
    }]
  }, true)
}

// ===== PCoA =====
function renderPCoA() {
  if (!pcoaRef.value || !result.value?.pcoaCoordinates) return
  if (!pcoaChart) pcoaChart = echarts.init(pcoaRef.value)

  const coords = result.value.pcoaCoordinates
  const names = result.value.distanceMatrix.names
  const scatterData = coords.map((c, i) => ({ value: [c[0], c[1]], name: names[i] }))

  pcoaChart.setOption({
    tooltip: { formatter: p => `${p.data.name}<br/>PC1: ${p.value[0].toFixed(4)}<br/>PC2: ${p.value[1].toFixed(4)}` },
    grid: { top: 40, bottom: 50, left: 60, right: 40 },
    xAxis: { name: 'PCo1', nameLocation: 'center', nameGap: 30, splitLine: { lineStyle: { type: 'dashed' } } },
    yAxis: { name: 'PCo2', nameLocation: 'center', nameGap: 40, splitLine: { lineStyle: { type: 'dashed' } } },
    series: [{
      type: 'scatter', data: scatterData, symbolSize: 14,
      itemStyle: { color: '#4a90d9', borderColor: '#2c6fad', borderWidth: 1.5 },
      label: { show: true, formatter: p => p.data.name, position: 'right', fontSize: 11, color: '#333' }
    }]
  }, true)
}

// ===== 环形进化树 =====
function renderCircularTree() {
  if (!treeRef.value || !result.value?.tree) return
  if (!treeChart) treeChart = echarts.init(treeRef.value)

  const treeData = parseNewick(result.value.tree)

  treeChart.setOption({
    tooltip: {
      trigger: 'item',
      formatter: p => {
        if (p.data.name) {
          let tip = p.data.name
          if (p.data.value > 0) tip += `<br/>分支长度: ${p.data.value.toFixed(4)}`
          return tip
        }
        return ''
      }
    },
    series: [{
      type: 'tree', data: [treeData],
      top: '5%', left: '10%', bottom: '5%', right: '25%',
      symbolSize: 8, orient: 'LR',
      layout: 'radial',
      label: {
        position: 'right', verticalAlign: 'middle', align: 'left',
        fontSize: 12, color: '#2c3e50', fontWeight: 'bold'
      },
      leaves: {
        label: { position: 'right', verticalAlign: 'middle', align: 'left', fontSize: 12, fontWeight: 'bold', color: '#1a5276' }
      },
      lineStyle: { color: '#4a90d9', width: 2, curveness: 0.5 },
      itemStyle: { color: '#4a90d9', borderColor: '#357abd' },
      expandAndCollapse: false,
      animationDuration: 600, animationDurationUpdate: 750
    }]
  }, true)
}

// ===== Newick 解析 =====
function parseNewick(newick) {
  if (!newick || newick === ';') return { name: 'root', children: [] }
  const str = newick.endsWith(';') ? newick.slice(0, -1) : newick

  function parse(sub) {
    if (!sub.startsWith('(')) {
      const colonIdx = sub.lastIndexOf(':')
      if (colonIdx > 0) {
        return { name: sub.substring(0, colonIdx), value: parseFloat(sub.substring(colonIdx + 1)) || 0 }
      }
      return { name: sub, value: 0 }
    }
    let depth = 0, inner = '', suffix = ''
    for (let i = 0; i < sub.length; i++) {
      if (sub[i] === '(') { depth++; if (depth === 1) continue }
      if (sub[i] === ')') { depth--; if (depth === 0) { suffix = sub.slice(i + 1); break } }
      if (depth >= 1) inner += sub[i]
    }
    let nodeValue = 0
    if (suffix.startsWith(':')) nodeValue = parseFloat(suffix.substring(1)) || 0
    const children = splitTopLevel(inner)
    return { name: '', value: nodeValue, children: children.map(c => parse(c.trim())) }
  }

  function splitTopLevel(s) {
    const parts = []; let depth = 0, current = ''
    for (let i = 0; i < s.length; i++) {
      if (s[i] === '(') depth++
      if (s[i] === ')') depth--
      if (s[i] === ',' && depth === 0) { parts.push(current); current = '' }
      else current += s[i]
    }
    if (current) parts.push(current)
    return parts
  }

  return parse(str)
}

// 窗口resize
function handleResize() {
  heatmapChart?.resize()
  pcoaChart?.resize()
  treeChart?.resize()
}
onMounted(() => window.addEventListener('resize', handleResize))
onBeforeUnmount(() => {
  window.removeEventListener('resize', handleResize)
  heatmapChart?.dispose()
  pcoaChart?.dispose()
  treeChart?.dispose()
})

watch(vizTab, () => { nextTick(() => handleResize()) })
</script>

<style scoped>
.analysis-page { max-width: 1000px; }
.page-header { margin-bottom: 24px; }
.page-header h1 { font-size: 24px; color: #1a2332; margin-bottom: 4px; }
.page-header p { color: #666; font-size: 14px; }

.card {
  background: white; border-radius: 12px; padding: 24px;
  margin-bottom: 20px; border: 1px solid #eef2f7;
  box-shadow: 0 2px 8px rgba(0,0,0,0.03);
}
.card h3 { font-size: 16px; color: #333; margin-bottom: 14px; display: flex; align-items: center; gap: 10px; }

.config-form { display: flex; flex-direction: column; gap: 12px; }
.config-row { display: flex; gap: 14px; align-items: flex-end; }
.config-item { display: flex; flex-direction: column; gap: 6px; flex: 1; }
.config-item label { font-size: 13px; color: #555; font-weight: 500; }
.select-input {
  padding: 10px 14px; border: 1.5px solid #e0e0e0; border-radius: 8px;
  font-size: 14px; outline: none; background: white;
}

.btn-primary {
  padding: 11px 24px; background: linear-gradient(135deg, #4a90d9, #357abd);
  color: white; border: none; border-radius: 8px; cursor: pointer;
  font-size: 14px; transition: all 0.2s; white-space: nowrap;
}
.btn-primary:hover:not(:disabled) { box-shadow: 0 4px 12px rgba(74,144,217,0.3); transform: translateY(-1px); }
.btn-primary:disabled { opacity: 0.5; cursor: not-allowed; }

.error-box {
  background: #fff2f0; border: 1px solid #ffccc7; color: #cf1322;
  padding: 12px 16px; border-radius: 8px; margin-bottom: 16px; font-size: 14px;
}

.badge {
  font-size: 12px; background: #e8f5e9; color: #2e7d32;
  padding: 2px 10px; border-radius: 12px; font-weight: normal;
}

.selection-info { margin-bottom: 12px; }
.sel-item { font-size: 12px; color: #666; margin-bottom: 3px; }

.seq-tags { display: flex; flex-wrap: wrap; gap: 6px; margin-bottom: 10px; }
.seq-tag {
  font-size: 12px; background: #f0f7ff; border: 1px solid #d0e3f7;
  padding: 4px 10px; border-radius: 4px; color: #2c6fad; font-family: monospace;
}
.method-info { font-size: 13px; color: #666; }

.viz-tabs { display: flex; gap: 4px; margin-bottom: 16px; background: #f0f0f0; border-radius: 10px; padding: 4px; }
.vtab {
  flex: 1; padding: 10px 16px; border: none; background: transparent;
  border-radius: 8px; cursor: pointer; font-size: 14px; transition: all 0.2s; color: #666;
}
.vtab.active { background: white; box-shadow: 0 2px 6px rgba(0,0,0,0.08); font-weight: 600; color: #1a5276; }

.viz-card { padding: 16px; }
.chart-container { width: 100%; height: 480px; }
.tree-chart { height: 560px; }
</style>
