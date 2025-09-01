#!/bin/bash
set -eu

echo "Munin for Docker v$(</run/version)..."

TZ="${TZ:-}"
NODES="${NODES:-}"
SNMP_NODES="${SNMP_NODES:-}"
SNMP_PLUGINS_EXCLUDED="${SNMP_PLUGINS_EXCLUDED:-}"

TEMP_SNMP_PLUGINS_SCRIPT="/tmp/snmp_plugins.$$"

if [ -n "$TZ" ]; then

  # Set timezone
  if [ ! -f "/usr/share/zoneinfo/$TZ" ]; then
    TZ="UTC"
  fi

  cp "/usr/share/zoneinfo/$TZ" /etc/localtime
  echo "$TZ" > /etc/timezone

fi

# Make directories before setting permissions
mkdir -p /run/munin
mkdir -p /var/log/munin
mkdir -p /var/lib/munin/cgi-tmp

# Fix ownership
chown munin:munin \
  /var/log/munin /run/munin /var/lib/munin /var/lib/munin/cgi-tmp \
  /etc/munin/munin-conf.d /etc/munin/plugin-conf.d

chmod 755 /usr/share/webapps/munin/html
chown -R munin:munin /usr/share/webapps/munin/html

# Prepare for rrdcached
sudo -u munin -- mkdir -p /var/lib/munin/rrdcached-journal
chown munin:munin /var/lib/munin/rrdcached-journal

# Start rrdcached
sudo -u munin -- /usr/sbin/rrdcached \
  -p /run/munin/rrdcached.pid \
  -B -b /var/lib/munin/ \
  -F -j /var/lib/munin/rrdcached-journal/ \
  -m 0660 -l unix:/run/munin/rrdcached.sock \
  -w 1800 -z 1800 -f 3600

# Generate node list
[[ ! -z "$NODES" ]] && for NODE in $NODES
do
  NAME=`echo "$NODE" | cut -d ":" -f1`
  HOST=`echo "$NODE" | cut -d ":" -f2`
  PORT=`echo "$NODE" | cut -d ":" -f3`
  if [ ${#PORT} -eq 0 ]; then
      PORT=4949
  fi
  if ! grep -q "$HOST" /etc/munin/munin-conf.d/nodes.conf 2>/dev/null ; then
    cat << EOF >> /etc/munin/munin-conf.d/nodes.conf
[$NAME]
    address $HOST
    use_node_name yes
    port $PORT

EOF
  fi
done

# Generate snmp_node list
[[ ! -z "$SNMP_NODES" ]] && for SNMP_NODE in $SNMP_NODES
do
  NAME=`echo "$SNMP_NODE" | cut -d ":" -f 1`
  COMM=`echo "$SNMP_NODE" | cut -d ":" -f 2`
  REMOTE=`echo "$NAME" | cut -d ";" -f 2`
  if [ ${#COMM} -eq 0 ]; then
      COMM="public"
  fi
  if ! grep -q "$HOST" /etc/munin/munin-conf.d/snmp_nodes.conf 2>/dev/null ; then
    cat << EOF >> /etc/munin/munin-conf.d/snmp_nodes.conf
[$NAME]
    address localhost
    use_node_name no

EOF

# Probe snmp host to get plugins
# Filter list by SNMP_PLUGIN_EXCLUDED regexp
    if [ ! -z "$SNMP_PLUGINS_EXCLUDED" ] ; then
      GREP_ARGS="-v"
      for r in $SNMP_PLUGINS_EXCLUDED ; do
        GREP_ARGS="$GREP_ARGS -e snmp__$r"
      done
      echo GREP_ARGS=$GREP_ARGS
      munin-node-configure --shell --snmp $REMOTE --snmpcommunity $COMM | grep $GREP_ARGS > $TEMP_SNMP_PLUGINS_SCRIPT
    fi
    [[ -z "$SNMP_PLUGINS_EXCLUDED" ]] && munin-node-configure --shell --snmp $NAME --snmpcommunity $COMM > $TEMP_SNMP_PLUGINS_SCRIPT
    . $TEMP_SNMP_PLUGINS_SCRIPT && rm -f $TEMP_SNMP_PLUGINS_SCRIPT
  fi
done

# Run once before we start fcgi
sudo -u munin -- /usr/bin/munin-cron munin

# Spawn fast cgi process for generating graphs on the fly
spawn-fcgi -s /var/run/munin/fastcgi-graph.sock -U nginx -u munin -g munin -- \
  /usr/share/webapps/munin/cgi/munin-cgi-graph

# Spawn fast cgi process for generating html on the fly
spawn-fcgi -s /var/run/munin/fastcgi-html.sock -U nginx -u munin -g munin -- \
  /usr/share/webapps/munin/cgi/munin-cgi-html

# Munin and logrotate runs in cron, start cron
crond

# Spawn munin-node
munin-node

# Start web-server
nginx
