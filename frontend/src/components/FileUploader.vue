<template>
  <div class="file-uploader">
    <!-- 输入模式切换 -->
    <div class="mode-tabs">
      <button :class="['tab', { active: mode === 'database' }]" @click="switchMode('database')">
        🗄️ 数据库数据
      </button>
      <button :class="['tab', { active: mode === 'mine' }]" @click="switchMode('mine')">
        📌 我的序列
      </button>
      <button :class="['tab', { active: mode === 'file' }]" @click="mode = 'file'">
        📂 文件上传
      </button>
      <button :class="['tab', { active: mode === 'text' }]" @click="mode = 'text'">
        ✏️ 文本输入
      </button>
    </div>

    <!-- 数据库数据选择模式 -->
    <div v-if="mode === 'database'" class="database-area">
      <div v-if="dbLoading" class="db-loading">加载中...</div>
      <div v-else-if="dbSequences.length === 0" class="db-empty">
        暂无默认数据，请先启动后端服务导入数据
      </div>
      <div v-else class="db-list">
        <p class="db-hint">选择数据集进行分析（可多选合并分析）：</p>
        <div class="db-items">
          <label
            v-for="item in dbSequences"
            :key="item.id"
            :class="['db-item', { selected: selectedDbIds.includes(item.id) }]"
          >
            <input
              type="checkbox"
              :value="item.id"
              v-model="selectedDbIds"
            />
            <div class="db-item-info">
              <span class="db-item-name">{{ item.name }}</span>
              <span class="db-item-desc">{{ item.sequenceCount }} 条序列 | {{ item.source === 'DEFAULT' ? '系统默认' : '用户上传' }}</span>
            </div>
          </label>
        </div>
      </div>
    </div>

    <!-- 我的序列模式 -->
    <div v-if="mode === 'mine'" class="database-area">
      <div v-if="myLoading" class="db-loading">加载中...</div>
      <div v-else-if="mySequences.length === 0" class="db-empty">
        暂无保存的序列，请在“文本输入”或“文件上传”后点击“💾 保存序列”
      </div>
      <div v-else class="db-list">
        <p class="db-hint">我保存的序列数据（可多选合并分析）：</p>
        <div class="db-items">
          <label
            v-for="item in mySequences"
            :key="item.id"
            :class="['db-item', { selected: selectedMyIds.includes(item.id) }]"
          >
            <input
              type="checkbox"
              :value="item.id"
              v-model="selectedMyIds"
            />
            <div class="db-item-info">
              <span class="db-item-name">{{ item.name }}</span>
              <span class="db-item-desc">{{ item.sequenceCount }} 条序列 | {{ item.createdAt }}</span>
            </div>
          </label>
        </div>
      </div>
    </div>

    <!-- 文件上传模式 -->
    <div v-if="mode === 'file'" class="upload-area" @click="triggerFileInput" @dragover.prevent @drop.prevent="handleDrop">
      <input
        ref="fileInput"
        type="file"
        accept=".fasta,.fa,.fas,.txt"
        @change="handleFileSelect"
        style="display: none"
      />
      <div v-if="!selectedFile" class="upload-placeholder">
        <p class="upload-icon">📁</p>
        <p>点击或拖拽上传 FASTA 文件</p>
        <p class="hint">支持 .fasta / .fa / .fas / .txt 格式</p>
      </div>
      <div v-else class="file-info">
        <p>✅ {{ selectedFile.name }}</p>
        <p class="hint">{{ (selectedFile.size / 1024).toFixed(1) }} KB</p>
        <button class="clear-btn" @click.stop="selectedFile = null">✕ 移除</button>
      </div>
    </div>

    <!-- 文本输入模式 -->
    <div v-if="mode === 'text'" class="text-input-area">
      <textarea
        v-model="fastaText"
        class="fasta-textarea"
        placeholder="在此粘贴 FASTA 格式序列，例如：&#10;>Species_A&#10;ATCGATCGATCG&#10;>Species_B&#10;ATGGATCGATCG&#10;>Species_C&#10;ATCGATGGATCG"
        rows="8"
      ></textarea>
      <button class="sample-btn" @click="loadSample">📋 加载示例数据</button>
    </div>

    <!-- 建树方法选择 -->
    <div class="method-select">
      <span class="method-label">建树方法：</span>
      <label class="radio-item">
        <input type="radio" v-model="method" value="upgma" />
        <span>UPGMA</span>
      </label>
      <label class="radio-item">
        <input type="radio" v-model="method" value="nj" />
        <span>Neighbor-Joining (NJ)</span>
      </label>
    </div>

    <!-- 分析按钮 -->
    <div class="action-buttons">
      <button
        class="analyze-btn"
        :disabled="!canAnalyze || loading"
        @click="startAnalysis"
      >
        <span v-if="loading" class="spinner"></span>
        {{ loading ? '分析中...' : '🚀 开始分析' }}
      </button>
      <button
        v-if="mode === 'text' || mode === 'file'"
        class="save-btn"
        :disabled="!canSave || saving"
        @click="saveSequence"
      >
        {{ saving ? '保存中...' : '💾 保存序列' }}
      </button>
    </div>

    <!-- 保存提示 -->
    <div v-if="saveMsg" :class="['save-msg', saveMsgType]">{{ saveMsg }}</div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { getDefaultSequences, getMySequences, saveUserSequence } from '../api'

const emit = defineEmits(['analyze'])

const mode = ref('database')
const fileInput = ref(null)
const selectedFile = ref(null)
const fastaText = ref('')
const method = ref('upgma')
const loading = ref(false)

// 数据库相关
const dbSequences = ref([])
const selectedDbIds = ref([])
const dbLoading = ref(false)

// 我的序列相关
const mySequences = ref([])
const selectedMyIds = ref([])
const myLoading = ref(false)

// 保存相关
const saving = ref(false)
const saveMsg = ref('')
const saveMsgType = ref('success')

const canAnalyze = computed(() => {
  if (mode.value === 'file') return !!selectedFile.value
  if (mode.value === 'text') return fastaText.value.trim().length > 0
  if (mode.value === 'database') return selectedDbIds.value.length > 0
  if (mode.value === 'mine') return selectedMyIds.value.length > 0
  return false
})

const canSave = computed(() => {
  if (mode.value === 'text') return fastaText.value.trim().length > 0
  if (mode.value === 'file') return !!selectedFile.value
  return false
})

// 加载数据库默认数据
async function loadDbSequences() {
  dbLoading.value = true
  try {
    const res = await getDefaultSequences()
    dbSequences.value = res.data
  } catch (e) {
    console.warn('加载默认数据失败', e)
    dbSequences.value = []
  } finally {
    dbLoading.value = false
  }
}

function switchMode(newMode) {
  mode.value = newMode
  if (newMode === 'database' && dbSequences.value.length === 0) {
    loadDbSequences()
  }
  if (newMode === 'mine') {
    loadMySequences()
  }
}

// 加载我的序列
async function loadMySequences() {
  myLoading.value = true
  try {
    const res = await getMySequences()
    mySequences.value = res.data
  } catch (e) {
    console.warn('加载我的序列失败', e)
    mySequences.value = []
  } finally {
    myLoading.value = false
  }
}

// 保存序列到数据库
async function saveSequence() {
  let fasta = ''
  let fileName = 'user_input'

  if (mode.value === 'text') {
    fasta = fastaText.value
  } else if (mode.value === 'file' && selectedFile.value) {
    fasta = await selectedFile.value.text()
    fileName = selectedFile.value.name
  }

  if (!fasta.trim()) return

  const name = prompt('请输入数据集名称：', fileName.replace(/\.[^.]+$/, ''))
  if (!name) return

  saving.value = true
  saveMsg.value = ''
  try {
    await saveUserSequence(name, fasta, fileName)
    saveMsg.value = '✅ 保存成功！'
    saveMsgType.value = 'success'
    loadMySequences()
  } catch (e) {
    saveMsg.value = '❌ 保存失败: ' + (e.response?.data?.error || e.message)
    saveMsgType.value = 'error'
  } finally {
    saving.value = false
    setTimeout(() => { saveMsg.value = '' }, 3000)
  }
}

onMounted(() => {
  loadDbSequences()
})

const SAMPLE_FASTA = `>Human
ATGGCACATGCAGCGCAAGTAGGTCTACAAGACGCTACTTCCCCTATCATAGAAGAGCTTATCACCTTTCATGATCACGCCCTCATAATCATTTTCCTTATCTGCTTCCTAGTCCTGTATGCCCTTTTCCTAACACTCACAACAAAACTAACTAATACTAACATCTCAGACGCTCAGGAAATAGAAACCGTCTGAACTATCCTGCCCGCCATCATCCTAGTCCTCATCGCCCTCCCATCCCTACGCATCCTTTACATAACAGACGAGGTCAACGATCCCTCCCTTACCATCAAATCAATTGGCCACCAATGGTACTGAACCTACGAGTACACCGACTACGGCGGACTAATCTTCAACTCCTACATACTTCCCCCATTATTCCTAGAACCAGGCGACCTGCGACTCCTTGACGTTGACAATCGAGTAGTACTCCCGATTGAAGCCCCCATTCGTATAATAATTACATCACAAGACGTCTTGCACTCATGAGCTGTCCCCACATTAGGCTTAAAAACAGATGCAATTCCCGGACGTCTAAACCAAACCACTTTCACCGCTACACGACCGGGGGTATACTACGGTCAATGCTCTGAAATCTGTGGAGCAAACCACAGTTTCATGCCCATCGTCCTAGAATTAATTCCCCTAAAAATCTTTGAAATAGGGCCCGTATTTACCCTATAG
>Chimpanzee
ATGGCACATGCAGCGCAAGTAGGTCTACAAGACGCTACTTCCCCTATCATAGAAGAGCTTATCACCTTTCATGATCACGCCCTCATAATCATTTTCCTTATCTGCTTCCTAGTCCTGTATGCCCTTTTCCTAACACTCACAACAAAACTAACTAATACTAACATCTCAGACGCTCAGGAAATAGAAACCGTCTGAACTATCCTGCCCGCCATCATCCTAGTCCTCATCGCCCTCCCATCCCTACGCATCCTTTACATAACAGACGAGGTCAACGATCCCTCCCTTACCATCAAATCAATTGGCCACCAATGGTACTGAACCTACGAGTACACCGACTACGGCGGACTAATCTTCAACTCCTACATACTTCCCCCATTATTCCTAGAACCAGGCGACCTGCGACTCCTTGACGTTGACAATCGAGTAGTACTCCCGATTGAAGCCCCCATTCGTATAATAATTACATCACAAGACGTCTTGCACTCATGAGCTGTCCCCACATTAGGCTTAAAAACAGATGCAATTCCCGGACGTCTAAACCAAACCACTTTCACCGCTACACGACCGGGGGTATACTACGGTCAATGCTCTGAAATCTGTGGAGCAAACCACAGTTTCATGCCCATCGTCCTAGAATTAATTCCCCTAAAAATCTTTGAAATAGGGCCCGTATTTACCCTATAG
>Gorilla
ATGGCACATGCAGCGCAAGTAGGTCTACAAGACGCTACTTCCCCTATCATAGAAGAGCTTATCACCTTTCATGATCACGCCCTCATAATCATTTTCCTTATCTGCTTCCTAGTCCTGTATGCCCTTTTCCTAACACTCACAACAAAACTAACTAATACTAACATCTCAGACGCTCAGGAAATAGAAACCGTCTGAACTATCCTGCCCGCCATCATCCTAGTCCTCATCGCCCTCCCATCCCTACGCATCCTTTACATAACAGACGAGGTCAACGATCCCTCCCTTACCATCAAATCAATTGGCCACCAATGGTACTGAACCTACGAGTACACCGACTACGGCGGACTAATCTTCAACTCCTACATACTTCCCCCATTATTCCTAGAACCAGGCGACCTGCGACTCCTTGACGTTGACAATCGAGTAGTACTCCCGATTGAAGCCCCCATTCGTATAATAATTACATCACAAGACGTCTTGCACTCATGAGCTGTCCCCACATTAGGCTTAAAAACAGATGCAATTCCCGGACGTCTAAACCAAACCACTTTCACCGCTACACGACCGGGGGTATACTACGGTCAATGCTCTGAAATCTGTGGAGCAAACCACAGTTTCATGCCCATCGTCCTAGAATTAATTCCCCTAAAAATCTTTGAAATAGGGCCCGTATTTACCCTATAG
>Orangutan
ATGGCACATGCAGCGCAAGTAGGTCTACAAGACGCTACTTCCCCTATCATAGAAGAGCTTATCACCTTTCATGATCACGCCCTCATAATCATTTTCCTTATCTGCTTCCTAGTCCTGTATGCCCTTTTCCTAACACTCACAACAAAACTAACTAATACTAACATCTCAGACGCTCAGGAAATAGAAACCGTCTGAACTATCCTGCCCGCCATCATCCTAGTCCTCATCGCCCTCCCATCCCTACGCATCCTTTACATAACAGACGAGGTCAACGATCCCTCCCTTACCATCAAATCAATTGGCCACCAATGGTACTGAACCTACGAGTACACCGACTACGGCGGACTAATCTTCAACTCCTACATACTTCCCCCATTATTCCTAGAACCAGGCGACCTGCGACTCCTTGACGTTGACAATCGAGTAGTACTCCCGATTGAAGCCCCCATTCGTATAATAATTACATCACAAGACGTCTTGCACTCATGAGCTGTCCCCACATTAGGCTTAAAAACAGATGCAATTCCCGGACGTCTAAACCAAACCACTTTCACCGCTACACGACCGGGGGTATACTACGGTCAATGCTCTGAAATCTGTGGAGCAAACCACAGTTTCATGCCCATCGTCCTAGAATTAATTCCCCTAAAAATCTTTGAAATAGGGCCCGTATTTACCCTATAG
>Gibbon
ATGGCACATGCAGCGCAAGTAGGTCTACAAGACGCTACTTCCCCTATCATAGAAGAGCTTATCACCTTTCATGATCACGCCCTCATAATCATTTTCCTTATCTGCTTCCTAGTCCTGTATGCCCTTTTCCTAACACTCACAACAAAACTAACTAATACTAACATCTCAGACGCTCAGGAAATAGAAACCGTCTGAACTATCCTGCCCGCCATCATCCTAGTCCTCATCGCCCTCCCATCCCTACGCATCCTTTACATAACAGACGAGGTCAACGATCCCTCCCTTACCATCAAATCAATTGGCCACCAATGGTACTGAACCTACGAGTACACCGACTACGGCGGACTAATCTTCAACTCCTACATACTTCCCCCATTATTCCTAGAACCAGGCGACCTGCGACTCCTTGACGTTGACAATCGAGTAGTACTCCCGATTGAAGCCCCCATTCGTATAATAATTACATCACAAGACGTCTTGCACTCATGAGCTGTCCCCACATTAGGCTTAAAAACAGATGCAATTCCCGGACGTCTAAACCAAACCACTTTCACCGCTACACGACCGGGGGTATACTACGGTCAATGCTCTGAAATCTGTGGAGCAAACCACAGTTTCATGCCCATCGTCCTAGAATTAATTCCCCTAAAAATCTTTGAAATAGGGCCCGTATTTACCCTATAG`

function loadSample() {
  fastaText.value = SAMPLE_FASTA
  mode.value = 'text'
}

function triggerFileInput() {
  fileInput.value.click()
}

function handleFileSelect(event) {
  const file = event.target.files[0]
  if (file) {
    selectedFile.value = file
  }
}

function handleDrop(event) {
  const file = event.dataTransfer.files[0]
  if (file) {
    selectedFile.value = file
  }
}

function startAnalysis() {
  if (!canAnalyze.value) return
  loading.value = true

  const payload = {
    mode: mode.value === 'mine' ? 'database' : mode.value,
    method: method.value,
    file: mode.value === 'file' ? selectedFile.value : null,
    text: mode.value === 'text' ? fastaText.value : null,
    dbIds: mode.value === 'database' ? selectedDbIds.value :
           mode.value === 'mine' ? selectedMyIds.value : null
  }

  emit('analyze', payload, () => {
    loading.value = false
  })
}
</script>

<style scoped>
.file-uploader {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 16px;
}

.mode-tabs {
  display: flex;
  gap: 4px;
  background: #f0f0f0;
  border-radius: 8px;
  padding: 4px;
}

.tab {
  padding: 8px 20px;
  border: none;
  background: transparent;
  border-radius: 6px;
  cursor: pointer;
  font-size: 14px;
  transition: all 0.2s;
}

.tab.active {
  background: white;
  box-shadow: 0 1px 3px rgba(0,0,0,0.1);
  font-weight: 600;
}

.upload-area {
  width: 100%;
  max-width: 500px;
  padding: 32px;
  border: 2px dashed #ccc;
  border-radius: 12px;
  text-align: center;
  cursor: pointer;
  transition: all 0.3s;
  background: #fafafa;
}

.upload-area:hover {
  border-color: #4a90d9;
  background: #f0f7ff;
}

.upload-icon {
  font-size: 32px;
  margin-bottom: 8px;
}

.hint {
  font-size: 12px;
  color: #999;
  margin-top: 4px;
}

.file-info {
  position: relative;
}

.clear-btn {
  margin-top: 8px;
  padding: 4px 12px;
  border: 1px solid #e0e0e0;
  background: white;
  border-radius: 4px;
  cursor: pointer;
  font-size: 12px;
  color: #666;
}

.clear-btn:hover {
  border-color: #e74c3c;
  color: #e74c3c;
}

.text-input-area {
  width: 100%;
  max-width: 500px;
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.fasta-textarea {
  width: 100%;
  padding: 12px;
  border: 2px solid #e0e0e0;
  border-radius: 8px;
  font-family: 'Courier New', monospace;
  font-size: 13px;
  resize: vertical;
  transition: border-color 0.3s;
  line-height: 1.5;
}

.fasta-textarea:focus {
  outline: none;
  border-color: #4a90d9;
}

.sample-btn {
  align-self: flex-start;
  padding: 6px 14px;
  border: 1px solid #4a90d9;
  background: #f0f7ff;
  color: #4a90d9;
  border-radius: 6px;
  cursor: pointer;
  font-size: 13px;
  transition: all 0.2s;
}

.sample-btn:hover {
  background: #4a90d9;
  color: white;
}

.method-select {
  display: flex;
  align-items: center;
  gap: 16px;
  font-size: 14px;
}

.method-label {
  color: #555;
  font-weight: 500;
}

.radio-item {
  display: flex;
  align-items: center;
  gap: 4px;
  cursor: pointer;
}

.radio-item input {
  cursor: pointer;
}

.analyze-btn {
  padding: 12px 36px;
  background: linear-gradient(135deg, #4a90d9, #357abd);
  color: white;
  border: none;
  border-radius: 8px;
  font-size: 16px;
  cursor: pointer;
  transition: all 0.3s;
  display: flex;
  align-items: center;
  gap: 8px;
}

.analyze-btn:hover:not(:disabled) {
  transform: translateY(-1px);
  box-shadow: 0 4px 12px rgba(74, 144, 217, 0.4);
}

.analyze-btn:disabled {
  background: #ccc;
  cursor: not-allowed;
  transform: none;
  box-shadow: none;
}

.action-buttons {
  display: flex;
  gap: 12px;
  align-items: center;
}

.save-btn {
  padding: 12px 24px;
  background: white;
  color: #27ae60;
  border: 2px solid #27ae60;
  border-radius: 8px;
  font-size: 15px;
  cursor: pointer;
  transition: all 0.3s;
}

.save-btn:hover:not(:disabled) {
  background: #27ae60;
  color: white;
}

.save-btn:disabled {
  border-color: #ccc;
  color: #ccc;
  cursor: not-allowed;
}

.save-msg {
  font-size: 13px;
  padding: 8px 14px;
  border-radius: 6px;
}

.save-msg.success {
  background: #eafaf1;
  color: #27ae60;
}

.save-msg.error {
  background: #fff3f3;
  color: #e74c3c;
}

.spinner {
  width: 16px;
  height: 16px;
  border: 2px solid rgba(255,255,255,0.3);
  border-top-color: white;
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

/* 数据库选择区域样式 */
.database-area {
  width: 100%;
  max-width: 600px;
}

.db-loading, .db-empty {
  text-align: center;
  padding: 24px;
  color: #999;
  font-size: 14px;
}

.db-hint {
  font-size: 13px;
  color: #666;
  margin-bottom: 12px;
}

.db-items {
  display: flex;
  flex-direction: column;
  gap: 8px;
  max-height: 300px;
  overflow-y: auto;
  padding-right: 4px;
}

.db-item {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 10px 14px;
  border: 1px solid #e0e0e0;
  border-radius: 8px;
  cursor: pointer;
  transition: all 0.2s;
  background: #fafafa;
}

.db-item:hover {
  border-color: #4a90d9;
  background: #f0f7ff;
}

.db-item.selected {
  border-color: #4a90d9;
  background: #e8f2fc;
  box-shadow: 0 0 0 1px #4a90d9;
}

.db-item input[type="checkbox"] {
  width: 16px;
  height: 16px;
  cursor: pointer;
}

.db-item-info {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.db-item-name {
  font-size: 14px;
  font-weight: 500;
  color: #333;
}

.db-item-desc {
  font-size: 12px;
  color: #888;
}
</style>
