# Frontend（Vue 3 + Vite）

## 本地运行

1. 先启动后端（`backend/`，端口 8080）
2. 再启动前端：

```bash
cd frontend
npm install
npm run dev
```

浏览器打开 Vite 提示的地址（默认 http://localhost:5173）。

## 功能

- 「开始分析」→ `POST /api/analysis/run`
- 成功后拉取矩阵与 Newick 并展示
