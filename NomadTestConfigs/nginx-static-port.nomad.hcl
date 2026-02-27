# Copyright IBM Corp. 2015, 2025
# SPDX-License-Identifier: BUSL-1.1

# nginx job — host network with a configurable static port
#
# This job runs nginx using Docker host networking so it binds to 0.0.0.0 on
# the host.  nginx is configured via a rendered template to listen on port 8080
# rather than the default port 80, which is useful when:
#   • Port 80 is already occupied on the host node.
#   • You need multiple nginx containers on the same node, each on a different
#     port, while keeping every one accessible on all network interfaces.
#
# Why NOT bridge mode with a static port?
# Nomad's Docker driver always passes the host's assigned IP address as the
# Docker bind IP (e.g. -p 127.0.0.1:8080:80 in dev mode).  Using bridge mode
# therefore binds the port to 127.0.0.1 in dev mode, which is exactly the
# problem being solved.  Host networking bypasses Docker NAT entirely: nginx
# listens directly on 0.0.0.0:8080 of the host's network stack.
#
# When to use this approach:
#   • You want a predictable, well-known port number AND 0.0.0.0 binding.
#   • You may run multiple nginx jobs on the same cluster by giving each job a
#     different static port value.
#
# Usage:
#   nomad job run NomadTestConfigs/nginx-static-port.nomad.hcl

job "nginx-static-port" {
  datacenters = ["dc1"]
  type        = "service"

  group "nginx" {
    count = 1

    network {
      # Host networking: no Docker NAT, container shares the host network stack.
      mode = "host"

      # The `static` value tells Nomad's service catalog which host port this
      # container listens on.  nginx will be configured below to actually bind
      # to this port on 0.0.0.0.
      port "http" {
        static = 8080
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

        # Host networking: nginx listens directly on the host's network
        # namespace, binding to 0.0.0.0:8080 on every interface.
        network_mode = "host"

        ports = ["http"]

        mount {
          type   = "bind"
          source = "local/nginx.conf"
          target = "/etc/nginx/nginx.conf"
        }
      }

      # Render a minimal nginx.conf that explicitly listens on 0.0.0.0 using
      # the port Nomad assigned (NOMAD_PORT_http = 8080).
      template {
        destination = "local/nginx.conf"
        data        = <<EOT
events {}
http {
  server {
    listen 0.0.0.0:{{ env "NOMAD_PORT_http" }};
    location / {
      root  /usr/share/nginx/html;
      index index.html;
    }
  }
}
EOT
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }
  }
}
