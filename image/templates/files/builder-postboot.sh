#!/bin/bash
#
# Copyright 2024 Oxide Computer Company
#

set -o errexit
set -o pipefail
set -o xtrace

cat >/dev/msglog <<EOF

##################################################
####     #############                          ##
###  ###  ############                          ##
##  ### #  ##  ###  ##  Oxide Computer Company  ##
##  ## ##  ###  #  ###                          ##
##  # ###  ####   ####    This Station Under    ##
###  ###  ####  #  ###     Computer Control     ##
####     ####  ###  ##                          ##
##################################################

EOF

#
# Look for scripts in bootfs that we might be expected to run.
#
if [[ -f /system/boot/postboot.sh ]]; then
	exec /bin/bash /system/boot/postboot.sh
else
	printf 'WARNING: no /system/boot/postboot.sh\n' >/dev/msglog
fi
