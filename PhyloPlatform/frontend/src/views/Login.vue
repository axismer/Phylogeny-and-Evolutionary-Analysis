<template>
  <div class="login-page">
    <div class="login-container">
      <div class="login-left">
        <div class="brand">
          <div class="logo-icon">🧬</div>
          <h1>PhyloPlatform</h1>
          <p class="tagline">系统发育分析平台</p>
          <p class="desc">基于 16S rRNA 序列的细菌进化关系分析<br/>支持 UPGMA / Neighbor-Joining 建树</p>
        </div>
        <div class="features">
          <div class="feature-item"><span>📊</span> 距离矩阵热图可视化</div>
          <div class="feature-item"><span>🌳</span> 环形系统发育树</div>
          <div class="feature-item"><span>🔬</span> PCoA 主坐标分析</div>
          <div class="feature-item"><span>📥</span> NCBI 数据在线下载</div>
        </div>
      </div>
      <div class="login-right">
        <div class="form-card">
          <div class="form-tabs">
            <button :class="['ftab', { active: mode === 'login' }]" @click="mode = 'login'">登录</button>
            <button :class="['ftab', { active: mode === 'register' }]" @click="mode = 'register'">注册</button>
          </div>

          <div v-if="error" class="form-error">{{ error }}</div>
          <div v-if="success" class="form-success">{{ success }}</div>

          <!-- 登录表单 -->
          <form v-if="mode === 'login'" @submit.prevent="handleLogin" class="form-body">
            <div class="input-group">
              <label>用户名</label>
              <input v-model="loginForm.uname" type="text" placeholder="请输入用户名" required />
            </div>
            <div class="input-group">
              <label>密码</label>
              <input v-model="loginForm.upassword" type="password" placeholder="请输入密码" required />
            </div>
            <button type="submit" class="submit-btn" :disabled="loading">
              {{ loading ? '登录中...' : '登 录' }}
            </button>
          </form>

          <!-- 注册表单 -->
          <form v-else @submit.prevent="handleRegister" class="form-body">
            <div class="input-group">
              <label>用户名</label>
              <input v-model="regForm.uname" type="text" placeholder="4-20位字符" required />
            </div>
            <div class="input-group">
              <label>昵称</label>
              <input v-model="regForm.nickname" type="text" placeholder="显示名称（可选）" />
            </div>
            <div class="input-group">
              <label>邮箱</label>
              <input v-model="regForm.email" type="email" placeholder="邮箱地址（可选）" />
            </div>
            <div class="input-group">
              <label>密码</label>
              <input v-model="regForm.upassword" type="password" placeholder="至少4位" required />
            </div>
            <button type="submit" class="submit-btn" :disabled="loading">
              {{ loading ? '注册中...' : '注 册' }}
            </button>
          </form>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '../stores/auth'

const router = useRouter()
const authStore = useAuthStore()

const mode = ref('login')
const loading = ref(false)
const error = ref('')
const success = ref('')

const loginForm = ref({ uname: '', upassword: '' })
const regForm = ref({ uname: '', nickname: '', email: '', upassword: '' })

async function handleLogin() {
  error.value = ''
  loading.value = true
  try {
    await authStore.login(loginForm.value.uname, loginForm.value.upassword)
    router.push('/')
  } catch (e) {
    error.value = e.response?.data?.error || '登录失败，请检查网络连接'
  } finally {
    loading.value = false
  }
}

async function handleRegister() {
  error.value = ''
  success.value = ''
  loading.value = true
  try {
    await authStore.register(regForm.value.uname, regForm.value.upassword, regForm.value.nickname, regForm.value.email)
    success.value = '注册成功，请登录'
    mode.value = 'login'
    loginForm.value.uname = regForm.value.uname
  } catch (e) {
    error.value = e.response?.data?.error || '注册失败'
  } finally {
    loading.value = false
  }
}
</script>

<style scoped>
.login-page {
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  background: linear-gradient(135deg, #0f2027 0%, #203a43 50%, #2c5364 100%);
  padding: 20px;
}
.login-container {
  display: flex;
  max-width: 960px;
  width: 100%;
  border-radius: 20px;
  overflow: hidden;
  box-shadow: 0 25px 60px rgba(0,0,0,0.3);
}
.login-left {
  flex: 1;
  background: linear-gradient(160deg, #1a5276, #148f77);
  padding: 50px 40px;
  color: white;
  display: flex;
  flex-direction: column;
  justify-content: center;
}
.logo-icon { font-size: 48px; margin-bottom: 12px; }
.brand h1 { font-size: 28px; margin-bottom: 6px; }
.tagline { font-size: 16px; opacity: 0.9; margin-bottom: 12px; }
.desc { font-size: 13px; opacity: 0.7; line-height: 1.8; }
.features { margin-top: 32px; display: flex; flex-direction: column; gap: 12px; }
.feature-item {
  display: flex; align-items: center; gap: 10px;
  font-size: 14px; opacity: 0.85;
  background: rgba(255,255,255,0.1); padding: 10px 14px; border-radius: 8px;
}
.login-right {
  flex: 1;
  background: #fff;
  padding: 50px 40px;
  display: flex;
  align-items: center;
  justify-content: center;
}
.form-card { width: 100%; max-width: 340px; }
.form-tabs { display: flex; gap: 0; margin-bottom: 28px; border-bottom: 2px solid #eee; }
.ftab {
  flex: 1; padding: 12px; border: none; background: none;
  font-size: 16px; cursor: pointer; color: #999;
  border-bottom: 2px solid transparent; margin-bottom: -2px; transition: all 0.3s;
}
.ftab.active { color: #1a5276; border-bottom-color: #1a5276; font-weight: 600; }
.form-error {
  background: #fff2f0; border: 1px solid #ffccc7; color: #cf1322;
  padding: 10px 14px; border-radius: 6px; margin-bottom: 16px; font-size: 13px;
}
.form-success {
  background: #f6ffed; border: 1px solid #b7eb8f; color: #389e0d;
  padding: 10px 14px; border-radius: 6px; margin-bottom: 16px; font-size: 13px;
}
.form-body { display: flex; flex-direction: column; gap: 18px; }
.input-group { display: flex; flex-direction: column; gap: 6px; }
.input-group label { font-size: 13px; color: #555; font-weight: 500; }
.input-group input {
  padding: 12px 14px; border: 1.5px solid #e0e0e0; border-radius: 8px;
  font-size: 14px; transition: border-color 0.3s; outline: none;
}
.input-group input:focus { border-color: #1a5276; }
.submit-btn {
  padding: 13px; background: linear-gradient(135deg, #1a5276, #148f77);
  color: white; border: none; border-radius: 8px; font-size: 15px;
  cursor: pointer; transition: all 0.3s; margin-top: 6px;
}
.submit-btn:hover:not(:disabled) { transform: translateY(-1px); box-shadow: 0 6px 20px rgba(26,82,118,0.3); }
.submit-btn:disabled { opacity: 0.6; cursor: not-allowed; }

@media (max-width: 768px) {
  .login-container { flex-direction: column; }
  .login-left { padding: 30px; }
  .features { display: none; }
}
</style>
