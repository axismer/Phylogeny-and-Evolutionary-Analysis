<template>
  <div class="file-uploader">
    <!-- 输入模式切换 -->
    <div class="mode-tabs">
      <button :class="['tab', { active: mode === 'file' }]" @click="mode = 'file'">
        📂 文件上传
      </button>
      <button :class="['tab', { active: mode === 'text' }]" @click="mode = 'text'">
        ✏️ 文本输入
      </button>
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
    <div v-else class="text-input-area">
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
    <button
      class="analyze-btn"
      :disabled="!canAnalyze || loading"
      @click="startAnalysis"
    >
      <span v-if="loading" class="spinner"></span>
      {{ loading ? '分析中...' : '🚀 开始分析' }}
    </button>
  </div>
</template>

<script setup>
import { ref, computed } from 'vue'

const emit = defineEmits(['analyze'])

const mode = ref('file')
const fileInput = ref(null)
const selectedFile = ref(null)
const fastaText = ref('')
const method = ref('upgma')
const loading = ref(false)

const canAnalyze = computed(() => {
  if (mode.value === 'file') return !!selectedFile.value
  return fastaText.value.trim().length > 0
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
    mode: mode.value,
    method: method.value,
    file: mode.value === 'file' ? selectedFile.value : null,
    text: mode.value === 'text' ? fastaText.value : null
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
</style>
