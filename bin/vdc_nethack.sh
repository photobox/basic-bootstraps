#!/bin/bash
#
# This script makes adjustments to VDC instance networking in order to make
# instances function as happy Babel servers. I'm not convinced a lot of the
# work done by this script actually needs to be done, but in the interests of
# expediency I just improved up the code I found in /etc/rc.local a bit and put
# it here for now.
#
# This script does the following things:
#
# * Sets the hostname to whatever DCHP thinks it should be (why?)
#
# * Sets up entries in /etc/hosts, using the "photobox.com" domain, so that
#   `hostname`, `hostname -s` & `hostname -f` all do the right thing (why do we
#   need to use the photobox.com domain?)
#
# * Sets up a route to 10.0.0.0/8 via the original, DHCP supplied, gateway so
#   that all outbound traffic doesn't use the NAT instance.
#
# * Sets a new default route using the NAT instance supplied as the envvar
#   NAT_DEVICE, or a default (why?)
#
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
