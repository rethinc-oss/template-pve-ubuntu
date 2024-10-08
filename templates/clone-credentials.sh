#!/bin/sh

# is_root()
#
# Returns 0 if the current user is root. Otherwise returns 1.
is_root ()
{
    [ "$(id -u)" -eq 0 ]
}

# contains(string, substring)
#
# Returns 0 if the specified string contains the specified substring,
# otherwise returns 1.
contains() {
    string="$1"
    substring="$2"
    if [ "${string#*"$substring"}" != "$string" ]; then
        return 0    # $substring is in $string
    else
        return 1    # $substring is not in $string
    fi
}

is_lxc() {
    contains $(systemd-detect-virt) 'lxc'
    return $?
}

is_pve() {
    contains $(uname -r) 'pve'
    return $?
}

ROOTPW='*'
get_root_pw() {
    ROOTPW="$(grep root /etc/shadow | awk -F: '{print $2}')"
}

if ! is_root; then
    echo 'Script must be run as root'
    exit 1
fi

get_root_pw
if [ "$ROOTPW" != '*' ]; then
    usermod -p "${ROOTPW}" sysop
    usermod -p "*" root
fi

if [ -f /root/.ssh/authorized_keys ]; then
    mkdir -m 0700 /home/sysop/.ssh
    cp /root/.ssh/authorized_keys /home/sysop/.ssh
    chown sysop:sysop /home/sysop/.ssh
    chown sysop:sysop /home/sysop/.ssh/authorized_keys
    rm -rf /root/.ssh
fi

systemctl disable clone-credentials.service
rm /etc/systemd/system/clone-credentials.service
rm /usr/local/bin/clone-credentials.sh
