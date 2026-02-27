# Copyright IBM Corp. 2015, 2025
# SPDX-License-Identifier: BUSL-1.1

# nginx job — host-network approach
#
# This job uses `network_mode = "host"` inside the Docker task config, which
# places the container directly in the host's network namespace.  nginx binds
# to 0.0.0.0:80 inside the container, but because the container shares the
# host's network stack that binding is immediately visible on every network
# interface of the host machine — no Docker NAT / port-forwarding is involved.
#
# When to use this approach:
#   • You want the simplest possible configuration.
#   • You are comfortable with the container sharing the host network stack
#     (i.e. any port the container listens on is exposed on every host
#     interface).
#
# Limitations:
#   • You cannot run more than one allocation of this job per host node
#     (both would try to bind port 80).
#   • Consul/Nomad service-port checks should use the host IP directly.
#
# Usage:
#   nomad job run NomadTestConfigs/nginx-host-network.nomad.hcl

job "nginx-host-network" {
  datacenters = ["dc1"]
  type        = "service"

  group "nginx" {
    count = 1

    # With network_mode = "host" the network stanza is used only to register
    # the port with Nomad's service catalog; Docker itself does not create a
    # port-mapping rule.
    network {
      mode = "host"

      port "http" {
        static = 80
        to     = 80
      }
    }

    service {
      name     = "nginx-host-network"
      port     = "http"
      provider = "nomad"

      check {
        type     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "nginx" {
      driver = "docker"

      config {
        image = "nginx:latest"

        # Share the host network namespace — the container will see and bind to
        # all interfaces that the host has (including 0.0.0.0).
        network_mode = "host"
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }
  }
}
