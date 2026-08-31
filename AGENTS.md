# MiniJinja Perl XS Module - Agent Notes

## Purpose

This directory contains Perl XS bindings for the [MiniJinja](https://github.com/mitsuhiko/minijinja) template engine. It provides low-level C bindings via minijinja-cabi exposed through Perl using XS.

## Architecture

- **Single namespace**: `MiniJinja` - no OO classes, pure functional API
- All functions operate on opaque handles (IVs) returned by other functions  
- Values are heap-allocated and must be freed manually with `mj_value_free()`
- Callbacks store references in global HVs to prevent garbage collection

### Key Files

| File | Purpose |
|------|---------|
| `lib/MiniJinja.pm` | Main module - exports all functions from XSLoader |
| `minijinja.xs` | XSUB definitions wrapping the minijinja-cabi C API |
| `perl_callbacks.c` | Callback helpers for Perl functions passed as filters/functions/tests |
| `Makefile.PL` | Build configuration - finds libminijinja_cabi |

### Function Categories

1. **Environment** (`mj_env_*`) - Create/configure environments, add/render templates
2. **Value** (`mj_value_*`) - Create/read/manipulate MiniJinja values
3. **Iterator** (`mj_value_iter_*`) - Iterate over sequences/maps
4. **Error** (`mj_err_*`) - Query error state after failed operations
5. **Syntax Config** (`mj_syntax_config_*`) - Custom template syntax delimiters

## Building

```bash
cd minijinja/minijinja-cabi && cargo build --release
export MINIJINJA_BUILD=/path/to/minijinja/target/release  
cd ../minijinja-perl
perl Makefile.PL && make && make test
```

Or set `MINIJINJA_SRC` and `MINIJINJA_BUILD` environment variables to point to cargo registry paths.

## Current State (After Cleanup)

- Removed all debug `fprintf(stderr)` statements from callbacks
- Converted from OO style (`MiniJinja::Environment`, etc.) to functional API in single `MiniJinja` namespace  
- Updated tests to use new functional API
- Tests reference external modules that may need Test::More installed

## Known Issues / Future Work

1. The iterator usage pattern in tests is awkward - consider providing a convenience function for iteration
2. Map iteration uses string keys but hash lookups could be more efficient with direct key access  
3. Memory management is manual - consider wrapper objects or AUTOLOAD for automatic cleanup
4. Error handling raises exceptions via croak but some functions don't check for errors
5. Need to verify all value kind constants match the C header definitions

## Value Kind Reference

| Constant | Value | Description |
|----------|-------|-------------|
| MJ_VALUE_KIND_UNDEFINED | 0 | Undefined value |
| MJ_VALUE_KIND_NONE | 1 | None/nil value |  
| MJ_VALUE_KIND_BOOL | 2 | Boolean true/false
| MJ_VALUE_KIND_NUMBER | 3 | Integer or float
| MJ_VALUE_KIND_STRING | 4 | UTF-8 string
| MJ_VALUE_KIND_BYTES | 5 | Raw bytes
| MJ_VALUE_KIND_SEQ | 6 | Sequence (list/array)
| MJ_VALUE_KIND_MAP | 7 | Map/object/hash
| MJ_VALUE_KIND_ITERABLE | 8 | Iterable (non-sequence)
| MJ_VALUE_KIND_PLAIN | 9 | Plain object
| MJ_VALUE_KIND_INVALID | 10 | Invalid/malformed
