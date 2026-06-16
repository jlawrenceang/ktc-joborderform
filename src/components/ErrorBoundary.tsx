import { Component, type ReactNode } from 'react'
import { reportError, isChunkLoadError, reloadForStaleChunk } from '../lib/errorReporting'

// Last-resort catch for render-time crashes: report it, show a friendly
// reload panel instead of a white screen. A stale-deploy chunk failure
// auto-reloads once (no more manual "Reload" clicks after a release).
export default class ErrorBoundary extends Component<{ children: ReactNode }, { crashed: boolean; updating: boolean }> {
  state = { crashed: false, updating: false }

  static getDerivedStateFromError(error: unknown) {
    return { crashed: true, updating: isChunkLoadError(error) }
  }

  componentDidCatch(error: unknown) {
    if (isChunkLoadError(error)) {
      reportError(error)
      // Silent one-time reload to fetch the fresh build. If we already tried
      // very recently (genuine failure), fall back to the manual panel.
      if (reloadForStaleChunk()) return
      this.setState({ updating: false })
      return
    }
    reportError(error)
  }

  render() {
    if (!this.state.crashed) return this.props.children
    if (this.state.updating) {
      return (
        <div style={{ display: 'grid', placeItems: 'center', minHeight: '100vh', padding: 24 }}>
          <div className="ktc-glass" style={{ padding: 32, maxWidth: 420, textAlign: 'center' }}>
            <h1 style={{ margin: 0, fontSize: 20, fontWeight: 650 }}>Updating to the latest version…</h1>
            <p className="ktc-label" style={{ marginTop: 10, fontSize: 13.5, lineHeight: 1.6 }}>
              A new version was just released — reloading.
            </p>
          </div>
        </div>
      )
    }
    return (
      <div style={{ display: 'grid', placeItems: 'center', minHeight: '100vh', padding: 24 }}>
        <div className="ktc-glass" style={{ padding: 32, maxWidth: 420, textAlign: 'center' }}>
          <h1 style={{ margin: 0, fontSize: 20, fontWeight: 650 }}>Something went wrong</h1>
          <p className="ktc-label" style={{ marginTop: 10, fontSize: 13.5, lineHeight: 1.6 }}>
            The error has been reported to KTC automatically. Reloading usually fixes it.
          </p>
          <button className="ktc-btn" style={{ marginTop: 18, width: 'auto', padding: '11px 26px' }}
            onClick={() => window.location.reload()}>
            ↻ Reload
          </button>
        </div>
      </div>
    )
  }
}
