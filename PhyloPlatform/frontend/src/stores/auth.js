import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import api from '../api'

export const useAuthStore = defineStore('auth', () => {
  const token = ref(localStorage.getItem('phylo_token') || '')
  const user = ref(JSON.parse(localStorage.getItem('phylo_user') || 'null'))

  const isLoggedIn = computed(() => !!token.value)
  const nickname = computed(() => user.value?.nickname || user.value?.uname || '')

  function setAuth(data) {
    token.value = data.token
    user.value = { uid: data.uid, uname: data.uname, nickname: data.nickname, role: data.role }
    localStorage.setItem('phylo_token', data.token)
    localStorage.setItem('phylo_user', JSON.stringify(user.value))
  }

  function logout() {
    token.value = ''
    user.value = null
    localStorage.removeItem('phylo_token')
    localStorage.removeItem('phylo_user')
  }

  async function login(uname, upassword) {
    const res = await api.post('/auth/login', { uname, upassword })
    setAuth(res.data)
    return res.data
  }

  async function register(uname, upassword, nickname, email) {
    const res = await api.post('/auth/register', { uname, upassword, nickname, email })
    return res.data
  }

  return { token, user, isLoggedIn, nickname, setAuth, logout, login, register }
})
