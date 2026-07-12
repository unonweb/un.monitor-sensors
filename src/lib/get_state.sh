# REQUIRES
# ========
# - STATE_DIR

function get_state {
    local dir="${1}"
	local key="${2}"
    local state_file="${STATE_DIR}/${dir}/${key}"
	
    if [[ -f "${state_file}" ]]; then
        cat "${state_file}"
    else
        echo ""
    fi
}