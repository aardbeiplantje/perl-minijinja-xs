# Minijinja Perl Module

Perl XS bindings to [minijinja](https://github.com/mitsuhiko/minijinja), 
a fast Rust implementation of the Jinja2 template engine.

## ⚠️ WARNING: PROJECT IS CURRENTLY BROKEN

This module does **not** compile or run in its current state. There are multiple critical issues preventing basic functionality:

1. Missing `typemap` file (referenced in Makefile.PL but doesn't exist)
2. No XS export mechanism - XSUBs defined but not exported to Perl
3. Function naming mismatch - `Minijinja.pm` calls functions with `mj_*` prefix but XS defines them with `_env_*`/`_value_*` prefixes  
4. Non-existent function `mj_render_simple()` called by the OO wrapper but never implemented
5. Missing external library at build time (`../minijinja/target/release/libminijinja_cabi.so`)

See `AGENTS.md` for detailed issue descriptions and fix requirements.

## Building

### Prerequisites

- Perl with development headers (`perl-devel` or `libperl-dev`)
- Rust toolchain (cargo + rustc) — install via [rustup.rs](https://rustup.rs/)

### Step 1: Build minijinja-cabi library

The `minijinja-cabi` crate is part of the [mitsuhiko/minijinja](https://github.com/mitsuhiko/minijinja) monorepo. It is **not published on crates.io** as a standalone package — you must clone the repo and build it from source.

```bash
cd ..
git clone https://github.com/mitsuhiko/minijinja.git
cd minijinja/minijinja-cabi
cargo build --release -p minijinja-cabi
```

This produces:
- Shared library: `../target/release/libminijinja_cabi.so` (or `.dylib` on macOS)
- C header: `include/minijinja.h`

### Step 2: Build the Perl module

```bash
cd ../../../perl-minijinja-xs.git
perl Makefile.PL
make
make test
sudo make install
```

Or set environment variables to point to custom locations:

```bash
export MINIJINJA_BUILD=/path/to/minijinja/target/release
export MINIJINJA_SRC=/path/to/minijinja
```

## Intended API (Not Yet Functional)

Once the above issues are fixed, the module will provide both low-level functional and high-level OO interfaces:

### OO Interface (via Minijinja.pm)

```perl
use Minijinja;

my $env = Minijinja->new();
$env->add_template('hello', 'Hello {{ name }}!');
print $env->render('hello', {name => 'World'});  # "Hello World!"
print $env->apply_from_string('Inline {{ template }}', {template => 'works'});
```

### Low-Level Functional API (from minijinja.xs)

```perl
use Minijinja;

# Environment creation
my $env = _env_new();
_env_add_template($env, 'hello', 'Hello {{ name }}!');
my $ctx = _value_new_object();
_value_set_string_key($ctx, 'name', _value_new_string('World'));
my $result = _env_render_template($env, 'hello', $ctx);
_value_free($ctx);
_env_free($env);

# Value manipulation  
my $str = _value_new_string('test');
my $kind = _value_get_kind($str);
_value_free($str);
```

## Files

- `Makefile.PL` - Build configuration  
- `Minijinja.pm` - Main Perl module with OO interface  
- `minijinja.xs` - XSUB definitions wrapping minijinja-cabi C API  
- `perl_callbacks.c` - Callback bridge for Perl functions as filters/functions/tests
- `Makefile.PL` line 21 - references `typemap` file that doesn't exist (blocker)
- `t/*.t` - Test suite (all currently broken)  
- `AGENTS.md` - Detailed technical documentation and issue tracking

## License

Apache 2.0 (same as upstream minijinja project). See LICENSE file.
