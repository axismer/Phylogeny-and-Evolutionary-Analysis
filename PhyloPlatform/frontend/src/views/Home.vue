<template>
  <div class="home-page">
    <div class="page-header">
      <h1>🧬 系统发育分析平台</h1>
      <p>基于 16S rRNA 基因序列的细菌进化关系分析工具</p>
    </div>

    <div class="stats-grid">
      <div class="stat-card">
        <div class="stat-icon">📂</div>
        <div class="stat-info">
          <span class="stat-value">{{ datasets.length }}</span>
          <span class="stat-label">数据集</span>
        </div>
      </div>
      <div class="stat-card">
        <div class="stat-icon">🧪</div>
        <div class="stat-info">
          <span class="stat-value">{{ totalSpecies }}</span>
          <span class="stat-label">物种数</span>
        </div>
      </div>
      <div class="stat-card">
        <div class="stat-icon">🌳</div>
        <div class="stat-info">
          <span class="stat-value">2</span>
          <span class="stat-label">建树方法</span>
        </div>
      </div>
      <div class="stat-card">
        <div class="stat-icon">📊</div>
        <div class="stat-info">
          <span class="stat-value">3</span>
          <span class="stat-label">可视化方式</span>
        </div>
      </div>
    </div>

    <div class="quick-actions">
      <h3>快速操作</h3>
      <div class="action-grid">
        <router-link to="/data" class="action-card">
          <span class="action-icon">📤</span>
          <span class="action-title">上传数据</span>
          <span class="action-desc">上传 FASTA 序列文件到数据集</span>
        </router-link>
        <router-link to="/ncbi" class="action-card">
          <span class="action-icon">📥</span>
          <span class="action-title">NCBI 下载</span>
          <span class="action-desc">从 NCBI 数据库下载 16S 序列</span>
        </router-link>
        <router-link to="/analysis" class="action-card">
          <span class="action-icon">🔬</span>
          <span class="action-title">开始分析</span>
          <span class="action-desc">构建系统发育树与距离矩阵</span>
        </router-link>
      </div>
    </div>

    <div class="workflow-section">
      <h3>分析流程</h3>
      <div class="workflow-steps">
        <div class="step"><span class="step-num">1</span><span>上传/下载序列数据</span></div>
        <div class="step-arrow">→</div>
        <div class="step"><span class="step-num">2</span><span>选择最优序列</span></div>
        <div class="step-arrow">→</div>
        <div class="step"><span class="step-num">3</span><span>计算距离矩阵</span></div>
        <div class="step-arrow">→</div>
        <div class="step"><span class="step-num">4</span><span>构建进化树</span></div>
        <div class="step-arrow">→</div>
        <div class="step"><span class="step-num">5</span><span>可视化展示</span></div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { getDatasets } from '../api'

const datasets = ref([])
const totalSpecies = ref(0)

onMounted(async () => {
  try {
    const res = await getDatasets()
    datasets.value = res.data
  } catch (e) { /* ignore */ }
})
</script>

<style scoped>
.home-page { max-width: 1000px; }
.page-header { margin-bottom: 32px; }
.page-header h1 { font-size: 26px; color: #1a2332; margin-bottom: 6px; }
.page-header p { color: #666; font-size: 14px; }

.stats-grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: 16px; margin-bottom: 32px; }
.stat-card {
  background: white; border-radius: 12px; padding: 20px;
  display: flex; align-items: center; gap: 14px;
  box-shadow: 0 2px 8px rgba(0,0,0,0.04); border: 1px solid #eef2f7;
}
.stat-icon { font-size: 28px; }
.stat-value { font-size: 24px; font-weight: 700; color: #1a2332; display: block; }
.stat-label { font-size: 12px; color: #888; }

.quick-actions { margin-bottom: 32px; }
.quick-actions h3, .workflow-section h3 { font-size: 16px; color: #333; margin-bottom: 14px; }
.action-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 16px; }
.action-card {
  background: white; border-radius: 12px; padding: 24px 20px;
  display: flex; flex-direction: column; gap: 8px;
  text-decoration: none; border: 1px solid #eef2f7;
  transition: all 0.3s; box-shadow: 0 2px 8px rgba(0,0,0,0.04);
}
.action-card:hover { transform: translateY(-3px); box-shadow: 0 8px 24px rgba(0,0,0,0.08); border-color: #4a90d9; }
.action-icon { font-size: 28px; }
.action-title { font-size: 15px; font-weight: 600; color: #1a2332; }
.action-desc { font-size: 12px; color: #888; }

.workflow-section { background: white; border-radius: 12px; padding: 24px; border: 1px solid #eef2f7; }
.workflow-steps { display: flex; align-items: center; gap: 8px; flex-wrap: wrap; }
.step {
  display: flex; align-items: center; gap: 8px;
  background: #f0f7ff; padding: 10px 16px; border-radius: 8px; font-size: 13px; color: #2c5282;
}
.step-num {
  width: 22px; height: 22px; border-radius: 50%;
  background: #4a90d9; color: white; display: flex;
  align-items: center; justify-content: center; font-size: 11px; font-weight: 700;
}
.step-arrow { color: #ccc; font-size: 18px; }

@media (max-width: 768px) {
  .stats-grid { grid-template-columns: repeat(2, 1fr); }
  .action-grid { grid-template-columns: 1fr; }
}
</style>
