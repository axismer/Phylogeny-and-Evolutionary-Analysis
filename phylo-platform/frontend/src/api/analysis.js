import http from './http'

export async function runAnalysis() {
  const { data } = await http.post('/api/analysis/run')
  return data
}

export async function fetchMatrix() {
  const { data } = await http.get('/api/analysis/matrix')
  return data
}

export async function fetchTree() {
  const { data } = await http.get('/api/analysis/tree')
  return data
}
