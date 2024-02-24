#!/bin/bash
#
# Copyright 2024 Oxide Computer Company
#

set -o errexit
set -o pipefail

if [[ ! -f "$HOME/.ssh/authorized_keys" ]]; then
	echo "ERROR: you have no $HOME/.ssh/authorized_keys file" >&2
	exit 1
fi

XID=$(id -u)
XNAME=$(id -un)
if [[ "$(uname)" == Darwin ]]; then
	XGECOS=$(id -F "$XNAME")
else
	XGECOS=$(getent passwd "$XNAME" | cut -d: -f5)
fi

# Below, the uuencode is changed via awk so that the permissions on the file
# are always 600. Over on the Helios side, we're going to write
# .ssh/authorized_keys so that its group is `staff`. Since the user's primary
# group ID isn't the same as the user ID, for sshd to accept
# `.ssh/authorized_keys`, it must not be group-writable.
#
# But some setups may be different -- in particular, on Ubuntu, by default, the
# group ID is the same as the user ID, and the default umask is 002 (on most
# Unixes the default umask is 022). This means that the `.ssh/authorized_keys`
# file may be group-writable. (sshd is fine with that arrangement too, since
# it's still not writable by others).
#
# When run on Ubuntu, uuencode isn't aware of this subtlety, though (nor would
# it be reasonable to expect uuencode to be). So it produces a file with
# group-writable permissions. The user will then fail to log in via ssh, and be
# left confused.
#
# The awk command fixes that by always forcing permissions to 600.

cat <<EOF
#!/bin/bash
set -o errexit
set -o pipefail
set -o xtrace
echo 'Just a moment...' >/dev/msglog
/sbin/zfs create 'rpool/home/$XNAME'
/usr/sbin/useradd -u '$XID' -g staff -c '$XGECOS' -d '/home/$XNAME' \\
    -P 'Primary Administrator' -s /bin/bash '$XNAME'
/bin/passwd -N '$XNAME'
/bin/mkdir '/home/$XNAME/.ssh'
/bin/uudecode <<'EOSSH'
$(uuencode -m "$HOME/.ssh/authorized_keys" "/home/$XNAME/.ssh/authorized_keys" | awk 'NR == 1 { $2 = "600" } { print }')
EOSSH
/bin/chown -R '$XNAME:staff' '/home/$XNAME'
/bin/chmod 0700 '/home/$XNAME'
/bin/sed -i \\
    -e '/^PATH=/s#\$#:/opt/ooce/bin:/opt/ooce/sbin#' \\
    /etc/default/login
/bin/ntpdig -S 0.pool.ntp.org || true
echo 'ok go' >/dev/msglog
EOF
