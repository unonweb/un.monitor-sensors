# REQUIRES
# ========
# - SENSORS_JSON
# - ALERT_MSG
# - NVME_ABOVE_WARN_THRESH

function check_nvme {

	# CHECK vars
	for var in SENSORS_JSON NVME_ABOVE_WARN_THRESH; do
		if [[ -z "${!var}" ]]; then
			log "<3> Required var missing: ${var}"
			exit 1
		fi
	done
	
	local alert_msg
	local timestamp=$(date +%s)
	local nvme_keys=()
	mapfile -t nvme_keys < <(echo "${SENSORS_JSON}" | jq -r 'keys[] | select(startswith("nvme-"))')

	if [[ ${#nvme_keys[@]} -eq 0 ]]; then
		log "<3> No keys found that are starting with 'nvme-'"
		return 1
	fi
	
	for nvme_key in "${nvme_keys[@]}"; do
		local nvme_input=$(echo "${SENSORS_JSON}" | jq --raw-output --arg nvme_key "${nvme_key}" '.[$nvme_key].temp1.input.value | floor')
		local nvme_max=$(echo "${SENSORS_JSON}" | jq --raw-output --arg nvme_key "${nvme_key}" '.[$nvme_key].temp1.max.value | floor')
		local nvme_crit=$(echo "${SENSORS_JSON}" | jq --raw-output --arg nvme_key "${nvme_key}" '.[$nvme_key].temp1.crit.value | floor')

		log "<7> nvme_input: ${nvme_input}"
		log "<7> nvme_max: ${nvme_max}"
		log "<7> nvme_crit: ${nvme_crit}"

		if [[ -z ${nvme_input} || -z ${nvme_max} || -z ${nvme_crit} ]]; then
			log "<3> Could not read one of 'input', 'max' and 'crit' from ${nvme_key}"
			continue
		fi
		
		# CHECK NVMe absolute critical limit
		if (( nvme_crit != 0 && nvme_input >= nvme_crit )); then
			alert_msg=""
			alert_msg+="[CRITICAL] NVMe SSD Overheating!\n"
			alert_msg+="Key: ${nvme_key}\n"
			alert_msg+="Critical: ${nvme_crit}°C\n"
			alert_msg+="Current: ${nvme_input}°C\n\n"

			log "<3> ${alert_msg}"
			
			ALERT_MSG+="${alert_msg}\n"
		fi

		# CHECK maximum warning limit (sustained tracking)
		if (( nvme_max != 0 && nvme_input >= nvme_max )); then
			# Fetch previous states (Default to 0 if not set)
			local nvme_above_max_timestamp=$(get_state "${nvme_key}" "nvme_above_max_timestamp")
			nvme_above_max_timestamp=${nvme_above_max_timestamp:-0}
			
			local nvme_alert_fired=$(get_state "${nvme_key}" "nvme_alert_fired")
			nvme_alert_fired=${nvme_alert_fired:-0}

			if (( nvme_above_max_timestamp > 0 )); then
				local seconds_above_max=$(( timestamp - nvme_above_max_timestamp ))
				
				if (( seconds_above_max > NVME_ABOVE_WARN_THRESH )); then
					# ONLY alert if we haven't already fired an alert for this specific breach event
					if (( nvme_alert_fired == 0 )); then

						alert_msg=""
						alert_msg+="[WARNING] Sustained High NVME Temperature Detected!\n"
						alert_msg+="Key: ${nvme_key}\n"
						alert_msg+="Warning: ${nvme_max}°C\n"
						alert_msg+="Current: ${nvme_input}°C\n"
						alert_msg+="Sustained for: ${seconds_above_max} seconds\n"
						alert_msg+="Sustain threshold: ${NVME_ABOVE_WARN_THRESH} seconds\n\n"

						log "<3> ${alert_msg}"
			
						ALERT_MSG+="${alert_msg}\n"
						
						# Mark that we alerted, but KEEP the original timestamp intact
						set_state "${nvme_key}" "nvme_alert_fired" 1
					fi
				fi
			else
				# First check breach threshold, initialize the clock
				set_state "${nvme_key}" "nvme_above_max_timestamp" "${timestamp}"
				set_state "${nvme_key}" "nvme_alert_fired" 0
			fi
		else
			# Temperature dropped back to safe levels! 
			# Reset everything completely
			log "<7> Temperature of ${nvme_key} at safe levels: ${nvme_input}"
			set_state "${nvme_key}" "nvme_above_max_timestamp" 0
			set_state "${nvme_key}" "nvme_alert_fired" 0
		fi
	done
}