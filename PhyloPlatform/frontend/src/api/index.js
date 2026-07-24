import axios from 'axios'

const api = axios.create({
  baseURL: '/api',
  timeout: 120000
})

// 请求拦截器 - 添加JWT Token
api.interceptors.request.use(config => {
  const token = localStorage.getItem('phylo_token')
  if (token) {
    config.headers.Authorization = `Bearer ${token}`
  }
  return config
})

// 响应拦截器 - 处理401
api.interceptors.response.use(
  response => response,
  error => {
    if (error.response && error.response.status === 401) {
      localStorage.removeItem('phylo_token')
      localStorage.removeItem('phylo_user')
      window.location.href = '/login'
    }
    return Promise.reject(error)
  }
)

// ===== 认证接口 =====
export function login(uname, upassword) {
  return api.post('/auth/login', { uname, upassword })
}
export function register(data) {
  return api.post('/auth/register', data)
}
export function getUserInfo() {
  return api.get('/auth/info')
}

// ===== 数据管理接口 =====
export function createDataset(name, description) {
  return api.post('/data/dataset', { name, description })
}
export function getDatasets() {
  return api.get('/data/datasets')
}
export function uploadFasta(file, did, speciesName) {
  const formData = new FormData()
  formData.append('file', file)
  formData.append('did', did)
  if (speciesName) formData.append('speciesName', speciesName)
  return api.post('/data/upload', formData, {
    headers: { 'Content-Type': 'multipart/form-data' }
  })
}
export function batchUploadFasta(files, did, speciesNames) {
  const formData = new FormData()
  files.forEach(f => formData.append('files', f))
  formData.append('did', did)
  if (speciesNames && speciesNames.length > 0) {
    formData.append('speciesNames', speciesNames.join(','))
  }
  return api.post('/data/batch-upload', formData, {
    headers: { 'Content-Type': 'multipart/form-data' },
    timeout: 300000
  })
}
export function getDatasetSpecies(did) {
  return api.get(`/data/dataset/${did}/species`)
}
export function deleteDataset(did) {
  return api.delete(`/data/dataset/${did}`)
}

// ===== NCBI 接口 =====
export function ncbiSearch(term, retMax = 10) {
  return api.get('/ncbi/search', { params: { term, retMax } })
}
export function ncbiDownload(did, accession, speciesName) {
  return api.post('/ncbi/download', { did, accession, speciesName })
}
export function ncbiBatchDownload(did, accessions, speciesName) {
  return api.post('/ncbi/batch-download', { did, accessions, speciesName })
}

// ===== 分析接口 =====
export function analyzeFasta(file, method = 'nj') {
  const formData = new FormData()
  formData.append('file', file)
  return api.post(`/analyze?method=${method}`, formData, {
    headers: { 'Content-Type': 'multipart/form-data' }
  })
}
export function analyzeFastaText(fasta, method = 'nj') {
  return api.post('/analyze-text', { fasta, method })
}
export function analyzeDataset(did, method = 'nj') {
  return api.post('/analyze-dataset', { did, method })
}

// ===== 健康检查 =====
export function healthCheck() {
  return api.get('/health')
}

export default api
