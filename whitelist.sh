#!/usr/bin/bash
# ========================================================================
fn=$(basename $0)

declare -A addIP # declare an associative array for IPs to add
declare -A delIP # declare an associative array for IPs to delete
declare -A white # declare an associative array of whitelisted IPs

site=
path=~webadmin/www
file=.htaccess

doHelp=
doInfo=
doPurge=

# ========================================================================
# help - generate help information
# ========================================================================
function help {
	echo "

NAME
	$fn - IP Whitelisting

SYNOPSIS
	$fn -site name [-base path] [-file name] [-add IP]* [-del IP]* 
	$fn -site name [-base path] [-file name] [-purge]

DESCRIPTION
	$fn is a tool to examine, add or remove whitelisted IP addresses
	for the named site. The whitelisted IP addresses allow access to the
	admin area of the site and the login form. This tool works by mutating
	the .htaccess file for the named site. Not specifying one or more -add
	or -del arguments or the -purge argument will show you the current
	whitelist.

OPTIONS
	-help
		Show this help text.
	
	-site name
		The name of the website for which the whitelisting applies. This
		will be the name of a folder in the base path containing the site
		files.

	-base path
		The path that contains site folders.
		Default: ${path}

	-file name
		The name of the .htaccess file.
		Default: ${file}
	
	-add IP
		The IP address to whitelist. You can specify this argument as many
		times as you like. If there is no whitelist block it will be created.
	
	-del IP
		The whitelisted IP address to remove. You can specify this argument
		as many times as you like. Removing the last whitelisted IP address
		will cause the whole whitelist block to be removed.

	-purge
		The whitelist block, if it exists, will be removed.

	"
	if [ ! -z "${1}" ]; then error "${1}"; fi
	exit 0
}

# ========================================================================
# parseCommandLine - parse command line arguments
# ========================================================================
function parseCommandLine {
	local -a item
	while [ $# -gt 0 ]; do
		case "${1}" in
			-help)
				doHelp=1
				shift
				;;

			-purge)
				doPurge=1
				shift
				;;

			-site)
				site=${2}
				shift
				shift
				;;

			-base)
				path=${2}
				shift
				shift
				;;

			-file)
				file=${2}
				shift
				shift
				;;

			-add)
				if [ -z "${2}" ]; then
				error "Invalid -add argument specified."
				fi
				addIP[${2}]=${2}
				info "IP: ${2} will be whitelisted."
				shift
				shift
				;;

			-del)
				if [ -z "${2}" ]; then
				error "Invalid -del argument specified."
				fi
				delIP[${2}]=${2}
				info "IP: ${2} will be un-whitelisted."
				shift
				shift
				;;

			*)
				help "Unknown argument '${1}'"
				shift
				;;
		esac
	done
	# issue help
	if [ ! -z "${doHelp}" ]; then
		help
	fi
	# -site must be specified
	if [ -z "$site" ]; then
		help "-site is a required argument."
	fi
	# reject mutually exclusive arguments
	if [[ ( ! -z "${doPurge}" ) && ( ${#addIP[@]} -gt 0 || ${#delIP[@]} -gt 0 ) ]] ; then
		help "-purge cannot be used with either -add or -del arguments."
	fi
	# if none of -purge, -add or -del arguments are specified, just show information
	if [[ -z "${doPurge}" && ${#addIP[@]} -eq 0 && ${#delIP[@]} -eq 0 ]] ; then
		doInfo=1
	fi
}

# =======================================================================
# processAdds - integrate -add requests into whitelist
# =======================================================================
function processAdds {
	local item=
	for ip in ${!addIP[@]} ; do
		item="RewriteCond %{REMOTE_ADDR} !^${ip}$"
		if [ ! -z "${white[${ip}]}" ]; then
			warn "Whitelist for ${ip} already exists, ignoring add."
		else
			info "ADD (${ip}): ${item}"
			white[${ip}]=${item}
		fi
	done
}

# =======================================================================
# processDeletes - integrate -del requests into whitelist
# =======================================================================
function processDeletes {
	for ip in ${!delIP[@]} ; do
		if [ -z "${white[${ip}]}" ]; then
			warn "Whitelist for ${ip} does not exist, ignoring delete."
		else
			info "DEL (${ip}): ${white[${ip}]}"
			unset white[${ip}]
		fi
	done
}

# =======================================================================
# purgeWhitelist - edit file in place to remove whitelist block
# =======================================================================
function purgeWhitelist {
	# sed script deletes the relevant block from the file
	local s1='/^# BEGIN ADMIN WHITELIST/,/^# END ADMIN WHITELIST.*$/d'
	sed -i -e "${s1}" ${filename}
}

# =======================================================================
# gatherWhitelist - collect existing whitelist entries
# =======================================================================
function gatherWhitelist {
	local ip

	# sed script extracts the relevant block from the file
	local s1='/^# BEGIN ADMIN WHITELIST/,/^# END ADMIN WHITELIST.*$/!d'

	# sed script strips the leading and trailing text
	local s2='{ s/^.*\^// ; s/\$.*$// }'

	# sed script extracts just the comment
	local s3='s/^.*#\s+//'

	# extract ip addresses and existing whitelist entries
	for ip in $( sed -e "${s1}" ${filename} | grep -i remote_addr | sed -e "${s2}" ) ; do
		white[${ip}]=$( sed -e "${s1}" ${filename} | grep "${ip}" )
		info "Currently whitelisted: ${white[${ip}]}"
	done
}

# =======================================================================
# generateWhitelist - generate whitelist block
# =======================================================================
function generateWhitelist {
	local ip
	echo "# BEGIN ADMIN WHITELIST / Generated: $(date)"
	echo '<IfModule mod_rewrite.c>
RewriteEngine On
RewriteCond %{REQUEST_URI} ^(.*)?wp-login\.php(.*)$ [OR]
RewriteCond %{REQUEST_URI} ^(.*)?wp-admin$'

	for ip in ${!white[@]} ; do
		echo ${white[${ip}]}
	done

	echo 'RewriteRule ^(.*)$ - [R=403,L]
</IfModule>
# END ADMIN WHITELIST'
}

# =======================================================================
# info - Issue an informational message
# =======================================================================
function info {
    echo "${fn}: INFO: ${1}"
}

# =======================================================================
# warn - Issue a warning message
# =======================================================================
function warn {
    echo "${fn}: WARNING: ${1}"
}

# =======================================================================
# error - Issue an error message and exit.
# =======================================================================
function error {
    echo "${fn}: ERROR: ${1}"
    exit 0
}


# =======================================================================
# main - where the work begins
# =======================================================================

info "IP Whitelisting"

parseCommandLine "$@"
filename=${path}/${site}/${file}

# verify readability
if [ ! -r ${filename} ] ; then
error "The file you've specified (${filename}) is not readable by you."
fi

if [ ! -z "${doPurge}" ] ; then

	# verify writability
	if [ ! -w ${filename} ] ; then
	error "The file you've specified (${filename}) is not writable by you."
	fi

	# purge the whitelist
	purgeWhitelist

else

	# gather current whitelist
	gatherWhitelist

	if [ -z "${doInfo}" ] ; then

		# verify writability
		if [ ! -w ${filename} ] ; then
		error "The file you've specified (${filename}) is not writable by you."
		fi

		# integrate add, delete requests
		processAdds
		processDeletes

		# purge the whitelist
		purgeWhitelist

		# if there are any IPs to whitelist, then carry on
		if [ ${#white[@]} -gt 0 ] ; then
		generateWhitelist >> ${filename}
		fi

	fi
fi

info "Done."
exit 0

