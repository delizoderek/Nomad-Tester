# Copyright IBM Corp. 2015, 2025
# SPDX-License-Identifier: BUSL-1.1

# nginx job — static port approach
#
# This job uses a *static* port in Nomad's network stanza.  When Nomad submits
# the Docker port-mapping to the Docker daemon it uses the form
#   -p 0.0.0.0:<host_port>:<container_port>
# which binds the host port on *all* interfaces, making the container
# reachable from outside the machine.
#
# By contrast, *dynamic* ports (no `static` value) default to an ephemeral
# port on 127.0.0.1 in many Docker / kernel configurations, which is why the
# container is unreachable from other hosts when running in -dev mode.
#
# When to use this approach:
#   • You want a predictable, well-known port number.
#   • You need standard Docker isolation (no host-network sharing).
#   • You may run multiple nginx jobs on the same cluster by giving each job a
#     different static port.
#
# Usage:
#   nomad job run NomadTestConfigs/nginx-static-port.nomad.hcl

job "nginx-static-port" {
  datacenters = ["dc1"]
  type        = "service"

  group "nginx" {
    count = 1

    network {
      # `static` pins the host-side port.  Nomad's Docker driver publishes
      # this as  0.0.0.0:8080 -> 80  so the container is reachable on port
      # 8080 of every network interface on the host.
      port "http" {
        static = 8080
        to     = 80
      }
    }

    service {
      name     = "nginx-static-port"
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

        # Tell Nomad which named ports from the network stanza to expose.
        # Nomad translates this to  -p 0.0.0.0:8080:80  for the Docker daemon.
        ports = ["http"]
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }
  }
}
