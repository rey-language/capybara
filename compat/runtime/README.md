# Rey runtime sources

These C sources are vendored from the Rey compiler's runtime so Capy can build
`librey_rt.a` as native object code for the machine that will link it.

The official Rey 0.3.0 archives ship `librey_rt.a` as LLVM 21 bitcode. That is
fine with Apple clang 21 or LLVM 21, but Ubuntu 22.04's default clang 14 cannot
read LLVM 21 bitcode. Building the runtime locally, without LTO, keeps the
bundled toolchain usable with the clang version the Capy installer provides.

Source: [`rey-language/rey`](https://github.com/rey-language/rey) at commit
`1b36410` (the Rey 0.3.0 runtime line), directory `rey-compiler/runtime`.

The Rey runtime is MIT licensed; see `LICENSE` in this directory.
