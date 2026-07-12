# REQUIRES
# ========
# - STATE_DIR

function set_state {
	local dir="${1}"
    local key="${2}"
    local value="${3}"
	
	# CHECK vars
	for var in STATE_DIR dir key value; do
		if [[ -z "${!var}" ]]; then
			log "<3> Required var missing: ${var}"
			return 1
		fi
	done

	mkdir --parent "${STATE_DIR}/${dir}"
    echo "${value}" > "${STATE_DIR}/${dir}/${key}"
}