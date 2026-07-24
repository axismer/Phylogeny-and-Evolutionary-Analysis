<template>
  <div class="data-page">
    <div class="page-header">
      <h1>📂 数据管理</h1>
      <p>管理数据集、上传 FASTA 序列文件</p>
    </div>

    <!-- 创建数据集 -->
    <div class="card create-section">
      <h3>创建数据集</h3>
      <div class="create-form">
        <input v-model="newDataset.name" placeholder="数据集名称" class="input" />
        <input v-model="newDataset.description" placeholder="描述（可选）" class="input" />
        <button class="btn-primary" @click="handleCreateDataset" :disabled="!newDataset.name">创建</button>
      </div>
    </div>

    <!-- 数据集列表 -->
    <div class="card">
      <h3>我的数据集</h3>
      <div v-if="datasets.length === 0" class="empty-state">暂无数据集，请先创建</div>
      <div v-else class="dataset-list">
        <div v-for="ds in datasets" :key="ds.did" class="dataset-item"
             :class="{ selected: selectedDataset?.did === ds.did }"
             @click="selectDataset(ds)">
          <div class="ds-info">
            <span class="ds-name">{{ ds.dname }}</span>
            <span class="ds-meta">{{ ds.source === 'ncbi' ? 'NCBI' : '本地上传' }} · {{ ds.dstatus }}</span>
          </div>
          <button class="btn-danger-sm" @click.stop="handleDelete(ds.did)">删除</button>
        </div>
      </div>
    </div>

    <!-- 上传文件 -->
    <div v-if="selectedDataset" class="card">
      <h3>上传序列到「{{ selectedDataset.dname }}」</h3>

      <!-- 拖拽/点击选择多文件 -->
      <div class="batch-upload-area" @click="triggerFileInput" @dragover.prevent @drop.prevent="handleDrop">
        <input type="file" accept=".fasta,.fa,.fas,.txt" multiple @change="handleFileSelect" ref="fileInput" hidden />
        <div v-if="selectedFiles.length === 0" class="upload-placeholder">
          <p class="upload-icon">📁</p>
          <p>点击或拖拽上传 FASTA 文件（支持多选）</p>
          <p class="hint">支持 .fasta / .fa / .fas / .txt 格式，可同时选择多个文件</p>
        </div>
        <div v-else class="selected-count">
          ✅ 已选择 {{ selectedFiles.length }} 个文件
        </div>
      </div>

      <!-- 已选文件列表 -->
      <div v-if="selectedFiles.length > 0" class="file-list">
        <div class="file-list-header">
          <span>文件名</span>
          <span>物种名称（可选，默认用文件名）</span>
          <button class="btn-text-danger" @click="clearFiles">清空全部</button>
        </div>
        <div v-for="(f, idx) in selectedFiles" :key="idx" class="file-row">
          <span class="file-name">📄 {{ f.file.name }}</span>
          <input v-model="f.speciesName" :placeholder="f.file.name.replace(/\.[^.]+$/, '')" class="input-sm" />
          <button class="btn-remove" @click="removeFile(idx)">✕</button>
        </div>
        <button class="btn-primary batch-btn" @click="handleBatchUpload" :disabled="uploading">
          {{ uploading ? `上传中 (${uploadProgress}/${selectedFiles.length})...` : `🚀 批量上传 (${selectedFiles.length} 个文件)` }}
        </button>
      </div>

      <!-- 上传结果 -->
      <div v-if="uploadResults.length > 0" class="upload-results">
        <h4>上传结果：成功 {{ uploadSuccessCount }} / 失败 {{ uploadFailCount }}</h4>
        <div v-for="(r, i) in uploadResults" :key="i" :class="['result-item', r.success ? 'ok' : 'fail']">
          <span>{{ r.success ? '✅' : '❌' }}</span>
          <span>{{ r.fileName }}</span>
          <span v-if="r.success" class="r-detail">→ {{ r.speciesName }} ({{ r.sequenceCount }} 条序列)</span>
          <span v-else class="r-detail">{{ r.error }}</span>
        </div>
      </div>

      <!-- 物种列表 -->
      <div v-if="speciesList.length > 0" class="species-section">
        <h4>已上传物种 ({{ speciesList.length }})</h4>
        <div class="species-grid">
          <div v-for="sp in speciesList" :key="sp.sid" class="species-card">
            <div class="sp-name">{{ sp.sname }}</div>
            <div class="sp-meta">{{ sp.sequenceCount }} 条序列</div>
            <div class="sp-seqs">
              <span v-for="seq in sp.sequences?.slice(0, 3)" :key="seq.seid" class="seq-tag">
                {{ seq.accession || seq.name?.substring(0, 20) }} ({{ seq.length }}bp)
              </span>
              <span v-if="sp.sequenceCount > 3" class="seq-tag more">+{{ sp.sequenceCount - 3 }}</span>
            </div>
          </div>
        </div>
      </div>
    </div>

    <div v-if="message" :class="['toast', messageType]">{{ message }}</div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { createDataset, getDatasets, batchUploadFasta, getDatasetSpecies, deleteDataset } from '../api'

const datasets = ref([])
const selectedDataset = ref(null)
const speciesList = ref([])
const newDataset = ref({ name: '', description: '' })
const selectedFiles = ref([])
const uploading = ref(false)
const uploadProgress = ref(0)
const uploadResults = ref([])
const uploadSuccessCount = ref(0)
const uploadFailCount = ref(0)
const fileInput = ref(null)
const message = ref('')
const messageType = ref('success')

onMounted(loadDatasets)

async function loadDatasets() {
  try {
    const res = await getDatasets()
    datasets.value = res.data
  } catch (e) { /* ignore */ }
}

async function handleCreateDataset() {
  try {
    await createDataset(newDataset.value.name, newDataset.value.description)
    newDataset.value = { name: '', description: '' }
    showToast('数据集创建成功')
    await loadDatasets()
  } catch (e) {
    showToast(e.response?.data?.error || '创建失败', 'error')
  }
}

async function selectDataset(ds) {
  selectedDataset.value = ds
  uploadResults.value = []
  try {
    const res = await getDatasetSpecies(ds.did)
    speciesList.value = res.data
  } catch (e) {
    speciesList.value = []
  }
}

function triggerFileInput() {
  fileInput.value.click()
}

function handleFileSelect(e) {
  const files = Array.from(e.target.files || [])
  files.forEach(f => {
    selectedFiles.value.push({ file: f, speciesName: '' })
  })
  e.target.value = ''
}

function handleDrop(e) {
  const files = Array.from(e.dataTransfer.files || [])
  files.forEach(f => {
    selectedFiles.value.push({ file: f, speciesName: '' })
  })
}

function removeFile(idx) {
  selectedFiles.value.splice(idx, 1)
}

function clearFiles() {
  selectedFiles.value = []
}

async function handleBatchUpload() {
  if (selectedFiles.value.length === 0 || !selectedDataset.value) return
  uploading.value = true
  uploadProgress.value = 0
  uploadResults.value = []
  uploadSuccessCount.value = 0
  uploadFailCount.value = 0

  const files = selectedFiles.value.map(f => f.file)
  const names = selectedFiles.value.map(f => f.speciesName || f.file.name.replace(/\.[^.]+$/, ''))

  try {
    const res = await batchUploadFasta(files, selectedDataset.value.did, names)
    const data = res.data
    uploadResults.value = data.results || []
    uploadSuccessCount.value = data.successCount || 0
    uploadFailCount.value = data.failCount || 0
    uploadProgress.value = files.length
    showToast(`批量上传完成：成功 ${data.successCount}，失败 ${data.failCount}`)
    selectedFiles.value = []
    await selectDataset(selectedDataset.value)
  } catch (e) {
    showToast(e.response?.data?.error || '批量上传失败', 'error')
  } finally {
    uploading.value = false
  }
}

async function handleDelete(did) {
  if (!confirm('确定删除此数据集？')) return
  try {
    await deleteDataset(did)
    showToast('删除成功')
    selectedDataset.value = null
    speciesList.value = []
    await loadDatasets()
  } catch (e) {
    showToast(e.response?.data?.error || '删除失败', 'error')
  }
}

function showToast(msg, type = 'success') {
  message.value = msg
  messageType.value = type
  setTimeout(() => { message.value = '' }, 3000)
}
</script>

<style scoped>
.data-page { max-width: 900px; }
.page-header { margin-bottom: 24px; }
.page-header h1 { font-size: 24px; color: #1a2332; margin-bottom: 4px; }
.page-header p { color: #666; font-size: 14px; }

.card {
  background: white; border-radius: 12px; padding: 24px;
  margin-bottom: 20px; border: 1px solid #eef2f7;
  box-shadow: 0 2px 8px rgba(0,0,0,0.03);
}
.card h3 { font-size: 16px; color: #333; margin-bottom: 14px; }
.card h4 { font-size: 14px; color: #555; margin: 16px 0 10px; }

.create-form { display: flex; gap: 10px; }
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
  padding: 10px 16px; border: 1.5px solid #4a90d9; color: #4a90d9;
  border-radius: 8px; cursor: pointer; font-size: 13px; display: inline-block;
  transition: all 0.2s; white-space: nowrap;
}
.btn-outline:hover { background: #f0f7ff; }

.btn-danger-sm {
  padding: 5px 12px; background: none; border: 1px solid #e0e0e0;
  color: #999; border-radius: 6px; cursor: pointer; font-size: 12px; transition: all 0.2s;
}
.btn-danger-sm:hover { border-color: #e74c3c; color: #e74c3c; }

.empty-state { text-align: center; color: #999; padding: 30px; font-size: 14px; }

.dataset-list { display: flex; flex-direction: column; gap: 8px; }
.dataset-item {
  display: flex; align-items: center; justify-content: space-between;
  padding: 14px 16px; border: 1.5px solid #eee; border-radius: 10px;
  cursor: pointer; transition: all 0.2s;
}
.dataset-item:hover { border-color: #4a90d9; background: #f8fbff; }
.dataset-item.selected { border-color: #4a90d9; background: #f0f7ff; }
.ds-name { font-weight: 600; font-size: 14px; color: #333; }
.ds-meta { font-size: 12px; color: #999; margin-left: 10px; }

.upload-form { margin-bottom: 10px; }
.upload-row { display: flex; gap: 10px; align-items: center; }
.file-label { cursor: pointer; }

.batch-upload-area {
  border: 2px dashed #ccc; border-radius: 12px; padding: 28px;
  text-align: center; cursor: pointer; transition: all 0.3s;
  background: #fafafa; margin-bottom: 16px;
}
.batch-upload-area:hover { border-color: #4a90d9; background: #f0f7ff; }
.upload-placeholder .upload-icon { font-size: 28px; margin-bottom: 6px; }
.upload-placeholder p { margin: 4px 0; font-size: 14px; color: #555; }
.upload-placeholder .hint { font-size: 12px; color: #999; }
.selected-count { font-size: 15px; font-weight: 600; color: #27ae60; }

.file-list { margin-bottom: 16px; }
.file-list-header {
  display: grid; grid-template-columns: 1fr 1fr auto;
  gap: 10px; padding: 8px 0; font-size: 12px; color: #888;
  border-bottom: 1px solid #eee; margin-bottom: 8px; align-items: center;
}
.file-row {
  display: grid; grid-template-columns: 1fr 1fr auto;
  gap: 10px; align-items: center; padding: 6px 0;
}
.file-name { font-size: 13px; color: #333; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.input-sm {
  padding: 7px 10px; border: 1.5px solid #e0e0e0; border-radius: 6px;
  font-size: 13px; outline: none; transition: border-color 0.3s; width: 100%;
}
.input-sm:focus { border-color: #4a90d9; }
.btn-remove {
  background: none; border: none; color: #ccc; cursor: pointer;
  font-size: 16px; padding: 4px 8px; transition: color 0.2s;
}
.btn-remove:hover { color: #e74c3c; }
.btn-text-danger {
  background: none; border: none; color: #e74c3c; cursor: pointer;
  font-size: 12px; padding: 2px 6px;
}
.btn-text-danger:hover { text-decoration: underline; }
.batch-btn { width: 100%; margin-top: 12px; padding: 12px; font-size: 15px; }

.upload-results { margin-top: 16px; }
.upload-results h4 { font-size: 14px; color: #333; margin-bottom: 10px; }
.result-item {
  display: flex; align-items: center; gap: 8px; padding: 8px 12px;
  border-radius: 6px; font-size: 13px; margin-bottom: 4px;
}
.result-item.ok { background: #f6ffed; }
.result-item.fail { background: #fff2f0; }
.r-detail { color: #666; font-size: 12px; }

.species-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(250px, 1fr)); gap: 12px; }
.species-card {
  border: 1px solid #eee; border-radius: 10px; padding: 14px;
  transition: all 0.2s;
}
.species-card:hover { border-color: #4a90d9; }
.sp-name { font-weight: 600; font-size: 14px; color: #1a2332; margin-bottom: 4px; }
.sp-meta { font-size: 12px; color: #888; margin-bottom: 8px; }
.sp-seqs { display: flex; flex-wrap: wrap; gap: 4px; }
.seq-tag {
  font-size: 11px; background: #f0f7ff; border: 1px solid #d0e3f7;
  padding: 2px 8px; border-radius: 4px; color: #2c6fad;
}
.seq-tag.more { background: #f5f5f5; border-color: #ddd; color: #666; }

.toast {
  position: fixed; bottom: 30px; right: 30px; padding: 12px 24px;
  border-radius: 8px; font-size: 14px; color: white; z-index: 999;
  animation: slideIn 0.3s ease;
}
.toast.success { background: #27ae60; }
.toast.error { background: #e74c3c; }
@keyframes slideIn { from { transform: translateY(20px); opacity: 0; } to { transform: translateY(0); opacity: 1; } }
</style>
