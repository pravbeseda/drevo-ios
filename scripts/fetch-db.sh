#!/bin/sh
# Places the databases db.lock pins under Drevo/Resources/Database/ as main.sqlite and patch.sqlite, downloading
# from the drevo-db releases whatever is missing or does not match its pinned SHA-256.
#
# With --check it downloads nothing and fails unless both files match: the Xcode build phase runs it that way, so a
# build never reaches the network and a db.lock bump without a fetch fails instead of bundling the old databases.
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
# shellcheck source=SCRIPTDIR/../db.lock
. "$root/db.lock"
dir="$root/Drevo/Resources/Database"
check=false
[ "${1:-}" = --check ] && check=true

numbers=${DB_RELEASE#db-}
tmp=
trap 'rm -rf "$tmp"' EXIT

matches() {
    [ -f "$1" ] && [ "$(shasum -a 256 "$1" | cut -d' ' -f1)" = "$2" ]
}

# place <name> <asset> <release> <sha256>
place() {
    target="$dir/$1"
    matches "$target" "$4" && return 0
    if $check; then
        echo "error: $target is missing or is not the database db.lock pins. Run scripts/fetch-db.sh" >&2
        return 1
    fi
    [ -n "$tmp" ] || tmp=$(mktemp -d)
    gh release download "$3" -R pravbeseda/drevo-db -p "$2" -D "$tmp"
    if ! matches "$tmp/$2" "$4"; then
        echo "error: $2 from release $3 does not match its SHA-256 in db.lock" >&2
        return 1
    fi
    mkdir -p "$dir"
    mv "$tmp/$2" "$target"
    echo "Installed $1 ($2 from $3)"
}

place main.sqlite "main.${numbers%-*}.ru.drevoinfo.obb" "$MAIN_RELEASE" "$MAIN_SHA256"
place patch.sqlite "patch.${numbers#*-}.ru.drevoinfo.obb" "$DB_RELEASE" "$PATCH_SHA256"
