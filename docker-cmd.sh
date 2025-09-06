#!/bin/bash
set -eu

echo "Munin for Docker v$(</run/version)..."

TZ="${TZ:-}"
NODES="${NODES:-}"
SNMP_NODES="${SNMP_NODES:-}"
SNMP_PLUGINS_EXCLUDED="${SNMP_PLUGINS_EXCLUDED:-}"

generate_node_config () {

  for NODE in $NODES
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

}

generate_snmp_node_config () {

  for SNMP_NODE in $SNMP_NODES
  do
    NAME=`echo "$SNMP_NODE" | cut -d ":" -f 1`
    COMM=`echo "$SNMP_NODE" | cut -d ":" -f 2`
    REMOTE=`echo "$NAME" | cut -d ";" -f 2`
    if ! grep -q "$REMOTE" /etc/munin/munin-conf.d/snmp_nodes.conf 2>/dev/null ; then
      cat << EOF >> /etc/munin/munin-conf.d/snmp_nodes.conf
[$NAME]
    address localhost
    use_node_name no

EOF
    fi

    # Probe snmp host to get SNMP plugins
    # Filter list by node entry in $h_snmp_plugins_excluded
    install_snmp_plugins
      
  done

}

install_snmp_plugins () {

  declare -A h_snmp_plugins_excluded

  for PLUGIN in $SNMP_PLUGINS_EXCLUDED ; do 
    NAME=`echo "$SNMP_PLUGINS_EXCLUDED" | cut -d ":" -f 1`
    PLUGIN_LIST=`echo "$SNMP_PLUGINS_EXCLUDED" | cut -d ":" -f 2`
    h_snmp_plugins_excluded[$NAME]="$(echo $PLUGIN_LIST | sed -e 's/,/ /g')"
  done

  echo "exclude_plugins: name=$NAME h_plugins_excluded[$NAME]=${h_snmp_plugins_excluded[$NAME]}" >> /docker-cmd.log
  if [ ! -z "${h_snmp_plugins_excluded[$NAME]}" ] ; then
    GREP_ARGS="-v"
    for r in ${h_snmp_plugins_excluded[$NAME]} ; do
      GREP_ARGS="$GREP_ARGS -e snmp__$r"
    done
    munin-node-configure --shell --snmp $REMOTE | grep $GREP_ARGS | sh
  fi

}

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

# Generate node config
[[ ! -z "$NODES" ]] && generate_node_config

# Generate snmp_node config
[[ ! -z "$SNMP_NODES" ]] && generate_snmp_node_config

# Add munin_stats plugin to /etc/munin/plugins/
ln -s /usr/lib/munin/plugins/munin_stats /etc/munin/plugins/munin_stats

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
