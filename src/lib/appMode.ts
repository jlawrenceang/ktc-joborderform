// "App mode" = the portal launched as an installed PWA (standalone) or via the
// ?app=1 entry the manifest start_url uses. We persist it so a checker who taps
// the home-screen icon stays in the focused app experience. Used to scope a
// shorter idle timeout and the focused app shell.
export function isAppMode(): boolean {
  if (typeof window === 'undefined') return false
  try {
    // Re-evaluated every call (no sticky localStorage latch): an installed/
    // standalone launch, the iOS standalone flag, or the current ?app=1 entry.
    // This avoids a device used as both a kiosk and a normal browser getting
    // stuck in app mode after one ?app=1 visit.
    if (window.matchMedia('(display-mode: standalone)').matches) return true
    if ((window.navigator as unknown as { standalone?: boolean }).standalone) return true
    return new URLSearchParams(window.location.search).get('app') === '1'
  } catch {
    return false
  }
}
