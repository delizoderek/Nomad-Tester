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
Docker containers created by Nomad are assigned **dynamic ports** whose
host-side binding defaults to `127.0.0.1` in many Docker/kernel
configurations, making those containers unreachable from any host other than
`localhost`.

## The Solution

There are two complementary fixes, each provided as a separate job spec:

| File | Approach | Best for |
|------|----------|----------|
| `nginx-host-network.nomad.hcl` | `network_mode = "host"` | Simplest setup; container shares the host network stack |
| `nginx-static-port.nomad.hcl`  | Static port `0.0.0.0:<port>` | Standard Docker isolation; predictable port number |

An accompanying `agent.hcl` replaces the `-dev` flag with an explicit
server+client config that correctly advertises the host IP.

---

## Files

### `agent.hcl`

A combined server+client Nomad agent configuration.  Replace `YOUR_HOST_IP`
with the actual IP address of the machine before using it.

```
nomad agent -config=NomadTestConfigs/agent.hcl
```

Key settings:
- `bind_addr = "0.0.0.0"` — binds the Nomad dashboard and API to all interfaces.
- `advertise { http/rpc/serf = "YOUR_HOST_IP" }` — tells cluster members which
  IP to use when contacting this node.

---

### `nginx-host-network.nomad.hcl`

Deploys nginx using Docker's **host network mode**.  The container shares the
host's network namespace so nginx's `0.0.0.0:80` binding is visible on every
interface of the host.

```
nomad job run NomadTestConfigs/nginx-host-network.nomad.hcl
```

After deployment nginx is reachable on port **80** of any IP address assigned
to the host.

> **Note:** Only one allocation of this job can run per node (port 80 cannot be
> shared).

---

### `nginx-static-port.nomad.hcl`

Deploys nginx with a **static port mapping** (`0.0.0.0:8080 → 80`).  Nomad
instructs the Docker daemon to publish the container port with an explicit
`0.0.0.0` bind address, making it reachable on all interfaces.

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

- Does not persist any state between restarts.
- Uses `localhost` for all internal communication.
- Skips several security checks.

For anything that must be reachable from other hosts (CI pipelines, integration
tests, other machines on the LAN), use a proper agent config such as the one in
`agent.hcl`.
