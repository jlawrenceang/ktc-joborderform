#!/usr/bin/env bash
# Apply assets/jotform-theme.css to the live KTC Job Order Form.
# Embeds assets/ktc-logo.png as a data URI (replacing the __KTC_LOGO__ token),
# then writes the combined CSS into the form's `styles` property.
#
# Usage:  JOTFORM_API_KEY=xxxxx bash scripts/apply-theme.sh
set -euo pipefail

FORM_ID="261546852224458"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CSS="$ROOT/assets/jotform-theme.css"
LOGO="$ROOT/assets/ktc-logo.png"
: "${JOTFORM_API_KEY:?Set JOTFORM_API_KEY}"

# build data URI (single line, no wraps)
DATA_URI="data:image/png;base64,$(base64 -w0 "$LOGO")"

# substitute token -> combined CSS in a temp file (kept inside the repo so
# Windows curl can read it; removed on exit)
TMP="$ROOT/.theme-combined.css"; trap 'rm -f "$TMP"' EXIT
LOGO_DATA="$DATA_URI" python - "$CSS" "$TMP" <<'PY'
import os,sys
css=open(sys.argv[1],encoding='utf-8').read()
css=css.replace('__KTC_LOGO__', os.environ['LOGO_DATA'])
open(sys.argv[2],'w',encoding='utf-8').write(css)
PY

# hand curl a Windows-style path when running under git-bash/cygwin
CURL_PATH="$TMP"; command -v cygpath >/dev/null && CURL_PATH="$(cygpath -m "$TMP")"

# injectCSS is the legacy-form "Inject Custom CSS" property (verified). The
# `styles` property is just the theme-name slug and must stay "nova".
curl -s -X POST -H "APIKEY: $JOTFORM_API_KEY" \
  --data-urlencode "properties[injectCSS]@$CURL_PATH" \
  "https://api.jotform.com/form/$FORM_ID/properties" \
  -o /dev/null -w "apply-theme: HTTP %{http_code}\n"
