import axios from 'axios'

// 创建 axios 实例
const api = axios.create({
  baseURL: '/api',
  timeout: 60000
})

/**
 * 上传FASTA文件并执行系统发育分析
 * @param {File} file - FASTA文件
 * @param {string} method - 建树方法: 'upgma' 或 'nj'
 * @returns {Promise} 分析结果
 */
export function analyzeFasta(file, method = 'upgma') {
  const formData = new FormData()
  formData.append('file', file)

  return api.post(`/analyze?method=${method}`, formData, {
    headers: {
      'Content-Type': 'multipart/form-data'
    }
  })
}

/**
 * 直接提交FASTA文本执行系统发育分析
 * @param {string} fasta - FASTA格式的序列文本
 * @param {string} method - 建树方法: 'upgma' 或 'nj'
 * @returns {Promise} 分析结果
 */
export function analyzeFastaText(fasta, method = 'upgma') {
  return api.post('/analyze-text', { fasta, method })
}

/**
 * 健康检查
 */
export function healthCheck() {
  return api.get('/health')
}

export default api
