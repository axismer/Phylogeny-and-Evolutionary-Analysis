<template>
  <div class="ncbi-page">
    <div class="page-header">
      <h1>📥 NCBI 数据下载</h1>
      <p>从 NCBI 核酸数据库搜索并下载 16S rRNA 序列</p>
    </div>

    <!-- 选择目标数据集 -->
    <div class="card">
      <h3>目标数据集</h3>
      <div class="dataset-select">
        <select v-model="selectedDid" class="select-input">
          <option value="">请选择数据集</option>
          <option v-for="ds in datasets" :key="ds.did" :value="ds.did">{{ ds.dname }}</option>
        </select>
        <router-link to="/data" class="link-btn">+ 新建数据集</router-link>
      </div>
    </div>

    <!-- 搜索区域 -->
    <div class="card">
      <h3>搜索 NCBI Nucleotide</h3>
      <div class="search-form">
        <input v-model="searchTerm" placeholder="输入搜索词，如: Escherichia coli 16S ribosomal RNA" class="input" @keyup.enter="handleSearch" />
        <button class="btn-primary" @click="handleSearch" :disabled="searching || !searchTerm">
          {{ searching ? '搜索中...' : '搜索' }}
        </button>
      </div>
      <div v-if="searchResult" class="search-result">
        <p class="result-info">找到 {{ searchResult.count || 0 }} 条结果（显示前 {{ searchResult.ids?.length || 0 }} 条 ID）</p>
        <div class="id-list">
          <span v-for="id in searchResult.ids" :key="id" class="id-tag" @click="addToDownload(id)">{{ id }}</span>
        </div>
      </div>
    </div>

    <!-- 直接下载 -->
    <div class="card">
      <h3>按 Accession 号下载</h3>
      <div class="download-form">
        <div class="form-row">
          <input v-model="accession" placeholder="Accession号（如 NR_114042.1）" class="input" />
          <input v-model="dlSpeciesName" placeholder="物种名称（可选）" class="input" />
          <button class="btn-primary" @click="handleDownload" :disabled="downloading || !accession || !selectedDid">
            {{ downloading ? '下载中...' : '下载' }}
          </button>
        </div>
        <p class="hint">支持批量下载：多个 accession 用逗号或换行分隔</p>
        <textarea v-model="batchAccessions" placeholder="批量输入，每行一个 accession&#10;NR_114042.1&#10;NR_112558.1&#10;NR_024570.1" class="batch-input" rows="4"></textarea>
        <button class="btn-outline" @click="handleBatchDownload" :disabled="downloading || !batchAccessions || !selectedDid">
          {{ downloading ? '批量下载中...' : '批量下载' }}
        </button>
      </div>
    </div>

    <!-- 下载结果 -->
    <div v-if="downloadResults.length > 0" class="card">
      <h3>下载结果</h3>
      <div class="result-list">
        <div v-for="(r, i) in downloadResults" :key="i" :class="['result-item', r.success ? 'ok' : 'fail']">
          <span class="r-icon">{{ r.success ? '✅' : '❌' }}</span>
          <span class="r-text">{{ r.success ? `${r.accession} - ${r.length}bp` : `${r.accession}: ${r.error}` }}</span>
        </div>
      </div>
    </div>

    <div v-if="message" :class="['toast', messageType]">{{ message }}</div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { getDatasets, ncbiSearch, ncbiDownload, ncbiBatchDownload } from '../api'

const datasets = ref([])
const selectedDid = ref('')
const searchTerm = ref('')
const searching = ref(false)
const searchResult = ref(null)
const accession = ref('')
const dlSpeciesName = ref('')
const batchAccessions = ref('')
const downloading = ref(false)
const downloadResults = ref([])
const message = ref('')
const messageType = ref('success')

onMounted(async () => {
  try {
    const res = await getDatasets()
    datasets.value = res.data
  } catch (e) { /* ignore */ }
})

async function handleSearch() {
  if (!searchTerm.value) return
  searching.value = true
  searchResult.value = null
  try {
    const res = await ncbiSearch(searchTerm.value, 20)
    const data = res.data
    if (data.raw) {
      const parsed = JSON.parse(data.raw)
      searchResult.value = {
        count: parsed?.esearchresult?.count || 0,
        ids: parsed?.esearchresult?.idlist || []
      }
    }
  } catch (e) {
    showToast('搜索失败: ' + (e.response?.data?.error || e.message), 'error')
  } finally {
    searching.value = false
  }
}

function addToDownload(id) {
  accession.value = id
}

async function handleDownload() {
  if (!selectedDid.value || !accession.value) return
  downloading.value = true
  try {
    const res = await ncbiDownload(selectedDid.value, accession.value, dlSpeciesName.value)
    downloadResults.value.unshift(res.data)
    showToast('下载成功: ' + accession.value)
    accession.value = ''
  } catch (e) {
    downloadResults.value.unshift({ accession: accession.value, success: false, error: e.response?.data?.error || '下载失败' })
    showToast(e.response?.data?.error || '下载失败', 'error')
  } finally {
    downloading.value = false
  }
}

async function handleBatchDownload() {
  if (!selectedDid.value || !batchAccessions.value) return
  const accs = batchAccessions.value.split(/[\n,]+/).map(s => s.trim()).filter(Boolean)
  if (accs.length === 0) return
  downloading.value = true
  try {
    const res = await ncbiBatchDownload(selectedDid.value, accs, dlSpeciesName.value)
    downloadResults.value = [...res.data.results, ...downloadResults.value]
    showToast(`批量下载完成: ${accs.length} 条`)
    batchAccessions.value = ''
  } catch (e) {
    showToast('批量下载失败', 'error')
  } finally {
    downloading.value = false
  }
}

function showToast(msg, type = 'success') {
  message.value = msg
  messageType.value = type
  setTimeout(() => { message.value = '' }, 3000)
}
</script>

<style scoped>
.ncbi-page { max-width: 900px; }
.page-header { margin-bottom: 24px; }
.page-header h1 { font-size: 24px; color: #1a2332; margin-bottom: 4px; }
.page-header p { color: #666; font-size: 14px; }

.card {
  background: white; border-radius: 12px; padding: 24px;
  margin-bottom: 20px; border: 1px solid #eef2f7;
  box-shadow: 0 2px 8px rgba(0,0,0,0.03);
}
.card h3 { font-size: 16px; color: #333; margin-bottom: 14px; }

.dataset-select { display: flex; gap: 12px; align-items: center; }
.select-input {
  flex: 1; padding: 10px 14px; border: 1.5px solid #e0e0e0;
  border-radius: 8px; font-size: 14px; outline: none;
}
.link-btn { font-size: 13px; color: #4a90d9; text-decoration: none; white-space: nowrap; }
.link-btn:hover { text-decoration: underline; }

.search-form { display: flex; gap: 10px; }
.input {
  flex: 1; padding: 10px 14px; border: 1.5px solid #e0e0e0;
  border-radius: 8px; font-size: 14px; outline: none; transition: border-color 0.3s;
}
.input:focus { border-color: #4a90d9; }

.btn-primary {
  padding: 10px 20px; background: linear-gradient(135deg, #4a90d9, #357abd);
  color: white; border: none; border-radius: 8px; cursor: pointer;
  font-size: 14px; transition: all 0.2s; white-space: nowrap;
}
.btn-primary:hover:not(:disabled) { box-shadow: 0 4px 12px rgba(74,144,217,0.3); }
.btn-primary:disabled { opacity: 0.5; cursor: not-allowed; }

.btn-outline {
  padding: 10px 20px; border: 1.5px solid #4a90d9; color: #4a90d9;
  background: none; border-radius: 8px; cursor: pointer; font-size: 14px;
  transition: all 0.2s; margin-top: 10px;
}
.btn-outline:hover:not(:disabled) { background: #f0f7ff; }
.btn-outline:disabled { opacity: 0.5; cursor: not-allowed; }

.search-result { margin-top: 14px; }
.result-info { font-size: 13px; color: #666; margin-bottom: 8px; }
.id-list { display: flex; flex-wrap: wrap; gap: 6px; }
.id-tag {
  font-size: 12px; background: #f0f7ff; border: 1px solid #d0e3f7;
  padding: 4px 10px; border-radius: 4px; color: #2c6fad; cursor: pointer;
  transition: all 0.2s;
}
.id-tag:hover { background: #4a90d9; color: white; }

.download-form { display: flex; flex-direction: column; gap: 10px; }
.form-row { display: flex; gap: 10px; }
.hint { font-size: 12px; color: #999; }
.batch-input {
  width: 100%; padding: 10px 14px; border: 1.5px solid #e0e0e0;
  border-radius: 8px; font-size: 13px; font-family: monospace;
  resize: vertical; outline: none;
}
.batch-input:focus { border-color: #4a90d9; }

.result-list { display: flex; flex-direction: column; gap: 6px; }
.result-item { display: flex; align-items: center; gap: 8px; padding: 8px 12px; border-radius: 6px; font-size: 13px; }
.result-item.ok { background: #f6ffed; }
.result-item.fail { background: #fff2f0; }
.r-text { color: #333; }

.toast {
  position: fixed; bottom: 30px; right: 30px; padding: 12px 24px;
  border-radius: 8px; font-size: 14px; color: white; z-index: 999;
}
.toast.success { background: #27ae60; }
.toast.error { background: #e74c3c; }
</style>
