<template>
  <div class="tree-viewer card" v-if="newick">
    <h3>🌳 系统发育树 <span class="method-badge">{{ method }}</span></h3>
    <p class="newick-text">Newick: <code>{{ newick }}</code></p>
    <div ref="chartRef" class="tree-chart"></div>
  </div>
</template>

<script setup>
import { ref, watch, onMounted, onBeforeUnmount, nextTick } from 'vue'
import * as echarts from 'echarts'

const props = defineProps({
  newick: {
    type: String,
    default: ''
  },
  method: {
    type: String,
    default: 'UPGMA'
  }
})

const chartRef = ref(null)
let chartInstance = null

/**
 * 解析 Newick 格式为 ECharts Tree 数据
 * 支持分支长度显示
 */
function parseNewick(newick) {
  if (!newick || newick === ';') return { name: 'root', children: [] }

  const str = newick.endsWith(';') ? newick.slice(0, -1) : newick

  function parse(sub) {
    if (!sub.startsWith('(')) {
      // 叶子节点: "Name:distance" 或 "Name"
      const colonIdx = sub.lastIndexOf(':')
      if (colonIdx > 0) {
        const name = sub.substring(0, colonIdx)
        const dist = sub.substring(colonIdx + 1)
        return { name: name, value: parseFloat(dist) || 0 }
      }
      return { name: sub, value: 0 }
    }

    // 找到最外层括号匹配
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

    // 解析内部节点的距离
    let nodeValue = 0
    if (suffix.startsWith(':')) {
      nodeValue = parseFloat(suffix.substring(1)) || 0
    }

    // 按顶层逗号分割子节点
    const children = splitTopLevel(inner)
    const node = {
      name: '',
      value: nodeValue,
      children: children.map(c => parse(c.trim()))
    }
    return node
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

function renderTree() {
  if (!chartRef.value || !props.newick) return

  if (!chartInstance) {
    chartInstance = echarts.init(chartRef.value)
  }

  const treeData = parseNewick(props.newick)

  const option = {
    tooltip: {
      trigger: 'item',
      triggerOn: 'mousemove',
      formatter: function (params) {
        const data = params.data
        if (data.name) {
          let tip = data.name
          if (data.value !== undefined && data.value > 0) {
            tip += `<br/>分支长度: ${data.value.toFixed(4)}`
          }
          return tip
        }
        return data.value !== undefined ? `分支长度: ${data.value.toFixed(4)}` : ''
      }
    },
    series: [
      {
        type: 'tree',
        data: [treeData],
        top: '10%',
        left: '12%',
        bottom: '10%',
        right: '20%',
        symbolSize: 10,
        orient: 'LR',
        label: {
          position: 'left',
          verticalAlign: 'middle',
          align: 'right',
          fontSize: 13,
          color: '#555'
        },
        leaves: {
          label: {
            position: 'right',
            verticalAlign: 'middle',
            align: 'left',
            fontSize: 13,
            fontWeight: 'bold',
            color: '#2c3e50'
          }
        },
        lineStyle: {
          color: '#4a90d9',
          width: 2,
          curveness: 0.5
        },
        itemStyle: {
          color: '#4a90d9',
          borderColor: '#357abd'
        },
        expandAndCollapse: false,
        animationDuration: 550,
        animationDurationUpdate: 750
      }
    ]
  }

  chartInstance.setOption(option, true)
}

watch(() => props.newick, () => {
  nextTick(() => renderTree())
})

onMounted(() => {
  nextTick(() => renderTree())
  window.addEventListener('resize', handleResize)
})

onBeforeUnmount(() => {
  window.removeEventListener('resize', handleResize)
  if (chartInstance) {
    chartInstance.dispose()
  }
})

function handleResize() {
  if (chartInstance) {
    chartInstance.resize()
  }
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
  height: 420px;
  border: 1px solid #e8e8e8;
  border-radius: 8px;
  background: #fefefe;
}
</style>
