# Copyright IBM Corp. 2015, 2025
# SPDX-License-Identifier: BUSL-1.1

# Nomad agent configuration for running a combined server+client node.
#
# Problem this solves:
# When using `nomad agent -dev`, Nomad only binds the HTTP dashboard to the
# configured bind address. Docker containers deployed by Nomad are assigned
# dynamic ports that are bound to the loopback interface (127.0.0.1) by the
# Docker engine, making them inaccessible from other machines.
#
# This config runs Nomad without -dev mode so that:
#   1. The Nomad HTTP API/UI is reachable on all interfaces (0.0.0.0).
#   2. Docker containers use explicit port bindings that are accessible on all
#      network interfaces — see the accompanying nginx job specs for details.
#
# Usage:
#   nomad agent -config=NomadTestConfigs/agent.hcl

# Bind the Nomad agent (HTTP, RPC, Serf) to all interfaces so the dashboard
# and API are reachable from any host on the network.
bind_addr = "0.0.0.0"

# Persist state to a dedicated directory with restricted permissions.
# /tmp is used here for quick local testing only — it is world-readable and
# may be cleared on reboot.  For anything more permanent use a directory such
# as /var/lib/nomad-test and ensure it is owned by the user running Nomad:
#   sudo mkdir -p /var/lib/nomad-test && sudo chown $(whoami) /var/lib/nomad-test
data_dir = "/tmp/nomad-test"

log_level = "INFO"

# Run a single-node server (no HA).
server {
  enabled          = true
  bootstrap_expect = 1
}

# Run the client on the same node.
client {
  enabled = true
}

# Advertise the agent's reachable address to other cluster members.
# Replace "YOUR_HOST_IP" with the IP address of the machine running Nomad,
# for example:
#   advertise { http = "192.168.1.10"  rpc = "192.168.1.10"  serf = "192.168.1.10" }
# Run `ip route get 1` or `hostname -I` to find the machine's primary IP.
# This tells Nomad what address to publish so that external clients (and
# Docker port-forwarding rules) know which interface to use.
advertise {
  http = "YOUR_HOST_IP"
  rpc  = "YOUR_HOST_IP"
  serf = "YOUR_HOST_IP"
}
