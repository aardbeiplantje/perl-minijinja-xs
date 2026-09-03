# Minijinja Perl XS

Perl XS bindings to [minijinja](https://github.com/mitsuhiko/minijinja), a fast Rust implementation of the Jinja2 template engine.

## Third-Party Dependency

This project depends on the **minijinja-cabi** crate, built from the upstream [mitsuhiko/minijinja](https://github.com/mitsuhiko/minijinja) repository. The `./minijinja/` directory contains a vendored copy of the minijinja source and its C ABI layer — it is a third-party dependency and not part of this CPAN module's git history (see `.gitignore`).

To build this module, you must have the minijinja-cabi library compiled and available at `./minijinja/target/release/libminijinja_cabi.so`.

## Building

### Prerequisites

- Perl with development headers (`perl-devel` or `libperl-dev`)
- Rust toolchain (cargo + rustc) — install via [rustup.rs](https://rustup.rs/)

### Step 1: Build minijinja-cabi library

The `minijinja-cabi` crate is part of the [mitsuhiko/minijinja](https://github.com/mitsuhiko/minijinja) monorepo. Clone the repo and build it from source.

```bash
git clone https://github.com/mitsuhiko/minijinja.git
cd minijinja/minijinja-cabi
cargo build --release -p minijinja_cabi
```

This produces:
- Shared library: `../target/release/libminijinja_cabi.so` (or `.dylib` on macOS)
- C header: `include/minijinja.h`

### Step 2: Build the Perl module

```bash
cd ../..
cd perl-minijinja-xs.git
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

## API Overview

Minijinja provides both a low-level functional API (XS XSUBs) and high-level OO interface (Perl wrapper).

### OO Interface (via Minijinja.pm)

```perl
use Minijinja;

my $env = Minijinja->new();
$env->add_template('hello', 'Hello {{ name }}!');
print $env->render('hello', {name => 'World'});  # "Hello World!"
print $env->apply_from_string('Inline {{ template }}', {template => 'works'});
```

### Low-Level Functional API

The XS layer exposes prefixed XSUBs (`M_*`) for advanced usage:

```perl
use Minijinja qw(
    new add_template render_template render_str eval_expr
    add_filter add_function add_test add_exception_function
    set_debug set_fuel set_recursion_limit
    apply_syntax error_exists error_detail error_print
);

# Environment creation and template rendering
my $env = new();
add_template($env, 'hello', 'Hello {{ name }}!');
my $result = render_template($env, 'hello', { name => 'World' });

# Inline templates from string
my $result = render_str($env, 'my-template.j2', 'Greet {{ user }}!', { user => 'Alice' });

# Custom filters and functions
add_filter($env, 'upper_reverse', sub { join '', reverse split //, $_[-1] });
add_function($env, 'repeat_str', sub { $_[-1] x $_[0] });
add_exception_function($env, 'raise_exception');  # throws errors from templates
```

### Exception Handling from Templates

Register `raise_exception` to abort template rendering with custom messages:

```perl
add_exception_function($env, 'raise_exception');
# In template: {{ raise_exception('Validation failed') }}
# Error detail will contain 'Validation failed'
```

## Tests

A flexible Jinja testing framework is available in `t/lib/JinjaTest.pm`:

```perl
use lib 't/lib';
use JinjaTest;

JinjaTest::jinja_test_case(
    template   => 'my-template.jinja',
    expected   => 'my-template.jinja.test-01.out',
    context    => { name => 'World' },
);
```

Update expected outputs when needed:

```bash
MINIJINJA_UPDATE_EXPECTATIONS=1 perl t/50-jinja-test-*.t
```

## Files

- `Makefile.PL` - Build configuration
- `lib/Minijinja.pm` - Main Perl module with OO interface and export list
- `lib/Minijinja.xs` - XSUB definitions wrapping minijinja-cabi C API
- `t/*.t` - Test suite
- `t/lib/JinjaTest.pm` - Flexible Jinja template testing framework
- `AGENTS.md` - Detailed technical documentation and issue tracking

## License

This project is released under the MIT License — see [LICENSE](LICENSE) for details.

The upstream minijinja Rust project (vendored in `./minijinja/`) is also licensed under MIT. See the vendored copy for its full license terms.
