import { createRouter, createWebHistory } from 'vue-router'
import Home from '../views/Home.vue'
import Login from '../views/Login.vue'

const routes = [
  {
    path: '/login',
    name: 'Login',
    component: Login,
    meta: { requiresAuth: false }
  },
  {
    path: '/',
    name: 'Home',
    component: Home,
    meta: { requiresAuth: true }
  }
]

const router = createRouter({
  history: createWebHistory(),
  routes
})

// 导航守卫：未登录用户跳转到登录页
router.beforeEach((to, from, next) => {
  const token = localStorage.getItem('token')
  const isLoggedIn = !!token

  if (to.meta.requiresAuth && !isLoggedIn) {
    // 需要登录但未登录，跳转到登录页
    next('/login')
  } else if (to.path === '/login' && isLoggedIn) {
    // 已登录用户访问登录页，跳转到主页
    next('/')
  } else {
    next()
  }
})

export default router
