import { type TourStep } from '../components/Tour'

// Per-page staff tours — each admin page calls usePageTour(key, steps). Steps
// spotlight elements on that page (no cross-page navigation). Role permissions
// already decide which pages a role can reach, so the page tours are generic.

export const dashboardSteps: TourStep[] = [
  {
    icon: '🧭', title: 'Welcome to the KTC admin portal',
    body: 'The Dashboard is your live overview. Each tile is a live count that links straight to where the work happens — here\'s what they mean.',
  },
  {
    icon: '✅', title: 'Accounts awaiting approval', target: '[data-tour="dash-pendingAccounts"]',
    body: 'New customers who confirmed their email and need verifying. A ring/dot means work is waiting — tap to open Approvals, view their ID, and approve or reject.',
  },
  {
    icon: '🏷️', title: 'Consignees pending', target: '[data-tour="dash-pendingConsignees"]',
    body: 'Consignees added but not yet approved. Tap to review and approve them so they\'re selectable when customers file.',
  },
  {
    icon: '👥', title: 'Customers', target: '[data-tour="dash-brokers"]',
    body: 'Your accredited customers. Tap to search, open a customer\'s detail, or suspend / reinstate an account.',
  },
  {
    icon: '🏗️', title: 'Consignees', target: '[data-tour="dash-consignees"]',
    body: 'The full consignee master list customers pick from. Tap to add, edit, or bulk-import.',
  },
  {
    icon: '📦', title: 'Open job orders', target: '[data-tour="dash-jobOrders"]',
    body: 'The live queue — submitted, processing, and on-hold orders. Tap to open the working queue. Most of the day-to-day lives there: process orders, confirm payments, record invoices.',
  },
]

export const checkerSteps: TourStep[] = [
  {
    icon: '🩻', title: 'X-ray Checker station',
    body: 'Your queue of orders waiting for X-ray, sorted by line number, with the "Now serving" strip on top.',
  },
  {
    icon: '🔎', title: 'Look up a container',
    body: 'Type a container or JO number to check a box: NOT CLEARED · X-ray pending means it\'s waiting; CLEARED shows when it passed. Use it when a trucker asks.',
  },
  {
    icon: '✅', title: 'Confirm X-ray done',
    body: 'When a container passes the X-ray, hit Confirm on its card — it stamps the date/time and the order leaves your queue (completing once its other services are done).',
  },
  {
    icon: '🧪', title: 'Assess RPS (operations)',
    body: 'If an order needs port-services moves (DEA / inspection), use Assess RPS on its card to record the moves — they bill per move on top of the base. Most orders need none.',
  },
]

export const vesselSteps: TourStep[] = [
  {
    icon: '🚢', title: 'Vessel schedule',
    body: 'The calls customers file against. Add one with the form, or bulk-update from your sheet with ⬇ Template then ⬆ Import (matched by vessel-visit, so re-importing updates rather than duplicates).',
  },
  {
    icon: '📸', title: 'Last free day & sharing',
    body: 'Last Free Day computes itself (finish discharging + the line\'s free-days), and past calls drop off automatically. Tap 📸 Snapshot to share the active vessels straight to your Viber group, and switch to the Calendar view for arrivals by month.',
  },
]
