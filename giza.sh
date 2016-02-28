#!/bin/sh
true

test -t 0 && TTY="$(tty)"
GIZA_VERSION="0.1"
PROGNAME="$(basename "$0")"
PROGDIR="$(dirname "$0")"
ARGS="$@"
[ "x$GIZA_NOW" = 'x' ] && GIZA_NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)" ||\
	echo 'WARNING: $GIZA_NOW is set, not using current time!' >&2
GIZA_USAGE="usage: $PROGNAME [OPTION]... [FILE]"
set -eu

usage() {
	test -f "$PROGDIR/man1/giza.1" && man -M "$PROGDIR/" giza || man giza
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

	case $(get_action) in
		'read')   flow_read;break;;
		'new')    flow_new;break;;
		'write')  flow_write;break;;
		'update') flow_update;break;;
		'meta')   flow_meta;break;;
		'revert') flow_revert;break;;
		'delete') flow_delete;break;;
		*)        flow_help;break;;
	esac
}

flow_help() {
	has_help && usage || echo "$GIZA_USAGE" >&2
}

flow_read() {
	echo "FLOW read" >&3
	if test -t 1 -a "$(get_method_command_from_file)" = 'save'
	then
		echo 'You cannot display this secret on your terminal,' >&2
		echo 'use output redirection instead.' >&2
		return 1
	fi

	get_input_cleartext | write_cleartext_output
}

flow_new() {
	echo "FLOW new" >&3
	echo "INFO obtaining cleartext" >&3
	clear="$(get_input_cleartext)"
	echo "INFO encrypt using giza" >&3
	giza="$(echo "$clear" | giza_from_cleartext)"
	echo "INFO writing" >&3
	echo "$giza" | write_cryptotext_output
}

flow_write() {
	echo "FLOW write" >&3
	clear="$(get_input_cleartext)"
	edited="$(echo "$clear" | edit_cleartext)"
	echo "$edited" | giza_from_cleartext | write_cryptotext_output
}

flow_update() {
	echo "FLOW update" >&3
	get_input_cleartext | giza_from_cleartext | write_cryptotext_output
}

flow_meta() {
	echo "FLOW meta" >&3
	if is_equal_access >/dev/null
	then
		get_cryptotext | giza_from_cryptotext | write_cryptotext_output
	else
		get_input_cleartext | giza_from_cleartext | write_cryptotext_output
	fi
}

flow_revert() {
	echo "FLOW revert" >&3
	echo "MISS flow revert NOT IMPLEMENTED" >&3
	# TODO
	return 1
}

flow_delete() {
	echo "FLOW delete" >&3
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

# in: cleartext, only if not obtained through other means
# out: cleartext
get_input_cleartext() {
	echo "CALL get_input_cleartext" >&3
	if has_flag --cleartext-in >/dev/null
	then
		file="$(get_input_cleartext_file)"
		cat "$file" && return 0 || return 1
	fi
	echo "INFO getting cleartext by decrypting cryptotext" >&3
	cryptotext="$(get_input_cryptotext)" || true
	if test -n "$cryptotext"
	then
		echo "$cryptotext" | gpg --quiet --decrypt
	else
		echo "INFO got no cryptotext, reading cleartext from stdin" >&3
		tee
	fi
}

# in: giza
# out: cryptotext
get_input_cryptotext() {
	echo "CALL get_input_cryptotext" >&3
	file="$(get_file)" || return 1
	echo "VARI file=$file" >&3
	if test -r "$file"
	then
		gpg --quiet --decrypt --no-tty --batch < "$file" 2>/dev/null \
			| awk '/^-----BEGIN PGP MESSAGE-----$/,/^-----END PGP MESSAGE-----$/'
	else
		echo "IOER cannot read $file" >&3
		return 1
	fi
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
	echo "INFO Consuming file $file" >&3
	export GIZA_INPUT="$(test -z "$file" && cat || cat "$file")"
	echo 'INFO Consumed' >&3
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
	echo "ARGS $recipient_gpg_arguments" >&3
	if test -n "$recipient_gpg_arguments"
	then
		gpg --quiet --armour --encrypt ${recipient_gpg_arguments}
	else
		echo "FAIL cannot make a working gpg command" >&3
		return 1
	fi
}

get_recipient_gpg_arguments() {
	echo "CALL get_recipient_gpg_arguments" >&3
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
	cryptotext="$(pgp_encrypt)"
	echo "$cryptotext" | giza_from_cryptotext
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
		echo -n 'Name-Hash: '
		get_output_name_hash
	else
		echo -n 'Name: '
		get_output_name_plain
	fi

	if has_flag_hash_comment >/dev/null
	then
		echo -n 'Comment-Hash: '
		get_output_comment_hash
	else
		echo -n 'Comment: '
		get_output_comment_plain
	fi

	generate_access_metadata

	echo "Content-Type: $(get_output_content_type_plain)"
	echo '-----END GIZA METADATA-----'
}

edit_cleartext() {
	echo 'CALL edit_cleartext' >&3
	tmpdir="/tmp/giza.$(id -u)"
	mkdir -p $tmpdir
	tee > "$tmpdir/giza_clear.bin"
	${EDITOR:=vim} "$tmpdir/giza_clear.bin" < "$TTY" > "$TTY"
	cat "$tmpdir/giza_clear.bin" && rm "$tmpdir/giza_clear.bin"
}

generate_access_metadata() {
	mode='access'
	get_arguments_for --access >&3
	get_arguments_for --access | while read line
	do
		if [ "$mode" = 'recipients' ]
		then
			echo -n 'Access: ' 
			s='' # splitter
			echo "+$access+" | grep --ignore-case --quiet '+read+' && echo -n "${s}READ" && s='+'
			echo "+$access+" | grep --ignore-case --quiet '+write+' && echo -n "${s}WRITE" && s='+'
			echo "+$access+" | grep --ignore-case --quiet '+admin+' && echo -n "${s}ADMIN"
			mode='access'
			echo -n " $(get_key_id_for_freetext "$line")"
			echo " $(get_key_name_for_freetext "$line")"
		else
			access="$line"
			mode='recipients'
		fi
	done
}

get_key_id_for_freetext() {
	gpg --with-colons --list-keys "$1" | grep ^uid | while read key
	do
		if test "x$(echo "$key" | cut -d: -f2)" = "x-"
		then
			echo "$key" | cut -d: -f8
			return
		fi
	done
}

get_key_name_for_freetext() {
	gpg --with-colons --list-keys "$1" | grep ^uid | while read key
	do
		if test "x$(echo "$key" | cut -d: -f2)" = "x-"
		then
			echo "$key" | cut -d: -f10
			return
		fi
	done
}

######################
## VARIABLE GETTERS ##
######################

get_action() {
	echo 'CALL get_action' >&3
	get_action_from_arg 2>/dev/null || get_action_command_from_file 2>/dev/null
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
}

get_output_comment_hash() {
	echo 'CALL get_output_comment_hash' >&3
	echo "MISS get_output_comment_hash NOT IMPLEMENTED" >&3
	return 1
}

get_output_comment_plain() {
	echo 'CALL get_output_comment_plain' >&3
	get_output_comment_plain_from_arg
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
	cleartext="$(get_input_cleartext)"
	contenttype="$(echo "$cleartext" | file --mime-type - | cut -d\  -f2)"
	echo "$contenttype"
}


##########################################
## VARIABLE GETTER FROM GIZA INPUT FILE ##
##########################################

get_action_command_from_file() {
	action="$(get_command_block_from_file | sed -n '/Action:/ s/.*: //p')"
	echo 'CALL get_action_command_from_file' >&3
	echo "VARI action=$action" >&3
	echo "$action"
}

get_method_command_from_file() {
	method="$(get_command_block_from_file | sed -n '/Method:/ s/.*: //p')"
	echo 'CALL get_method_command_from_file' >&3
	echo "VARI method=$method" >&3
	echo "$method"
}

get_command_block_from_file() {
	get_giza_file_contents | awk '/^-----BEGIN GIZA COMMAND-----$/,/^-----END GIZA COMMAND-----$/'
}


############################################
## COMMANDLINE ARGUMENT HANDLER FUNCTIONS ##
############################################

has_help() {
	has_flag --help
}

get_file() {
	last=
	skip=0
	for arg in $ARGS
	do
		if [ $skip -gt 0 ]
		then
			skip=$((skip-1))
			last=
			continue
		else
			skip=$(get_skip_for_argument "$arg")
			if [ $skip -eq 0 ]
			then
				last="$arg"
			fi
		fi
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
			'--read') action='read';found=$((found+1));continue;;
			'--new') action='new';found=$((found+1));continue;;
			'--write') action='write';found=$((found+1));continue;;
			'--update') action='update';found=$((found+1));continue;;
			'--meta') action='meta';found=$((found+1));continue;;
			'--revert') action='revert';found=$((found+1));continue;;
			'--delete') action='delete';found=$((found+1));continue;;

			# Aliases
			'--decrypt') action='read';found=$((found+1));continue;;
			'--edit') action='write';found=$((found+1));continue;;
		esac
	done
	if [ $found -eq 1 ]
	then
		echo $action
		echo "VARI action=$action" >&3
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
}

get_output_comment_plain_from_arg() {
	echo 'CALL get_output_comment_plain_from_arg' >&3
	get_arguments_for --comment
}

get_output_name_plain_from_arg() {
	echo 'CALL get_output_name_plain_from_arg' >&3
	get_arguments_for --name
}

get_output_content_type_plain_from_arg() {
	echo 'CALL get_output_content_type_plain_from_arg' >&3
	get_arguments_for --content-type
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

		# Various
		'--debug') echo 0;return 0;;
		'--read') echo 0;return 0;;
		'--new') echo 0;return 0;;
		'--write') echo 0;return 0;;
		'--update') echo 0;return 0;;
		'--meta') echo 0;return 0;;
		'--revert') echo 0;return 0;;
		'--delete') echo 0;return 0;;

		# Aliases
		'--decrypt') echo 0;return 0;;
		'--edit') echo 0;return 0;;

		# stdin
		'-') echo 0;return 0;;
		*) echo "FAIL unknown argument $arg" >&3;echo 0
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
			return 0
		fi
	done
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
