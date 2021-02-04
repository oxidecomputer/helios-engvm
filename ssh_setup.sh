#!/bin/bash

#
# Updates SSH configuration, allowing for easier connections
# into VMs with the syntax "ssh <VM NAME>.vm"
#

set -eou pipefail

TOP=$(cd "$(dirname "$0")" && pwd)

USER=$(id -un)
SSH_INCLUDE="Include ~/.ssh/helios_engvm_config"

# If we don't have have a VM-routing configuration, add one.
# This merely appends an "Include" statement to the User's ssh
# config, pointing to a custom config file.
#
# Separating the custom config from the user's config makes
# it easier to customize the VM-specific configuration
# without trampling user-defined configs.
if ! grep -x "$SSH_INCLUDE" ~/.ssh/config &> /dev/null ; then
  echo "Adding \""$SSH_INCLUDE"\" to ~/.ssh/config"
  cat >>~/.ssh/config <<EOL
$SSH_INCLUDE
EOL
fi

# Overwrite the custom config unconditionally.
#
# If a user moves the location of the "helios-engvm" repo in
# their source tree, re-running ssh_setup will fix the config.
cat >~/.ssh/helios_engvm_config <<EOL
Host *.vm
  User $USER
  ProxyCommand $TOP/_nc_virsh.sh vm %h %p
  ForwardAgent yes
  ServerAliveInterval 15
EOL
