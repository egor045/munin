FROM alpine

# Install packages
RUN apk --update --no-cache add \
  coreutils \
  dumb-init \
  findutils \
  logrotate \
  munin \
  munin-node \
  nginx \
  perl-cgi-fast \
  procps \
  rrdtool-cached \
  spawn-fcgi \
  sudo \
  ttf-opensans \
  tzdata; \
  && sed '/^[^*].*$/d; s/ munin //g' /etc/munin/munin.cron.sample | crontab -u munin -; \
  && sed -i 's#^log_file.*#log_file /dev/stdout#' /etc/munin/munin-node.conf;

# Default nginx.conf
COPY nginx.conf /etc/nginx/

# Copy munin config to nginx
COPY default.conf /etc/nginx/conf.d/

# Copy munin conf
COPY munin.conf /etc/munin/

# Start script with all processes
COPY docker-cmd.sh /

# Logrotate script for munin logs
COPY munin /etc/logrotate.d/

# Expose volumes
VOLUME /etc/munin/munin-conf.d /etc/munin/plugin-conf.d /var/lib/munin /var/log/munin

# Expose NODES variable
ENV NODES ""

# Expose SNMP_NODES variable
ENV SNMP_NODES ""

# Expose variable to disable node
ENV DISABLE_MUNIN_NODE true

# Expose nginx
EXPOSE 80

# Container version
ARG DATE_ARG=""
ARG BUILD_ARG=0
ARG VERSION_ARG="0.0"
ENV VERSION=$VERSION_ARG

LABEL org.opencontainers.image.created=${DATE_ARG}
LABEL org.opencontainers.image.revision=${BUILD_ARG}
LABEL org.opencontainers.image.version=${VERSION_ARG}
LABEL org.opencontainers.image.url=https://hub.docker.com/r/kroese/munin-docker/
LABEL org.opencontainers.image.source=https://github.com/kroese/munin-docker/

# Healthcheck
HEALTHCHECK --interval=30s --retries=1 --timeout=3s CMD wget -nv -t1 --spider 'http://localhost:80/munin/' || exit 1

# Use dumb-init since we run a lot of processes
ENTRYPOINT ["/usr/bin/dumb-init", "--"]

# Run start script or what you choose
CMD /docker-cmd.sh
