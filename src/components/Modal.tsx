import { type ReactNode, useEffect } from 'react'
import { createPortal } from 'react-dom'

// Small reusable modal built on the existing visionOS glass modal classes
// (ktc-modal-backdrop / ktc-modal-panel in index.css). Click-outside or Esc closes.
// Rendered through a PORTAL to <body> so it always escapes ancestor stacking
// contexts — a parent `.ktc-glass` (backdrop-filter) would otherwise trap the
// fixed backdrop and let the bottom tabbar / footer overlap it.
export default function Modal({
  open,
  onClose,
  title,
  children,
  maxWidth = 460,
}: {
  open: boolean
  onClose: () => void
  title?: string
  children: ReactNode
  maxWidth?: number
}) {
  useEffect(() => {
    if (!open) return
    function onKey(e: KeyboardEvent) { if (e.key === 'Escape') onClose() }
    document.addEventListener('keydown', onKey)
    return () => document.removeEventListener('keydown', onKey)
  }, [open, onClose])

  if (!open || typeof document === 'undefined') return null
  return createPortal(
    <div className="ktc-modal-backdrop" onClick={onClose}>
      <div
        className="ktc-glass ktc-modal-panel"
        onClick={(e) => e.stopPropagation()}
        style={{ width: '100%', maxWidth, padding: 0, display: 'flex', flexDirection: 'column', maxHeight: '88vh' }}
      >
        {title && (
          <div style={{ padding: '14px 18px', borderBottom: '1px solid var(--glass-brd)', display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 10 }}>
            <div style={{ fontSize: 15.5, fontWeight: 700 }}>{title}</div>
            <button type="button" onClick={onClose} aria-label="Close" className="ktc-link" style={{ fontSize: 22, lineHeight: 1, padding: '0 4px' }}>×</button>
          </div>
        )}
        <div style={{ overflowY: 'auto', padding: '16px 18px' }}>{children}</div>
      </div>
    </div>,
    document.body,
  )
}
