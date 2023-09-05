docker-munin
=============

[![Build]][build_url]
[![Version]][tag_url]
[![Size]][tag_url]
[![Pulls]][hub_url]

Container image for a Munin master server, optimized for a large number of nodes in an effective manner.

* `rrdcached` is used to be able to handle a large number of nodes

* `fcgi` is used for generation of graphs on demand and not cron

## How to use

Via `docker-compose`

```yaml
version: "3"
services:
  munin:
    container_name: munin
    image: dockurr/munin:latest
    environment:
      - "NODES=node1:10.0.0.101 node2:10.0.0.102"
      - "TZ=Europe/Berlin"
    ports:
      - "80:80/tcp"
    volumes:
      - "/munin/lib:/var/lib/munin"
      - "/munin/log:/var/log/munin"
      - "/munin/conf:/etc/munin/munin-conf.d"
      - "/munin/plugin:/etc/munin/plugin-conf.d"
    restart: "onfailure"
    stop_grace_period: 1m
```

Via docker `run`

```bash
docker run -d \
  -p 80:80 --name munin \
  -v /munin/lib:/var/lib/munin \
  -v /munin/log:/var/log/munin \
  -v /munin/conf:/etc/munin/munin-conf.d \
  -v /munin/plugin:/etc/munin/plugin-conf.d \
  -e NODES="node1:10.0.0.101 node2:10.0.0.102" \
  dockurr/munin
```

Access the container at `http://host/munin/`

[build_url]: https://github.com/dockur/munin/
[hub_url]: https://hub.docker.com/r/dockurr/munin
[tag_url]: https://hub.docker.com/r/dockurr/munin/tags

[Build]: https://github.com/dockur/munin/actions/workflows/build.yml/badge.svg
[Size]: https://img.shields.io/docker/image-size/dockurr/munin/latest?color=066da5&label=size
[Pulls]: https://img.shields.io/docker/pulls/dockurr/munin.svg?style=flat&label=pulls&logo=docker
[Version]: https://img.shields.io/docker/v/dockurr/munin/latest?arch=amd64&sort=semver&color=066da5
