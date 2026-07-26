<template>
  <div class="tree-viewer card" v-if="newick || circularTreeImage">
    <h3>
      🌳 系统发育树 
      <span class="method-badge">{{ method }}</span>
      <button class="ai-btn" @click="triggerAiAnalysis" :disabled="aiLoading">
        {{ aiLoading ? '🤖 AI 分析中...' : '🧠 AI 智能解读' }}
      </button>
    </h3>
    
    <!-- R 绘制的环状树 -->
    <div v-if="circularTreeImage" class="r-tree-image">
      <img :src="'data:image/png;base64,' + circularTreeImage" alt="R Circular Phylogenetic Tree" />
      <p class="note">由 R 语言和 ggtree 包绘制</p>
    </div>
    
    <!-- D3.js 环状树作为备用方案 -->
    <template v-else-if="newick">
      <p class="newick-text">Newick: <code>{{ newick }}</code></p>
      <div ref="chartRef" class="tree-chart"></div>
    </template>
    
    <!-- AI 分析报告 -->
    <div v-if="aiReport" class="ai-report card">
      <h4>🤖 AI 智能解读报告</h4>
      <div v-html="renderAiReport(aiReport)" class="report-content"></div>
      <button @click="showFullReport = !showFullReport" class="toggle-btn">
        {{ showFullReport ? '收起' : '展开全文' }}
      </button>
    </div>
  </div>
</template>

<script setup>
import { ref, watch, onMounted, onBeforeUnmount, nextTick } from 'vue'
import * as d3 from 'd3'
import { interpretPhylogeneticTree } from '../api'

const props = defineProps({
  newick: {
    type: String,
    default: ''
  },
  method: {
    type: String,
    default: 'UPGMA'
  },
  circularTreeImage: {
    type: String,  // Base64 encoded PNG
    default: ''
  }
})

const chartRef = ref(null)
const aiLoading = ref(false)
const aiReport = ref(null)
const showFullReport = ref(false)

/**
 * 解析 Newick 格式为 D3 hierarchy 数据
 */
function parseNewick(newick) {
  if (!newick || newick === ';') return { name: 'root', children: [] }

  const str = newick.endsWith(';') ? newick.slice(0, -1) : newick

  function parse(sub) {
    if (!sub.startsWith('(')) {
      const colonIdx = sub.lastIndexOf(':')
      if (colonIdx > 0) {
        const name = sub.substring(0, colonIdx)
        const dist = parseFloat(sub.substring(colonIdx + 1)) || 0
        return { name, branchLength: dist }
      }
      return { name: sub, branchLength: 0 }
    }

    let depth = 0
    let inner = ''
    let suffix = ''

    for (let i = 0; i < sub.length; i++) {
      if (sub[i] === '(') {
        depth++
        if (depth === 1) continue
      }
      if (sub[i] === ')') {
        depth--
        if (depth === 0) {
          suffix = sub.slice(i + 1)
          break
        }
      }
      if (depth >= 1) {
        inner += sub[i]
      }
    }

    let branchLength = 0
    if (suffix.startsWith(':')) {
      branchLength = parseFloat(suffix.substring(1)) || 0
    }

    const children = splitTopLevel(inner)
    return {
      name: '',
      branchLength,
      children: children.map(c => parse(c.trim()))
    }
  }

  function splitTopLevel(s) {
    const parts = []
    let depth = 0
    let current = ''
    for (let i = 0; i < s.length; i++) {
      if (s[i] === '(') depth++
      if (s[i] === ')') depth--
      if (s[i] === ',' && depth === 0) {
        parts.push(current)
        current = ''
      } else {
        current += s[i]
      }
    }
    if (current) parts.push(current)
    return parts
  }

  return parse(str)
}

/**
 * 渲染环状系统发育树
 */
function renderTree() {
  if (!chartRef.value || !props.newick) return

  // 清空之前的内容
  d3.select(chartRef.value).selectAll('*').remove()

  const container = chartRef.value
  const width = container.clientWidth || 700
  const height = container.clientHeight || 520
  const radius = Math.min(width, height) / 2 - 80

  const svg = d3.select(container)
    .append('svg')
    .attr('width', width)
    .attr('height', height)

  const g = svg.append('g')
    .attr('transform', `translate(${width / 2},${height / 2})`)

  // 添加缩放功能
  const zoom = d3.zoom()
    .scaleExtent([0.3, 4])
    .on('zoom', (event) => {
      g.attr('transform', event.transform)
    })
  svg.call(zoom)
  svg.call(zoom.transform, d3.zoomIdentity.translate(width / 2, height / 2))

  const treeData = parseNewick(props.newick)
  const root = d3.hierarchy(treeData)

  // 计算每个节点到根部的累计分支长度（用于径向距离）
  root.each(node => {
    node.data._cumLength = (node.parent ? node.parent.data._cumLength || 0 : 0) + (node.data.branchLength || 0)
  })

  const maxDepth = d3.max(root.descendants(), d => d.data._cumLength) || 1

  // 使用 cluster 布局分配角度
  const clusterLayout = d3.cluster().size([2 * Math.PI, radius])
  clusterLayout(root)

  // 径向比例尺：将累计分支长度映射到半径
  const radiusScale = d3.scaleLinear().domain([0, maxDepth]).range([0, radius])

  // 重新计算每个节点的径向位置（基于分支长度）
  root.each(node => {
    node.radius = radiusScale(node.data._cumLength || 0)
  })

  // 极坐标转直角坐标
  function polarToCartesian(angle, r) {
    return [r * Math.cos(angle - Math.PI / 2), r * Math.sin(angle - Math.PI / 2)]
  }

  // 生成弧形连接路径（先径向再角向）
  function linkPath(d) {
    const sourceAngle = d.parent.x - Math.PI / 2
    const sourceR = d.parent.radius
    const targetAngle = d.x - Math.PI / 2
    const targetR = d.radius

    const sx = sourceR * Math.cos(sourceAngle)
    const sy = sourceR * Math.sin(sourceAngle)
    const tx = targetR * Math.cos(targetAngle)
    const ty = targetR * Math.sin(targetAngle)

    // 在父节点半径处画弧，然后径向连接到子节点
    const arc = d3.arc()
    const arcPath = arc({
      innerRadius: sourceR,
      outerRadius: sourceR,
      startAngle: Math.min(sourceAngle, targetAngle) + Math.PI / 2,
      endAngle: Math.max(sourceAngle, targetAngle) + Math.PI / 2
    })

    // 使用路径：从父节点画弧到子节点角度，再径向延伸到子节点
    const midX = sourceR * Math.cos(targetAngle)
    const midY = sourceR * Math.sin(targetAngle)

    return `M${sx},${sy}A${sourceR},${sourceR} 0 0,${targetAngle > sourceAngle ? 1 : 0} ${midX},${midY}L${tx},${ty}`
  }

  // 绘制连接线
  const links = root.links().filter(d => d.target.depth > 0)

  g.selectAll('.link')
    .data(links)
    .join('path')
    .attr('class', 'link')
    .attr('d', linkPath)
    .attr('fill', 'none')
    .attr('stroke', '#4a90d9')
    .attr('stroke-width', 2)
    .attr('stroke-opacity', 0.8)

  // 绘制节点
  const nodes = root.descendants()

  // 内部节点
  g.selectAll('.node-internal')
    .data(nodes.filter(d => d.children))
    .join('circle')
    .attr('class', 'node-internal')
    .attr('cx', d => d.radius * Math.cos(d.x - Math.PI / 2))
    .attr('cy', d => d.radius * Math.sin(d.x - Math.PI / 2))
    .attr('r', 4)
    .attr('fill', '#4a90d9')
    .attr('stroke', '#357abd')
    .attr('stroke-width', 1.5)

  // 叶子节点
  const leaves = nodes.filter(d => !d.children)

  g.selectAll('.node-leaf')
    .data(leaves)
    .join('circle')
    .attr('class', 'node-leaf')
    .attr('cx', d => d.radius * Math.cos(d.x - Math.PI / 2))
    .attr('cy', d => d.radius * Math.sin(d.x - Math.PI / 2))
    .attr('r', 5)
    .attr('fill', '#e74c3c')
    .attr('stroke', '#c0392b')
    .attr('stroke-width', 1.5)

  // 叶子标签
  g.selectAll('.label')
    .data(leaves)
    .join('text')
    .attr('class', 'label')
    .attr('transform', d => {
      const angle = d.x - Math.PI / 2
      const x = (d.radius + 12) * Math.cos(angle)
      const y = (d.radius + 12) * Math.sin(angle)
      const rotate = (d.x * 180 / Math.PI)
      const flip = d.x > Math.PI
      return `translate(${x},${y}) rotate(${flip ? rotate + 180 : rotate})`
    })
    .attr('text-anchor', d => d.x > Math.PI ? 'end' : 'start')
    .attr('dominant-baseline', 'middle')
    .attr('font-size', '12px')
    .attr('font-weight', 'bold')
    .attr('fill', '#2c3e50')
    .text(d => d.data.name)

  // Tooltip
  const tooltip = d3.select(container)
    .append('div')
    .attr('class', 'tree-tooltip')
    .style('position', 'absolute')
    .style('display', 'none')
    .style('background', 'rgba(0,0,0,0.8)')
    .style('color', '#fff')
    .style('padding', '6px 10px')
    .style('border-radius', '4px')
    .style('font-size', '12px')
    .style('pointer-events', 'none')
    .style('z-index', '10')

  g.selectAll('.node-leaf, .node-internal')
    .on('mouseover', function (event, d) {
      let tip = d.data.name || '内部节点'
      if (d.data.branchLength > 0) {
        tip += `<br/>分支长度: ${d.data.branchLength.toFixed(4)}`
      }
      tooltip.html(tip)
        .style('display', 'block')
        .style('left', (event.offsetX + 10) + 'px')
        .style('top', (event.offsetY - 10) + 'px')
    })
    .on('mousemove', function (event) {
      tooltip
        .style('left', (event.offsetX + 10) + 'px')
        .style('top', (event.offsetY - 10) + 'px')
    })
    .on('mouseout', function () {
      tooltip.style('display', 'none')
    })
}

watch(() => props.newick, (newValue) => {
  console.log('TreeViewer: newick changed', newValue)
  nextTick(() => renderTree())
}, { immediate: true })

onMounted(() => {
  console.log('TreeViewer mounted')
  nextTick(() => renderTree())
  window.addEventListener('resize', handleResize)
})

onBeforeUnmount(() => {
  window.removeEventListener('resize', handleResize)
})

function handleResize() {
  renderTree()
}

/**
 * 触发 AI 分析报告生成
 */
async function triggerAiAnalysis() {
  if (!props.newick) {
    alert('请先生成进化树后再进行 AI 分析')
    return
  }
  
  aiLoading.value = true
  aiReport.value = null
  showFullReport.value = false
  
  try {
    // 提取序列名称（从 Newick 树中解析叶子节点）
    const seqNames = extractSeqNamesFromNewick(props.newick)
    
    console.log('开始 AI 分析...', { newick: props.newick, sequences: seqNames, method: props.method })
    
    const response = await interpretPhylogeneticTree(
      props.newick,
      seqNames,
      props.method
    )
    
    console.log('AI 响应:', response.data)
    
    if (response.data && response.data.status === 'success') {
      aiReport.value = response.data.fullContent || response.data.report
      console.log('✅ AI 分析完成')
    } else {
      throw new Error(response.data?.error || 'AI 分析失败')
    }
  } catch (err) {
    console.error('AI 分析错误:', err)
    alert('AI 分析失败：' + (err.response?.data?.error || err.message))
    
    // 降级处理：显示基础分析
    aiReport.value = `【系统发育树基础解读】\n\n` +
      `分析方法：${props.method}\n\n` +
      `由于 AI 分析服务暂时不可用，建议:\n` +
      `1. 查看距离矩阵确定序列间的遗传距离\n` +
      `2. 观察树的拓扑结构识别近缘关系\n` +
      `3. 检查分支长度判断分化程度\n\n` +
      `💡提示：在 application.properties 中配置 DeepSeek API Key 可启用智能分析功能。`
  } finally {
    aiLoading.value = false
  }
}

/**
 * 从 Newick 格式提取序列名称
 */
function extractSeqNamesFromNewick(newick) {
  const names = []
  let currentName = ''
  let depth = 0
  
  for (let i = 0; i < newick.length; i++) {
    const char = newick[i]
    
    if (char === '(') {
      depth++
    } else if (char === ')') {
      depth--
    } else if (char === ':' && depth === 0 && currentName) {
      // 分支长度分隔符，清空当前名称
      currentName = ''
    } else if (char === ',' && depth === 0) {
      // 节点分隔符
      if (currentName.trim()) {
        names.push(currentName.trim())
      }
      currentName = ''
    } else if (char === ';' && depth === 0) {
      // 结束符，处理最后一个节点
      if (currentName.trim()) {
        names.push(currentName.trim())
      }
      break
    } else {
      currentName += char
    }
  }
  
  return names.length > 0 ? names : ['Unknown']
}

/**
 * 渲染 AI 报告内容（转换为 Markdown 风格）
 */
function renderAiReport(content) {
  if (!content) return ''
  
  // 简单的 Markdown 转换
  return content
    .replace(/##\s+(.*)/g, '<strong>$1</strong><br/>')
    .replace(/###\s+(.*)/g, '<em>$1</em><br/>')
    .replace(/\*\*(.*)\*\*/g, '<strong>$1</strong>')
    .replace(/\*\s+(.*)/g, '• $1<br/>')
    .replace(/\n/g, '<br/>')
}
</script>

<style scoped>
.tree-viewer {
  margin-top: 0;
}

.card {
  background: white;
  border: 1px solid #e8e8e8;
  border-radius: 10px;
  padding: 20px;
  margin-bottom: 20px;
}

h3 {
  margin-bottom: 8px;
  color: #333;
  display: flex;
  align-items: center;
  gap: 10px;
}

.method-badge {
  font-size: 12px;
  background: #e8f5e9;
  color: #2e7d32;
  padding: 2px 10px;
  border-radius: 12px;
  font-weight: normal;
}

.newick-text {
  font-size: 13px;
  color: #666;
  margin-bottom: 12px;
  word-break: break-all;
}

.newick-text code {
  background: #f5f5f5;
  padding: 2px 6px;
  border-radius: 3px;
  font-size: 12px;
}

.tree-chart {
  width: 100%;
  height: 520px;
  border: 1px solid #e8e8e8;
  border-radius: 8px;
  background: #fefefe;
  position: relative;
  overflow: hidden;
}

.r-tree-image {
  text-align: center;
  padding: 20px;
  border: 1px solid #e8e8e8;
  border-radius: 8px;
  margin-bottom: 20px;
}

.r-tree-image img {
  max-width: 100%;
  height: auto;
  border-radius: 8px;
  box-shadow: 0 2px 8px rgba(0,0,0,0.1);
}

.note {
  margin-top: 10px;
  font-size: 12px;
  color: #999;
  font-style: italic;
}

/* AI 报告样式 */
.ai-btn {
  background: linear-gradient(135deg, #667eea, #764ba2);
  color: white;
  border: none;
  padding: 4px 12px;
  border-radius: 6px;
  font-size: 12px;
  cursor: pointer;
  transition: all 0.3s;
  margin-left: 8px;
  box-shadow: 0 2px 6px rgba(102, 126, 234, 0.3);
}

.ai-btn:hover:not(:disabled) {
  transform: translateY(-1px);
  box-shadow: 0 4px 12px rgba(102, 126, 234, 0.4);
}

.ai-btn:disabled {
  opacity: 0.7;
  cursor: not-allowed;
}

.ai-report {
  background: linear-gradient(135deg, #f5f7fa, #e8f4f8);
  border: 2px solid #667eea;
  position: relative;
}

.ai-report h4 {
  margin: 0 0 12px 0;
  color: #667eea;
  font-size: 16px;
}

.report-content {
  font-size: 14px;
  line-height: 1.6;
  color: #333;
  max-height: 400px;
  overflow-y: auto;
  padding: 12px;
  background: white;
  border-radius: 8px;
  border: 1px solid #e0e0e0;
}

.toggle-btn {
  margin-top: 12px;
  padding: 8px 16px;
  background: #667eea;
  color: white;
  border: none;
  border-radius: 6px;
  cursor: pointer;
  font-size: 13px;
  transition: all 0.2s;
}

.toggle-btn:hover {
  background: #5568d3;
}
</style>
