#!/usr/bin/bash

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE}")"
SCRIPT_DIR=$(dirname -- "$(readlink -f "${BASH_SOURCE}")")
SCRIPT_NAME=$(basename -- "$(readlink -f "${BASH_SOURCE}")")
SCRIPT_PARENT=$(dirname "${SCRIPT_DIR}")

APP_NAME="${SCRIPT_PARENT##*/}"

PATH_CONFIG="${SCRIPT_PARENT}/config.cfg"
PATH_DEFAULTS="${SCRIPT_PARENT}/defaults.cfg"

ALERT_MSG=""

# IMPORTS
source "${SCRIPT_DIR}/lib/alert.sh"
source "${SCRIPT_DIR}/lib/log.sh"
source "${SCRIPT_DIR}/lib/get_state.sh"
source "${SCRIPT_DIR}/lib/set_state.sh"
source "${SCRIPT_DIR}/lib/check_cpu.sh"
source "${SCRIPT_DIR}/lib/check_nvme.sh"

function main {

	# CHECK root
	if [ "${UID}" -ne 0 ]; then
  		echo "This script must be run as root."
  		exit 1
	fi

	# CONFIG & DEFAULTS
	if [[ -r "${PATH_CONFIG}" ]]; then
		source "${PATH_CONFIG}"
	else
		echo "<4>WARN: No config file found at ${PATH_CONFIG}. Using defaults ..."
		source "${PATH_DEFAULTS}"
	fi

	# CHECK internal dependencies
	for fctn in log alert; do
    	if ! declare -f "${fctn}" > /dev/null; then
        	echo "<3> Error: Required function missing: ${fctn}" >&2
        	exit 1
    	fi
	done
	
	# CHECK external dependencies
	for cmd in mail jq; do
    	if ! command -v "${cmd}" &> /dev/null; then
        	log "<3> Error: Required external command missing: ${cmd}" >&2
        	exit 1
    	fi
	done

	# CHECK vars
	for var in STATE_DIR; do
		if [[ -z "${!var}" ]]; then
			log "<3> Required var missing: ${var}"
			exit 1
		fi
	done

	# VARS
	local alert_msg=""
	local state_file_hashes="${STATE_DIR}/journald_alerted_hashes.txt"
	local state_file_cursor="${STATE_DIR}/journald_cursor.txt"

	# DEBUG
	log "<7> PATH_CONFIG: ${PATH_CONFIG}"
	log "<7> STATE_DIR: ${STATE_DIR}"

	# MKDIR
	mkdir -p "${STATE_DIR}"
	# mkdir -p "${TMP_DIR}"
	# mkdir -p "${LOG_DIR}"

	# Capture the raw JSON from lm-sensors
	SENSORS_JSON=$(sensors -J 2>/dev/null)
	if [ -z "${SENSORS_JSON}" ]; then
		echo "Error: Failed to fetch data from 'sensors -J'." >&2
		exit 1
	fi

	# CPU
	# ===

	check_cpu

	# NVME
	# ====

	check_nvme

	# ALERT
	# =====
	
	alert "${ALERT_MSG}"
}

main