# NomadTestConfigs

This directory contains Nomad HCL configuration files that solve the problem of
Docker containers deployed by Nomad only being accessible on `localhost` when
the agent is started with `-dev` mode.

## The Problem

When you start Nomad with:

```
nomad agent -dev -bind 0.0.0.0
```

The `-bind 0.0.0.0` flag only affects the **Nomad HTTP API / dashboard** port.
Docker containers created by Nomad are assigned ports whose host-side binding
is controlled by the `HostIP` that Nomad's scheduler assigns to each port.

In dev mode on Linux, Nomad defaults to `network_interface = "lo"` (loopback).
That means every port's `HostIP` is `127.0.0.1`, and Docker receives the
binding as `-p 127.0.0.1:<port>:<container_port>` — making those containers
unreachable from any other host.

Passing `-bind 0.0.0.0` to the Nomad agent does **not** change this; `HostIP`
is determined by the client's `network_interface`, not by `bind_addr`.

## The Solution

Both job specs use `network_mode = "host"` so Docker containers share the
host's network namespace and nginx listens directly on `0.0.0.0` — no Docker
NAT or port-forwarding is involved.

| File | nginx port | Best for |
|------|-----------|----------|
| `nginx-host-network.nomad.hcl`  | 80   | Single nginx instance per node, default port |
| `nginx-static-port.nomad.hcl`   | 8080 | Multiple nginx instances per node, different ports |

An accompanying `agent.hcl` replaces the `-dev` flag with an explicit
server+client config that correctly advertises the host IP.

> **Why not bridge mode with a static port?**
> In Nomad's Docker driver, the host-side bind IP always comes from the port's
> `HostIP` (set from the client's `network_interface`).  In dev mode this is
> `127.0.0.1`, so even a static port would be bound as
> `-p 127.0.0.1:8080:80` — still unreachable externally.
> Using `network_mode = "host"` bypasses Docker port mapping entirely and is
> the only reliable way to bind nginx to all host interfaces (`0.0.0.0`).

---

## Files

### `agent.hcl`

A combined server+client Nomad agent configuration.  Edit the two placeholder
values before using it:
- Replace `YOUR_HOST_IP` in the `advertise` block with the machine's actual IP.
  Run `ip route get 1 | awk '{print $7; exit}'` to print the source IP for
  outbound traffic (the IP other machines use to reach this host).
- Replace `"eth0"` in `network_interface` with the NIC name for that IP.
  Run `ip route get 1 | awk '{print $5; exit}'` to print the interface name.

```
nomad agent -config=NomadTestConfigs/agent.hcl
```

Key settings:
- `bind_addr = "0.0.0.0"` — binds the Nomad dashboard and API to all interfaces.
- `client { network_interface = "eth0" }` — ensures ports are registered with
  the real NIC address, not the loopback.
- `advertise { http/rpc/serf = "YOUR_HOST_IP" }` — tells cluster members which
  IP to use when contacting this node.

---

### `nginx-host-network.nomad.hcl`

Deploys nginx using Docker's **host network mode**.  The container shares the
host's network namespace so nginx's default `0.0.0.0:80` binding is visible on
every interface of the host.

```
nomad job run NomadTestConfigs/nginx-host-network.nomad.hcl
```

After deployment nginx is reachable on port **80** of any IP address assigned
to the host.

> **Note:** Only one allocation of this job can run per node (port 80 cannot be
> shared).

---

### `nginx-static-port.nomad.hcl`

Deploys nginx with host networking and a rendered `nginx.conf` that tells nginx
to listen on `0.0.0.0:8080`.  The Nomad `static = 8080` port in the network
stanza informs the service catalog of the port; because `network_mode = "host"`
is used, Docker does no port mapping — nginx itself owns the port directly on
the host.

```
nomad job run NomadTestConfigs/nginx-static-port.nomad.hcl
```

After deployment nginx is reachable on port **8080** of any IP address assigned
to the host.

> **Tip:** To run multiple nginx instances on the same cluster, change the
> `static` value in each job to a unique port number.

---

## Why -dev mode doesn't work

`nomad agent -dev` is designed for **local development only**.  In addition to
the port-binding issue described above, the dev agent:

- Sets `network_interface = "lo"`, causing all port `HostIP` values to be
  `127.0.0.1`.
- Does not persist any state between restarts.
- Uses `localhost` for all internal communication.
- Skips several security checks.

For anything that must be reachable from other hosts (CI pipelines, integration
tests, other machines on the LAN), use a proper agent config such as the one in
`agent.hcl`.
