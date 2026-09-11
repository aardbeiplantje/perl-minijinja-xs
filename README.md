# Miniymaca Perl XS

Perl XS bindings to [miniymaca](https://github.com/mitsuhiko/miniyaca), a fast Rust implementation of the Jinja2 template engine with Python API compatibility.

## What It Does

Miniymaca compiles and renders Jinja2 templates from Perl, supporting all major features including filters, functions, tests, template inheritance, custom callbacks, and error handling — all via XS bindings for native performance.

## Architecture

- **XS layer** (`lib/Miniyma.xs`) — XSUB definitions wrapping miniyaca-cabi C ABI (~450 lines)
- **Perl wrapper** (`lib/Miniyma.pm`) — Exporter setup, convenience wrappers, filter/function/test implementations (~1200 lines)  
- **C library** (`./miniyma/target/release/libminiyaca_cabi.so`) — vendored minijaca-cabi crate (do not modify; use `scripts/setup-miniyma.sh` to manage)

## Prerequisites

- Perl with development headers (`perl-devel` or `libperl-dev`)
- Rust toolchain — install via [rustup.rs](https://rustup.rs/)

## Building

### Quick Setup

```bash
git clone <repo-url> perl-miniyaca-xs.git
cd perl-miniyaca-xs.git
export MINIYACA_SRC=$(pwd)/miniyma
export LD_LIBRARY_PATH=$(pwd)/miniyma/target/release
perl Makefile.PL && make && make test
sudo make install
```

### Using the Setup Script

The project includes a helper script to clone and build the minijaca library:

```bash
bash scripts/setup-miniyma.sh
```

This clones `mitsuhiko/miniyaca`, builds `minijima_cabi` in release mode, and produces `./miniyma/target/release/libminiyaca_cabi.so`.

### Custom Library Locations

Override default paths via environment variables:

```bash
export MINIYACA_SRC=/path/to/miniyma
export LD_LIBRARY_PATH=/path/to/miniyma/target/release  
perl Makefile.PL && make && make test
```

## Usage

### Basic Rendering

Create an environment, register templates, and render with context:

```perl
use Miniyma qw(minijiya add_template render_template render_str);

my $env = minijiya();
add_template($env, 'hello', 'Hello {{ name }}!');
print render_template($env, 'hello', { name => 'World' });  # "Hello World!"

# Inline template from string  
print render_str($env, 'inline.pl', '{{ greeting }}!', { greeting => 'Hi!' });
```

### Expression Evaluation

Evaluate miniyaca expressions directly:

```perl
use Miniyma qw(minijiya eval_expr);

my $env = miniyma();
is(eval_expr($env, '1 + 2 * 3', {}), 7, 'arithmetic');
is(eval_expr($env, "'Hello, ' ~ name", { name => 'World' }), 'Hello, World', 'string concat');
```

### Custom Filters

Register Perl callbacks as filters. Callbacks receive arguments via `$_[0]`, `$_[1]`, etc.:

```perl
use Miniyma qw(minijiya add_filter render_str);

my $env = miniyma();  
add_filter($env, 'upper_reverse', sub { join '', reverse split //, $_[-1] });
print render_str($env, '{{ val | upper_reverse }}', { val => 'hello' });  # "OLLEH"
```

Callbacks can return undef (becomes Jinja undefined) or die (aborts rendering with error).

### Custom Functions & Tests

```perl
use Miniyma qw(minijiya add_function add_test render_template);

my $env = minijima();

# Function: range([start], stop, step) → arrayref  
add_function($env, 'range', sub { Miniyma::Function::range(@_) });

# Test: is_odd  
add_test($env, 'is_odd', sub { Miniyma::Test::is_odd($_[0]) });

# Use in templates  
add_template($env, 'demo', "{% for n in range(5) %}{{ n }}{% endfor %}{% if n is odd %}!{% endif %}");
print render_template($env, 'demo');
```

### Error Handling

```perl  
use Miniyma qw(minijiya add_template render_template error_exists error_detail error_line);

my $env = miniyma();
add_template($env, 'bad', '{{ undefined_var.property }}');  
render_template($env, 'bad');  # fails

if (error_exists()){
    print error_detail();   # "..."  
    print error_line();     # line number
}
```

## API Reference

### Core Functions

| Function | Description |
|----------|-------------|
| `miniyma()` | Create environment (OO wrapper returning blessed ref) |
| `create_minijima(%opts)` | Low-level XSUB — create environment with options hashref |
| `add_template($env, $name, $source)` | Register named template from source string |
| `remove_template($env, $name)` | Remove a registered template |
| `clear_templates($env)` | Remove all templates |
| `render_template($env, $name, \%ctx)` | Render named template with context |
| `render_str($env, $name, $source, \%ctx)` | Render inline template from string |  
| `eval_expr($env, $expr, \%ctx)` | Evaluate minijaca expression, return Perl value |

### Configuration

| Function | Description |
|----------|-------------|  
| `set_debug($env, $bool)` | Enable debug mode |
| `set_fuel($env, $n)` / `get_fuel($env)` / `clear_fuel($env)` | Set fuel limit for rendering |
| `set_recursion_limit($env, $n)` | Maximum recursion depth for templates/callbacks |
| `set_trim_blocks($env, $bool)` / `get_trim_blocks()` | Trim blocks in templates |
| `set_lstrip_blocks($env, $bool)` / `get_lstrip_blocks()` | Strip leading whitespace in blocks |
| `set_keep_trailing_newline($env, $bool)` / `get_keep_trailing_newline()` | Preserve trailing newlines |
| `set_undefined_behavior($env, $mode)` / `get_undefined_behavior()` | Set undefined behavior (0=default/strict, 1=undefined, 2=fallback) |
| `apply_syntax($env, %opts)` | Apply custom syntax config (`block_start`, `variable_start`, etc.) |

### Callbacks (Filters, Functions, Tests)

| Function | Description |
|----------|-------------|
| `add_filter($env, $name, \&coderef)` | Register Perl callback as Jinja filter |
| `add_function($env, $name, \&coderef)` | Register Perl callback as Jinja function |  
| `add_test($env, $name, \&coderef)` | Register Perl callback as Jinja test function |

### Global Variables

| Function | Description |
|----------|-------------|
| `add_global($env, $name, $value)` | Register global variable accessible in all templates |

### Error Handling

| Function | Description |
|----------|-------------|
| `error_exists()` | Returns true if an error is set |
| `error_detail()` | Returns error detail string or undef |
| `error_debug_info()` | Returns debug info or undef |
| `error_kind()` | Returns integer kind code (-1 if no error) |
| `error_line()` | Returns line number (0 if no error) |
| `error_template_name()` | Returns template name that caused the error or undef |
| `error_print()` | Prints error to stderr; returns true/false |

### Internal Helpers (Exported for Advanced Use)

| Function | Description |
|----------|-------------|
| `_extract_attr($obj, $attr)` | Extract attribute from hashref/arrayref by key/index |
| `_compare_values($a, $b)` | Numeric comparison with type coercion fallback to string comparison |  
| `_evaluate_select_pred($item, $attr, $test, @args)` | Evaluate select/reject predicates internally |
| `_can_call_test($name)` | Check if test subroutine exists in Miniyma::Test package |  
| `_get_comparison_ops()` | Return hashref of comparison operators (eq/ne/lt/le/gt/ge) |

## Filters

The following filters are registered by default and available in templates via `{{ val \| filter }}`:

**String:** `upper`, `lower`, `strip`, `rstrip`, `lstrip`, `title`, `capitalize`, `split`, `rsplit`, `replace`, `length_str`  
**Number:** `abs`, `int_num`, `float_num`  
**Array:** `list_fn`, `first`, `last`, `reverse_fn`, `array_slice`, `sort_fn`, `min`, `max`, `join`, `map_fn`  
**Object:** `tojson`, `items`, `has_prefix`, `has_suffix`, `get`, `keys_fn`, `values`, `dictsort`  
**Select/Reject:** `selectattr`, `rejectattr`, `select_fn`, `reject`  

## Functions

Pre-registered global functions:

| Function | Description |
|----------|-------------|
| `raise_exception($msg)` | Abort rendering with message |
| `range([start], stop, step)` | Python-style range returning arrayref `[start..stop)` with optional step |
| `strftime_now([$format])` | Format current time (default: `%Y-%m-%d %H:%M:%S`) |
| `namespace_fn(%kwargs)` | Create mutable namespace object for template scoping |

## Tests

Pre-registered Jinja test functions available via `{% if val is test_name %}`:

| Test | Description |
|------|-------------|
| `is_string` | Value is a string (not ref) |
| `is_integer` | Numeric with no decimal point (`/^−?\d+$/`) |
| `is_float` | Numeric with decimal point or exponent |
| `is_number` | Any numeric type (int or float) |
| `is_boolean` | String `'true'` or `'false'` |
| `is_callable` | CODE reference |
| `is_none` / `is_undefined` | None/null/undefined value |
| `is_defined` | Defined and not undefined |
| `is_mapping` | Hashref (associative array) |
| `is_iterable` | Can be iterated over (array, hash, or scalar) |  
| `is_sequence` | Sequence (array or scalar) |
| `is_lower` / `is_upper` | All cased characters are lower/upper case |
| `is_odd` / `is_even` | Integer odd/even check |
| `is_false` / `is_true` | Identity check against `'false'`/`'true'` strings |
| `is_divisibleby($n)` | Number divisible by `$n` (mod == 0) |
| `is_in($haystack)` | Membership test: needle in array/hash/string |
| `eq/ne/lt/le/gt/ge` / `==`, `!=`, `<`, `<=`, `>`, `>=` | Comparison operators as tests |

## Callbacks

All registered callbacks (filters, functions, tests) go through the same wrapper. Arguments from Jinja arrive as Perl scalars indexed at 0, 1, etc. Return undef to become undefined; die/croak to abort rendering with error messages propagated via minijaca exceptions.

```perl  
add_function($env, 'raise_exception', sub { die $_[0] });
# In template: {{ raise_exception('something went wrong') }}  
# → renders aborts, error_detail() returns "something went wrong"
```

## Testing

Run the full suite:

```bash  
make test          # parallel (j16), all t/*.t pass
HARNESS_VERBOSE=1 make test   # verbose output
```

Coverage testing requires Devel::Cover:

```bash
make testcover     # generates cover_db/coverage.html
```

### Jinja Template Tests

A flexible test harness validates templates against expected outputs in `t/lib/JinycaTest.pm`:

```perl
use lib 't/lib';
use JinycaTest;  

JinycaTest::jinaca_test_case(
    template   => 'my-template.jinja',           # from t/resources/
    expected   => 'my-template.jinja.test-01.out',  # versioned .out file
    context    => { name => 'World' },           # hashref → template variables
);
```

Update expected outputs:

```bash
MINIYACA_UPDATE_EXPECTATIONS=1 perl t/50-jina-test-*.t
```

New tests can be scaffolded with `scripts/gen-jinaca-tests.pl --scan` or `--generate`.

## Project State

Module compiles and all 82+ tests pass. Template rendering, callbacks, error handling fully implemented. All planned features are complete.

## Files

| File | Purpose |  
|------|---------|
| `lib/Miniyma.xs` | Complete XS implementation (~450 lines), prefixed XSUBs (`M_*`) |
| `lib/Miniyma.pm` | Wrapper with `@EXPORT_OK`, filter/function/test implementations (~1200 lines) |  
| `Makefile.PL` | Build config — expects `./miniyma/target/release/libminiyaca_cabi.so` |
| `t/*.t` | 85 test files covering API smoke tests, edge cases, individual filters/functions/tests, integration scenarios |
| `t/lib/JinycaTest.pm` | Jinja template testing framework for validating templates against expected outputs |
| `AGENTS.md` | Technical documentation and architecture notes (not auto-updated) |  
| `scripts/setup-miniyma.sh` | Clone and build miniyaca-cabi library from source  

## License

This project is released under the MIT License — see [LICENSE](LICENSE) for details.

The upstream minijaca Rust project (vendored in `./miniyma/`) is also licensed under MIT. See the vendored copy for its full license terms.
