# REQUIRES
# ========
# - ALERT_MAIL
# - MAIL_TO
# - MAIL_SUBJECT

function alert {

	local message="${1}"

	if (( ! ALERT_MAIL )); then
		return 0
	fi

	if [[ -z "${message}" ]]; then
		return 0
	fi

	if (( ALERT_MAIL )) && [[ -z "${MAIL_TO}" ]]; then
		log "<3> Required var not set: MAIL_TO"
		return 1
	fi

	# ALERT
	alert_msg_header+="DATE:		$(date "+%Y-%m-%d %H:%M:%S")\n"
	alert_msg_header+="HOSTNAME:	${HOSTNAME}\n\n"

	log "<6> Sending Mail-Alert to ${MAIL_TO} ..."
	
	echo -e "${alert_msg_header}${message}" | \
	mail -s "${MAIL_SUBJECT} ALERT" "${MAIL_TO}" 2>/dev/null \
	&& log "<5> Alert Mail send to: ${MAIL_TO}"

}