#!/usr/bin/env bash
#
# setup.sh — Hermes Skills Provisioning Script
#
# Copies all skill directories to /opt/data/skills and installs all
# prerequisites: OS packages, Python libraries, and Node.js global packages.
#
# Usage:
#   ./setup.sh              # Required deps only
#   ./setup.sh --all        # Required + optional deps (OCR, pdftk, etc.)
#   ./setup.sh --help       # Show help
#

set -euo pipefail

# ─── Configuration ───────────────────────────────────────────────────────────

HERMES_ROOT="/opt/hermes"
SKILLS_DIR="/opt/data/skills"
VENV_PYTHON="${HERMES_ROOT}/.venv/bin/python"
VENV_PIP="${HERMES_ROOT}/.venv/bin/pip"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

INSTALL_ALL=false

# ─── Help ────────────────────────────────────────────────────────────────────

usage() {
	cat <<'EOF'
Usage: ./setup.sh [--all] [--help]

  --all      Also install optional/legacy dependencies (pdftk-java, tesseract,
             pytesseract, pypdfium2, numpy).
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


# ─── Copy skills to /opt/data/skills ──────────────────────────────────────

echo ""
echo "==> Setting up /opt/data/skills..."

# Remove all existing skills
if [[ -d "${SKILLS_DIR}" ]]; then
	echo "    Removing existing skills..."
	rm -rf "${SKILLS_DIR}"
fi
mkdir -p "${SKILLS_DIR}"

# Copy category directories (excluding PREREQUESITES-DEPENDENCIES/)
echo "    Copying skills..."
for category_dir in "${SCRIPT_DIR}"/*/; do
	category_name="$(basename "${category_dir}")"
	# Skip PREREQUESITES-DEPENDENCIES and any non-skill dirs (like the script itself)
	[[ "${category_name}" == "PREREQUESITES-DEPENDENCIES" ]] && continue
	cp -a "${category_dir}" "${SKILLS_DIR}/${category_name}"
done

echo "    Done. Skill categories installed:"
find "${SKILLS_DIR}" -maxdepth 1 -mindepth 1 -type d | sort | while read -r d; do
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
	# pdf
	pypdf
	pdfplumber
	pdf2image
	Pillow
	reportlab
	pandas
	# pptx
	markitdown[all]
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
	pypdfium2
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
KEY_IMPORTS=(defusedxml lxml pypdf pdfplumber pdf2image PIL reportlab pandas markitdown openpyxl)
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

# ─── Disable built-in skills that conflict with provisioned ones ──────────

echo ""
echo "==> Disabling built-in skills that conflict with provisioned ones..."

DISABLE_SKILLS=(
  "blogwatcher"
  "llm-wiki"
  "arxiv"
  "excalidraw"
  "obsidian"
)

CONFIG_PATH="${HERMES_ROOT}/.hermes/config.yaml"

if command -v python3 &>/dev/null && "${VENV_PYTHON}" -c "import yaml" 2>/dev/null; then
	if [ -f "$CONFIG_PATH" ]; then
		# Merge into existing config
		python3 -c "
import yaml
with open('$CONFIG_PATH') as f:
    config = yaml.safe_load(f) or {}
skills = config.setdefault('skills', {})
existing = set(skills.get('disabled') or [])
merged = sorted(existing | set('''${DISABLE_SKILLS[*]}'''.split()))
if merged != (skills.get('disabled') or []):
    skills['disabled'] = merged
    with open('$CONFIG_PATH', 'w') as f:
        yaml.safe_dump(config, f, default_flow_style=False, sort_keys=False)
    print(f'    Disabled skills ({len(merged)} total): {merged}')
else:
    print('    No changes needed')
" || {
			echo "WARNING: Failed to update skills config — continuing."
		}
	else
		# Bootstrap fresh config with just the disabled list
		mkdir -p "$(dirname "$CONFIG_PATH")"
		python3 -c "
import yaml
config = {'skills': {'disabled': sorted('''${DISABLE_SKILLS[*]}'''.split())}}
with open('$CONFIG_PATH', 'w') as f:
    yaml.safe_dump(config, f, default_flow_style=False)
print('    Created config.yaml with disabled skills')
" || {
			echo "WARNING: Failed to create config.yaml — continuing."
		}
	fi
else
	echo "WARNING: python3 or PyYAML not available — skipping skills.disable config."
fi

# ─── Grant permissions to hermes user ─────────────────────────────────────

echo ""
echo "==> Granting ownership of ${SKILLS_DIR} to hermes:hermes..."
chown -R hermes:hermes "${SKILLS_DIR}" || {
	echo "WARNING: Failed to chown skills directory — continuing."
}

# ─── Done ───────────────────────────────────────────────────────────────────

echo ""
echo "========================================"
echo "  Hermes Skills setup complete!"
echo "  Skills directory: ${SKILLS_DIR}"
echo "  Python: ${VENV_PYTHON}"
echo "  Run with --all next time for optional deps"
echo "========================================"
