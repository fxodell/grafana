#!/usr/bin/env bash
set -euo pipefail

# ============================================
# CONFIGURATION (must match apply-branding.sh)
# ============================================
OLD_MOD="github.com/grafana/grafana"
NEW_MOD="github.com/NFM-Consulting/nfm-dashboard"

OLD_SERVER="grafana-server"
NEW_SERVER="nfm-dashboard-server"
OLD_CLI="grafana-cli"
NEW_CLI="nfm-dashboard-cli"

APP_TITLE="NFM Dashboard"
DOCS_URL="https://docs.nfmconsulting.com/nfm-dashboard"

EMAIL_TMPL="public/emails/ng_alert_notification.html"

# Directories to skip in recursive searches
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

# ANSI colors
GREEN='\e[32m'; RED='\e[31m'; YELLOW='\e[33m'; RESET='\e[0m'
ok()   { echo -e "${GREEN}✔${RESET} $*"; }
fail(){ echo -e "${RED}✘${RESET} $*"; FAILS=$((FAILS+1)); }
warn(){ echo -e "${YELLOW}⚠${RESET} $*"; }

FAILS=0

echo -e "\n==== Checking NFM Dashboard Branding ====\n"

# 1) go.mod module path
if [[ -f go.mod ]]; then
  current=$(awk '/^module /{print $2; exit}' go.mod || echo "")
  if [[ "$current" == "$NEW_MOD" ]]; then
    ok "go.mod module path is '$NEW_MOD'"
  else
    fail "go.mod module is '$current', expected '$NEW_MOD'"
  fi
else
  fail "go.mod not found"
fi

# 2) Go imports
cnt=$(grep -R "${EXCLUDES[@]}" --include='*.go' -n "$OLD_MOD" . | wc -l)
(( cnt == 0 )) && ok "No imports of '$OLD_MOD'" || fail "Found ${cnt} import(s) of '$OLD_MOD'"

# 3) build.go & Makefile
for f in build.go Makefile; do
  if [[ -f $f ]]; then
    grep -qP "\b$NEW_SERVER\b" "$f" && ok "$f references '$NEW_SERVER'" \
                                     || fail "$f missing '$NEW_SERVER'"
    grep -qP "\b$NEW_CLI\b"    "$f" && ok "$f references '$NEW_CLI'"    \
                                     || fail "$f missing '$NEW_CLI'"
  else
    warn "$f not found"
  fi
done

# 4) conf/*.ini
for ini in conf/defaults.ini conf/sample.ini conf/custom.ini; do
  if [[ -f $ini ]]; then
    grep -qE "^instance_name *= *${APP_TITLE}" "$ini" && ok "$ini: instance_name set" \
                                                   || fail "$ini: instance_name not set"
    grep -qE "^disable_telemetry *= *true"     "$ini" && ok "$ini: telemetry disabled" \
                                                   || fail "$ini: disable_telemetry not true"
  else
    warn "$ini not found"
  fi
done

# 5) public/img assets
for old in grafana_icon.svg grafana_typelogo.svg; do
  if [[ -f public/img/$old ]]; then
    fail "public/img/$old still present"
  else
    ok "public/img/$old removed"
  fi
done
for new in nfm-dashboard_icon.svg nfm-dashboard_typelogo.svg; do
  if [[ -f public/img/$new ]]; then
    ok "public/img/$new present"
  else
    fail "public/img/$new missing"
  fi
done

# 6) frontend title
if [[ -f public/views/index.html ]]; then
  grep -q "$APP_TITLE" public/views/index.html && ok "index.html contains '$APP_TITLE'" \
                                                    || fail "index.html missing '$APP_TITLE'"
else
  warn "public/views/index.html not found"
fi

# 7) frontend config.ts
CFG="public/app/core/config.ts"
if [[ -f $CFG ]]; then
  grep -qE "appTitle *= *'${APP_TITLE}'" "$CFG" && ok "$CFG: appTitle set" \
                                             || fail "$CFG: appTitle not set"
  grep -qE "docsUrl *= *'${DOCS_URL}'"    "$CFG" && ok "$CFG: docsUrl set" \
                                             || fail "$CFG: docsUrl not set"
else
  warn "$CFG not found"
fi

# 8) public/ UI text replacements
echo -e "\n-- Checking public/ UI text replacements --"

# 8a) HTML/CSS/MD must not contain Grafana/grafana
cnt_html=$(grep -R "${EXCLUDES[@]}" -n -E "Grafana|grafana" \
             --include='*.html' --include='*.css' --include='*.md' public/ | wc -l)
(( cnt_html == 0 )) && ok "No 'Grafana' or 'grafana' in HTML/CSS/MD under public/" \
                       || fail "Found ${cnt_html} stray refs in HTML/CSS/MD under public/"

# 8b) JS/TS must not contain UI text Grafana/grafana outside import lines
cnt_js=$(grep -R "${EXCLUDES[@]}" -n -E "Grafana|grafana" \
           --include='*.js' --include='*.ts' public/ \
         | grep -vP '^\./public/.*:\d+:import ' | wc -l)
(( cnt_js == 0 )) && ok "No stray 'Grafana' or 'grafana' in JS/TS outside import lines" \
                      || fail "Found ${cnt_js} UI-text refs in JS/TS; imports only should remain"

# 9) README.md & docs/
if [[ -f README.md ]]; then
  grep -qE "^# ${APP_TITLE}" README.md && ok "README.md title updated" \
                                         || fail "README.md title not updated"
  grep -q "${DOCS_URL}"      README.md && ok "README.md docs URL updated" \
                                         || fail "README.md docs URL not updated"
else
  warn "README.md not found"
fi

if [[ -d docs ]]; then
  cnt=$(grep -R "${EXCLUDES[@]}" -n "grafana.com" docs/ | wc -l)
  (( cnt == 0 )) && ok "No 'grafana.com' refs in docs/" || fail "Found ${cnt} 'grafana.com' refs in docs/"
else
  warn "docs/ not found"
fi

# 10) packaging/
if [[ -d packaging ]]; then
  cnt_old=$(grep -R "${EXCLUDES[@]}" -n "grafana" packaging/ | wc -l)
  cnt_new=$(grep -R "${EXCLUDES[@]}" -n "nfm-dashboard" packaging/ | wc -l)
  (( cnt_old == 0 )) && ok "No 'grafana' in packaging/" || fail "Found ${cnt_old} 'grafana' in packaging/"
  (( cnt_new > 0  )) && ok "Packaging updated"         || fail "No 'nfm-dashboard' in packaging/"
else
  warn "packaging/ not found"
fi

# 11) metrics & telemetry
MFILE="pkg/infra/metrics/metrics.go"
if [[ -f $MFILE ]]; then
  grep -qE 'ExporterName *= *"nfm_dashboard"' "$MFILE" && ok "metrics.go: ExporterName updated" \
                                                      || fail "metrics.go: ExporterName not updated"
else
  warn "$MFILE not found"
fi
cnt_m=$(grep -R "${EXCLUDES[@]}" -n '"grafana_' pkg/ | wc -l)
(( cnt_m == 0 )) && ok "No 'grafana_' metrics" || fail "Found ${cnt_m} 'grafana_' metrics"
cnt_t=$(grep -R "${EXCLUDES[@]}" -n -E "stats\.grafana\.com|telemetry\.grafana\.com" pkg/ | wc -l)
(( cnt_t == 0 )) && ok "No telemetry endpoints"  || fail "Found ${cnt_t} telemetry endpoints"

# 12) email template
if [[ -f $EMAIL_TMPL ]]; then
  grep -q "nfm-dashboard_typelogo.svg" "$EMAIL_TMPL" && ok "Email logo updated" \
                                                    || fail "Email logo not updated"
  if grep -q "grafana.com" "$EMAIL_TMPL"; then
    fail "Found Grafana.com URLs in email template"
  else
    ok "No Grafana.com URLs in email"
  fi
else
  warn "$EMAIL_TMPL not found"
fi

echo -e "\n==== Complete ====\n"
(( FAILS > 0 )) && exit 1 || exit 0
