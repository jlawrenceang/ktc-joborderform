import OrgInfo from './OrgInfo'
import NeedHelp from './NeedHelp'
import { ORG } from '../lib/org'

// The public-pages letterhead: the KTC logo with the registered address + "Need help?"
// to its RIGHT on desktop, stacked under it on phone. Shared by the landing and the
// sign-in / create-account pages so they read as one consistent family.
export default function PublicBrand({ logoHeight = 50 }: { logoHeight?: number }) {
  return (
    <div className="ktc-brand">
      <img src="/ktc-logo.png" alt={ORG.name} style={{ height: logoHeight, flex: '0 0 auto' }} />
      <div className="ktc-brand-side">
        <OrgInfo />
        <NeedHelp />
      </div>
    </div>
  )
}
