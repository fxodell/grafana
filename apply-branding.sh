#!/usr/bin/env bash
set -euo pipefail

# ============================================
# CONFIGURATION (update only if you rename again)
# ============================================
OLD_MOD="github.com/grafana/grafana"
NEW_MOD="github.com/NFM-Consulting/nfm-dashboard"

OLD_SERVER="grafana-server"
NEW_SERVER="nfm-dashboard-server"
OLD_CLI="grafana-cli"
NEW_CLI="nfm-dashboard-cli"

APP_TITLE="NFM Dashboard"
DOCS_URL="https://docs.nfmconsulting.com/nfm-dashboard"

ASSET_SRC="branding_assets/img"
ASSET_DST="public/img"
EMAIL_TMPL="public/emails/ng_alert_notification.html"

# Directories to skip for finds
EXCLUDES=(
  --exclude-dir=.git
  --exclude-dir=bin
  --exclude-dir=data
  --exclude-dir=.yarn
  --exclude-dir=node_modules
  --exclude-dir=dist
  --exclude-dir=coverage
  --exclude-dir=vendor
)

# ============================================
# Helpers
# ============================================
info(){ echo -e "\e[1;34m[INFO]\e[0m $*"; }
warn(){ echo -e "\e[1;33m[WARN]\e[0m $*"; }
safe_sed(){
  local file=$1 cmd=$2
  if [[ -f $file ]]; then
    sed -i.bak "$cmd" "$file" && rm -f "${file}.bak"
  else
    warn "File not found: $file"
  fi
}
bulk_replace(){
  local pattern=$1 replacement=$2
  find . -type f \( -name '*.go' -o -name '*.ts' -o -name '*.js' -o -name '*.html' \
                   -o -name '*.md' -o -name '*.ini' \) \
    "${EXCLUDES[@]}" -print0 \
  | xargs -0 sed -i.bak -E "s/${pattern}/${replacement}/g"
  find . -name '*.bak' -delete
}

# ============================================
# 1) Rewrite Go module path
# ============================================
info "1) Updating module path in go.mod"
safe_sed go.mod "s|^module ${OLD_MOD}|module ${NEW_MOD}|"

# ============================================
# 2) Update Go imports
# ============================================
info "2) Rewriting Go imports from ${OLD_MOD} → ${NEW_MOD}"
find . -type f -name '*.go' "${EXCLUDES[@]}" -print0 \
  | xargs -0 sed -i.bak -E "s|${OLD_MOD}|${NEW_MOD}|g"
find . -name '*.bak' -delete

# ============================================
# 3) Rename backend binaries in build scripts
# ============================================
info "3) Renaming binaries in build.go & Makefile"
for f in build.go Makefile; do
  safe_sed "$f" "s|\b${OLD_SERVER}\b|${NEW_SERVER}|g"
  safe_sed "$f" "s|\b${OLD_CLI}\b|${NEW_CLI}|g"
done

# ============================================
# 4) Patch default configs
# ============================================
info "4) Patching conf/*.ini"
for ini in conf/defaults.ini conf/sample.ini conf/custom.ini; do
  safe_sed "$ini" "s|^instance_name *=.*|instance_name = ${APP_TITLE}|"
  safe_sed "$ini" "s|^disable_telemetry *=.*|disable_telemetry = true|"
done

# ============================================
# 5) Copy new logo assets
# ============================================
info "5) Copying branding assets"
if [[ -d $ASSET_SRC ]]; then
  mkdir -p "$ASSET_DST"
  cp -v "$ASSET_SRC"/* "$ASSET_DST"/
else
  warn "Asset source not found: $ASSET_SRC"
fi

# ============================================
# 6) Patch frontend title
# ============================================
info "6) Updating public/views/index.html title"
safe_sed public/views/index.html "s|\[\[\.AppTitle\]\]|${APP_TITLE}|g"

# ============================================
# 7) Update frontend config.ts
# ============================================
info "7) Rewriting public/app/core/config.ts"
safe_sed public/app/core/config.ts "s|appTitle *= *'.*'|appTitle = '${APP_TITLE}'|"
safe_sed public/app/core/config.ts "s|docsUrl *= *'.*'|docsUrl = '${DOCS_URL}'|"

# ============================================
# 8) Rebrand UI text without breaking imports
# ============================================
info "8a) Rebranding HTML/CSS/MD in public/"
find public/ -type f \( -name '*.html' -o -name '*.css' -o -name '*.md' \) \
  "${EXCLUDES[@]}" -print0 \
  | xargs -0 sed -i.bak -E "s/Grafana/${APP_TITLE}/g; s/grafana/nfm-dashboard/g"
info "8b) Rewriting JS/TS outside import lines"
find public/ -type f \( -name '*.js' -o -name '*.ts' \) \
  "${EXCLUDES[@]}" -print0 \
  | xargs -0 sed -i.bak -E '/^import /! s/Grafana/NFM Dashboard/g; /^import /! s/grafana/nfm-dashboard/g'
find public/ -name '*.bak' -delete

# ============================================
# 9) Rebrand README & docs/
# ============================================
info "9) Updating README.md & docs/"
safe_sed README.md "s|^# Grafana|# ${APP_TITLE}|"
safe_sed README.md "s|https://grafana.com|${DOCS_URL}|"
if [[ -d docs ]]; then
  bulk_replace "grafana" "nfm-dashboard"
fi

# ============================================
# 10) Rebrand packaging/
# ============================================
info "10) Updating packaging/ files"
if [[ -d packaging ]]; then
  bulk_replace "grafana" "nfm-dashboard"
fi

# ============================================
# 11) Metrics & telemetry
# ============================================
info "11) Renaming metrics & disabling telemetry pings"
safe_sed pkg/infra/metrics/metrics.go \
  's|ExporterName *= *"grafana"|ExporterName = "nfm_dashboard"|'
bulk_replace '"grafana_' '"nfm_dashboard_'
find pkg -type f -name '*.go' \
  "${EXCLUDES[@]}" \
  -print0 \
  | xargs -0 sed -i.bak -E 's|(https?://(stats|telemetry)\.grafana\.com[^ )]+)|// \1|g'
find pkg -name '*.bak' -delete

# ============================================
# 12) Patch alert-email template logo
# ============================================
info "12) Replacing Grafana logo in alert emails"
if [[ -f "$EMAIL_TMPL" ]]; then
  safe_sed "$EMAIL_TMPL" \
    's|<img height="auto" src="https://grafana\.com/static/assets/img/logo_new_transparent_light_400x100\.png"[^>]*>|<img height="auto" src="{{ .AppUrl }}/public/img/nfm-dashboard_typelogo.svg" alt="NFM Dashboard" style="border:0;display:block;outline:none;text-decoration:none;height:auto;width:100%;font-size:13px;" width="200">|'
else
  warn "Email template not found: $EMAIL_TMPL"
fi

# ============================================
# Post‐patch validations on email template
# ============================================
info "Validating email template for leftover Grafana references…"
if grep -q "logo_new_transparent_light_400x100.png" "$EMAIL_TMPL"; then
  warn "Still references Grafana’s hosted logo"
else
  info "No Grafana logo references remain"
fi
if grep -q "grafana.com" "$EMAIL_TMPL"; then
  warn "Found other Grafana.com URLs"
else
  info "No Grafana.com URLs remain"
fi

echo
info "🎉 Branding apply complete!"
echo "Next steps:"
echo "  go run build.go build"
echo "  yarn install && yarn build"
echo "  Restart your ${NEW_SERVER} and test a branded alert email."
