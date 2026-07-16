# Contributing to ZDM Proxy Automation

Thank you for your interest in contributing! This document explains how to test your changes locally before submitting a pull request.

## Unit Tests

Run all Go unit tests from the `zdm-util` directory:

```shell
cd zdm-util
go test ./...
```

Expected output: both `pkg/config` and `pkg/userinteraction` pass with no failures.

Also confirm the binary compiles cleanly:

```shell
go build -o zdm-util-test .
```

---

## Manual End-to-End Testing

This section describes how to run manual end-to-end tests of the ZDM Proxy Automation locally.

### Prerequisites

- [Docker](https://docs.docker.com/get-docker/) and [Docker Compose](https://docs.docker.com/compose/install/) installed and running
- Go 1.24+ installed (for unit tests and building `zdm-util`)
- An SSH key pair — generate a throwaway one if needed:
  ```shell
  ssh-keygen -t rsa -f test-key
  ```

> **Note:** `zdm-util` is only officially supported on Linux. Running it on Windows will work for most steps but the generated Ansible inventory will contain your Windows username instead of `ubuntu` as the `ansible_user`. Edit the inventory manually inside the container to correct this if needed.

---

### Option 1 — Docker Compose (without zdm-util)

This path uses the built-in jumphost container to run Ansible automatically against the proxy containers.

#### Start the stack

> **Important:** ensure `compose/keys/` is empty before starting. A stale public key from a previous run will cause SSH authentication failures.

```shell
rm -f compose/keys/*
docker-compose up -d
docker logs -f zdm-proxy-automation-jumphost-1
```

Wait for the jumphost to complete (~10-15 min). It ends with `Ready`.

#### Verify the proxy is working

Wait for the client container to also print `Ready`:

```shell
docker logs -f zdm-proxy-automation-client-1
```

Then issue a CQL query through the proxy:

```shell
docker exec -it zdm-proxy-automation-client-1 cqlsh zdm-proxy-automation-proxy-1 -e 'SELECT * FROM system.local;'
```

#### Test a new configuration variable

Pin the proxy image to the version under test in `ansible/vars/zdm_proxy_container_config.yml`:

```yaml
zdm_proxy_image: datastax/zdm-proxy:2.5.0
```

Run a rolling update from inside the jumphost container:

```shell
docker exec -it zdm-proxy-automation-jumphost-1 bash -c "
  cd /opt/zdm-proxy-automation/ansible &&
  gosu ubuntu ansible-playbook rolling_update_zdm_proxy.yml \
    -i zdm_ansible_inventory \
    -e 'zdm_proxy_max_prepared_statement_cache_size=5000' \
    -e 'origin_username=foo' -e 'origin_password=foo' \
    -e 'target_username=foo' -e 'target_password=foo' \
    -e 'origin_contact_points=zdm-proxy-automation-origin-1' \
    -e 'origin_port=9042' \
    -e 'target_contact_points=zdm-proxy-automation-target-1' \
    -e 'target_port=9042'"
```

Check the proxy logs to confirm the new configuration was applied:

```shell
docker exec zdm-proxy-automation-proxy-1 docker logs \
  $(docker exec zdm-proxy-automation-proxy-1 docker ps -q)
```

#### Teardown

```shell
docker-compose down
rm -f compose/keys/*
```

---

### Option 2 — zdm-util

This path tests `zdm-util` itself by using it to create and initialize the Ansible Control Host container, replacing the jumphost.

#### Build zdm-util

```shell
cd zdm-util
go build -o zdm-util-test .
```

#### Start cluster and proxy containers (no jumphost)

```shell
rm -f compose/keys/*
docker-compose up -d origin target proxy
```

Copy your public key into `compose/keys/` immediately so the proxy containers can install it while zdm-util is running:

```shell
cp test-key.pub compose/keys/id_rsa.pub
```

Wait for all three proxies to print `Ready`:

```shell
docker logs zdm-proxy-automation-proxy-1 2>&1 | tail -3
docker logs zdm-proxy-automation-proxy-2 2>&1 | tail -3
docker logs zdm-proxy-automation-proxy-3 2>&1 | tail -3
```

Get the proxy IPs:

```shell
docker inspect zdm-proxy-automation-proxy-1 zdm-proxy-automation-proxy-2 zdm-proxy-automation-proxy-3 \
  --format '{{.Name}}: {{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}'
```

#### Run zdm-util

```shell
cd zdm-util
./zdm-util-test
```

When prompted, enter:

| Prompt | Value |
|---|---|
| SSH key path | `../test-key` |
| Proxy IP address prefix | `192.168.*` (or whatever subnet your compose network uses) |
| Existing Ansible inventory? | `n` — generate a new one |
| Demo or production? | production |
| Proxy IPs | Enter each IP from the previous step, then press Enter on an empty line to finish |
| Monitoring server? | `n` |

Expected output ends with:
```
Ansible container zdm-ansible-container successfully initialized
```

#### Connect the container to the proxy network

```shell
docker network connect proxy zdm-ansible-container
```

#### Deploy via Ansible

Get the Origin and Target IPs:

```shell
docker inspect zdm-proxy-automation-origin-1 zdm-proxy-automation-target-1 \
  --format '{{.Name}}: {{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}'
```

Exec into the container:

```shell
docker exec -it zdm-ansible-container bash
```

Switch to the branch under test (the container clones `main` from GitHub on first run):

```shell
cd /home/ubuntu/zdm-proxy-automation
git fetch origin <your-branch>
git checkout <your-branch>
git log --oneline -3
```

Pre-scan host keys to avoid interactive fingerprint prompts:

```shell
ssh-keyscan <proxy-ip-1> <proxy-ip-2> <proxy-ip-3> >> ~/.ssh/known_hosts
```

Run the deploy playbook (substitute actual Origin and Target IPs):

```shell
cd /home/ubuntu && ansible-playbook zdm-proxy-automation/ansible/deploy_zdm_proxy.yml \
  -i zdm-proxy-automation/ansible/zdm_ansible_inventory \
  -e "origin_username=foo" -e "origin_password=foo" \
  -e "target_username=foo" -e "target_password=foo" \
  -e "origin_contact_points=<origin-ip>" -e "origin_port=9042" \
  -e "target_contact_points=<target-ip>" -e "target_port=9042"
```

Expected: all three proxies complete with `unreachable=0 failed=0`.

#### Test a new configuration variable via rolling update

```shell
ansible-playbook zdm-proxy-automation/ansible/rolling_update_zdm_proxy.yml \
  -i zdm-proxy-automation/ansible/zdm_ansible_inventory \
  -e "zdm_proxy_max_prepared_statement_cache_size=5000" \
  -e "origin_username=foo" -e "origin_password=foo" \
  -e "target_username=foo" -e "target_password=foo" \
  -e "origin_contact_points=<origin-ip>" -e "origin_port=9042" \
  -e "target_contact_points=<target-ip>" -e "target_port=9042"
```

#### Verify proxy logs

From outside the container:

```shell
docker exec zdm-proxy-automation-proxy-1 docker logs \
  $(docker exec zdm-proxy-automation-proxy-1 docker ps -q)
docker exec zdm-proxy-automation-proxy-2 docker logs \
  $(docker exec zdm-proxy-automation-proxy-2 docker ps -q)
docker exec zdm-proxy-automation-proxy-3 docker logs \
  $(docker exec zdm-proxy-automation-proxy-3 docker ps -q)
```

#### Teardown

```shell
exit   # exit the container shell
docker-compose down
docker rm -f zdm-ansible-container
rm -f compose/keys/*
```

---

## CI Workflows

| Workflow | Trigger | What it validates |
|---|---|---|
| `zdm-util-unit-tests.yml` | Every push | Go unit tests in `golang:1.26.5-bookworm` |
| `ansible-integration.yaml` | Every push | Full docker-compose stack + cqlsh probe query |

After pushing your branch, confirm the unit test and integration workflows pass before requesting a review.
