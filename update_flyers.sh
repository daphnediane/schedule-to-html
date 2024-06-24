#!/bin/bash

set -eo pipefail

# Globals
declare DRYRUN=""
declare YEAR="2024"
declare EXCEL_FILE="${YEAR} Schedule.xlsx"
declare PATH=/opt/local/bin:${SCRIPT_DIR}:$PATH
declare SCRIPT_DIR=${SCRIPT_PATH%/*}
declare SCRIPT_PATH=$(realpath "$0")
declare SRC_DIR=~/"Library/CloudStorage/OneDrive-Personal/Cosplay America - Daphne/${YEAR}/Schedule"
declare KIOSK_DESC=~/"Library/CloudStorage/OneDrive-Personal/Cosplay America - Daphne/${YEAR}/Kiosk"
declare OUTPUT_DIR="output/flyers"
declare KIOSK_DIR="kiosk"

# Functions
fail() {
    echo "$@" >&2
    exit 1
}

usage() {
    echo "Usage: $0 [--dry-run]"
    exit 1
}

cmd() {
    local args=("$@")
    echo "${args[@]}"
    [[ -z "${DRYRUN:-}" ]] || return 0
    "${args[@]}"
}

main() {
    while [ $# -gt 0 ]; do
        case "$1" in
        --dry-run | -n)
            DRYRUN="echo"
            shift
            ;;
        *)
            usage
            ;;
        esac
    done

    [[ -d "${OUTPUT_DIR}" ]] || fail "output/flyers not found"

    # Remove old schedule
    cmd find "${OUTPUT_DIR}" -name '*.html' -exec ${DRYRUN} rm -v {} + || true

    # Update schedule from one drive
    cmd rsync -aPHAX "${SRC_DIR}/${EXCEL_FILE}" "input/${EXCEL_FILE}"
    SRC_DATE="$(date -r "input/${EXCEL_FILE}" +'%b %d %I:%M %p')"

    # Generate new schedule
    cmd ./dump_flyers --title "Cosplay America ${YEAR} Schedule Draft, Updated: ${SRC_DATE}"

    # Output schedule
    cmd rsync -aPHAX --delete-after "${OUTPUT_DIR}/" "${SRC_DIR}/COS${YEAR}Schedule/html/"

    # Output kiosk
    cmd rsync -aPHAX --delete-after "${KIOSK_DIR}/" "${KIOSK_DESC}/COS${YEAR}-Kiosk/"
}

main "$@"
