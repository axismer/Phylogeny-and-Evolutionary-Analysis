<script setup>
import { ref } from 'vue'
import { runAnalysis, fetchMatrix, fetchTree } from './api/analysis.js'
import DistanceMatrixTable from './components/DistanceMatrixTable.vue'
import PhylogeneticTreeView from './components/PhylogeneticTreeView.vue'

const loading = ref(false)
const error = ref('')
const statusMessage = ref('')
const labels = ref([])
const values = ref([])
const newick = ref('')

async function startAnalysis() {
  loading.value = true
  error.value = ''
  statusMessage.value = '正在运行分析…'
  try {
    const runResult = await runAnalysis()
    statusMessage.value = runResult?.message || 'analysis completed'

    const [matrix, tree] = await Promise.all([fetchMatrix(), fetchTree()])
    labels.value = matrix.labels || []
    values.value = matrix.values || []
    newick.value = tree.newick || ''
    statusMessage.value = '分析完成'
  } catch (err) {
    const detail = err.response?.data?.detail || err.response?.data?.error || err.message
    error.value = detail || '请求失败，请确认后端已在 8080 端口运行'
    statusMessage.value = ''
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <div class="page">
    <header class="hero">
      <h1 class="brand">系统发育分析与进化树展示平台</h1>
      <p class="lead">基于 16S 序列计算 p-distance，并用 UPGMA 构建系统发育树。</p>
      <button class="cta" type="button" :disabled="loading" @click="startAnalysis">
        {{ loading ? '分析中…' : '开始分析' }}
      </button>
      <p v-if="statusMessage" class="status ok">{{ statusMessage }}</p>
      <p v-if="error" class="status err">{{ error }}</p>
    </header>

    <section class="section" v-if="labels.length">
      <h2>距离矩阵</h2>
      <DistanceMatrixTable :labels="labels" :values="values" />
    </section>

    <section class="section" v-if="newick">
      <h2>系统发育树</h2>
      <PhylogeneticTreeView :newick="newick" />
    </section>
  </div>
</template>
