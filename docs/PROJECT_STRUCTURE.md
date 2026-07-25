# 项目结构说明（MVP）

## 目录总览

```
phylo-platform/
├── backend/          Spring Boot：REST API + 分析流程编排
├── frontend/         Vue 3：上传、触发分析、结果展示
├── data/             本地文件存储（无数据库）
│   ├── raw/          原始 FASTA（输入）
│   ├── aligned/      MSA 结果（Clustal/MUSCLE 输出）
│   ├── matrix/       distance_matrix.csv
│   └── tree/         tree.nwk（Newick）
└── docs/             设计与 API 文档
```

## Backend 包结构（Java）

```
com.phylo.platform
├── PhyloPlatformApplication.java
├── config/           数据目录路径等配置
├── controller/       REST 接口
├── dto/              请求/响应对象
├── model/            领域模型（如 FastaRecord）
└── service/
    ├── fasta/        FASTA 解析与读取
    ├── alignment/    调用外部 MSA 工具（后续）
    ├── matrix/       p-distance（后续）
    └── tree/         UPGMA + Newick（后续）
```

原则：每个分析步骤一个 Service，Controller 只负责参数校验与调用，便于逐步联调。

## Frontend 结构（Vue 3）

```
frontend/src/
├── App.vue
├── main.js
├── api/              封装 fetch 调用 backend
├── views/            页面（分析主页）
└── components/       上传、矩阵表格、树图（后续）
```

第一版不使用 Pinia/Vue Router 也可运行；页面较少时 `App.vue` + 组件即可。

## 数据流

1. 用户上传或选择 `data/raw` 已有 FASTA
2. Backend 解析序列 → 写 combined FASTA 供 MSA
3. 调用 Clustal Omega / MUSCLE → `data/aligned/`
4. 比对列上算 p-distance → `data/matrix/distance_matrix.csv`
5. UPGMA → `data/tree/tree.nwk`
6. Frontend 拉取 CSV / Newick 并可视化
