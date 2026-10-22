#!/bin/sh
# Tests scripts/fetch-db.sh against a fake gh, each case in a scratch copy of the layout the script expects.
set -u
script="$(cd "$(dirname "$0")/.." && pwd)/fetch-db.sh"
failures=0

sha256() { printf '%s' "$1" | shasum -a 256 | cut -d' ' -f1; }

# A fake drevo-db with main.1 in release db-1-1 and patch.2 in db-1-2, and a db.lock pinning both.
setup() {
    work=$(mktemp -d)
    mkdir -p "$work/scripts" "$work/bin" "$work/releases/db-1-1" "$work/releases/db-1-2"
    cp "$script" "$work/scripts/fetch-db.sh"
    printf main >"$work/releases/db-1-1/main.1.ru.drevoinfo.obb"
    printf patch >"$work/releases/db-1-2/patch.2.ru.drevoinfo.obb"
    cat >"$work/db.lock" <<EOF
DB_RELEASE=db-1-2
MAIN_RELEASE=db-1-1
MAIN_SHA256=$(sha256 main)
PATCH_SHA256=$(sha256 patch)
EOF
    cat >"$work/bin/gh" <<'EOF'
#!/bin/sh
# Serves `gh release download <tag> -R <repo> -p <asset> -D <dir>` from $FAKE_RELEASES.
echo "$*" >>"$FAKE_GH_LOG"
tag=$3
shift 3
while [ $# -gt 0 ]; do
    case $1 in
        -p) asset=$2 ;;
        -D) dir=$2 ;;
    esac
    shift 2
done
cp "$FAKE_RELEASES/$tag/$asset" "$dir/$asset"
EOF
    chmod +x "$work/bin/gh"
    db="$work/Drevo/Resources/Database"
    : >"$work/gh.log"
}

run() {
    PATH="$work/bin:$PATH" FAKE_RELEASES="$work/releases" FAKE_GH_LOG="$work/gh.log" \
        "$work/scripts/fetch-db.sh" "$@" >"$work/out.log" 2>&1
}

fail() {
    echo "FAIL: $case: $1"
    sed 's/^/    /' "$work/out.log"
    failures=$((failures + 1))
}

calls() { wc -l <"$work/gh.log" | tr -d ' '; }

case="installs both databases under their constant names"
setup
run || fail "exit $?"
[ "$(cat "$db/main.sqlite" 2>/dev/null)" = main ] || fail "main.sqlite not installed"
[ "$(cat "$db/patch.sqlite" 2>/dev/null)" = patch ] || fail "patch.sqlite not installed"
grep -q '^release download db-1-1 -R pravbeseda/drevo-db -p main.1.ru.drevoinfo.obb ' "$work/gh.log" ||
    fail "main not fetched from MAIN_RELEASE"
grep -q '^release download db-1-2 -R pravbeseda/drevo-db -p patch.2.ru.drevoinfo.obb ' "$work/gh.log" ||
    fail "patch not fetched from DB_RELEASE"

case="downloads nothing when both files already match"
run
: >"$work/gh.log"
run || fail "exit $?"
[ "$(calls)" = 0 ] || fail "gh called $(calls) times"

case="replaces a stale file and keeps the current one"
printf old >"$db/patch.sqlite"
: >"$work/gh.log"
run || fail "exit $?"
[ "$(cat "$db/patch.sqlite")" = patch ] || fail "stale patch.sqlite kept"
[ "$(calls)" = 1 ] || fail "gh called $(calls) times, expected 1"

case="refuses a download that does not match db.lock"
setup
printf tampered >"$work/releases/db-1-2/patch.2.ru.drevoinfo.obb"
if run; then fail "exit 0"; fi
[ ! -e "$db/patch.sqlite" ] || fail "mismatching patch.sqlite installed"
grep -q 'patch.2.ru.drevoinfo.obb' "$work/out.log" || fail "error does not name the file"

case="--check fails without downloading when a file is missing"
setup
if run --check; then fail "exit 0"; fi
[ "$(calls)" = 0 ] || fail "gh called $(calls) times"
grep -q 'scripts/fetch-db.sh' "$work/out.log" || fail "error does not say how to fix it"

case="--check passes when both files match"
run
: >"$work/gh.log"
run --check || fail "exit $?"
[ "$(calls)" = 0 ] || fail "gh called $(calls) times"

if [ "$failures" -gt 0 ]; then
    echo "$failures failure(s)"
    exit 1
fi
echo "fetch-db: all cases passed"
