# Rey home migration

Capybara uses `~/.capy` as its default mutable home. On first setup it detects
an existing `~/.rey`, migrates data without deleting it, and leaves a
compatibility path for Rey tooling. The installer and CLI follow the migration
rules in [CONTRACT.md](CONTRACT.md).

## Before

A legacy installation may have data under `~/.rey`. The beta does not require a
particular set of entries there; migration preserves the contents it finds.

```text
~/.rey/
└── ... existing Rey data ...
```

## After

Capy creates its home directories and a migration marker. When the default
migration applies, `~/.rey` points to `~/.capy` for older tooling. The compiler
also looks for standard-library sources at `~/.reyc/std/src`.

```text
~/.capy/
├── .rey-migrated
├── bin/
├── cache/
├── registry/
├── store/
└── toolchains/

~/.rey -> ~/.capy
~/.reyc/
└── std -> <toolchain-root>/std
    └── src/
```

The `~/.reyc/std` link is created only if it does not already exist. Existing
links or directories there are left alone, including development setups that
point to a Rey source tree.

## Migration cases

- If `~/.capy` is absent and `~/.rey` exists, Capy moves `~/.rey` to
  `~/.capy`, creates `~/.rey -> ~/.capy`, and writes the marker.
- If both directories exist and no marker is present, Capy copies missing
'top-level entries from `~/.rey` into `~/.capy`, renames the old directory to
  `~/.rey.bak.<seconds>`, creates the compatibility symlink, and writes the
  marker.
- Capy creates `bin/`, `cache/`, `store/`, `toolchains/`, and `registry/` in
  its home. Migration does not delete user data.

## Choosing another home

`CAPY_HOME` selects the mutable Capy home instead of the default `~/.capy`.
Set it before invoking the installer or CLI to keep Capy's files under a
separate location. The beta contract does not further specify how a preexisting
`~/.rey` is merged when a nondefault `CAPY_HOME` is selected; inspect both
locations before changing either one.

## Manual rollback

There is no automatic rollback command. Stop using Capy before changing these
paths. If `~/.rey` is the compatibility symlink and `~/.rey` does not contain
separate data, remove the link and move the migrated home back:

```sh
rm ~/.rey
mv ~/.capy ~/.rey
```

If the migration created a `~/.rey.bak.<seconds>` directory because both
homes existed, keep that backup. Review it and `~/.capy` and restore individual
files deliberately; the merge copied only entries that were missing and the
result may contain newer Capy data. Do not replace either directory wholesale
if it contains data you still need.

If migration created `~/.reyc/std`, remove it only after confirming it is the
link created by Capy and no compiler still needs that standard-library path.
