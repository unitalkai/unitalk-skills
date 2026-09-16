#!/usr/bin/env bash
#
# update-skill.sh -- Explicitly update selected repository skills in Hermes.
#
# Usage:
#   ./update-skill.sh code/plan documents-and-analysis/pdf
#   ./update-skill.sh --force code/plan
#

set -euo pipefail

HERMES_HOME="${HERMES_HOME:-/opt/data}"
SKILLS_DIR="${HERMES_HOME}/skills"
BACKUP_ROOT="${HERMES_HOME}/skill-update-backups"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCK_DIR="${UNITALK_LOCK_DIR:-/run/lock}"

FORCE=false
REQUESTED_SKILLS=()

usage() {
	cat <<'EOF'
Usage: ./update-skill.sh [--force] <category/skill> [<category/skill> ...]

Explicitly replaces selected skills in the active Hermes profile with the
versions from this repository. Existing targets are backed up before changes.

Options:
  --force   Replace a target even when its existing frontmatter name differs.
  --help    Show this message.

Examples:
  ./update-skill.sh code/plan
  ./update-skill.sh code/plan documents-and-analysis/pdf
EOF
}

for arg in "$@"; do
	case "${arg}" in
		--force) FORCE=true ;;
		--help)
			usage
			exit 0
			;;
		--*)
			echo "ERROR: Unknown option: ${arg}"
			usage >&2
			exit 1
			;;
		*) REQUESTED_SKILLS+=("${arg}") ;;
	esac
done

if [[ "${#REQUESTED_SKILLS[@]}" -eq 0 ]]; then
	echo "ERROR: Provide at least one repository-relative skill path."
	usage >&2
	exit 1
fi

if [[ "$(id -u)" -ne 0 ]]; then
	echo "ERROR: This script must be run as root (or with sudo)."
	exit 1
fi

mkdir -p "${HERMES_HOME}"
if [[ -L "${HERMES_HOME}" || -L "${SKILLS_DIR}" || -L "${BACKUP_ROOT}" ]]; then
	echo "ERROR: Refusing to update through symlinked Hermes data paths."
	exit 1
fi

mkdir -p "${LOCK_DIR}"
exec 9>"${LOCK_DIR}/unitalk-skills-$(stat -c '%d-%i' "${HERMES_HOME}").lock"
if ! flock -n 9; then
	echo "ERROR: Another Unitalk skills operation is already running."
	exit 1
fi

declare -A SEEN_PATHS=()
declare -A TARGET_EXISTED=()
NORMALIZED_SKILLS=()

read_skill_name() {
	local skill_md="$1"
	local name

	name="$(
		"${PYTHON:-python3}" - "${skill_md}" <<'PY'
import re
import sys

path = sys.argv[1]
with open(path, encoding="utf-8") as source:
    content = source.read()

if not content.startswith("---\n"):
    raise SystemExit("SKILL.md must start with YAML frontmatter")

end = content.find("\n---", 4)
if end == -1:
    raise SystemExit("SKILL.md has unterminated YAML frontmatter")

frontmatter = content[4:end]
matches = re.findall(r"^name:\s*(['\"]?)([^'\"\n]+)\1\s*$", frontmatter, re.MULTILINE)
if len(matches) != 1 or not matches[0][1].strip():
    raise SystemExit("SKILL.md frontmatter must contain exactly one non-empty name")

print(matches[0][1].strip())
PY
	)"
	printf '%s\n' "${name}"
}

if ! command -v "${PYTHON:-python3}" &>/dev/null; then
	echo "ERROR: Python is required to validate skill metadata."
	exit 1
fi

echo "==> Validating requested skills..."
for requested in "${REQUESTED_SKILLS[@]}"; do
	if [[ -z "${requested}" || "${requested}" == /* || "${requested}" == */ || "${requested}" == *//* ]]; then
		echo "ERROR: Invalid skill path: ${requested}"
		exit 1
	fi

	IFS='/' read -r -a path_parts <<< "${requested}"
	if [[ "${#path_parts[@]}" -ne 2 || "${path_parts[0]}" == "." || "${path_parts[1]}" == "." || "${requested}" == *".."* ]]; then
		echo "ERROR: Skill paths must be exactly <category>/<skill>: ${requested}"
		exit 1
	fi

	normalized="${path_parts[0]}/${path_parts[1]}"
	if [[ -n "${SEEN_PATHS[${normalized}]+x}" ]]; then
		echo "ERROR: Duplicate skill argument: ${normalized}"
		exit 1
	fi
	SEEN_PATHS["${normalized}"]=1

	source_skill="${SCRIPT_DIR}/${normalized}"
	if [[ -L "${source_skill}" || ! -d "${source_skill}" || ! -f "${source_skill}/SKILL.md" ]]; then
		echo "ERROR: Repository skill not found: ${normalized}"
		exit 1
	fi

	resolved_source="$(realpath "${source_skill}")"
	case "${resolved_source}/" in
		"$(realpath "${SCRIPT_DIR}")"/*) ;;
		*)
			echo "ERROR: Repository skill resolves outside this repository: ${normalized}"
			exit 1
			;;
	esac

	NORMALIZED_SKILLS+=("${normalized}")
done

STAGE_ROOT="$(mktemp -d "${HERMES_HOME}/.skill-update.XXXXXX")"
cleanup_stage() {
	rm -rf "${STAGE_ROOT}"
}
trap cleanup_stage EXIT

echo "==> Staging ${#NORMALIZED_SKILLS[@]} skill(s)..."
for normalized in "${NORMALIZED_SKILLS[@]}"; do
	source_skill="${SCRIPT_DIR}/${normalized}"
	staged_skill="${STAGE_ROOT}/${normalized}"
	if find "${source_skill}" -type l -print -quit | grep -q .; then
		echo "ERROR: Repository skill contains a symlink: ${normalized}"
		exit 1
	fi
	if find "${source_skill}" ! -type d ! -type f -print -quit | grep -q .; then
		echo "ERROR: Repository skill contains a special file: ${normalized}"
		exit 1
	fi
	mkdir -p "$(dirname "${staged_skill}")"
	cp -a "${source_skill}" "${staged_skill}"
	chown -R hermes:hermes "${staged_skill}"
done

# Validate metadata from the immutable staged copies, not the live repository.
declare -A SOURCE_NAMES=()
declare -A SEEN_NAMES=()
for normalized in "${NORMALIZED_SKILLS[@]}"; do
	staged_skill="${STAGE_ROOT}/${normalized}"
	source_name="$(read_skill_name "${staged_skill}/SKILL.md")" || {
		echo "ERROR: Invalid SKILL.md metadata in ${normalized}."
		exit 1
	}
	if [[ -n "${SEEN_NAMES[${source_name}]+x}" ]]; then
		echo "ERROR: Requested skills declare the same name '${source_name}': ${SEEN_NAMES[${source_name}]} and ${normalized}"
		exit 1
	fi
	SOURCE_NAMES["${normalized}"]="${source_name}"
	SEEN_NAMES["${source_name}"]="${normalized}"
done

mkdir -p "${SKILLS_DIR}"
chown hermes:hermes "${SKILLS_DIR}"

# Validate existing targets before changing any of them.
for normalized in "${NORMALIZED_SKILLS[@]}"; do
	target_skill="${SKILLS_DIR}/${normalized}"
	if [[ -L "${target_skill}" ]]; then
		echo "ERROR: Refusing to replace symlinked target: ${normalized}"
		exit 1
	fi
	category_dir="${SKILLS_DIR}/${normalized%%/*}"
	if [[ -L "${category_dir}" ]]; then
		echo "ERROR: Refusing to update through symlinked category: ${normalized%%/*}"
		exit 1
	fi

	target_parent="$(dirname "${target_skill}")"
	resolved_parent="$(realpath -m "${target_parent}")"
	case "${resolved_parent}/" in
		"$(realpath -m "${SKILLS_DIR}")"/*) ;;
		*)
			echo "ERROR: Target resolves outside ${SKILLS_DIR}: ${normalized}"
			exit 1
			;;
	esac

	if [[ -e "${target_skill}" ]]; then
		if [[ ! -d "${target_skill}" || ! -f "${target_skill}/SKILL.md" ]]; then
			echo "ERROR: Existing target is not a valid skill directory: ${normalized}"
			exit 1
		fi
		target_name="$(read_skill_name "${target_skill}/SKILL.md")" || {
			echo "ERROR: Existing target has invalid SKILL.md metadata: ${normalized}"
			exit 1
		}
		if [[ "${target_name}" != "${SOURCE_NAMES[${normalized}]}" && "${FORCE}" != true ]]; then
			echo "ERROR: ${normalized} contains skill '${target_name}', but the repository skill is '${SOURCE_NAMES[${normalized}]}'."
			echo "       Re-run with --force to explicitly replace this path."
			exit 1
		fi
		TARGET_EXISTED["${normalized}"]=true
	else
		TARGET_EXISTED["${normalized}"]=false
	fi
done

mkdir -p "${BACKUP_ROOT}"
chown root:root "${BACKUP_ROOT}"
chmod 0700 "${BACKUP_ROOT}"
BACKUP_BATCH="$(mktemp -d "${BACKUP_ROOT}/$(date -u +%Y%m%dT%H%M%SZ).XXXXXX")"
chown root:root "${BACKUP_BATCH}"
chmod 0700 "${BACKUP_BATCH}"

if [[ "$(stat -c '%d' "${STAGE_ROOT}")" != "$(stat -c '%d' "${SKILLS_DIR}")" || \
	"$(stat -c '%d' "${BACKUP_BATCH}")" != "$(stat -c '%d' "${SKILLS_DIR}")" ]]; then
	echo "ERROR: Skills, staging, and backup directories must be on the same filesystem."
	exit 1
fi

TRANSACTION_SKILLS=()
TRANSACTION_COMMITTED=false

rollback_updates() {
	local normalized target_skill backup_skill quarantine
	local rollback_failed=false
	if [[ "${TRANSACTION_COMMITTED}" == true ]]; then
		return
	fi

	set +e
	for ((index=${#TRANSACTION_SKILLS[@]} - 1; index >= 0; index--)); do
		normalized="${TRANSACTION_SKILLS[index]}"
		target_skill="${SKILLS_DIR}/${normalized}"
		backup_skill="${BACKUP_BATCH}/${normalized}"

		if [[ "${TARGET_EXISTED[${normalized}]}" == true ]]; then
			# If no backup exists, the original never completed its move and must
			# be left untouched. A present backup is the source of truth.
			if [[ ! -d "${backup_skill}" ]]; then
				continue
			fi
			quarantine="${STAGE_ROOT}/rollback/${normalized}"
			if [[ -e "${target_skill}" || -L "${target_skill}" ]]; then
				mkdir -p "$(dirname "${quarantine}")"
				if ! mv "${target_skill}" "${quarantine}"; then
					echo "ERROR: Cannot quarantine replacement for ${normalized}." >&2
					rollback_failed=true
					continue
				fi
			fi

			mkdir -p "$(dirname "${target_skill}")"
			if ! mv "${backup_skill}" "${target_skill}"; then
				echo "ERROR: Cannot restore backup for ${normalized}." >&2
				[[ -e "${quarantine}" ]] && mv "${quarantine}" "${target_skill}"
				rollback_failed=true
				continue
			fi
			rm -rf "${quarantine}"
		else
			rm -rf "${target_skill}"
		fi
	done
	set -e

	if [[ "${rollback_failed}" == true ]]; then
		echo "ERROR: One or more skills could not be rolled back." >&2
	fi
}

trap 'rollback_updates; cleanup_stage' EXIT

echo "==> Updating requested skills..."
for normalized in "${NORMALIZED_SKILLS[@]}"; do
	target_skill="${SKILLS_DIR}/${normalized}"
	staged_skill="${STAGE_ROOT}/${normalized}"
	backup_skill="${BACKUP_BATCH}/${normalized}"
	# Journal the pre-operation state before the first filesystem mutation.
	TRANSACTION_SKILLS+=("${normalized}")

	if [[ "${TARGET_EXISTED[${normalized}]}" == true ]]; then
		mkdir -p "$(dirname "${backup_skill}")"
		mv "${target_skill}" "${backup_skill}"
	fi

	mkdir -p "$(dirname "${target_skill}")"
	if ! mv "${staged_skill}" "${target_skill}"; then
		echo "ERROR: Failed to publish ${normalized}."
		exit 1
	fi
	echo "    Updated ${normalized}"
done

TRANSACTION_COMMITTED=true
trap cleanup_stage EXIT
cleanup_stage
trap - EXIT

echo ""
echo "========================================"
echo "  Hermes skill update complete!"
echo "  Updated: ${#NORMALIZED_SKILLS[@]}"
echo "  Backup batch: ${BACKUP_BATCH}"
echo "  Restart Hermes or run /reload-skills"
echo "========================================"
