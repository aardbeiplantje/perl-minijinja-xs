# Minijinja Perl XS - Agent Notes

## Project State

**WORKING.** Module compiles and all tests pass. Template rendering, callbacks, error handling fully implemented.

## Architecture

Perl XS bindings wrapping [minijinja-cabi](https://github.com/mitsuhiko/minijinja) (Rust template engine). Two interfaces work together:

- **XS layer** (`Minijinja.xs`) — XSUB definitions providing low-level access to minijinja CABI
- **Perl wrapper** (`Minijinja.pm`) — Exporter setup + convenience `new(%opts)` wrapper, loads XS via XSLoader

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

Flexible test harness in `t/lib/JinjaTest.pm` for validating templates against pre-saved expected outputs:

**How it works**: Each `.jinja` template can have multiple test cases (one per `.t` file). Tests render the template with context, then compare output using `is($got, $expected)` — diff-style failures show exactly what changed. Expected outputs live alongside templates in `t/resources/` and are versioned in git.

```perl
JinjaTest::jinja_test_case(
    template   => 'my-template.jinja',        # from t/resources/
    expected   => 'my-template.jinja.test-01.out',  # versioned .out file  
    context    => { name => 'World' },         # hashref → template variables
);
```

Update expected outputs when changes warrant it:
```bash
MINIJINJA_UPDATE_EXPECTATIONS=1 perl t/50-jinja-test-*.t
```

Scaffold new tests with `scripts/gen-jinja-tests.pl --scan` or `--generate`.
