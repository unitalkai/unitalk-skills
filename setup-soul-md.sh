#!/usr/bin/env bash
#
# setup-soul-md.sh -- SOUL.md provisioning script
#
# Replaces /opt/data/SOUL.md with the SOUL.md bundled in this repository.
#
# Usage:
#   ./setup-soul-md.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HERMES_HOME="/opt/data"
SOURCE_SOUL="${SCRIPT_DIR}/SOUL.md"
TARGET_SOUL="${HERMES_HOME}/SOUL.md"

echo "==> Setting up ${TARGET_SOUL}..."

if [[ "$(id -u)" -ne 0 ]]; then
	echo "ERROR: This script must be run as root (or with sudo)."
	exit 1
fi

if [[ ! -f "${SOURCE_SOUL}" ]]; then
	echo "ERROR: Source SOUL.md not found at ${SOURCE_SOUL}"
	exit 1
fi

mkdir -p "${HERMES_HOME}"
rm -f "${TARGET_SOUL}"
cp "${SOURCE_SOUL}" "${TARGET_SOUL}"

# ─── Grant permissions to hermes user ─────────────────────────────────────

echo ""
echo "==> Granting ownership of ${TARGET_SOUL} to hermes:hermes..."
chown hermes:hermes "${TARGET_SOUL}"
chmod u+rw "${TARGET_SOUL}"

echo "    Installed ${TARGET_SOUL}."
