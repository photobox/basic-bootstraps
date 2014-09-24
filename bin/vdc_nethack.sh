#!/bin/bash
#
# rc.local
#
# This script is executed at the end of each multiuser runlevel.
# Make sure that the script will "exit 0" on success or any other
# value on error.
#
# In order to enable or disable this script just change the execution
# bits.
#
# By default this script does nothing.
set -e

NAT_DEVICE=${NAT_DEVICE:-"10.93.2.129"}

xlog(){
  echo "$(date -u +%FT%T.%6NZ) [vdc_nethack] $1"
  logger -t vdc_nethack $1
}

xlog "Using NAT device: ${NAT_DEVICE}"

ADDRESS=
while [ -z "${ADDRESS}" ]; do
        ADDRESS=$(ip a show dev eth0|grep 'inet '|awk '{print $2}'|cut -d/ -f1)
        sleep 5
done
xlog "Address: ${ADDRESS}"

NS=$(grep domain-name-servers /var/lib/dhcp3/dhclient.eth0.leases|tail -1|sed -E 's/;$//'|awk '{print $NF}'|cut -d, -f1)
xlog "Using local NS: ${NS}"

HOSTNAME=$(grep host-name /var/lib/dhcp3/dhclient.eth0.leases|tail -1|sed -E 's/;$//'|awk '{print $NF}'|sed 's/"//g')
hostname ${HOSTNAME}
echo ${HOSTNAME} > /etc/hostname
xlog "Set hostname to: ${HOSTNAME}"

VDC_ROUTER=$(grep routers /var/lib/dhcp3/dhclient.eth0.leases|tail -1|sed -E 's/;$//'|awk '{print $NF}')
xlog "VDC Router is: ${VDC_ROUTER}"

sed '/^127\..*/d' /etc/hosts > /tmp/hosts.$$
cat <<EOF > /etc/hosts
# Added by $0
127.0.0.1 localhost
127.0.1.1 ${HOSTNAME}.photobox.com ${HOSTNAME}

EOF
cat /tmp/hosts.$$ >> /etc/hosts

set +e
{
  ip route del default
  ip route add 10.0.0.0/8 via ${VDC_ROUTER} 
  ip route add default via ${NAT_DEVICE}
} 2>/dev/null

exit 0
