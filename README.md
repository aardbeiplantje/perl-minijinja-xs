# MiniJinja Perl Bindings

Functional Perl XS bindings for the [MiniJinja](https://github.com/mitsuhiko/minijinja) template engine.

## Installation

### Prerequisites

1. Install Rust and Cargo
2. Build minijinja-cabi:

```bash
cd minijinja/minijinja-cabi
cargo build --release
```

3. Set environment variables for the build:

```bash
export MINIJINJA_BUILD=/path/to/minijinja/target/release
```

Or the build will try to find the library in standard locations like `/usr/local/lib` and `~/.cargo/registry`.

### Building the Perl Module

```bash
cd minijinja/minijinja-perl
perl Makefile.PL
make
make test
```

## Usage

All functions operate on opaque handles (returned as integers). Values are heap-allocated and must be freed manually.

```perl
use MiniJinja;

# Create environment and context
my $env = mj_env_new();
my $ctx = mj_value_new_object();
mj_value_set_string_key($ctx, 'name', mj_value_new_string('World'));

# Add a template and render
mj_env_add_template($env, 'hello.html', 'Hello {{ name }}!');
my $output = mj_env_render_template($env, 'hello.html', $ctx);
print "$output\n";  # "Hello World!"

# Render from string directly  
$output = mj_env_render_named_str($env, 'inline.pl', 'Hello {{ name }}!', $ctx);

# Evaluate expressions
my $result = mj_env_eval_expr($env, '1 + 2 * 3', $ctx);
print mj_value_as_i64($result), "\n";  # 7
mj_value_free($result);

# Add custom filters
mj_env_add_filter($env, 'upper', sub {
    my ($val) = @_;
    return uc($val);
});
$output = mj_env_render_named_str($env, 'filter.pl', '{{ "hello" | upper }}', $ctx);
print "$output\n";  # "HELLO"

# Add custom functions
mj_env_add_function($env, 'greet', sub {
    my ($name) = @_;
    return "Hello, $name!";
});
$output = mj_env_render_named_str($env, 'func.pl', '{{ greet("World") }}', $ctx);

# Add custom tests
mj_env_add_test($env, 'even', sub {
    my ($val) = @_;
    return $val % 2 == 0;
});

# Add globals
mj_env_add_global($env, 'site_name', mj_value_new_string('MySite'));

# Configure environment
mj_env_set_debug($env, 1);
mj_env_set_undefined_behavior($env, 1);  # strict mode
mj_env_set_fuel($env, 10000);

# Custom syntax delimiters
my $syntax = mj_syntax_config_new();
mj_syntax_config_set_block_start($syntax, '<%');
mj_syntax_config_set_block_end($syntax, '%>');
mj_syntax_config_set_variable_start($syntax, '<$');
mj_syntax_config_set_variable_end($syntax, '$>');
mj_env_set_syntax_config($env, $syntax);
mj_syntax_config_free($syntax);

# Clean up
mj_value_free($ctx);
mj_env_free($env);
```

## API Reference

### Environment Functions (`mj_env_*`)

| Function | Description |
|----------|-------------|
| `mj_env_new()` | Create new environment (returns handle) |
| `mj_env_free(IV $env)` | Free environment handle |
| `mj_env_add_template(IV $env, string $name, string $source)` | Add named template |
| `mj_env_remove_template(IV $env, string $name)` | Remove template by name |
| `mj_env_clear_templates(IV $env)` | Clear all templates |
| `mj_env_render_template(IV $env, string $name, IV $ctx)` | Render template by name |
| `mj_env_render_named_str(IV $env, string $name, string $src, IV $ctx)` | Render from string source |
| `mj_env_eval_expr(IV $env, string $expr, IV $ctx)` | Evaluate expression (returns value handle) |
| `mj_env_add_filter(IV $env, string $name, CV $cb)` | Add custom filter callback |
| `mj_env_add_function(IV $env, string $name, CV $cb)` | Add custom function callback |
| `mj_env_add_test(IV $env, string $name, CV $cb)` | Add custom test callback |
| `mj_env_add_global(IV $env, string $name, IV $val)` | Add global variable |
| `mj_env_remove_global(IV $env, string $name)` | Remove global variable |
| `mj_env_set_debug(IV $env, bool)` / `mj_env_get_debug(IV $env)` | Debug mode toggle/query |
| `mj_env_set_undefined_behavior(IV $env, int)` / `mj_env_get_undefined_behavior(IV $env)` | Undefined behavior mode (0=lenient, 1=strict, 2=chainable) |
| `mj_env_set_fuel(IV $env, UV)` / `mj_env_get_fuel(IV $env)` / `mj_env_clear_fuel(IV $env)` | Fuel budget management |
| `mj_env_set_loader(IV $env, CV?)` | Set template loader callback (undef to remove) |
| `mj_env_set_auto_escape_callback(IV $env, CV?)` | Set auto-escape callback by filename |
| `mj_env_set_path_join_callback(IV $env, CV?)` | Set path join callback for inheritance |
| `mj_env_set_recursion_limit(IV $env, UV)` | Set recursion limit |
| `mj_env_set_trim_blocks(IV $env, bool)` | Enable/disable trim blocks |
| `mj_env_set_lstrip_blocks(IV $env, bool)` | Enable/disable lstrip blocks |
| `mj_env_set_keep_trailing_newline(IV $env, bool)` | Keep trailing newline option |

### Value Functions (`mj_value_*`)

| Function | Description |
|----------|-------------|
| `mj_value_new_none()` / `new_bool(bool)` / `new_i64(int64)` | Create scalar values |
| `new_u64(uint64)` / `new_f64(double)` / `new_string(string)` | More value constructors |
| `new_bytes(bytes)` / `new_list()` / `new_object()` / `new_undefined()` | Container/value types |
| `mj_value_free(IV $val)` | Free a value handle (decref + free) |
| `mj_value_get_kind(IV $val) -> int` | Get value kind constant |
| `mj_value_is_true(IV $val)` / `is_number(IV $val)` | Type checking predicates |
| `mj_value_as_i64(IV $val)` / `_as_u64(IV $val)` / `_as_f64(IV $val)` | Numeric conversions |
| `mj_value_to_str(IV $val) -> string` | Convert to string (must be freed with mj_str_free) |
| `mj_value_len(IV $val) -> uint64` | Length of sequences/maps |
| `mj_value_get_by_index(IV $val, uint64 idx)` | Get list element by index |
| `mj_value_get_by_str(IV $val, string key)` | Get map element by string key |
| `mj_value_get_by_value(IV $val, IV key)` | Get element by value key |
| `mj_value_append(IV $list, IV $val)` | Append to list |
| `mj_value_set_key(IV $obj, IV key, IV val)` | Set object/map key-value pair |
| `mj_value_set_string_key(IV $obj, string key, IV val)` | Set key using string identifier |
| `mj_value_try_iter(IV $val) -> IV` | Get iterator handle or 0 if not iterable |

### Iterator Functions (`mj_value_iter_*`)

| Function | Description |
|----------|-------------|
| `mj_value_iter_free(IV $iter)` | Free iterator handle |
| `mj_value_iter_next(IV $iter, IV $buf) -> bool` | Advance and write next value into buffer (heap-allocated mj_value) |

### Syntax Config Functions (`mj_syntax_config_*`)

| Function | Description |
|----------|-------------|
| `mj_syntax_config_new()` / `mj_syntax_config_free(IV)` | Create/free config handles |
| `mj_syntax_config_set_block_start\|end(...)` | Set block delimiters |
| `_set_variable_start\|end(...)` | Set variable delimiters |  
| `_set_comment_start\|end(...)` | Set comment delimiters |
| `_set_line_statement_prefix\|line_comment_prefix(...)` | Set line prefix options |

### Error Functions (`mj_err_*`)

| Function | Description |
|----------|-------------|
| `mj_err_is_set() -> bool` | Check if error state is active |
| `mj_err_clear()` | Clear error state |
| `mj_err_get_kind() -> int` | Get error kind constant |
| `mj_err_get_detail() -> string` | Get error message/detail |
| `mj_err_get_debug_info() -> string` | Get debug info for rendering errors |
| `mj_err_get_template_name() -> string` | Get template name from error context |
| `mj_err_get_line() -> uint32` | Get line number from error context |
| `mj_err_print() -> bool` | Print current error to stderr (returns true if error was set) |

### Utility

- `mj_str_free(string $str)` - Free strings returned by C API (e.g., from mj_value_to_str)

## Value Kind Constants

Constants returned by `mj_value_get_kind()`:

| Constant | Value | Description |
|----------|-------|-------------|
| MJ_VALUE_KIND_UNDEFINED | 0 | Undefined value |
| MJ_VALUE_KIND_NONE | 1 | None/nil value |  
| MJ_VALUE_KIND_BOOL | 2 | Boolean true/false |
| MJ_VALUE_KIND_NUMBER | 3 | Integer or float
| MJ_VALUE_KIND_STRING | 4 | UTF-8 string
| MJ_VALUE_KIND_BYTES | 5 | Raw bytes
| MJ_VALUE_KIND_SEQ | 6 | Sequence (list/array)
| MJ_VALUE_KIND_MAP | 7 | Map/object/hash
| MJ_VALUE_KIND_ITERABLE | 8 | Iterable (non-sequence)
| MJ_VALUE_KIND_PLAIN | 9 | Plain object
| MJ_VALUE_KIND_INVALID | 10 | Invalid/malformed

## License

Public Domain (see [LICENSE](LICENSE) or <https://unlicense.org>)
