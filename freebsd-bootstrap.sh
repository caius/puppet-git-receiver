#!/usr/bin/env sh
#
# Bootstrap https://github.com/brightbox/puppet-git-receiver/ on FreeBSD
#

set -e

# Install dependencies
pkg install -y bash git puppet38 sudo
gem install --no-rdoc --no-ri librarian-puppet

# Sort out SSL certs for ruby's openssl or librarian-puppet can't work
[ -f /etc/ssl/cert.pem ] || ln -sf /usr/local/etc/ssl/cert.pem /etc/ssl/cert.pem

BRANCH="freebsd"
REPO="https://github.com/caius/puppet-git-receiver.git"

PGR_HOME="/var/puppet-git-receiver"
PGR_USER="puppet-git"
PGR_GROUP="puppet-git"

PGR_DIR="$PGR_HOME/puppet-git-receiver.git"
PUPPET_DIR="$PGR_HOME/puppet.git"
HOOKS_DIR="$PUPPET_DIR/hooks"

# Add puppet-git user & group
# name:uid:gid:class:change:expire:gecos:home_dir:shell:password
id ${PGR_USER} > /dev/null 2>&1 || echo "${PGR_USER}:::::::${PGR_HOME}:/usr/local/libexec/git-core/git-shell:" | adduser -f - -M 750 -w no

if [ ! -d "$PGR_DIR" ]; then
  git clone -q -b "$BRANCH" "$REPO" "$PGR_DIR"
fi

if [ ! -d "$PUPPET_DIR" ]; then
  mkdir -p $PUPPET_DIR
  chmod 2770 $PUPPET_DIR
fi

if [ ! -d "$HOOKS_DIR" ]
then
  GIT_DIR=$PUPPET_DIR git init --bare
fi

# Install update hook as puppet-git user/group
ln -fns "$PGR_DIR/puppet-git-receiver-update-hook" "$HOOKS_DIR/update"
chown -h $PGR_USER:$PGR_GROUP "$HOOKS_DIR/update"

# Allow puppet-git to run puppet as root
if [ ! -f /usr/local/etc/sudoers.d/puppet-git ]; then
  echo "puppet-git ALL=NOPASSWD: SETENV:/usr/local/bin/puppet" > /usr/local/etc/sudoers.d/puppet-git
fi

# Allow SSH access via key
mkdir -p "$PGR_HOME/.ssh"
curl -so "$PGR_HOME/.ssh/authorized_keys" "http://caius.name/_sshkey.txt"

# Move cache somewhere semi-persistent (as we're running git hook in temp dir)
mkdir -p "$PGR_HOME/.librarian/puppet"
echo '---
LIBRARIAN_PUPPET_TMP: "/tmp"
' > "$PGR_HOME/.librarian/puppet/config"

# Tidy up permissions
chown -R $PGR_USER:$PGR_GROUP $PGR_HOME
