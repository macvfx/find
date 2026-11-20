#!/bin/bash
# dev_space_cleanup.sh — see what Xcode and the dev tools are using, and reclaim it safely.
#
#   dev_space_cleanup.sh                 report only (changes nothing)
#   dev_space_cleanup.sh clean           ask per category, then move candidates to the Trash
#   dev_space_cleanup.sh clean --yes     no questions
#   dev_space_cleanup.sh clean --dry-run show what would go, change nothing
#
# Options
#   --days N           archives older than N days are candidates        (default 60)
#   --derived-days N   DerivedData folders untouched for N days         (default 14)
#   --only a,b         limit to: archives,devsupport,derived,caches,simulators
#   --list             also print every candidate path
#
# Rules
#   archives    older than --days, but the newest archive of each app is always kept
#                (an archive holds the only dSYMs for that build)
#   devsupport  device debug symbols; keeps the newest version per device model
#                (Xcode rebuilds one when the device is next connected)
#   derived     build products, always regenerable
#   caches      Xcode and SwiftPM caches, always regenerable
#   simulators  removes only "unavailable" devices; runtimes are listed, never
#                deleted here (that is a choice — see the hint printed)
#
# Also run from find_xcode_projects_cleanup.sh --dev-tools. The same rules are
# implemented in Swift in Code Project Backup (DevToolsCleanupService.swift, in
# the CodeCleanUp repo): change one, change the other.
#
# Everything is moved to the Trash through Finder, so it can be put back. Space is
# freed when the Trash is emptied.

set -u

ARCH_DAYS=60
DERIVED_DAYS=14
CMD=report
DRY=0
YES=0
LIST=0
ONLY=""

while [ $# -gt 0 ]; do
  case "$1" in
    report|clean) CMD=$1 ;;
    --days) ARCH_DAYS=${2:?}; shift ;;
    --derived-days) DERIVED_DAYS=${2:?}; shift ;;
    --only) ONLY=${2:?}; shift ;;
    --yes) YES=1 ;;
    --dry-run) DRY=1 ;;
    --list) LIST=1 ;;
    -h|--help) sed -n '2,29p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $1 (try --help)" >&2; exit 2 ;;
  esac
  shift
done

XC="$HOME/Library/Developer/Xcode"
DD="$XC/DerivedData"
SIM="$HOME/Library/Developer/CoreSimulator"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/devspace.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

fmt() {
  awk -v b="$1" 'BEGIN{n=split("B KB MB GB TB",u," ");i=1;while(b>=1024&&i<n){b/=1024;i++}printf "%.1f %s",b,u[i]}'
}

# total bytes of the paths listed on stdin
sum_bytes() {
  tr '\n' '\0' | xargs -0 du -sk 2>/dev/null | awk '{s+=$1} END{print s*1024+0}'
}

want() {
  [ -z "$ONLY" ] && return 0
  case ",$ONLY," in *",$1,"*) return 0 ;; esac
  return 1
}

trash_paths() {
  # args: paths. Batched so Finder is never handed thousands at once.
  local n=0 batch=()
  for p in "$@"; do
    batch+=("$p"); n=$((n+1))
    if [ $n -ge 40 ]; then trash_batch "${batch[@]}"; batch=(); n=0; fi
  done
  [ $n -gt 0 ] && trash_batch "${batch[@]}"
  return 0
}
trash_batch() {
  osascript - "$@" <<'AS' >/dev/null
on run argv
  set l to {}
  repeat with p in argv
    set end of l to POSIX file (contents of p)
  end repeat
  tell application "Finder" to delete l
end run
AS
}

# ---- candidate finders: print one path per line -------------------------------

py() { python3 -I - "$@" <<'PY'
import os, re, sys, datetime
kind = sys.argv[1]
home = os.path.expanduser('~')

def vkey(v):
    return tuple(int(x) if x.isdigit() else 0 for x in re.split(r'[.\-]', v))

if kind == 'archives':
    days = int(sys.argv[2])
    root = home + '/Library/Developer/Xcode/Archives'
    if not os.path.isdir(root): sys.exit(0)
    cut = (datetime.date.today() - datetime.timedelta(days=days)).isoformat()
    arcs, newest = [], {}
    for d in sorted(os.listdir(root)):
        p = os.path.join(root, d)
        if not (os.path.isdir(p) and re.match(r'\d{4}-\d\d-\d\d$', d)): continue
        for a in os.listdir(p):
            if not a.endswith('.xcarchive'): continue
            n = re.sub(r'-\d.*', '', re.sub(r' \d{4}-\d\d-\d\d.*', '', a[:-10]))
            path = os.path.join(p, a)
            key = (d, os.path.getmtime(path))
            arcs.append((n, d, path))
            if n not in newest or key > newest[n][0]:
                newest[n] = (key, path)
    keep = {v[1] for v in newest.values()}
    for n, d, path in arcs:
        if d < cut and path not in keep:
            print(path)

elif kind == 'devsupport':
    base = home + '/Library/Developer/Xcode'
    if not os.path.isdir(base): sys.exit(0)
    for plat in sorted(os.listdir(base)):
        if not plat.endswith(' DeviceSupport'): continue
        pdir = os.path.join(base, plat)
        groups = {}
        for e in os.listdir(pdir):
            m = re.match(r'(\S+) (\S+) \(', e)
            if m and os.path.isdir(os.path.join(pdir, e)):
                groups.setdefault(m.group(1), []).append((vkey(m.group(2)), e))
        for model, items in groups.items():
            items.sort()
            for _, e in items[:-1]:
                print(os.path.join(pdir, e))
PY
}

cand_archives()  { py archives "$ARCH_DAYS"; }
cand_devsupport() { py devsupport; }
cand_derived() {
  [ -d "$DD" ] && find "$DD" -mindepth 1 -maxdepth 1 -type d -mtime +"$DERIVED_DAYS" 2>/dev/null
  return 0
}
cand_caches() {
  for p in "$HOME/Library/Caches/com.apple.dt.Xcode" \
           "$HOME/Library/Caches/org.swift.swiftpm" \
           "$HOME/Library/Logs/CoreSimulator"; do
    [ -e "$p" ] && echo "$p"
  done
  return 0
}

# ---- one category: report, and optionally clean --------------------------------

TOTAL=0
handle() {
  local key=$1 title=$2 note=$3
  want "$key" || return 0
  "cand_$key" > "$TMP/$key.txt"
  local count bytes
  count=$(grep -c . "$TMP/$key.txt")
  bytes=$(sum_bytes < "$TMP/$key.txt")
  TOTAL=$((TOTAL + bytes))
  printf '\n== %s\n   %s\n   %s candidate(s), %s\n' "$title" "$note" "$count" "$(fmt "$bytes")"
  [ "$LIST" = 1 ] && sed 's/^/     /' "$TMP/$key.txt"
  [ "$CMD" = clean ] && [ "$count" -gt 0 ] || return 0
  if [ "$DRY" = 1 ]; then echo "   (dry run — nothing moved)"; return 0; fi
  if [ "$YES" != 1 ]; then
    printf '   Move these to the Trash? [y/N] '
    read -r ans </dev/tty
    case "$ans" in y|Y|yes) ;; *) echo "   skipped"; return 0 ;; esac
  fi
  local paths=()
  while IFS= read -r l; do paths+=("$l"); done < "$TMP/$key.txt"
  trash_paths "${paths[@]}"
  echo "   moved $count item(s) to the Trash"
}

echo "Dev space — $(date '+%Y-%m-%d %H:%M')   mode: $CMD$([ "$DRY" = 1 ] && echo ' (dry run)')"
echo "Disk free: $(df -h / | awk 'NR==2{print $4}')"

handle archives   "Xcode archives"  "older than $ARCH_DAYS days; newest archive of each app is kept"
handle devsupport "Device support"  "old OS symbols; newest per device model is kept"
handle derived    "DerivedData"     "folders untouched for $DERIVED_DAYS days; rebuilt on next build"
handle caches     "Caches"          "Xcode / SwiftPM caches and simulator logs; rebuilt on demand"

if want simulators; then
  printf '\n== Simulators\n'
  if ! command -v xcrun >/dev/null 2>&1; then
    echo "   xcrun not found"
  else
    unavail=$(xcrun simctl list devices 2>/dev/null | grep -c '(unavailable')
    avail=$(xcrun simctl list devices available 2>/dev/null | grep -c '^    ')
    datab=$(du -sk "$SIM/Devices" 2>/dev/null | awk '{print $1*1024+0}')
    echo "   $avail device(s), $(fmt "${datab:-0}") of device data, $unavail unavailable"
    echo "   Runtimes:"
    xcrun simctl runtime list 2>/dev/null | grep -E '^iOS|^watchOS|^tvOS|^visionOS|^Total' | sed 's/^/     /'
    echo "   Runtimes are never removed here. To delete one:  xcrun simctl runtime delete <id>"
    echo "   To delete a device:  xcrun simctl delete <udid>"
    if [ "$CMD" = clean ] && [ "$unavail" -gt 0 ]; then
      if [ "$DRY" = 1 ]; then echo "   (dry run — unavailable devices kept)"
      else
        ans=y
        [ "$YES" != 1 ] && { printf '   Delete the %s unavailable device(s)? [y/N] ' "$unavail"; read -r ans </dev/tty; }
        case "$ans" in y|Y|yes) xcrun simctl delete unavailable && echo "   deleted unavailable devices" ;; *) echo "   skipped" ;; esac
      fi
    fi
  fi
fi

printf '\nReclaimable by the Trash-based categories above: %s\n' "$(fmt "$TOTAL")"
[ "$CMD" = clean ] && [ "$DRY" != 1 ] && echo "Empty the Trash to actually free the space."
exit 0
