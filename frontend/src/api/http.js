import axios from 'axios'

const http = axios.create({
  baseURL: 'http://localhost:8080',
  timeout: 120000,
  headers: {
    'Content-Type': 'application/json',
  },
})

export default http
