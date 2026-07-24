<template>
  <div class="layout">
    <aside class="sidebar">
      <div class="sidebar-brand">
        <span class="brand-icon">🧬</span>
        <span class="brand-text">PhyloPlatform</span>
      </div>
      <nav class="sidebar-nav">
        <router-link to="/" class="nav-item" exact-active-class="active">
          <span class="nav-icon">🏠</span><span>首页概览</span>
        </router-link>
        <router-link to="/data" class="nav-item" active-class="active">
          <span class="nav-icon">📂</span><span>数据管理</span>
        </router-link>
        <router-link to="/ncbi" class="nav-item" active-class="active">
          <span class="nav-icon">📥</span><span>NCBI 下载</span>
        </router-link>
        <router-link to="/analysis" class="nav-item" active-class="active">
          <span class="nav-icon">🌳</span><span>系统发育分析</span>
        </router-link>
      </nav>
      <div class="sidebar-footer">
        <div class="user-info">
          <span class="user-avatar">{{ avatarText }}</span>
          <span class="user-name">{{ authStore.nickname }}</span>
        </div>
        <button class="logout-btn" @click="handleLogout">退出登录</button>
      </div>
    </aside>
    <main class="main-content">
      <router-view />
    </main>
  </div>
</template>

<script setup>
import { computed } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '../stores/auth'

const router = useRouter()
const authStore = useAuthStore()

const avatarText = computed(() => (authStore.nickname || 'U').charAt(0).toUpperCase())

function handleLogout() {
  authStore.logout()
  router.push('/login')
}
</script>

<style scoped>
.layout {
  display: flex;
  min-height: 100vh;
}
.sidebar {
  width: 240px;
  background: linear-gradient(180deg, #1a2332 0%, #1e3a4f 100%);
  color: white;
  display: flex;
  flex-direction: column;
  position: fixed;
  top: 0;
  left: 0;
  bottom: 0;
  z-index: 100;
}
.sidebar-brand {
  padding: 24px 20px;
  display: flex;
  align-items: center;
  gap: 10px;
  border-bottom: 1px solid rgba(255,255,255,0.08);
}
.brand-icon { font-size: 26px; }
.brand-text { font-size: 17px; font-weight: 700; letter-spacing: 0.5px; }
.sidebar-nav {
  flex: 1;
  padding: 16px 12px;
  display: flex;
  flex-direction: column;
  gap: 4px;
}
.nav-item {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px 16px;
  border-radius: 10px;
  color: rgba(255,255,255,0.7);
  text-decoration: none;
  font-size: 14px;
  transition: all 0.2s;
}
.nav-item:hover {
  background: rgba(255,255,255,0.08);
  color: white;
}
.nav-item.active {
  background: rgba(74, 144, 217, 0.25);
  color: #7ec8e3;
  font-weight: 600;
}
.nav-icon { font-size: 18px; width: 24px; text-align: center; }
.sidebar-footer {
  padding: 16px 20px;
  border-top: 1px solid rgba(255,255,255,0.08);
}
.user-info {
  display: flex;
  align-items: center;
  gap: 10px;
  margin-bottom: 12px;
}
.user-avatar {
  width: 32px;
  height: 32px;
  border-radius: 50%;
  background: linear-gradient(135deg, #4a90d9, #148f77);
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 14px;
  font-weight: 700;
}
.user-name { font-size: 13px; color: rgba(255,255,255,0.85); }
.logout-btn {
  width: 100%;
  padding: 8px;
  background: rgba(255,255,255,0.06);
  border: 1px solid rgba(255,255,255,0.15);
  color: rgba(255,255,255,0.7);
  border-radius: 6px;
  cursor: pointer;
  font-size: 13px;
  transition: all 0.2s;
}
.logout-btn:hover {
  background: rgba(231, 76, 60, 0.2);
  border-color: rgba(231, 76, 60, 0.4);
  color: #e74c3c;
}
.main-content {
  flex: 1;
  margin-left: 240px;
  padding: 32px;
  background: #f4f6f9;
  min-height: 100vh;
}
</style>
