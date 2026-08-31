# Minijinja Perl XS - Agent Notes

## Project State

**BROKEN.** This module does not compile or run. Multiple critical blockers exist. All fixes require coordinated changes across XS, Perl wrapper, and tests.

## Architecture

Perl XS bindings wrapping [minijinja-cabi](https://github.com/mitsuhiko/minijinja) (Rust template engine). Two interfaces conflict:

- **XS layer** (`Minijinja.xs`)     - perl XS binding to the cabi minijinja
- **Perl wrapper** (`Minijinja.pm`) - perl .pm wrapper, mostly XSLoad()

## Key Files (all at project root, no lib/ subdirectory)

| File | Purpose |
|------|---------|
| `Minijinja.pm` | wrapper — BROKEN: calls undefined XSUBs (`mj_*` prefix) |
| `Minijinja.xs` | ~395 lines of XSUB definitions — underscore-prefixed, uses bracket syntax with CODE blocks |
| `Makefile.PL` | Build config — expects `../minijinja/target/release/libminijinja_cabi.so` |
| `t/*` | Simpler tests using |

## Build Steps

```bash
rustup default stable
bash scripts/setup-minijinja.sh
export MINIJINJA_SRC=$(pwd)/minijinja
export LD_LIBRARY_PATH=$(pwd)/minijinja/target/release
perl Makefile.PL
make
make test
```
