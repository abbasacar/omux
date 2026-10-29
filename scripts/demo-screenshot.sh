#!/bin/zsh
# Makes docs/screenshot.png: runs a separate omux on a demo workspace (sample projects,
# sessions and conversation history) and has it capture its own window.
#
# Your omux, workspace, conversations and settings are left alone: the demo gets its own
# home folder, takes its settings from the command line (they aren't saved), listens on
# its own debug channel, shows sample usage limits instead of reading your Claude login,
# and runs no Claude: each demo session runs a script that prints sample work and reports
# its status the way Claude Code does (OSC 7501).
#
# Run ./build.sh first. Usage: scripts/demo-screenshot.sh [output.png]
set -e
cd "$(dirname "$0")/.."
REPO=$PWD
OUT=${1:-$REPO/docs/screenshot.png}
APP=${OMUX_APP:-$REPO/build/omux.app}
[[ -x $APP/Contents/MacOS/omux ]] || { echo "No $APP; run ./build.sh first" >&2; exit 1; }

# Under ~/Library/Caches: /tmp and $TMPDIR go through symlinks, and the demo's home must be
# a plain path for omux to show its folders as ~/code/….
DEMO=${OMUX_DEMO_DIR:-$(mktemp -d ~/Library/Caches/omux-demo.XXXXXX)}
KEEP=${OMUX_DEMO_DIR:+1}
H=$DEMO/home
rm -rf $H && mkdir -p $H/bin $H/code "$H/Library/Application Support/omux" $H/.claude/projects

# A plain prompt, and the scene script on the PATH.
cat > $H/.zshrc <<'EOF'
export PATH="$HOME/bin:/usr/bin:/bin:/usr/sbin:/sbin"
PROMPT='%F{blue}%1~%f %F{8}❯%f '
EOF

# Sample projects, so the folders and the Files panel have something in them.
for p in acme-web api-server docs; do mkdir -p $H/code/$p/src; done
print '{ "name": "acme-web", "version": "2.4.0" }' > $H/code/acme-web/package.json
touch $H/code/acme-web/src/{CheckoutPage,OrderSummary,Settings}.tsx $H/code/acme-web/README.md
touch $H/code/api-server/src/{limiter,routes,db}.ts $H/code/docs/{index,setup,deploy}.md

# scene <name>: clears the screen, prints sample work and reports a status.
cat > $H/bin/scene <<'EOF'
#!/bin/zsh
b=$'\e[1m' d=$'\e[2m' r=$'\e[0m' g=$'\e[32m' y=$'\e[33m' c=$'\e[36m' m=$'\e[35m' gr=$'\e[90m'
report() { printf '\e]7501;state=%s:msg=%s%s\a' $1 "$(printf %s "$2" | base64)" "${3:+:kind=$3}"; }
printf '\e[2J\e[H\e[?25l'
case $1 in
checkout)
  print "${b}› Redesign the checkout page with the new design tokens${r}\n"
  print "${c}•${r} Read ${b}src/checkout/CheckoutPage.tsx${r} ${gr}(212 lines)${r}"
  print "${c}•${r} Read ${b}src/styles/tokens.ts${r} ${gr}(88 lines)${r}"
  print "${c}•${r} Edited ${b}src/checkout/CheckoutPage.tsx${r}  ${g}+48${r} ${m}−31${r}"
  print "${c}•${r} Edited ${b}src/checkout/OrderSummary.tsx${r}  ${g}+22${r} ${m}−9${r}"
  print "${c}•${r} Running ${b}npm test -- checkout${r}\n"
  print "   ${g}PASS${r}  src/checkout/CheckoutPage.test.tsx"
  print "     ${g}✓${r} renders the order summary ${gr}(41 ms)${r}"
  print "     ${g}✓${r} applies a discount code ${gr}(18 ms)${r}"
  print "     ${g}✓${r} validates card fields ${gr}(26 ms)${r}"
  print "   ${y}RUNS${r}  src/checkout/Payment.test.tsx\n"
  print "${y}*${r} ${d}Running checkout tests… 1m 12s${r}"
  report working "Running checkout tests" ;;
login)
  print "${b}› The login test fails about one run in ten. Find out why.${r}\n"
  print "${c}•${r} Read ${b}tests/login.spec.ts${r} ${gr}(64 lines)${r}"
  print "${c}•${r} Searched for ${b}waitForNavigation${r} in tests/ ${gr}(3 results)${r}\n"
  print "  The test clicks Sign in before the form's submit handler is"
  print "  attached, so the first click is sometimes lost. Waiting for the"
  print "  button to be enabled fixes it. Running it 20 times to confirm.\n"
  print "${y}╭──────────────────────────────────────────────╮${r}"
  print "${y}│${r} ${b}Run this command?${r}                            ${y}│${r}"
  print "${y}│${r}   npx playwright test login --repeat-each=20 ${y}│${r}"
  print "${y}│${r}                                              ${y}│${r}"
  print "${y}│${r} ${b}❯ Yes${r}    Yes, don't ask again    No          ${y}│${r}"
  print "${y}╰──────────────────────────────────────────────╯${r}"
  report blocked "Run npx playwright test?" permission ;;
darkmode)
  print "${b}› Add a dark mode toggle to settings${r}\n"
  print "${c}•${r} Edited ${b}src/settings/Appearance.tsx${r}  ${g}+36${r} ${m}−4${r}"
  print "${c}•${r} Edited ${b}src/styles/theme.css${r}  ${g}+58${r}"
  print "${c}•${r} Edited ${b}src/settings/Settings.test.tsx${r}  ${g}+21${r}"
  print "${c}•${r} Ran ${b}npm test -- settings${r}  ${g}12 passed${r}\n"
  print "  Done. The toggle follows the system appearance by default"
  print "  and remembers the choice. 3 files changed."
  report done "3 files changed" ;;
devserver)
  print "${c}acme-web${r} ${gr}❯${r} npm run dev\n"
  print "> acme-web@2.4.0 dev\n> vite\n"
  print "  ${g}${b}VITE${r} ${g}v6.0.3${r}  ${d}ready in ${r}${b}412${r}${d} ms${r}\n"
  print "  ${g}➜${r}  ${b}Local${r}:   ${c}http://localhost:5173/${r}"
  print "  ${g}➜${r}  ${d}Network: use --host to expose${r}"
  print "\n  ${gr}12:41:07${r} ${c}[vite]${r} hmr update ${d}/src/checkout/CheckoutPage.tsx${r}" ;;
limiter)
  print "${b}› Add per-key rate limiting backed by Redis${r}\n"
  print "${c}•${r} Edited ${b}src/limiter.ts${r}  ${g}+74${r}"
  report working "Writing limiter tests" ;;
migrations)
  print "${b}› Squash the 2024 migrations${r}\n  Done. 14 migrations merged into one."
  report done "Migrations squashed" ;;
esac
exec sleep 86400
EOF
chmod +x $H/bin/scene

# Sessions run `scene <name>`; the demo starts them all at launch.
uuid() { uuidgen | tr 'A-Z' 'a-z' }
tab() { # name, scene, color
  print -n "{\"id\":\"$(uuidgen)\",\"name\":\"$1\",\"command\":\"$2\",\"color\":\"${3:-none}\",\"claudeSessionID\":\"$(uuidgen)\"}"
}
CHECKOUT=$(uuidgen)
cat > "$H/Library/Application Support/omux/workspace.json" <<EOF
{
  "selectedTabID": "$CHECKOUT",
  "groups": [
    { "id": "$(uuidgen)", "name": "acme-web", "directory": "$H/code/acme-web", "command": "claude", "tabs": [
      {"id":"$CHECKOUT","name":"Checkout redesign","command":"scene checkout","color":"purple","claudeSessionID":"$(uuidgen)"},
      $(tab "Fix flaky login test" "scene login"),
      $(tab "Dark mode" "scene darkmode"),
      $(tab "Dev server" "scene devserver")
    ]},
    { "id": "$(uuidgen)", "name": "api-server", "directory": "$H/code/api-server", "command": "claude", "tabs": [
      $(tab "Rate limiter" "scene limiter"),
      $(tab "Migrations" "scene migrations")
    ]},
    { "id": "$(uuidgen)", "name": "docs", "directory": "$H/code/docs", "command": "claude", "tabs": [
      $(tab "Deploy guide" "exit")
    ]}
  ]
}
EOF

# Conversation history for the Recent section, with Claude Code's titles and ages.
recent() { # project, title, prompt, age like 2H or 3d
  local dir=$H/.claude/projects/-demo-$1 file
  mkdir -p $dir
  file=$dir/$(uuid).jsonl
  print -r -- "{\"type\":\"user\",\"cwd\":\"$H/code/$1\",\"message\":{\"content\":\"$3\"}}" > $file
  print -r -- "{\"type\":\"ai-title\",\"aiTitle\":\"$2\"}" >> $file
  touch -t $(date -v-$4 +%Y%m%d%H%M.%S) $file
}
recent acme-web "Upgrade to React 19" "Upgrade the app to React 19" 2H
recent api-server "Stripe webhooks" "Handle Stripe webhooks for refunds" 5H
recent acme-web "Slow dashboard query" "Why is the dashboard slow to load?" 1d
recent docs "Onboarding guide" "Write an onboarding guide for new developers" 3d
recent api-server "CI caching" "Cache dependencies in CI" 6d

# The demo shares omux's settings file, where macOS also keeps window and sidebar sizes.
# Settings given on the command line below aren't saved, but window bookkeeping is, so the
# file is put back once the demo has quit. (Don't override settings the app writes back,
# like showMenuBar: that would be saved.)
PREFS=$DEMO/prefs-backup.plist
defaults export net.pf1.omux $PREFS

send() { # command for the demo omux only
  osascript -l JavaScript -e "ObjC.import('Foundation'); \$.NSDistributedNotificationCenter.defaultCenter.postNotificationNameObjectUserInfoDeliverImmediately('net.pf1.omux.debug.demo', '$1', \$(), true)" >/dev/null
}

HOME=$H CFFIXED_USER_HOME=$H OMUX_DEBUG_CHANNEL=demo OMUX_DEMO_USAGE="5h=38,Week=21" \
  $APP/Contents/MacOS/omux \
  -debugHooks '<true/>' -autoResume '<true/>' -gridMode '<true/>' -showFiles '<false/>' \
  -theme tokyoNight -fontSize '<real>12</real>' -showFolderPath '<true/>' -recentCollapsed '<false/>' \
  -confirmQuit '<false/>' \
  -notifyNeedsYou '<false/>' -notifyDone '<false/>' -notifyPrograms '<false/>' \
  >$DEMO/omux.log 2>&1 &
PID=$!
cleanup() {
  kill $PID 2>/dev/null || true
  wait $PID 2>/dev/null || true
  defaults import net.pf1.omux $PREFS
  defaults export net.pf1.omux $DEMO/prefs-after.plist
  if ! cmp -s <(plutil -convert xml1 -o - $PREFS) <(plutil -convert xml1 -o - $DEMO/prefs-after.plist); then
    echo "Note: omux settings differ from before the demo; compare $PREFS and $DEMO/prefs-after.plist" >&2
    return
  fi
  [[ -n $KEEP ]] || rm -rf $DEMO
}
trap cleanup EXIT

sleep 4
send size:1440x900
sleep 4
SNAP=$H/Library/Caches/net.pf1.omux/snapshots
rm -rf $SNAP
send snapshot
for i in {1..20}; do [[ -f $SNAP/window.png ]] && break; sleep 0.5; done
[[ -f $SNAP/window.png ]] || { echo "No capture; see $DEMO/omux.log" >&2; exit 1; }
cp $SNAP/window.png $OUT
send quit
for i in {1..20}; do kill -0 $PID 2>/dev/null || break; sleep 0.5; done
echo "Saved $OUT ($(sips -g pixelWidth -g pixelHeight $OUT | awk '/pixel/ {printf "%s ", $2}'))"
