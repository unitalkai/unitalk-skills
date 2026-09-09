#!/usr/bin/env bash
#
# setup.sh — Hermes Skills Provisioning Script
#
# Updates repository-provided skill directories in /opt/data/skills and installs
# all prerequisites: OS packages, Python libraries, and Node.js global packages.
#
# Usage:
#   ./setup.sh              # Required deps only
#   ./setup.sh --all        # Required + optional deps (OCR, pdftk, etc.)
#   ./setup.sh --help       # Show help
#

set -euo pipefail

# ─── Configuration ───────────────────────────────────────────────────────────

HERMES_ROOT="${HERMES_ROOT:-/opt/hermes}"
HERMES_HOME="${HERMES_HOME:-/opt/data}"
SKILLS_DIR="${HERMES_HOME}/skills"
MANAGED_SKILLS_DIR="${HERMES_HOME}/unitalk-skills"
MANAGED_SKILLS_STAGE="${HERMES_HOME}/.unitalk-skills.next"
LAYOUT_MARKER="${HERMES_HOME}/.unitalk-skills-layout-v2"
MIGRATION_BACKUP_ROOT="${HERMES_HOME}/migration-backups"
MIGRATION_BACKUP_DIR="${MIGRATION_BACKUP_ROOT}/skills-layout-v1"
VENV_PYTHON="${HERMES_ROOT}/.venv/bin/python"
VENV_PIP="${HERMES_ROOT}/.venv/bin/pip"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

INSTALL_ALL=false
NEEDS_LAYOUT_MIGRATION=false

# ─── Help ────────────────────────────────────────────────────────────────────

usage() {
	cat <<'EOF'
Usage: ./setup.sh [--all] [--help]

  --all      Also install optional/legacy dependencies (pdftk-java, tesseract,
             pytesseract, numpy).
  --help     Show this message.
EOF
	exit 0
}

for arg in "$@"; do
	case "$arg" in
		--all)  INSTALL_ALL=true ;;
		--help) usage ;;
		*)      echo "Unknown argument: $arg"; usage ;;
	esac
done

# ─── Pre-flight checks ──────────────────────────────────────────────────────

echo "==> Running pre-flight checks..."

if [[ "$(id -u)" -ne 0 ]]; then
	echo "ERROR: This script must be run as root (or with sudo)."
	exit 1
fi

mkdir -p "${HERMES_HOME}"
if [[ -L "${HERMES_HOME}" || -L "${SKILLS_DIR}" || -L "${MANAGED_SKILLS_DIR}" || -L "${LAYOUT_MARKER}" || -L "${MIGRATION_BACKUP_ROOT}" ]]; then
	echo "ERROR: Refusing to provision through symlinked Hermes data paths."
	exit 1
fi
LOCK_DIR="${UNITALK_LOCK_DIR:-/run/lock}"
mkdir -p "${LOCK_DIR}"
exec 9>"${LOCK_DIR}/unitalk-skills-$(stat -c '%d-%i' "${HERMES_HOME}").lock"
if ! flock -n 9; then
	echo "ERROR: Another Unitalk skills setup is already running."
	exit 1
fi


# ─── Provision managed skills and migrate the legacy layout ──────────────

echo ""
echo "==> Setting up Hermes skills..."

# Hermes re-seeds bundled skills on startup unless the active profile opts out.
# Opt-out is non-interactive and leaves all existing skills untouched.
echo "    Opting out of Hermes bundled-skill seeding..."
HERMES_HOME="${HERMES_HOME}" "${HERMES_ROOT}/.venv/bin/hermes" skills opt-out || {
	echo "ERROR: Failed to opt out of Hermes bundled-skill seeding."
	exit 1
}

mkdir -p "${SKILLS_DIR}"

if [[ ! -f "${LAYOUT_MARKER}" ]]; then
	NEEDS_LAYOUT_MIGRATION=true
fi

# Configure discovery before moving any legacy skill. Write atomically so an
# interrupted deployment cannot truncate unrelated Hermes configuration.
CONFIG_PATH="${HERMES_HOME}/config.yaml"
echo "    Configuring managed skill discovery..."
"${VENV_PYTHON}" - "${CONFIG_PATH}" "${MANAGED_SKILLS_DIR}" "${NEEDS_LAYOUT_MIGRATION}" <<'PY' || {
import os
import sys
import tempfile

import yaml

config_path, managed_dir, migrate = sys.argv[1:]
config = {}
if os.path.exists(config_path):
    with open(config_path, encoding="utf-8") as source:
        config = yaml.safe_load(source) or {}
if not isinstance(config, dict):
    raise TypeError("config.yaml root must be a mapping")

skills = config.setdefault("skills", {})
if not isinstance(skills, dict):
    raise TypeError("config.yaml skills value must be a mapping")

external_dirs = skills.get("external_dirs") or []
if isinstance(external_dirs, str):
    external_dirs = [external_dirs]
if not isinstance(external_dirs, list) or not all(isinstance(item, str) for item in external_dirs):
    raise TypeError("skills.external_dirs must be a string or list of strings")
if managed_dir not in external_dirs:
    external_dirs.append(managed_dir)
skills["external_dirs"] = external_dirs

disabled = skills.get("disabled") or []
if isinstance(disabled, str):
    disabled = [disabled]
if not isinstance(disabled, list) or not all(isinstance(item, str) for item in disabled):
    raise TypeError("skills.disabled must be a string or list of strings")
if migrate == "true":
    legacy_disabled = {"blogwatcher", "llm-wiki", "arxiv", "excalidraw", "obsidian"}
    disabled = [name for name in disabled if name not in legacy_disabled]
skills["disabled"] = sorted(set(disabled))

config_dir = os.path.dirname(config_path)
fd, temporary_path = tempfile.mkstemp(prefix=".config.yaml.", dir=config_dir, text=True)
try:
    with os.fdopen(fd, "w", encoding="utf-8") as target:
        yaml.safe_dump(config, target, default_flow_style=False, sort_keys=False)
        target.flush()
        os.fsync(target.fileno())
    with open(temporary_path, encoding="utf-8") as check:
        yaml.safe_load(check)
    if os.path.exists(config_path):
        stat = os.stat(config_path)
        os.chmod(temporary_path, stat.st_mode)
        os.chown(temporary_path, stat.st_uid, stat.st_gid)
    else:
        import grp
        import pwd
        account = pwd.getpwnam("hermes")
        group = grp.getgrnam("hermes")
        os.chmod(temporary_path, 0o600)
        os.chown(temporary_path, account.pw_uid, group.gr_gid)
    os.replace(temporary_path, config_path)
finally:
    if os.path.exists(temporary_path):
        os.unlink(temporary_path)
PY
	echo "ERROR: Failed to configure managed skill discovery."
	exit 1
}

# Build the managed tree completely before replacing the live copy.
rm -rf "${MANAGED_SKILLS_STAGE}"
mkdir -p "${MANAGED_SKILLS_STAGE}"
echo "    Staging Unitalk-managed skills..."
for category_dir in "${SCRIPT_DIR}"/*/; do
	category_name="$(basename "${category_dir}")"
	# Skip repository directories that are not skill categories.
	[[ "${category_name}" == "PREREQUESITES-DEPENDENCIES" || "${category_name}" == "profiles" ]] && continue
	cp -a "${category_dir}" "${MANAGED_SKILLS_STAGE}/${category_name}"
done
chown -R root:root "${MANAGED_SKILLS_STAGE}"
chmod -R a+rX,u+w,go-w "${MANAGED_SKILLS_STAGE}"

# Existing installations stored Unitalk and user skills together. On the first
# split-layout run, back up and remove only exact paths owned by this repository.
# Unknown paths remain in the user-writable local skills directory.
if [[ "${NEEDS_LAYOUT_MIGRATION}" == true ]]; then
	echo "    Migrating legacy Unitalk skills out of ${SKILLS_DIR}..."
	mkdir -p "${MIGRATION_BACKUP_ROOT}"
	chown root:root "${MIGRATION_BACKUP_ROOT}"
	chmod 0700 "${MIGRATION_BACKUP_ROOT}"
	mkdir -p "${MIGRATION_BACKUP_DIR}"
	MIGRATION_IN_PROGRESS=true
	rollback_migration() {
		if [[ "${MIGRATION_IN_PROGRESS}" != true ]]; then
			return
		fi
		while IFS= read -r -d '' backup_skill_md; do
			relative_skill="${backup_skill_md#"${MIGRATION_BACKUP_DIR}/"}"
			relative_skill="${relative_skill%/SKILL.md}"
			backup_skill="${MIGRATION_BACKUP_DIR}/${relative_skill}"
			legacy_skill="${SKILLS_DIR}/${relative_skill}"
			if [[ ! -e "${legacy_skill}" ]]; then
				mkdir -p "$(dirname "${legacy_skill}")"
				mv "${backup_skill}" "${legacy_skill}"
			fi
		done < <(find "${MIGRATION_BACKUP_DIR}" -type f -name SKILL.md -print0)
		while IFS= read -r -d '' backup_description; do
			relative_description="${backup_description#"${MIGRATION_BACKUP_DIR}/"}"
			legacy_description="${SKILLS_DIR}/${relative_description}"
			if [[ ! -e "${legacy_description}" ]]; then
				mkdir -p "$(dirname "${legacy_description}")"
				mv "${backup_description}" "${legacy_description}"
			fi
		done < <(find "${MIGRATION_BACKUP_DIR}" -type f -name DESCRIPTION.md -print0)
	}
	trap rollback_migration EXIT
	while IFS= read -r -d '' skill_md; do
		relative_skill="${skill_md#"${MANAGED_SKILLS_STAGE}/"}"
		relative_skill="${relative_skill%/SKILL.md}"
		legacy_skill="${SKILLS_DIR}/${relative_skill}"
		backup_skill="${MIGRATION_BACKUP_DIR}/${relative_skill}"

		if [[ -d "${legacy_skill}" ]]; then
			mkdir -p "$(dirname "${backup_skill}")"
			if [[ -e "${backup_skill}" ]]; then
				echo "ERROR: Migration backup already exists for ${relative_skill}; refusing to remove the local copy."
				exit 1
			fi
			mv "${legacy_skill}" "${backup_skill}"
			echo "      Migrated ${relative_skill}"
		fi
	done < <(find "${MANAGED_SKILLS_STAGE}" -type f -name SKILL.md -print0)

	# Category descriptions are managed too, but category directories may also
	# contain custom skills and therefore must never be removed wholesale.
	while IFS= read -r -d '' description; do
		relative_description="${description#"${MANAGED_SKILLS_STAGE}/"}"
		legacy_description="${SKILLS_DIR}/${relative_description}"
		backup_description="${MIGRATION_BACKUP_DIR}/${relative_description}"

		if [[ -f "${legacy_description}" ]]; then
			mkdir -p "$(dirname "${backup_description}")"
			if [[ -e "${backup_description}" ]]; then
				echo "ERROR: Migration backup already exists for ${relative_description}; refusing to remove the local copy."
				exit 1
			fi
			mv "${legacy_description}" "${backup_description}"
		fi
	done < <(find "${MANAGED_SKILLS_STAGE}" -type f -name DESCRIPTION.md -print0)
fi

# This tree contains no user data, so every deployment can replace it. Keep the
# previous tree until the staged copy has been published successfully.
MANAGED_SKILLS_PREVIOUS="${MANAGED_SKILLS_DIR}.previous"
if [[ ! -d "${MANAGED_SKILLS_DIR}" && -d "${MANAGED_SKILLS_PREVIOUS}" ]]; then
	mv "${MANAGED_SKILLS_PREVIOUS}" "${MANAGED_SKILLS_DIR}"
fi
rm -rf "${MANAGED_SKILLS_PREVIOUS}"
if [[ -d "${MANAGED_SKILLS_DIR}" ]]; then
	mv "${MANAGED_SKILLS_DIR}" "${MANAGED_SKILLS_PREVIOUS}"
fi
if ! mv "${MANAGED_SKILLS_STAGE}" "${MANAGED_SKILLS_DIR}"; then
	[[ -d "${MANAGED_SKILLS_PREVIOUS}" ]] && mv "${MANAGED_SKILLS_PREVIOUS}" "${MANAGED_SKILLS_DIR}"
	echo "ERROR: Failed to publish Unitalk-managed skills."
	exit 1
fi
rm -rf "${MANAGED_SKILLS_PREVIOUS}"

# The destructive part of the legacy migration is complete. Record it now so
# later dependency failures cannot cause the migration to run a second time.
# Use Hermes's own manifest/hash checks to remove byte-identical bundled skills
# only after the replacement managed tree is live.
echo "    Removing unmodified Hermes bundled skills..."
HERMES_HOME="${HERMES_HOME}" PYTHONPATH="${HERMES_ROOT}${PYTHONPATH:+:${PYTHONPATH}}" "${VENV_PYTHON}" -c '
from tools.skills_sync import remove_pristine_bundled_skills

result = remove_pristine_bundled_skills(dry_run=False)
removed = result.get("removed", [])
kept = result.get("skipped", [])
failures = [item for item in kept if "delete failed" in str(item).lower()]
print(f"    Removed {len(removed)} unmodified bundled skill(s).")
if kept:
    print(f"    Preserved {len(kept)} modified or unowned skill(s).")
if failures:
    raise RuntimeError(f"Failed to remove bundled skills: {failures}")
' || {
	echo "ERROR: Failed to remove unmodified Hermes bundled skills."
	exit 1
}

if [[ "${NEEDS_LAYOUT_MIGRATION}" == true ]]; then
	MARKER_STAGE="$(mktemp "${HERMES_HOME}/.unitalk-layout.XXXXXX")"
	chmod 0644 "${MARKER_STAGE}"
	mv "${MARKER_STAGE}" "${LAYOUT_MARKER}"
	MIGRATION_IN_PROGRESS=false
	trap - EXIT
fi

echo "    Unitalk skill categories installed:"
find "${MANAGED_SKILLS_DIR}" -maxdepth 1 -mindepth 1 -type d | sort | while read -r d; do
	echo "      $(basename "$d")"
done

# ─── Bootstrap pip ──────────────────────────────────────────────────────────

echo ""
echo "==> Setting up pip in the Hermes virtual environment..."

if [[ ! -x "${VENV_PYTHON}" ]]; then
	echo "ERROR: Python not found at ${VENV_PYTHON}"
	echo "       Make sure the Hermes virtual environment exists before running this script."
	exit 1
fi

if "${VENV_PIP}" --version &>/dev/null; then
	echo "    pip is already available — skipping ensurepip."
else
	echo "    Running ensurepip..."
	"${VENV_PYTHON}" -m ensurepip --default-pip || {
		echo "WARNING: ensurepip failed. Attempting to install pip via apt..."
		apt-get update -qq && apt-get install -y -qq python3-pip
		# Recreate the venv pip symlink / bootstrap if needed
		"${VENV_PYTHON}" -m ensurepip --default-pip || {
			echo "ERROR: Could not bootstrap pip. Aborting."
			exit 1
		}
	}
	echo "    Upgrading pip..."
	"${VENV_PIP}" install --upgrade pip -q
fi

# ─── OS packages ────────────────────────────────────────────────────────────

echo ""
echo "==> Installing OS-level dependencies..."

apt-get update -qq

# Required packages (consolidated from all skills, deduplicated)
REQUIRED_PKGS=(
	# docx
	pandoc
	libreoffice-core
	poppler-utils
	gcc
	# pdf (additional)
	qpdf
	imagemagick
	# pptx (additional)
	libreoffice-impress
)

# Optional / legacy packages
OPTIONAL_PKGS=(
	tesseract-ocr       # OCR engine for pytesseract (pdf)
	pdftk-java          # Legacy PDF toolkit (pdf)
)

echo "    Installing required packages: ${REQUIRED_PKGS[*]}"
apt-get install -y -qq "${REQUIRED_PKGS[@]}" || {
	echo "ERROR: Failed to install required OS packages."
	exit 1
}

if [[ "${INSTALL_ALL}" == true ]]; then
	echo ""
	echo "    Installing optional packages: ${OPTIONAL_PKGS[*]}"
	apt-get install -y -qq "${OPTIONAL_PKGS[@]}" || {
		echo "WARNING: Some optional packages failed to install — continuing."
	}
fi

# Verify critical binaries are on PATH
echo ""
echo "    Verifying critical binaries..."
CRITICAL_BINS=(pandoc soffice pdftoppm gcc)
for bin in "${CRITICAL_BINS[@]}"; do
	if command -v "${bin}" &>/dev/null; then
		echo "      ✓ ${bin} ($(command -v "${bin}"))"
	else
		echo "      ✗ ${bin} NOT FOUND — some functionality will not work."
	fi
done

# ─── Python packages ────────────────────────────────────────────────────────

echo ""
echo "==> Installing Python dependencies..."

# Core Python packages (required, deduplicated across all skills)
CORE_PYTHON=(
	# docx
	defusedxml
	lxml
	python-docx
	# pdf
	pypdf
	pdfplumber
	pdf2image
	Pillow
	reportlab
	pypdfium2
	pandas
	# nano-pdf
	nano-pdf
	# pptx / powerpoint
	markitdown[all]
	python-pptx
	# xlsx
	openpyxl
	# config management
	PyYAML
)

echo "    Installing core packages into venv: ${CORE_PYTHON[*]}"
"${VENV_PIP}" install "${CORE_PYTHON[@]}" -q || {
	echo "ERROR: Failed to install core Python packages into venv."
	exit 1
}

# Also install into system Python so that `python -m markitdown` and similar
# ad-hoc commands work without needing to activate the venv.
echo "    Installing core packages into system Python: ${CORE_PYTHON[*]}"
SYSTEM_PIP="$(command -v pip3 || command -v pip || echo '')"
if [[ -n "${SYSTEM_PIP}" ]]; then
	"${SYSTEM_PIP}" install "${CORE_PYTHON[@]}" -q || {
		echo "WARNING: Failed to install some packages into system Python — continuing."
	}
else
	echo "WARNING: No system pip found — skipping system Python install."
	echo "         Agents must use ${VENV_PYTHON} instead of bare 'python'."
fi

# Optional Python packages
OPTIONAL_PYTHON=(
	pytesseract
	numpy
)

if [[ "${INSTALL_ALL}" == true ]]; then
	echo ""
	echo "    Installing optional packages into venv: ${OPTIONAL_PYTHON[*]}"
	"${VENV_PIP}" install "${OPTIONAL_PYTHON[@]}" -q || {
		echo "WARNING: Some optional Python packages failed to install into venv — continuing."
	}
	if [[ -n "${SYSTEM_PIP}" ]]; then
		echo "    Installing optional packages into system Python: ${OPTIONAL_PYTHON[*]}"
		"${SYSTEM_PIP}" install "${OPTIONAL_PYTHON[@]}" -q || {
			echo "WARNING: Some optional packages failed to install into system Python — continuing."
		}
	fi
fi

echo "    Verifying key Python imports (venv)..."
KEY_IMPORTS=(defusedxml lxml docx pypdf pdfplumber pdf2image PIL reportlab pypdfium2 pandas markitdown pptx openpyxl)
for mod in "${KEY_IMPORTS[@]}"; do
	if "${VENV_PYTHON}" -c "import ${mod}" 2>/dev/null; then
		echo "      ✓ ${mod} (venv)"
	else
		echo "      ✗ ${mod} FAILED TO IMPORT in venv"
	fi
done

echo "    Verifying key Python imports (system)..."
SYSTEM_PYTHON="$(command -v python3 || command -v python || echo '')"
if [[ -n "${SYSTEM_PYTHON}" ]]; then
	for mod in "${KEY_IMPORTS[@]}"; do
		if "${SYSTEM_PYTHON}" -c "import ${mod}" 2>/dev/null; then
			echo "      ✓ ${mod} (system)"
		else
			echo "      ✗ ${mod} FAILED TO IMPORT in system Python"
		fi
	done
else
	echo "    WARNING: No system Python found — skipping verification."
fi

# ─── Node.js & NPM global packages ──────────────────────────────────────────

echo ""
echo "==> Checking Node.js / npm..."

NPM_GLOBAL_PKGS=(
	# docx
	docx
	# pptx
	pptxgenjs
	react-icons
	react
	react-dom
	sharp
)

if command -v node &>/dev/null && command -v npm &>/dev/null; then
	echo "    Node.js $(node --version) / npm $(npm --version) detected."

	echo "    Installing global npm packages: ${NPM_GLOBAL_PKGS[*]}"
	npm install -g "${NPM_GLOBAL_PKGS[@]}" -q 2>&1 || {
		echo "WARNING: Some npm packages failed to install. Check npm output above."
	}

	echo "    Verifying key npm packages..."
	for pkg in docx pptxgenjs react-icons react react-dom sharp; do
		if node -e "require('${pkg}')" 2>/dev/null; then
			echo "      ✓ ${pkg}"
		else
			echo "      ✗ ${pkg} NOT FOUND"
		fi
	done
else
	echo "    WARNING: Node.js or npm not found on PATH."
	echo "    The following npm packages were SKIPPED: ${NPM_GLOBAL_PKGS[*]}"
	echo "    Install Node.js first (e.g., 'apt install nodejs npm') and re-run this script."
fi

# ─── Grant permissions to hermes user ─────────────────────────────────────

echo ""
echo "==> Granting ownership of ${SKILLS_DIR} to hermes:hermes..."
chown -R hermes:hermes "${SKILLS_DIR}" || {
	echo "WARNING: Failed to chown skills directory — continuing."
}

# Managed skills are readable by Hermes but writable only by provisioning.
chown -R root:root "${MANAGED_SKILLS_DIR}" || {
	echo "ERROR: Failed to set ownership on managed skills."
	exit 1
}
chmod -R a+rX,u+w,go-w "${MANAGED_SKILLS_DIR}" || {
	echo "ERROR: Failed to set permissions on managed skills."
	exit 1
}

# ─── Done ───────────────────────────────────────────────────────────────────

echo ""
echo "========================================"
echo "  Hermes Skills setup complete!"
echo "  User skills: ${SKILLS_DIR}"
echo "  Managed skills: ${MANAGED_SKILLS_DIR}"
echo "  Python: ${VENV_PYTHON}"
echo "  Run with --all next time for optional deps"
echo "========================================"
