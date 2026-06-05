import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import './styles/v2-tokens.css'
import './index.css'
import App from './App'

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <App />
  </StrictMode>,
)
