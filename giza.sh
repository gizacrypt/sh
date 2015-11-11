#!/bin/sh
true
GIZA_VERSION="0.1"
PROGNAME="$(basename "$0")"
PROGDIR="$(dirname "$0")"
ARGS="$@"
[ "x$GIZA_NOW" = 'x' ] && GIZA_NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)" ||\
	echo 'WARNING: $GIZA_NOW is set, not using current time!' >&2
GIZA_USAGE="usage: $PROGNAME [OPTION]... [FILE]"
set -e

usage() {
	man -M "$PROGDIR/" "$PROGNAME"
}


######################
## APPLICATION FLOW ##
######################

main() {
	exec 3>/dev/null
	if has_flag --debug >/dev/null
	then
		exec 3>&2
	fi

	if get_action >/dev/null
	then
		case $(get_action) in
			'read')   flow_read;break;;
			'new')    flow_new;break;;
			'write')  flow_write;break;;
			'update') flow_update;break;;
			'meta')   flow_meta;break;;
			'revert') flow_revert;break;;
			'delete') flow_delete;break;;
		esac
	else
		has_help && usage || echo $GIZA_USAGE >&2
		return 0
	fi
	return $?
}

flow_read() {
	get_input_cleartext | write_cleartext_output
}

flow_new() {
	get_input_cleartext | giza_from_cleartext | write_cryptotext_output
}

flow_write() {
	get_input_cleartext | edit_cleartext | giza_from_cleartext | write_cryptotext_output
}

flow_update() {
	get_input_cleartext | giza_from_cleartext | write_cryptotext_output
}

flow_meta() {
	if is_equal_access >/dev/null
	then
		get_cryptotext | giza_from_cryptotext | write_cryptotext_output
	else
		get_input_cleartext | giza_from_cleartext | write_cryptotext_output
	fi
}

flow_revert() {
	# TODO
	return 1
}

flow_delete() {
	giza_delete | write_cryptotext_output
}


###########################
## DESTRUCTIVE FUNCTIONS ##
###########################

# in: cryptotext
# out: cryptotext (may write to file instead)
write_cryptotext_output() {
	# TODO: support different outputs, eg file or curl
	tee
}

# in: cleartext
# out: cleartext (may write to file instead)
write_cleartext_output() {
	# TODO: support different outputs, eg file or curl
	tee
}

get_input_cleartext() {
	file="$(get_input_cleartext_file)"
	if [ -z "$file" ]
	then
		echo "CALL get_input_cleartext AND --cleartext-in NOT SET" >&3
		get_input_cryptotext | gpg --quiet --decrypt
	else
		cat "$file"
	fi
}

# in: giza
# out: cryptotext
get_input_cryptotext() {
	get_input_cleartext | gpg --quiet --decrypt | awk '/^-----BEGIN PGP MESSAGE-----$/,/^-----END PGP MESSAGE-----$/'
}

# in: giza from stdin (may read from filesystem instead)
# out: giza
get_giza_file_contents() {
	if [ ${GIZA_INPUT_CONSUMED:-0} -eq 1 ]
	then
		echo "$GIZA_INPUT"
		return 0
	fi
	file="$(get_file)"
	export GIZA_INPUT="$(test -z "$file" && cat || cat "$file")"
	test -z "$file" || export GIZA_INPUT_CONSUMED=1
	echo "$GIZA_INPUT"
}


##############################
## CRYPROGRAPHIC OPERATIONS ##
##############################

pgp_sign() {
	echo "CALL pgp_sign" >&3
	gpg --quiet --clearsign
}

# in: cleartext
# out: cryptotext
pgp_encrypt() {
	echo "CALL pgp_encrypt" >&3
	recipient_gpg_arguments=$(get_recipient_gpg_arguments)
	gpg --quiet --armour --encrypt ${recipient_gpg_arguments}
}

get_recipient_gpg_arguments() {
	mode='access'
	get_arguments_for --access | while read line
	do
		if [ "$mode" = 'recipients' ]
		then
			echo "+$access+" | grep --ignore-case --quiet '+read+' && echo --recipient "$line"
			mode='access'
		else
			access="$line"
			mode='recipients'
		fi
	done
}


########################
## CONTENT OPERATIONS ##
########################

# in: cryptotext
# out: giza
giza_from_cryptotext() {
	echo "CALL giza_from_cryptotext" >&3
	# echo "$(tee)\n$(generate_metadata | pgp_sign)" | pgp_sign
	contents="$(tee)"
	metadata=$(generate_metadata)
	signed_metadata="$(echo "$metadata" | pgp_sign)"
	contents="$contents
${signed_metadata}"
	echo "$contents" | pgp_sign
}

# in: cleartext
# out: giza
giza_from_cleartext() {
	echo "CALL giza_from_cleartext" >&3
	pgp_encrypt | giza_from_cryptotext
}

# out: giza
giza_delete() {
	echo "CALL giza_delete" >&3
	# double sign for consistency,
	# no concatenation of content is required though
	generate_metadata | pgp_sign | pgp_sign
}

# out: giza-metadata
generate_metadata() {
	echo '-----BEGIN GIZA METADATA-----'
	echo "Giza-Version: ${GIZA_VERSION}"
	echo "Action: $(get_action)"
	echo "Date: ${GIZA_NOW}"
	echo "Revision: $(uuidgen | tr '[:upper:]' '[:lower:]')"
	if [ ! -z "$(get_output_previous)" ]
	then
		echo "Previous: $(get_output_previous)"
	fi
	if [ ! -z "$(get_output_basedon)" ]
	then
		echo "Based-On: $(get_output_basedon)"
	fi

	if has_flag_hash_name >/dev/null
	then
		echo "Name-Hash: $(get_output_name_hash)"
	else
		echo "Name: $(get_output_name_plain)"
	fi

	if has_flag_hash_comment >/dev/null
	then
		echo "Comment-Hash: $(get_output_comment_hash)"
	else
		echo "Comment: $(get_output_comment_plain)"
	fi

	## TODO: Access

	echo "Content-Type: $(get_output_content_type_plain)"
	echo '-----END GIZA METADATA-----'
}


######################
## VARIABLE GETTERS ##
######################

get_action() {
	echo 'CALL get_action' >&3
	get_action_from_arg 2>/dev/null || get_action_from_file 2>/dev/null
}

get_output_previous() {
	echo 'CALL get_output_previous' >&3
	echo "MISS get_output_previous NOT IMPLEMENTED" >&3
	return 1
}

get_output_basedon() {
	echo 'CALL get_output_basedon' >&3
	echo "MISS get_output_basedon NOT IMPLEMENTED" >&3
	return 1
}

get_output_name_hash() {
	echo 'CALL get_output_name_hash' >&3
	echo "MISS get_output_name_hash NOT IMPLEMENTED" >&3
	return 1
}

get_output_name_plain() {
	echo 'CALL get_output_name_plain' >&3
	get_output_name_plain_from_arg
	return $?
}

get_output_comment_hash() {
	echo 'CALL get_output_comment_hash' >&3
	echo "MISS get_output_comment_hash NOT IMPLEMENTED" >&3
	return 1
}

get_output_comment_plain() {
	echo 'CALL get_output_comment_plain' >&3
	get_output_comment_plain_from_arg
	return $?
}

get_output_content_type_plain() {
	echo 'CALL get_output_content_type_plain' >&3
	get_output_content_type_plain_from_arg 2>/dev/null || \
	get_output_content_type_from_plain_input
}

get_input_cleartext_file() {
	echo 'CALL get_input_cleartext_file' >&3
	get_input_cleartext_file_from_arg
}

is_equal_access() {
	echo 'CALL is_equal_access' >&3
	echo "MISS is_equal_access NOT IMPLEMENTED" >&3
	return 1
}

has_flag_hash_name() {
	echo 'CALL has_flag_hash_name' >&3
	echo "MISS has_flag_hash_name NOT IMPLEMENTED" >&3
	return 1
}

has_flag_hash_comment() {
	echo 'CALL has_flag_hash_comment' >&3
	echo "MISS has_flag_hash_comment NOT IMPLEMENTED" >&3
	return 1
}


######################################
## VARIABLE GETTER FROM PLAIN INPUT ##
######################################

get_output_content_type_from_plain_input() {
	echo 'CALL get_output_content_type_from_plain_input' >&3
	contenttype="$(get_input_cleartext | file --mime-type - | cut -d\  -f2)"
	echo $contenttype
	return 0
}


##########################################
## VARIABLE GETTER FROM GIZA INPUT FILE ##
##########################################

get_action_from_file() {
	echo 'CALL get_action_from_file' >&3
	echo "MISS get_action_from_file NOT IMPLEMENTED" >&3
	return 1
}

get_command_block_from_file() {
	get_giza_file_contents | awk '/^-----BEGIN GIZA COMMAND-----$/,/^-----END GIZA COMMAND-----$/'
}


############################################
## COMMANDLINE ARGUMENT HANDLER FUNCTIONS ##
############################################

has_help() {
	return $(has_flag --help)
}

get_file() {
	last=
	for arg in $ARGS
	do
		last="$arg"
	done
	[ "$last" = '' ] && return 1
	[ "$(echo "$last" | head -c2)" = '--' ] && return 1
	echo "$last"
}


###########################
## COMMANDLINE ARGUMENTS ##
###########################

get_action_from_arg() {
	echo 'CALL get_action_from_arg' >&3
	found=0
	action=
	for flag in $(get_flags)
	do
		case "$flag" in
			'--new') action='new';found=$((found+1));continue;;
			'--write') action='write';found=$((found+1));continue;;
			'--update') action='update';found=$((found+1));continue;;
			'--meta') action='meta';found=$((found+1));continue;;
			'--revert') action='revert';found=$((found+1));continue;;
			'--delete') action='delete';found=$((found+1));continue;;
		esac
	done
	if [ $found -eq 1 ]
	then
		echo $action
		return 0
	elif [ $found -eq 0 ]
	then
		echo 'No action specified.' >&2
	else
		echo 'More than one action specified' >&2
	fi
	if ! has_help
	then
		echo "$GIZA_USAGE" >&2
		echo 'Run with --help for usage information.' >&2
	fi
	echo >&2
	return 1
}

get_input_cleartext_file_from_arg() {
	echo 'CALL get_input_cleartext_file_from_arg' >&3
	get_arguments_for --cleartext-in
	return $?
}

get_output_comment_plain_from_arg() {
	echo 'CALL get_output_comment_plain_from_arg' >&3
	get_arguments_for --comment
	return $?
}

get_output_name_plain_from_arg() {
	echo 'CALL get_output_name_plain_from_arg' >&3
	get_arguments_for --name
	return $?
}

get_output_content_type_plain_from_arg() {
	echo 'CALL get_output_content_type_plain_from_arg' >&3
	get_arguments_for --content-type
	return $?
}


############################################
## COMMANDLINE ARGUMENT PARSING FUNCTIONS ##
############################################

# Get the amount of arguments to skip after the specified argument
get_skip_for_argument() {
	arg="$1"
	case "$arg" in
		'--access') echo 2;return 0;;
		'--callback') echo 1;return 0;;
		'--secret-out') echo 1;return 0;;
		'--cleartext-out') echo 1;return 0;;
		'--cleartext-in') echo 1;return 0;;
		'--editor') echo 1;return 0;;
		'--template') echo 1;return 0;;
		'--input-content-type') echo 1;return 0;;
		'--name') echo 1;return 0;;
		'--comment') echo 1;return 0;;
		*) echo 0;return 0;;
	esac
}

# Write all flags to stdout
get_flags() {
	skip=0
	for arg in $ARGS
	do
		if [ $skip -gt 0 ]
		then
			skip=$((skip-1))
			continue
		else
			skip=$(get_skip_for_argument "$arg")
		fi
		echo $arg
	done
}

has_flag() {
	find_flag="$1"
	for flag in $(get_flags)
	do
		if [ "$flag" = "$find_flag" ]
		then
			echo 0
			return 0
		fi
	done
	echo 1
	return 1
}

get_arguments_for() {
	skip=0
	find_flag="$1"
	found=0
	for arg in $ARGS
	do
		if [ $skip -gt 0 ]
		then
			if [ "$find_flag" = "$found_flag" ]
			then
				found=1
				echo "$arg"
			fi
			skip=$((skip-1))
			continue
		else
			skip=$(get_skip_for_argument "$arg")
			found_flag="$arg"
		fi
	done
	if [ $found -eq 0 ]
	then
		echo "Argument $find_flag expected but missing" >&2
		return 1
	fi
	if [ $skip -gt 0 ]
	then
		echo "Argument $found_flag incomplete" >&2
		return 1
	fi
}


########################
## THAT'S ALL, FOLKS! ##
########################

main
exit $?
