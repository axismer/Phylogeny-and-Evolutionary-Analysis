<template>
  <div class="login-page">
    <!-- 背景装饰 -->
    <div class="bg-decoration">
      <div class="bg-circle circle-1"></div>
      <div class="bg-circle circle-2"></div>
      <div class="bg-circle circle-3"></div>
    </div>

    <div class="login-container">
      <!-- 头像区域 -->
      <div class="avatar-wrapper">
        <div class="avatar-circle">
          <svg viewBox="0 0 24 24" fill="none" class="avatar-icon">
            <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 3c1.66 0 3 1.34 3 3s-1.34 3-3 3-3-1.34-3-3 1.34-3 3-3zm0 14.2c-2.5 0-4.71-1.28-6-3.22.03-1.99 4-3.08 6-3.08 1.99 0 5.97 1.09 6 3.08-1.29 1.94-3.5 3.22-6 3.22z" fill="currentColor"/>
          </svg>
        </div>
      </div>

      <!-- 主卡片 -->
      <div class="login-card">
        <!-- 标题 -->
        <div class="card-title">
          <h2>{{ isLogin ? '欢迎登录' : '注册账号' }}</h2>
          <p>系统发育分析平台 · PhyloPlatform</p>
        </div>

        <!-- 切换标签 -->
        <div class="form-tabs">
          <div class="tab-indicator" :class="{ right: !isLogin }"></div>
          <button :class="['form-tab', { active: isLogin }]" @click="isLogin = true">
            密码登录
          </button>
          <button :class="['form-tab', { active: !isLogin }]" @click="isLogin = false">
            注册账号
          </button>
        </div>

        <!-- 错误/成功提示 -->
        <transition name="fade">
          <div v-if="message" :class="['form-message', messageType]">
            <svg v-if="messageType === 'error'" viewBox="0 0 24 24" class="msg-icon">
              <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-2h2v2zm0-4h-2V7h2v6z" fill="currentColor"/>
            </svg>
            <svg v-else viewBox="0 0 24 24" class="msg-icon">
              <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z" fill="currentColor"/>
            </svg>
            {{ message }}
          </div>
        </transition>

        <!-- 登录表单 -->
        <form v-if="isLogin" @submit.prevent="handleLogin" class="auth-form">
          <div class="input-group">
            <div class="input-icon">
              <svg viewBox="0 0 24 24" fill="none">
                <path d="M12 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm0 2c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z" fill="currentColor"/>
              </svg>
            </div>
            <input
              v-model="loginForm.username"
              type="text"
              placeholder="请输入用户名"
              autocomplete="username"
            />
          </div>
          <div class="input-group">
            <div class="input-icon">
              <svg viewBox="0 0 24 24" fill="none">
                <path d="M18 8h-1V6c0-2.76-2.24-5-5-5S7 3.24 7 6v2H6c-1.1 0-2 .9-2 2v10c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2V10c0-1.1-.9-2-2-2zm-6 9c-1.1 0-2-.9-2-2s.9-2 2-2 2 .9 2 2-.9 2-2 2zm3.1-9H8.9V6c0-1.71 1.39-3.1 3.1-3.1 1.71 0 3.1 1.39 3.1 3.1v2z" fill="currentColor"/>
              </svg>
            </div>
            <input
              v-model="loginForm.password"
              type="password"
              placeholder="请输入密码"
              autocomplete="current-password"
            />
          </div>

          <div class="form-options">
            <label class="remember-me">
              <input type="checkbox" checked />
              <span>记住我</span>
            </label>
            <a href="javascript:void(0)" class="forgot-link">忘记密码？</a>
          </div>

          <button type="submit" class="submit-btn" :disabled="loading">
            <span v-if="loading" class="btn-spinner"></span>
            {{ loading ? '登录中...' : '登 录' }}
          </button>

          <div class="form-footer">
            <span>还没有账号？</span>
            <a href="javascript:void(0)" @click="isLogin = false">立即注册</a>
          </div>
        </form>

        <!-- 注册表单 -->
        <form v-else @submit.prevent="handleRegister" class="auth-form">
          <div class="input-group">
            <div class="input-icon">
              <svg viewBox="0 0 24 24" fill="none">
                <path d="M12 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm0 2c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z" fill="currentColor"/>
              </svg>
            </div>
            <input
              v-model="registerForm.username"
              type="text"
              placeholder="用户名（2-20个字符）"
              autocomplete="username"
            />
          </div>
          <div class="input-group">
            <div class="input-icon">
              <svg viewBox="0 0 24 24" fill="none">
                <path d="M20 4H4c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V6c0-1.1-.9-2-2-2zm0 4l-8 5-8-5V6l8 5 8-5v2z" fill="currentColor"/>
              </svg>
            </div>
            <input
              v-model="registerForm.email"
              type="email"
              placeholder="邮箱（选填）"
              autocomplete="email"
            />
          </div>
          <div class="input-group">
            <div class="input-icon">
              <svg viewBox="0 0 24 24" fill="none">
                <path d="M18 8h-1V6c0-2.76-2.24-5-5-5S7 3.24 7 6v2H6c-1.1 0-2 .9-2 2v10c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2V10c0-1.1-.9-2-2-2zm-6 9c-1.1 0-2-.9-2-2s.9-2 2-2 2 .9 2 2-.9 2-2 2zm3.1-9H8.9V6c0-1.71 1.39-3.1 3.1-3.1 1.71 0 3.1 1.39 3.1 3.1v2z" fill="currentColor"/>
              </svg>
            </div>
            <input
              v-model="registerForm.password"
              type="password"
              placeholder="密码（至少6位）"
              autocomplete="new-password"
            />
          </div>
          <div class="input-group">
            <div class="input-icon">
              <svg viewBox="0 0 24 24" fill="none">
                <path d="M18 8h-1V6c0-2.76-2.24-5-5-5S7 3.24 7 6v2H6c-1.1 0-2 .9-2 2v10c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2V10c0-1.1-.9-2-2-2zm-6 9c-1.1 0-2-.9-2-2s.9-2 2-2 2 .9 2 2-.9 2-2 2zm3.1-9H8.9V6c0-1.71 1.39-3.1 3.1-3.1 1.71 0 3.1 1.39 3.1 3.1v2z" fill="currentColor"/>
              </svg>
            </div>
            <input
              v-model="registerForm.confirmPassword"
              type="password"
              placeholder="确认密码"
              autocomplete="new-password"
            />
          </div>

          <button type="submit" class="submit-btn" :disabled="loading">
            <span v-if="loading" class="btn-spinner"></span>
            {{ loading ? '注册中...' : '注 册' }}
          </button>

          <div class="form-footer">
            <span>已有账号？</span>
            <a href="javascript:void(0)" @click="isLogin = true">返回登录</a>
          </div>
        </form>
      </div>

      <!-- 底部信息 -->
      <div class="login-footer">
        <p>支持 UPGMA / NJ 建树 · p-distance / k-mer 距离计算</p>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, reactive } from 'vue'
import { useRouter } from 'vue-router'
import { login, register } from '../api'

const router = useRouter()

const isLogin = ref(true)
const loading = ref(false)
const message = ref('')
const messageType = ref('error')

const loginForm = reactive({
  username: '',
  password: ''
})

const registerForm = reactive({
  username: '',
  email: '',
  password: '',
  confirmPassword: ''
})

async function handleLogin() {
  message.value = ''

  if (!loginForm.username.trim()) {
    message.value = '请输入用户名'
    messageType.value = 'error'
    return
  }
  if (!loginForm.password) {
    message.value = '请输入密码'
    messageType.value = 'error'
    return
  }

  loading.value = true
  try {
    const res = await login(loginForm.username.trim(), loginForm.password)
    localStorage.setItem('token', res.data.token)
    localStorage.setItem('username', res.data.username)
    localStorage.setItem('email', res.data.email || '')
    router.push('/')
  } catch (err) {
    message.value = err.response?.data?.error || '登录失败，请检查网络连接'
    messageType.value = 'error'
  } finally {
    loading.value = false
  }
}

async function handleRegister() {
  message.value = ''

  if (!registerForm.username.trim()) {
    message.value = '请输入用户名'
    messageType.value = 'error'
    return
  }
  if (registerForm.username.trim().length < 2) {
    message.value = '用户名至少2个字符'
    messageType.value = 'error'
    return
  }
  if (!registerForm.password) {
    message.value = '请输入密码'
    messageType.value = 'error'
    return
  }
  if (registerForm.password.length < 6) {
    message.value = '密码长度至少6位'
    messageType.value = 'error'
    return
  }
  if (registerForm.password !== registerForm.confirmPassword) {
    message.value = '两次输入的密码不一致'
    messageType.value = 'error'
    return
  }

  loading.value = true
  try {
    await register(registerForm.username.trim(), registerForm.password, registerForm.email.trim())
    message.value = '注册成功！请登录'
    messageType.value = 'success'
    isLogin.value = true
    loginForm.username = registerForm.username
    loginForm.password = ''
    registerForm.username = ''
    registerForm.email = ''
    registerForm.password = ''
    registerForm.confirmPassword = ''
  } catch (err) {
    message.value = err.response?.data?.error || '注册失败，请检查网络连接'
    messageType.value = 'error'
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
  padding: 20px;
  background: linear-gradient(180deg, #e8f4fd 0%, #f7fafc 40%, #ffffff 100%);
  position: relative;
  overflow: hidden;
}

/* 背景装饰圆 */
.bg-decoration {
  position: absolute;
  inset: 0;
  pointer-events: none;
}

.bg-circle {
  position: absolute;
  border-radius: 50%;
  opacity: 0.15;
}

.circle-1 {
  width: 400px;
  height: 400px;
  background: #12b7f5;
  top: -100px;
  right: -100px;
}

.circle-2 {
  width: 300px;
  height: 300px;
  background: #0d94d3;
  bottom: -80px;
  left: -80px;
}

.circle-3 {
  width: 200px;
  height: 200px;
  background: #5dd5fa;
  top: 50%;
  left: 10%;
}

.login-container {
  width: 100%;
  max-width: 400px;
  position: relative;
  z-index: 1;
}

/* 头像区域 */
.avatar-wrapper {
  display: flex;
  justify-content: center;
  margin-bottom: -40px;
  position: relative;
  z-index: 2;
}

.avatar-circle {
  width: 80px;
  height: 80px;
  border-radius: 50%;
  background: linear-gradient(135deg, #12b7f5, #0d94d3);
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: 0 8px 24px rgba(18, 183, 245, 0.35);
  border: 4px solid #fff;
}

.avatar-icon {
  width: 42px;
  height: 42px;
  color: white;
}

/* 主卡片 */
.login-card {
  background: white;
  border-radius: 16px;
  padding: 56px 36px 36px;
  box-shadow: 0 12px 40px rgba(0, 0, 0, 0.08), 0 2px 12px rgba(0, 0, 0, 0.04);
}

.card-title {
  text-align: center;
  margin-bottom: 28px;
}

.card-title h2 {
  font-size: 22px;
  font-weight: 600;
  color: #1a1a1a;
  margin: 0 0 6px;
}

.card-title p {
  font-size: 13px;
  color: #999;
  margin: 0;
}

/* 切换标签 */
.form-tabs {
  display: flex;
  position: relative;
  margin-bottom: 24px;
  background: #f5f7fa;
  border-radius: 8px;
  padding: 3px;
}

.tab-indicator {
  position: absolute;
  top: 3px;
  left: 3px;
  width: calc(50% - 3px);
  height: calc(100% - 6px);
  background: white;
  border-radius: 6px;
  box-shadow: 0 2px 6px rgba(0, 0, 0, 0.08);
  transition: transform 0.3s cubic-bezier(0.4, 0, 0.2, 1);
}

.tab-indicator.right {
  transform: translateX(100%);
}

.form-tab {
  flex: 1;
  padding: 10px;
  border: none;
  background: transparent;
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  transition: color 0.3s;
  color: #999;
  position: relative;
  z-index: 1;
}

.form-tab.active {
  color: #12b7f5;
}

/* 提示信息 */
.form-message {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 10px 14px;
  border-radius: 8px;
  font-size: 13px;
  margin-bottom: 16px;
}

.form-message.error {
  background: #fff2f0;
  border: 1px solid #ffccc7;
  color: #cf1322;
}

.form-message.success {
  background: #f0fff4;
  border: 1px solid #b7eb8f;
  color: #389e0d;
}

.msg-icon {
  width: 16px;
  height: 16px;
  flex-shrink: 0;
}

/* 表单 */
.auth-form {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.input-group {
  display: flex;
  align-items: center;
  background: #f5f7fa;
  border-radius: 8px;
  border: 2px solid transparent;
  transition: all 0.3s;
  overflow: hidden;
}

.input-group:focus-within {
  background: #fff;
  border-color: #12b7f5;
  box-shadow: 0 0 0 3px rgba(18, 183, 245, 0.1);
}

.input-icon {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 44px;
  flex-shrink: 0;
}

.input-icon svg {
  width: 20px;
  height: 20px;
  color: #bbb;
  transition: color 0.3s;
}

.input-group:focus-within .input-icon svg {
  color: #12b7f5;
}

.input-group input {
  flex: 1;
  padding: 13px 14px 13px 0;
  border: none;
  background: transparent;
  font-size: 14px;
  outline: none;
  color: #333;
}

.input-group input::placeholder {
  color: #bbb;
}

/* 选项行 */
.form-options {
  display: flex;
  align-items: center;
  justify-content: space-between;
  font-size: 13px;
}

.remember-me {
  display: flex;
  align-items: center;
  gap: 5px;
  color: #666;
  cursor: pointer;
}

.remember-me input[type="checkbox"] {
  width: 15px;
  height: 15px;
  accent-color: #12b7f5;
  cursor: pointer;
}

.forgot-link {
  color: #12b7f5;
  text-decoration: none;
}

.forgot-link:hover {
  text-decoration: underline;
}

/* 提交按钮 */
.submit-btn {
  margin-top: 4px;
  padding: 13px;
  background: linear-gradient(135deg, #12b7f5, #0d94d3);
  color: white;
  border: none;
  border-radius: 8px;
  font-size: 16px;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.3s;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  letter-spacing: 2px;
}

.submit-btn:hover:not(:disabled) {
  background: linear-gradient(135deg, #0da8e5, #0b85c0);
  box-shadow: 0 6px 20px rgba(18, 183, 245, 0.4);
  transform: translateY(-1px);
}

.submit-btn:active:not(:disabled) {
  transform: translateY(0);
}

.submit-btn:disabled {
  opacity: 0.7;
  cursor: not-allowed;
  transform: none;
}

.btn-spinner {
  width: 16px;
  height: 16px;
  border: 2px solid rgba(255, 255, 255, 0.3);
  border-top-color: white;
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

/* 底部链接 */
.form-footer {
  text-align: center;
  font-size: 13px;
  color: #999;
}

.form-footer a {
  color: #12b7f5;
  text-decoration: none;
  font-weight: 500;
}

.form-footer a:hover {
  text-decoration: underline;
}

/* 页面底部 */
.login-footer {
  text-align: center;
  margin-top: 24px;
  color: #aaa;
  font-size: 12px;
}

/* 过渡动画 */
.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.3s, transform 0.3s;
}

.fade-enter-from,
.fade-leave-to {
  opacity: 0;
  transform: translateY(-8px);
}
</style>
