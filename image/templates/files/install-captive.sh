#!/bin/bash
#
# Copyright 2024 Oxide Computer Company
#

function sgr_bold {
	printf '\x1b[1m'
}

function sgr_reset {
	printf '\x1b[0m'
}

function banner {
	buf=' --'
	if [[ -n $1 ]]; then
		buf+=" $1 "
	fi

	while (( ${#buf} < 78 )); do
		buf+='-'
	done

	sgr_bold
	printf -- '%s\n' "$buf"
	sgr_reset
}

printf '\n'
printf '\n'
banner 'Welcome to Oxide Helios!'
printf '\n'
printf '    This bootable ISO allows you to install Helios on a traditional\n'
printf '    install-to-disk system; e.g., a desktop PC or a BIOS/EFI-boot\n'
printf '    server.\n'
printf '\n'
printf '    To install, use "diskinfo" to locate the disk you wish to install\n'
printf '    to, and then use "install-helios" to format it and install the\n'
printf '    operating system.\n'
printf '\n'
printf '    More information is available in the "Installing on a physical\n'
printf '    machine using the ISO" section of the README at:\n'
printf '\n'
printf '        https://github.com/oxidecomputer/helios-engvm\n'
printf '\n'
banner
printf '\n'

#
# Drop the user at a basic root shell:
#
unset SMF_FMRI
unset SMF_METHOD
unset SMF_ZONENAME
unset SMF_RESTARTER
export PS1='# '
export PATH='/usr/sbin:/usr/bin:/sbin'
export HOME='/root'
export LOGNAME='root'
if [[ $(/usr/lib/bootparams console) == tty* ]]; then
	export TERM=xterm
else
	export TERM=sun-color
fi
exec /usr/bin/bash --login
