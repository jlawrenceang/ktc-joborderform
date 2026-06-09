import body from './broker-irr.md?raw'

// Bump IRR_VERSION whenever the IRR text changes materially. The version the
// broker accepted at registration is recorded (auth metadata + brokers row), so
// a new version can later require re-acceptance.
export const IRR_VERSION = 'v1'

// Human-readable label shown next to the acceptance checkbox.
export const IRR_VERSION_LABEL = 'Version 1.0'

export const IRR_BODY = body
