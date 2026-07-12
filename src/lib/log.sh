# NOTES
# =====
# 0: Emergency, 1: Alert, 2: Critical, 3: Error, 4: Warning, 5: Notice, 6: Info, 7: Debug

# REQUIRES
# ========
# - LOG_FILE
# - LOG_TO_FILE
# - LOG_TO_CONSOLE
# - LOG_LVL
# - LOG_TO_CONSOLE_WITH_LVL

function log {

    local message="${1}"
	local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
	local msg_lvl
	local msg_only

	# Regex pattern that captures two groups:
	# <number>
	# message
    if [[ "${message}" =~ ^\<([0-7])\>[[:space:]]*(.*) ]]; then
        msg_lvl="${BASH_REMATCH[1]}"
        msg_only="${BASH_REMATCH[2]}"
	else
    	msg_lvl="" # Optional: or set a default level like "6" (info) or "3" (err)
    	msg_only="${message}"
	fi

	# Check msg_lvl
	# If not specified default to log, too
	if [[ -z "${msg_lvl}" || "${msg_lvl}" -le "${LOG_LVL}" ]]; then
		
		# Log to file
		if (( LOG_TO_FILE )); then
			echo -e "${timestamp} [LVL ${msg_lvl}] ${msg_only}" >> "${LOG_FILE}"
		fi

		# Log to console
		if (( LOG_TO_CONSOLE )); then
			# Replace all newlines with a space
			message="${message//\\n/ }"
			msg_only="${msg_only//\\n/ }"
			# Remove space after "<num> "
			message="${message/> />}"
			msg_only="${msg_only/> />}"
			
			if (( LOG_TO_CONSOLE_WITH_LVL )); then
				# Use this when connected to systemd journal
				# Log original message
				echo -e "${message}"
			else
				# No systemd service around
				# Log clean message
				echo -e "${msg_only}"
			fi
		fi
	fi
}