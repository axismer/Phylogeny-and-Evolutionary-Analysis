import axios from 'axios'

// 创建 axios 实例
const api = axios.create({
  baseURL: '/api',
  timeout: 60000
})

// 请求拦截器：自动添加Token
api.interceptors.request.use(config => {
  const token = localStorage.getItem('token')
  if (token) {
    config.headers.Authorization = `Bearer ${token}`
  }
  return config
})

// ===== 用户认证接口 =====

/**
 * 用户登录
 * @param {string} username - 用户名
 * @param {string} password - 密码
 * @returns {Promise}
 */
export function login(username, password) {
  return api.post('/auth/login', { username, password })
}

/**
 * 用户注册
 * @param {string} username - 用户名
 * @param {string} password - 密码
 * @param {string} email - 邮箱（可选）
 * @returns {Promise}
 */
export function register(username, password, email = '') {
  return api.post('/auth/register', { username, password, email })
}

/**
 * 验证Token有效性
 * @returns {Promise}
 */
export function verifyToken() {
  return api.get('/auth/verify')
}

/**
 * 退出登录
 * @returns {Promise}
 */
export function logout() {
  return api.post('/auth/logout')
}

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
 * 获取数据库中的默认序列数据列表
 * @returns {Promise} 序列数据列表
 */
export function getDefaultSequences() {
  return api.get('/sequences/default')
}

/**
 * 获取所有序列数据列表（默认 + 用户）
 * @returns {Promise} 序列数据列表
 */
export function getAllSequences() {
  return api.get('/sequences')
}

/**
 * 使用数据库中的单个序列数据执行分析
 * @param {number} id - 序列数据ID
 * @param {string} method - 建树方法
 * @returns {Promise} 分析结果
 */
export function analyzeFromDb(id, method = 'upgma') {
  return api.post('/analyze-db', { id, method })
}

/**
 * 使用多个数据库序列数据合并后执行分析
 * @param {number[]} ids - 序列数据ID列表
 * @param {string} method - 建树方法
 * @returns {Promise} 分析结果
 */
export function analyzeFromDbMulti(ids, method = 'upgma') {
  return api.post('/analyze-db-multi', { ids, method })
}

/**
 * 保存用户上传的序列数据到数据库
 * @param {string} name - 数据集名称
 * @param {string} fasta - FASTA内容
 * @param {string} fileName - 文件名
 * @returns {Promise}
 */
export function saveUserSequence(name, fasta, fileName = 'user_input') {
  return api.post('/sequences/save', { name, fasta, fileName })
}

/**
 * 获取当前用户保存的序列数据列表
 * @returns {Promise}
 */
export function getMySequences() {
  return api.get('/sequences/mine')
}

/**
 * 健康检查
 */
export function healthCheck() {
  return api.get('/health')
}

export default api

