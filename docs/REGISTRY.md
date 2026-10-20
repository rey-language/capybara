# Package registry

The beta registry is the Git repository
[`rey-language/packages`](https://github.com/rey-language/packages). Its
package layout is:

```text
packages/
└── <name>/
    ├── capy.toml
    └── src/
        └── main.rey
```

A package manifest declares its name, version, entry, and dependencies. The
beta keeps one version per package directory. A dependency requirement is an
exact version string or `*`/empty for any version; range semantics are not
defined by the beta.

## Install and vendor behavior

Capy caches the registry at `~/.capy/registry/packages`. If absent, it clones
the configured URL shallowly. Unless `--offline` or `--locked` is selected, an
existing cache is updated using `git pull --ff-only`. `capy install` can use
the default repository or a URL/local path supplied with `--registry`.

For each selected package, Capy copies the contents of
`packages/<name>/src/` into `<project>/vendor/<name>/` (so `main.rey` is at the
vendor root) and copies `packages/<name>/capy.toml` to
`vendor/<name>/capy.toml`. The beta import convention is:

```rey
import vendor::<name>;
```

Packages provide source and a manifest; installation does not run package
scripts. The package source becomes part of the consuming project under
`vendor/`.

## Lockfile

`capy.lock` records the resolved version, registry Git commit hash, and source
for each package:

```toml
[rey-postgres]
version = "0.1.0"
commit = "0123456789abcdef"
source = "rey-language/packages"
```

Commit the lockfile with the project to preserve the selected registry
revision. `capy install --locked` verifies that the lock satisfies every
manifest dependency and does not update it. The beta lock format does not
specify a separate package-content hash field; the recorded commit identifies
the registry revision.

## Registry features beyond the beta

These are future work, not available beta commands or guarantees:

- A generated index or search service.
- A package publishing workflow or `capy publish` command.
- Package signature creation or verification.
- A yank operation. The beta has no yank metadata or behavior; release and
  registry artifacts should be treated as immutable, with fixes published as
  later versions/commits.
