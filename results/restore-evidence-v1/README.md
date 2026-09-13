# ARM64 synthetic restore evidence

This packet records one successful Miniflux and Grafana recovery drill for
commit `ff85dd76a4ce9cd50850845bb26aee3f881327ad`. The drill ran in a disposable
`aarch64` NixOS test machine inside an ARM64 UTM guest with Nix 2.34.8.

The test wrote the exact synthetic marker
`nix-homelab-restore-evidence-v1` to a dedicated table in each service
database. It created a 1,716-byte PostgreSQL backup and a 181-byte SQLite
backup, deleted both marker tables, restored them, recovered the exact marker
from both databases, and verified both service health endpoints.

The measured restore-and-verify stage took 58.013 seconds. The full test took
528.228 seconds, including the first software-emulated service startup. These
figures describe one disposable test run. They are not a recovery-time
objective or a production-readiness claim.

See [`result.json`](result.json) for inputs, hashes, assertions, stage timings,
and limitations. Verify the retained artifacts from this directory with:

```sh
sha256sum --check manifest.sha256
```

This packet contains synthetic markers and hashes only. It contains no real
backup, hostname, address, credential, private configuration, or service data.
