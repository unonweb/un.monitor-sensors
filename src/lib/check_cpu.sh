# REQUIRES
# ========
# - SENSORS_JSON
# - ALERT_MSG
# - CPU_ABOVE_WARN_THRESH

function check_cpu {

	local timestamp=$(date +%s)
	local alert_msg

	# CHECK vars
	for var in SENSORS_JSON CPU_ABOVE_WARN_THRESH; do
		if [[ -z "${!var}" ]]; then
			log "<3> Required var missing: ${var}"
			exit 1
		fi
	done

	# GET cpu_key
	# Use the key starting with 'coretemp-isa'
	local cpu_key=$(echo "${SENSORS_JSON}" | jq --raw-output 'keys[] | select(startswith("coretemp-isa"))' | head -n 1)
	if [[ -z "${cpu_key}" ]]; then
		log "<3> Could not find key starting with 'coretemp-isa'"
		return 1
	fi

	log "<7> cpu_key: ${cpu_key}"

	# GET temp values
	# Use the 'temp1' key to get the overall CPU package sensor
	# The coretemp kernel driver consistently maps 'Package id 0' to 'temp1'
	local cpu_input=$(echo "${SENSORS_JSON}" | jq --raw-output --arg cpu_key "${cpu_key}" '.[$cpu_key].temp1.input.value | floor')
	local cpu_max=$(echo "${SENSORS_JSON}" | jq --raw-output --arg cpu_key "${cpu_key}" '.[$cpu_key].temp1.max.value | floor')
	local cpu_crit=$(echo "${SENSORS_JSON}" | jq --raw-output --arg cpu_key "${cpu_key}" '.[$cpu_key].temp1.crit.value | floor')
	
	if [[ -z ${cpu_input} || -z ${cpu_max} || -z ${cpu_crit} ]]; then
		log "<3> Could not read one of 'input', 'max' and 'crit' from ${cpu_key}"
		return 1
	fi

	log "<7> cpu_input: ${cpu_input}"
	log "<7> cpu_max: ${cpu_max}"
	log "<7> cpu_crit: ${cpu_crit}"

	# CHECK critical
	if (( cpu_crit != 0 && cpu_input >= cpu_crit )); then
		alert_msg=""
		alert_msg+="[Critical] CPU overheating!\n"
		alert_msg+="Critical: ${cpu_crit}°C\n"
		alert_msg+="Current: ${cpu_input}°C\n\n"

		log "<3> ${alert_msg}"
		ALERT_MSG+="${alert_msg}\n"
	fi

	# CHECK maximum warning limit (sustained tracking)
	if (( cpu_max != 0 && cpu_input >= cpu_max )); then
		# Fetch previous states (Default to 0 if not set)
		local cpu_above_max_timestamp=$(get_state "${cpu_key}" "cpu_above_max_timestamp")
		cpu_above_max_timestamp=${cpu_above_max_timestamp:-0}
		
		local cpu_alert_fired=$(get_state "${cpu_key}" "cpu_alert_fired")
		cpu_alert_fired=${cpu_alert_fired:-0}

		if (( cpu_above_max_timestamp > 0 )); then
			local seconds_above_max=$(( timestamp - cpu_above_max_timestamp ))
			
			if (( seconds_above_max > CPU_ABOVE_WARN_THRESH )); then
				# ONLY alert if we haven't already fired an alert for this specific breach event
				if (( cpu_alert_fired == 0 )); then
					alert_msg=""
					alert_msg+="[WARNING] Sustained High CPU Temperature Detected!\n"
					alert_msg+="Warning: ${cpu_max}°C\n"
					alert_msg+="Current: ${cpu_input}°C\n"
					alert_msg+="Sustained for: ${seconds_above_max} seconds\n"
					alert_msg+="Sustain threshold: ${CPU_ABOVE_WARN_THRESH} seconds\n\n"
					
					log "<3> ${alert_msg}"
					ALERT_MSG+="${alert_msg}\n"

					# Mark that we alerted, but KEEP the original timestamp intact
					set_state "${cpu_key}" "cpu_alert_fired" 1
				fi
			fi
		else
			# First check breach threshold, initialize the clock
			set_state "${cpu_key}" "cpu_above_max_timestamp" "${timestamp}"
			set_state "${cpu_key}" "cpu_alert_fired" 0
		fi
	else
		# Temperature dropped back to safe levels! 
		# Reset everything completely
		log "<7> Temperature of ${cpu_key} at safe levels: ${cpu_input}"
		set_state "${cpu_key}" "cpu_above_max_timestamp" 0
		set_state "${cpu_key}" "cpu_alert_fired" 0
	fi
}