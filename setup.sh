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
VENV_PYTHON="${HERMES_ROOT}/.venv/bin/python"
VENV_PIP="${HERMES_ROOT}/.venv/bin/pip"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

INSTALL_ALL=false

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
if [[ -L "${HERMES_HOME}" || -L "${SKILLS_DIR}" ]]; then
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

if [[ ! -x "${VENV_PYTHON}" ]]; then
	echo "ERROR: Python not found at ${VENV_PYTHON}"
	exit 1
fi

if [[ ! -x "${HERMES_ROOT}/.venv/bin/hermes" ]]; then
	echo "ERROR: Hermes CLI not found at ${HERMES_ROOT}/.venv/bin/hermes"
	exit 1
fi


# ─── Add missing repository skills ────────────────────────────────────────

echo ""
echo "==> Setting up Hermes skills..."

# Stage and validate the complete repository before making any changes to the
# installed skills. This ensures bundled cleanup is never followed by a failed
# repository discovery or source copy.
SKILLS_STAGE="$(mktemp -d "${HERMES_HOME}/.unitalk-skills.XXXXXX")"
cleanup_skills_stage() {
	rm -rf "${SKILLS_STAGE}"
}
trap cleanup_skills_stage EXIT

echo "    Staging repository skills..."
for category_dir in "${SCRIPT_DIR}"/*/; do
	category_name="$(basename "${category_dir}")"
	[[ "${category_name}" == "PREREQUESITES-DEPENDENCIES" || "${category_name}" == "profiles" ]] && continue
	cp -a "${category_dir}" "${SKILLS_STAGE}/${category_name}"
done

mapfile -d '' REPOSITORY_SKILL_FILES < <(find "${SKILLS_STAGE}" -type f -name SKILL.md -print0)
REPOSITORY_SKILLS="${#REPOSITORY_SKILL_FILES[@]}"

if [[ "${REPOSITORY_SKILLS}" -eq 0 ]]; then
	echo "ERROR: No repository skills were found."
	exit 1
fi

mkdir -p "${SKILLS_DIR}"
chown hermes:hermes "${SKILLS_DIR}"

# Hermes re-seeds bundled skills on startup unless the active profile opts out.
# Opt-out is non-interactive and leaves all existing skills untouched.
echo "    Opting out of Hermes bundled-skill seeding..."
HERMES_HOME="${HERMES_HOME}" "${HERMES_ROOT}/.venv/bin/hermes" skills opt-out || {
	echo "ERROR: Failed to opt out of Hermes bundled-skill seeding."
	exit 1
}

# Use Hermes's own manifest/hash checks to remove byte-identical bundled skills
# without invoking the CLI confirmation prompt. Modified bundled skills and
# untracked custom skills are preserved by Hermes.
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

INSTALLED_SKILLS=0
EXISTING_SKILLS=0

echo "    Adding missing repository skills..."
for skill_md in "${REPOSITORY_SKILL_FILES[@]}"; do
	source_skill="$(dirname "${skill_md}")"
	relative_skill="${source_skill#"${SKILLS_STAGE}/"}"
	target_skill="${SKILLS_DIR}/${relative_skill}"

	if [[ -e "${target_skill}" || -L "${target_skill}" ]]; then
		EXISTING_SKILLS=$((EXISTING_SKILLS + 1))
		continue
	fi

	target_parent="$(dirname "${target_skill}")"
	resolved_parent="$(realpath -m "${target_parent}")"
	case "${resolved_parent}/" in
		"$(realpath -m "${SKILLS_DIR}")"/*) ;;
		*)
			echo "ERROR: Refusing to install ${relative_skill} through a path outside ${SKILLS_DIR}."
			exit 1
			;;
	esac
	if [[ ! -d "${target_parent}" ]]; then
		mkdir -p "${target_parent}"
		chown hermes:hermes "${target_parent}"
	fi
	chown -R hermes:hermes "${source_skill}"
	mv -T -n "${source_skill}" "${target_skill}"
	if [[ -e "${source_skill}" ]]; then
		EXISTING_SKILLS=$((EXISTING_SKILLS + 1))
		continue
	fi
	if [[ ! -d "${target_skill}" ]]; then
		echo "ERROR: Failed to install ${relative_skill}."
		exit 1
	fi
	INSTALLED_SKILLS=$((INSTALLED_SKILLS + 1))
	echo "      Installed ${relative_skill}"
done

while IFS= read -r -d '' description; do
	relative_description="${description#"${SKILLS_STAGE}/"}"
	target_description="${SKILLS_DIR}/${relative_description}"
	if [[ ! -e "${target_description}" && ! -L "${target_description}" ]]; then
		target_parent="$(dirname "${target_description}")"
		resolved_parent="$(realpath -m "${target_parent}")"
		case "${resolved_parent}/" in
			"$(realpath -m "${SKILLS_DIR}")"/*) ;;
			*)
				echo "ERROR: Refusing to install ${relative_description} through a path outside ${SKILLS_DIR}."
				exit 1
				;;
		esac
		mkdir -p "${target_parent}"
		staged_description="$(mktemp "${target_parent}/.DESCRIPTION.md.XXXXXX")"
		cp -a "${description}" "${staged_description}"
		chown hermes:hermes "${staged_description}"
		# A hard link provides create-if-absent semantics. If another process
		# wins the race, its file remains untouched.
		ln "${staged_description}" "${target_description}" 2>/dev/null || true
		rm -f "${staged_description}"
	fi
done < <(find "${SKILLS_STAGE}" -mindepth 2 -maxdepth 2 -type f -name DESCRIPTION.md -print0)

cleanup_skills_stage
trap - EXIT

echo "    Repository skills: ${REPOSITORY_SKILLS}"
echo "    Newly installed: ${INSTALLED_SKILLS}"
echo "    Already present: ${EXISTING_SKILLS}"

# ─── Bootstrap pip ──────────────────────────────────────────────────────────

echo ""
echo "==> Setting up pip in the Hermes virtual environment..."

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

# ─── Remove legacy managed skills directory ────────────────────────────────

LEGACY_MANAGED_SKILLS_DIR="${HERMES_HOME}/unitalk-skills"

if [[ -L "${LEGACY_MANAGED_SKILLS_DIR}" ]]; then
	echo "ERROR: Refusing to remove symlinked legacy skills path: ${LEGACY_MANAGED_SKILLS_DIR}"
	exit 1
elif [[ -d "${LEGACY_MANAGED_SKILLS_DIR}" ]]; then
	echo ""
	echo "==> Removing legacy skills directory ${LEGACY_MANAGED_SKILLS_DIR}..."
	rm -rf "${LEGACY_MANAGED_SKILLS_DIR}"
fi

# ─── Done ───────────────────────────────────────────────────────────────────

echo ""
echo "========================================"
echo "  Hermes Skills setup complete!"
echo "  Skills directory: ${SKILLS_DIR}"
echo "  Repository skills: ${REPOSITORY_SKILLS}"
echo "  Newly installed: ${INSTALLED_SKILLS}"
echo "  Already present: ${EXISTING_SKILLS}"
echo "  Python: ${VENV_PYTHON}"
echo "  Run with --all next time for optional deps"
echo "========================================"
