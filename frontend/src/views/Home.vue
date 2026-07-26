<template>
  <div class="home">
    <!-- 顶部用户栏 -->
    <div class="user-bar">
      <span class="user-info">👤 {{ username }}</span>
      <button class="logout-btn" @click="handleLogout">退出登录</button>
    </div>

    <header class="header">
      <h1>🧬 系统发育分析平台</h1>
      <p class="subtitle">上传 FASTA 文件 → 计算距离矩阵 → 构建系统发育树</p>
    </header>

    <section class="upload-section">
      <FileUploader @analyze="handleAnalyze" />
    </section>

    <!-- 错误提示 -->
    <div v-if="error" class="error-box">
      ⚠️ {{ error }}
    </div>

    <!-- 分析结果 -->
    <section v-if="result" class="result-section">
      <!-- 序列信息 -->
      <div class="seq-info card">
        <h3>📊 序列信息</h3>
        <p>共 <strong>{{ result.sequences.length }}</strong> 条序列，
           长度 <strong>{{ result.sequences[0]?.length }}</strong> bp，
           建树方法：<strong>{{ result.method }}</strong></p>
        <div class="seq-list">
          <span v-for="seq in result.sequences" :key="seq.name" class="seq-tag">
            {{ seq.name }} ({{ seq.length }})
          </span>
        </div>
      </div>

      <MatrixTable :matrix="result.distanceMatrix" />
      <TreeViewer :newick="result.tree" :method="result.method" :circular-tree-image="result.circularTreeImage" />
    </section>

    <footer class="footer">
      <p>PhyloPlatform · 支持 UPGMA / Neighbor-Joining 建树 · p-distance 距离计算</p>
    </footer>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import FileUploader from '../components/FileUploader.vue'
import MatrixTable from '../components/MatrixTable.vue'
import TreeViewer from '../components/TreeViewer.vue'
import { analyzeFasta, analyzeFastaText, analyzeFromDb, analyzeFromDbMulti, logout } from '../api'
import { analyzeFromNcbi, analyzeFromNcbiMulti } from '../api'

const router = useRouter()
const result = ref(null)
const error = ref('')
const username = ref(localStorage.getItem('username') || '用户')

async function handleLogout() {
  try {
    await logout()
  } catch (e) {
    // 忽略退出接口错误
  }
  localStorage.removeItem('token')
  localStorage.removeItem('username')
  localStorage.removeItem('email')
  router.push('/login')
}

async function handleAnalyze(payload, doneCallback) {
  console.log('=== 开始分析 ===', payload)
  error.value = ''
  result.value = null

  try {
    let response
    if (payload.mode === 'file') {
      response = await analyzeFasta(payload.file, payload.method)
    } else if (payload.mode === 'text') {
      response = await analyzeFastaText(payload.text, payload.method)
    } else if (payload.mode === 'database') {
      // 数据库模式：单个或合并分析
      if (payload.dbIds.length === 1) {
        response = await analyzeFromDb(payload.dbIds[0], payload.method)
      } else {
        response = await analyzeFromDbMulti(payload.dbIds, payload.method)
      }
    } else if (payload.mode === 'ncbi') {
      // NCBI 模式：根据 useMulti 选择单个或多个下载
      console.log('执行 NCBI 分析...', payload.accessions, payload.method, payload.useMulti)
      if (payload.useMulti && payload.accessions.length > 1) {
        response = await analyzeFromNcbiMulti(payload.accessions, payload.method)
      } else {
        // 单个序列（即使 accessions 是数组）
        response = await analyzeFromNcbi(payload.accessions[0], payload.method)
      }
      console.log('NCBI 响应:', response)
      console.log('response.data:', response.data)
      console.log('tree value:', response.data?.tree)
    }
    console.log('获取到的结果:', response.data)
    result.value = response.data
  } catch (err) {
    console.error('分析错误:', err)
    if (err.response && err.response.data && err.response.data.error) {
      error.value = err.response.data.error
    } else if (err.message) {
      error.value = '请求失败：' + err.message
    } else {
      error.value = '请求失败，请确认后端服务已启动（端口 8080）'
    }
  } finally {
    console.log('完成分析回调')
    doneCallback()
  }
}
</script>

<style scoped>
.home {
  max-width: 900px;
  margin: 0 auto;
  padding: 40px 20px;
}

.user-bar {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: 12px;
  margin-bottom: 16px;
  padding: 10px 16px;
  background: white;
  border-radius: 10px;
  border: 1px solid #e8e8e8;
}

.user-info {
  font-size: 14px;
  color: #555;
  font-weight: 500;
}

.logout-btn {
  padding: 6px 14px;
  border: 1px solid #e0e0e0;
  background: white;
  border-radius: 6px;
  cursor: pointer;
  font-size: 13px;
  color: #666;
  transition: all 0.2s;
}

.logout-btn:hover {
  border-color: #e74c3c;
  color: #e74c3c;
  background: #fff5f5;
}

.header {
  text-align: center;
  margin-bottom: 32px;
}

.header h1 {
  font-size: 28px;
  color: #2c3e50;
}

.subtitle {
  color: #7f8c8d;
  margin-top: 8px;
}

.upload-section {
  margin-bottom: 24px;
}

.error-box {
  background: #fff3f3;
  border: 1px solid #ffcdd2;
  color: #c62828;
  padding: 12px 16px;
  border-radius: 8px;
  margin-bottom: 16px;
  font-size: 14px;
}

.result-section {
  margin-top: 24px;
}

.card {
  background: white;
  border: 1px solid #e8e8e8;
  border-radius: 10px;
  padding: 20px;
  margin-bottom: 20px;
}

.seq-info h3 {
  margin-bottom: 8px;
  color: #333;
}

.seq-info p {
  color: #555;
  font-size: 14px;
  margin-bottom: 12px;
}

.seq-list {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.seq-tag {
  background: #f0f7ff;
  border: 1px solid #d0e3f7;
  padding: 4px 10px;
  border-radius: 4px;
  font-size: 13px;
  color: #2c6fad;
  font-family: 'Courier New', monospace;
}

.footer {
  text-align: center;
  margin-top: 48px;
  padding-top: 20px;
  border-top: 1px solid #eee;
  color: #aaa;
  font-size: 13px;
}
</style>
