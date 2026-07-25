/**
 * 简易 Newick 解析（支持引号标签与枝长）。
 * 返回树：{ name, length, children[] }
 */
export function parseNewick(newick) {
  const input = (newick || '').trim().replace(/;$/, '')
  let i = 0

  function peek() {
    return input[i]
  }

  function parseSubtree() {
    let children = null
    if (peek() === '(') {
      i++
      children = []
      children.push(parseSubtree())
      while (peek() === ',') {
        i++
        children.push(parseSubtree())
      }
      if (peek() !== ')') {
        throw new Error('Newick 缺少右括号')
      }
      i++
    }

    const name = parseName()
    let length = null
    if (peek() === ':') {
      i++
      length = parseNumber()
    }

    return {
      name: name || (children ? '' : 'unnamed'),
      length,
      children: children || [],
    }
  }

  function parseName() {
    if (peek() === "'") {
      i++
      let name = ''
      while (i < input.length && peek() !== "'") {
        name += input[i++]
      }
      if (peek() === "'") {
        i++
      }
      return name
    }
    let name = ''
    while (i < input.length && !'(),:;'.includes(peek())) {
      name += input[i++]
    }
    return name.trim()
  }

  function parseNumber() {
    const start = i
    if (peek() === '-') {
      i++
    }
    while (i < input.length && /[0-9.eE+-]/.test(peek())) {
      i++
    }
    return Number(input.slice(start, i))
  }

  const root = parseSubtree()
  return root
}

export function collectLeaves(node, out = []) {
  if (!node.children || node.children.length === 0) {
    out.push(node)
    return out
  }
  for (const child of node.children) {
    collectLeaves(child, out)
  }
  return out
}
