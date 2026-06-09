import irrBody from './broker-irr.md?raw'
import termsBody from './terms-and-conditions.md?raw'
import privacyBody from './privacy-notice.md?raw'

// Bump a *_VERSION whenever that document changes materially. The versions a
// broker accepted at registration are recorded (auth metadata + brokers row),
// so a new version can later require re-acceptance / re-consent.

export const IRR_VERSION = 'v1'
export const IRR_VERSION_LABEL = 'Version 1.0'
export const IRR_BODY = irrBody

export const TERMS_VERSION = 'v1'
export const TERMS_VERSION_LABEL = 'Version 1.0'
export const TERMS_BODY = termsBody

export const PRIVACY_VERSION = 'v1'
export const PRIVACY_VERSION_LABEL = 'Version 1.0'
export const PRIVACY_BODY = privacyBody
