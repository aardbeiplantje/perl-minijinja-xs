# Minijinja Perl XS - Agent Notes

## Project State

Module compiles and all tests pass. Template rendering, callbacks, error handling fully implemented.

## Architecture

Perl XS bindings wrapping
[minijinja-cabi](https://github.com/mitsuhiko/minijinja) (Rust template
engine). Two interfaces work together:

- **XS layer** (`Minijinja.xs`) — XSUB definitions providing low-level access
  to minijinja CABI
- **Perl wrapper** (`Minijinja.pm`) — Exporter setup + convenience `new(%opts)`
  wrapper, loads XS via XSLoader

## Key Files

| File | Purpose |
|------|---------|
| `lib/Minijinja.xs` | Complete XS implementation (~450 lines), prefixed XSUBs (`M_*`) |
| `lib/Minijinja.pm` | Wrapper with `@EXPORT_OK` list, convenience wrappers |
| `Makefile.PL` | Build config — expects `./minijinja/target/release/libminijinja_cabi.so` |
| `t/*.t` | Tests: load smoke test → API smoke tests → comprehensive API → integration edge cases |
| `t/lib/JinjaTest.pm` | Flexible Jinja template testing framework (see below) |

## Build Steps

```bash
rustup default stable
bash scripts/setup-minijinja.sh
export MINIJINJA_SRC=$(pwd)/minijinja
export LD_LIBRARY_PATH=$(pwd)/minijinja/target/release
perl Makefile.PL && make && make test
```

---

## Jinja Template Testing Framework

Flexible test harness in `t/lib/JinjaTest.pm` for validating templates against
pre-saved expected outputs.

Each `.jinja` template can have multiple test cases (one per `.t` file). Tests
render the template with context, then compare output using `is($got,
$expected)` — diff-style failures show exactly what changed. Expected outputs
live alongside templates in `t/resources/` and are versioned in git.

```perl
JinjaTest::jinja_test_case(
    template   => 'template.jinja',              # from t/resources/
    expected   => 'template.jinja.test-01.out',  # versioned .out file
    context    => {name => 'World'},             # hashref → template variables
);
```

Update expected outputs when changes warrant it:
```bash
MINIJINJA_UPDATE_EXPECTATIONS=1 perl t/50-jinja-test-*.t
```

Scaffold new tests with `scripts/gen-jinja-tests.pl --scan` or `--generate`.

## Callbacks

All registered callbacks (filters, functions, tests) go through the same
`cb_filter_wrapper`. They receive arguments from Jinja as Perl scalars and
return values back via `mj_value`. A few things to remember:

- **Multiple args**: `$_[0]`, `$_[1]`, etc. — the first argument is always
  index 0.
- **Return undef** → becomes `undefined` in Jinja. Return a
  string/number/blessed object for normal values.
- **die/croak** → caught internally via `perl_call_sv(G_EVAL)`, error message
  extracted from `$@` and propagated as a minijinja rendering exception that
  aborts template processing. No special API needed.

### Example: custom function that throws an error

```perl
add_function($env, 'raise_exception', sub { die $_[0] });
# In Jinja: {{ raise_exception('something went wrong') }}
# → rendering aborts, error_detail() returns "something went wrong"
```

### Editor tip

After editing a file, clean up trailing whitespace:

```bash
sed -i 's/[[:space:]]*$//' lib/Minijinja.xs
```

### regarding AGENTS.md

Never auto update, only when requested.
