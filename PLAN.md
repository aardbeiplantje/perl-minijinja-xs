# Plan: Implement Minijinja Perl XS Module

## Current State Assessment

| File | Status | Notes |
|------|--------|-------|
| `lib/Minijinja.xs` | Stub (~39 lines) | Only `M_new()` and `M_DESTROY()` with TODO bodies |
| `lib/Minijinja.pm` | Minimal | Just `XSLoader::load()`, no exports, no wrappers |
| `t/00-basic.t` | 242 lines, broken API | Tests full API using functions that don't exist yet |
| `t/01-render.t` | 31 lines, OO style | Calls `$mj_env->add_template()` etc. — methods don't exist |
| `t/00-load.t` | 21 lines, OK | Basic load test — minor changes only |
| `minijinja/` | Built ✅ | Library at `./minijinja/target/release/libminijinja_cabi.so` |

---

## Architecture Decisions

### 1. No heavy OO hierarchy
Bless a scalar ref to a heap-allocated wrapper struct (most that you need). All XSUBs are functional-style: `Minijinja::render_template($env, $name, $ctx)`.

### 2. mj_value boxing
Since `mj_value` is an opaque struct passed by copy (not pointer), we allocate a heap wrapper containing the actual value + validity flag. Each blessed SV holds an integer ID into a global HV mapping to the allocated struct. DESTROY callbacks free and clean up automatically. Double-free protection via validity flag.

### 3. Getter storage for CABI-missing getters
The CABI header has no getters for debug mode, fuel limit, recursion limit, etc. We store these values in a Perl HV keyed by env pointer address.

### 4. Flexible undef-safe API
Every XSUB handles undef input gracefully: returns sensible defaults (0, undef, false, empty string) instead of crashing. Callers don't need to check before calling.

### 5. Callback registration pattern
Store Perl coderef userdata in a global HV keyed by unique callback ID. The C callback wrapper looks up the coderef, converts `mj_value* args` → Perl scalars, calls the coderef, then converts return value back to `mj_value`.

---

## Phase 1: XS Implementation (`lib/Minijinja.xs`)

### 1a. Environment management

| XSUB | CABI call | Notes |
|------|-----------|-------|
| `new(%opts)` | `mj_env_new()` + setters | Blessed `Minijinja::Env` containing `mj_env*`; optional `%opts` hash sets config flags on creation |
| `free($env)` | `mj_env_free()` | Explicit free; also via DESTROY |
| `DESTROY(env)` | implicit | Calls `mj_env_free(THIS(sv))` if valid flag set |

### 1b. Template management

| XSUB | CABI call | Notes |
|------|-----------|-------|
| `add_template($env, $name, $source)` | `mj_env_add_template()` | Returns bool |
| `remove_template($env, $name)` | `mj_env_remove_template()` | Returns bool |
| `clear_templates($env)` | `mj_env_clear_templates()` | Returns bool |

### 1c. Rendering

| XSUB | CABI call | Notes |
|------|-----------|-------|
| `render_template($env, $name, $ctx?)` | `mj_env_render_template()` | If `$ctx` is undef → create empty object internally; returns string or undef+sets error; caller doesn't need to free returned char* (it's freed internally) |
| `render_str($env, $name, $source, $ctx?)` | `mj_env_render_named_str()` | Same undef handling as above; returns owned string or undef+error |
| `eval_expr($env, $expr, $ctx?)` | `mj_env_eval_expr()` | Returns blessed mj_value wrapper (or undefined value on error); ctx same undef handling |

**Error handling for render functions**: On failure, set a thread-local error flag via CABI, return undef from Perl side. User can query error via `error_detail()`, etc.

### 1d. Value creation (all return blessed Minijinja::Value with heap-allocated wrapper struct)

All accept optional args with safe undef defaults:

| XSUB | CABI call | Undef behavior |
|------|-----------|----------------|
| `value_new_string($s?)` | `mj_value_new_string()` | undef → undefined value |
| `value_new_i64($n?)` | `mj_value_new_i64()` | undef → none value |
| `value_new_f64($f?)` | `mj_value_new_f64()` | undef → none value |
| `value_new_bool($b?)` | `mj_value_new_bool()` | undef → false (0) |
| `value_new_list()` | `mj_value_new_list()` | N/A |
| `value_new_object()` | `mj_value_new_object()` | N/A |
| `value_new_none()` | `mj_value_new_none()` | N/A |
| `value_new_undefined()` | `mj_value_new_undefined()` | N/A |

### 1e. Value queries/accessors

| XSUB | CABI call | Undef handling |
|------|-----------|----------------|
| `value_kind($v?)` | `mj_value_get_kind()` | Returns -1 for undef; returns enum int otherwise |
| `value_is_true($v?)` | `mj_value_is_true()` | Returns false for undef/non-true values |
| `value_as_i64($v?)` | `mj_value_as_i64()` | Returns 0 for undef/non-numeric; coerces floats to int |
| `value_as_f64($v?)` | `mj_value_as_f64()` | Returns 0.0 for undef/non-numeric; coerces ints to float |
| `value_to_string($v?)` | `mj_value_to_str()` + frees internally | Returns Perl string or undef (if not convertible); handles mj_str_free() automatically — caller never needs to free |
| `value_len($v?)` | `mj_value_len()` | Returns 0 for undef/non-container types |

### 1f. Container operations

| XSUB | CABI call | Notes |
|------|-----------|-------|
| `value_set_key($obj, $key, $val)` | `mj_value_set_string_key()` | `$key` is a Perl string, auto-converted to mj_value via new_string() internally; returns bool |
| `value_get_key($obj, $key)` | `mj_value_get_by_str()` | Returns blessed value wrapper or undef if key not found/value is undefined |
| `value_append($list, $val)` | `mj_value_append()` | Returns bool (false on error) |
| `value_get_index($container, $idx)` | `mj_value_get_by_index()` | Returns blessed value wrapper or undef out-of-bounds/undefined value |

### 1g. Iterators

| XSUB | CABI call | Notes |
|------|-----------|-------|
| `try_iter($v?)` | `mj_value_try_iter()` | Blessed `Minijinja::Iter` containing iterator pointer; undef if value not iterable or undef input |
| `iter_next($iter)` | `mj_value_iter_next()` | **Simplified API** — just return the next element as blessed value or undef at end. No out-buffer parameter needed (that was a C pattern awkward in Perl). DESTROY callback frees iterator. |

### 1h. Globals and configuration

| XSUB | CABI call | Getter? | Notes |
|------|-----------|---------|-------|
| `add_global($env, $name, $val)` | `mj_env_add_global()` | N/A (takes ownership of `$val`) |
| `set_debug($env, $bool)` / `get_debug($env)` | CABI only has setter | Yes — stored in env config HV |
| `set_fuel($env, $n)` / `get_fuel($env)` | CABI only has setter + clearer | Yes — stored in env config HV; `clear_fuel()` also updates stored value to 0 |
| `clear_fuel($env)` | `mj_env_clear_fuel()` | Updates stored value to 0 |
| `set_recursion_limit($env, $n)` / `get_recursion_limit($env)` | CABI only has setter | Yes — stored in env config HV |
| `set_trim_blocks($env, $bool)` / `get_trim_blocks($env)` | CABI only has setter | Yes — stored in env config HV |
| `set_lstrip_blocks($env, $bool)` / `get_lstrip_blocks($env)` | CABI only has setter | Yes — stored in env config HV |
| `set_keep_trailing_newline($env, $bool)` / `get_keep_trailing_newline($env)` | CABI only has setter | Yes — stored in env config HV |
| `set_undefined_behavior($env, $mode)` / `get_undefined_behavior($env)` | Both available (getter from stored state) | Stored in env config HV; mode is 0/1/2 matching enum values |

**Env config storage**: Global HV `%ENV_CONFIGS` keyed by stringified `mj_env*` address. Each entry is a hashref with keys: debug, fuel, recursion_limit, trim_blocks, lstrip_blocks, trailing_newline, undefined_behavior.

### 1i. Syntax configuration

Two approaches available (both implemented):

**A. Convenience inline** — single XSUB that builds syntax config internally and applies it:
```perl
apply_syntax($env, %opts)  # opts = block_start => '<%', variable_start => '<$', ... etc.
```
Unspecified keys get defaults from `mj_syntax_config_default()`. No explicit handle needed.

**B. Explicit handle management** (matches test file style):
```perl
$syntax = syntax_new()                  # blessed wrapper with heap-allocated mj_syntax_config*
syntax_block_start($syntax, $str)       # sets field
syntax_block_end($syntax, $str)         # sets field
# ... all 8 fields have setters ...
env_set_syntax_config($env, $syntax)    # applies to environment
syntax_free($syntax)                    # frees struct
```

Both exported; tests can use either approach.

### 1j. Custom callbacks (filters, functions, tests)

| XSUB | CABI call | Notes |
|------|-----------|-------|
| `add_filter($env, $name, \&coderef)` | `mj_env_add_filter()` | Returns bool on success; stores coderef in global HV keyed by unique ID; callback wrapper converts args → Perl scalars, calls coderef, converts return → mj_value |
| `add_function($env, $name, \&coderef)` | `mj_env_add_function()` | Same pattern |
| `add_test($env, $name, \&coderef)` | `mj_env_add_test()` | Same pattern |

**Callback conversion details**:
- Args: convert each `const mj_value*` to Perl scalar by checking kind — string → `value_to_string()`, number → `value_as_i64()` or `value_as_f64()`, bool → true/false, undefined/none → undef, container → warn and pass as string representation
- Return value: check type — Perl string → `new_string()`, int → `new_i64()`, float → `new_f64()`, undef → `new_undefined()`, error → set CABI error via `mj_err_*` functions

### 1k. Loader/auto_escape/path_join callbacks

| XSUB | CABI call | Notes |
|------|-----------|-------|
| `set_loader($env, \&coderef)` | `mj_env_set_loader()` | Returns bool; wrapper receives `(Perl_str)`, calls coderef with template name, returns `strdup()`'ed result (minijinja will free it via `mj_str_free`) |
| `set_auto_escape($env, \&coderef)` | `mj_env_set_auto_escape_callback()` | Returns bool; wrapper calls coderef with template name, returns MJ_AUTO_ESCAPE_NONE or MJ_AUTO_ESCAPE_HTML |
| `set_path_join($env, \&coderef)` | `mj_env_set_path_join_callback()` | Returns bool; wrapper receives `(name, parent)`, calls coderef, returns `strdup()`'d result |

**Callback userdata**: Each registered callback gets a unique ID stored in global HV `%CALLBACKS`. The void* userdata pointer is cast to this ID. Free function (if provided by CABI for cleanup) removes from HV. For simplicity: register all callbacks without free funcs and let them clean up when env is freed (we can walk %CALLBACKS and remove entries whose ID prefix matches the env address).

Actually simpler: store callbacks in an HV keyed by env pointer, with sub-hashes for filter/function/test/loader/auto_escape/path_join namespaces. On env DESTROY, remove those entries.

### 1l. Error handling

| XSUB | CABI call | Notes |
|------|-----------|-------|
| `error_exists()` | `mj_err_is_set()` | Returns true/false |
| `error_detail()` | `mj_err_get_detail()` + frees internally | Returns string or undef; frees C string automatically |
| `error_debug_info()` | `mj_err_get_debug_info()` + frees internally | Returns string or undef; frees C string automatically |
| `error_kind()` | `mj_err_get_kind()` → enum int | Returns integer or -1 if no error |
| `error_line()` | `mj_err_get_line()` → uint32_t | Returns int or 0 if no error |
| `error_template_name()` | `mj_err_get_template_name()` + frees internally | Returns string or undef; frees C string automatically |
| `error_print()` | `mj_err_print()` | Prints to stderr via CABI; returns bool (true on success) |

---

## Phase 2: Update Minijinja.pm

Current file is minimal (10 lines). Changes needed:

1. Add `%EXPORT_OK` listing all exported functions (use Exporter::import for standard export support)
2. Add convenience wrapper for `new(%opts)` that chains env creation with config setters
3. Add basic POD documentation stub

Example exports:
```perl
use Exporter 'import';
our @EXPORT_OK = qw(
    new free
    add_template remove_template clear_templates
    render_template render_str eval_expr
    add_global
    add_filter add_function add_test
    set_debug get_debug
    set_fuel get_fuel clear_fuel
    set_recursion_limit get_recursion_limit
    set_trim_blocks get_trim_blocks
    set_lstrip_blocks get_lstrip_blocks
    set_keep_trailing_newline get_keep_trailing_newline
    set_undefined_behavior get_undefined_behavior
    apply_syntax env_set_syntax_config syntax_new
    syntax_block_start syntax_block_end syntax_variable_start syntax_variable_end
    syntax_comment_start syntax_comment_end syntax_line_statement_prefix syntax_line_comment_free
    set_loader set_auto_escape set_path_join
    error_exists error_detail error_debug_info error_kind error_line error_template_name error_print
    value_new_string value_new_i64 value_new_f64 value_new_bool
    value_new_list value_new_object value_new_none value_new_undefined
    value_free value_kind value_is_true value_as_i64 value_as_f64
    value_to_string value_len
    value_set_key value_get_key value_append value_get_index
    try_iter iter_next
);
```

Convenience `new(%opts)` wrapper: creates env, then conditionally applies config options from `%opts` hash (e.g., `{ debug => 1, trim_blocks => 0 }`).

---

## Phase 3: Rewrite Tests

### `t/00-load.t` — minimal changes
- Keep structure as-is (load test)
- Update test count to match actual tests run
- Add `use_ok('Minijinja', '@EXPORT_OK')` or just keep simple `use_ok('Minijinja')`

### `t/01-render.t` — rewrite (~20 tests)
Functional API smoke tests for the most common workflow:

```perl
use strict; use warnings;
use Test::More;
use Minijinja qw(new add_template render_template render_str 
                  value_new_object value_set_key value_new_string free);

# Smoke test: environment creation
my $env = Minijinja::new();
ok($env, 'environment created');

# Smoke test: template registration + rendering with context
my $ctx = Minijinja::value_new_object();
Minijinja::value_set_key($ctx, 'name', Minijinja::value_new_string('World'));
Minijinja::add_template($env, 'hello', 'Hello {{ name }}!');
is(Minijinja::render_template($env, 'hello', $ctx), 'Hello World!', 'basic render');

# Smoke test: inline template rendering  
is(Minijinja::render_str($env, 'inline.pl', '{{ greeting }}!', $ctx), 'Hi there!', 'inline render');

# Cleanup
Minijinja::free($env);
Minijinja::value_free($ctx);

done_testing();
```

### `t/02-api.t` — comprehensive (~100+ tests)
Replaces old `t/00-basic.t`. Organized by section with SKIP blocks for optional features that depend on library availability.

Sections:
1. **Environment** (8-10 tests): new, free, add/remove/clear templates
2. **Value creation** (12 tests): all 8 creators + basic sanity checks
3. **Value queries** (15 tests): kind, is_true, as_i64, as_f64, to_string, len on various types
4. **Containers** (15 tests): set/get key, append, get_index on lists and objects
5. **Iterators** (8 tests): try_iter, iter_next — simplified return-based API
6. **Globals** (6 tests): add_global, remove_global, verify in template rendering
7. **Config setters/getters** (16 tests): debug, fuel, recursion_limit, trim_blocks, lstrip_blocks, trailing_newline, undefined_behavior
8. **Syntax config** (8 tests): both inline apply_syntax and explicit handle approaches
9. **Custom filters/functions/tests** (12 tests): register + use in template rendering
10. **Callbacks** (8 tests): loader, auto_escape, path_join callbacks used in rendering
11. **Error handling** (10 tests): error_exists after failure, detail/debug_info/kind/line/template_name/print

### `t/03-integration.t` — edge cases (~15-20 tests)
- Invalid templates (syntax errors) → check error_detail/error_kind
- Missing template name rendering → check error
- Empty strings, empty containers
- Nested containers and iteration
- Multiple contexts and variable shadowing
- Numeric type coercion edge cases

---

## Implementation Order

Build incrementally so each chunk compiles and can be tested:

1. **Environment**: `new`, `free`, `DESTROY` → test with `t/00-load.t` modified to actually create env
2. **Value creators**: All 8 new_* functions → test basic creation
3. **Value queries**: kind, is_true, as_i64/f64, to_string, len → test on created values
4. **Container ops**: set_key, get_key, append, get_index → test list/object manipulation  
5. **Iterators**: try_iter, iter_next → test iterating over lists/objects
6. **Template management**: add/remove/clear templates
7. **Rendering**: render_template, render_str, eval_expr → smoke test full pipeline
8. **Globals**: add_global, remove_global + config setters/getters
9. **Callbacks**: filter/function/test registration + loader/auto_escape/path_join
10. **Syntax config**: both approaches
11. **Error handling**: all mj_err_* wrappers
12. **Value free/decref** with safe double-free protection (IV flag)

Each step compiles independently — run `perl Makefile.PL && make` after every batch.

---

## Wrapper Struct Design

```c
/* Value wrapper — heap-allocated box for mj_value */
typedef struct perl_mj_value {
    mj_value val;       /* actual minijinja value */
    int valid;          /* 1 = alive, 0 = already freed (safe no-op on free) */
} perl_mj_value_t;

/* Env wrapper — blessed scalar containing mj_env* pointer */
/* Already standard: bless SV ref to IV holding mj_env* cast as void* */

/* Iterator wrapper */
typedef struct perl_mj_iter {
    mj_value_iter *iter;   /* iterator handle */
    int valid;             /* validity flag */
} perl_mj_iter_t;

/* Syntax config wrapper */
typedef struct perl_syntax {
    mj_syntax_config config;  /* the struct itself (not pointer) */
    int valid;                 /* validity flag */
} perl_syntax_t;
```

### XS Helper Macros

```c
#define NEW_VALUE() \
    ST(0) = sv_newmortal(); \
    perl_mj_value_t *pv = malloc(sizeof(*pv)); \
    if (!pv) croak("malloc failed"); \
    pv->valid = 1; \
    SvROK_on(ST(0)); SvRV(ST(0)) = (SV*)pv; SvTYPE_set((SV*)SvRV(ST(0)), SV_PVMG); \
    sv_bless(ST(0), gv_stashpv("Minijinja::Value", GV_AUTO));

#define VALUE_PTR(sv, label) \
    (!THISSvOK(sv) || !SvIV(SvRV(sv))) \
        ? (croak("%s: value argument must be a blessed Minijinja::Value", label), (perl_mj_value_t*)NULL) \
        : !(INT2PTR(perl_mj_value_t*, SvIV(SvRV(sv))))->valid \
            ? (croak("%s: value already freed", label), (perl_mj_value_t*)NULL) \
            : INT2PTR(perl_mj_value_t*, SvIV(SvRV(sv)));

#define ENV_PTR(sv, label) (...) /* similar pattern for env handles */
```

Actually, the macro approach above is getting messy. Let me use a cleaner XS pattern where the blessed scalar's RV points directly to the struct — standard XS `sv_setsv` + `sv_upgrade` approach:

```c
/* Clean creation of blessed value wrapper */
static SV* new_sv_value() {
    perl_mj_value_t *pv = malloc(sizeof(*pv));
    if (!pv) croak("malloc failed");
    pv->valid = 1;
    
    SV *sv = sv_newmortal();
    sv_bless(sv, gv_stashpv("Minijinja::Value", GV_ADD));
    sv_setiv(sv, PTR2IV(pv));
    return sv;
}

/* Safe extraction */
static perl_mj_value_t* extract_value(SV *sv) {
    if (!sv || !SvROK(sv)) return NULL;
    SV *rv = SvRV(sv);
    if (!SvIOK(rv)) return NULL;
    perl_mj_value_t *pv = INT2PTR(perl_mj_value_t*, SvIV(rv));
    if (pv && pv->valid) return pv;
    return NULL;  /* already freed or invalid */
}
```

This is much cleaner. The SV itself holds the pointer as an IV. DESTROY on the SV calls free cleanup. No global HV needed for values!

For env handles: similar pattern — bless scalar ref, store `mj_env*` as IV.

For callbacks: we DO need a global HV because the CABI passes back `void* userdata` and we need to look up the Perl coderef. Structure: `%CALLBACK_MAP` keyed by `(env_ptr . "_" . callback_type . "_" . index)` → coderef SV*. On env free, iterate keys matching env prefix and delete entries + clear registrations via... hmm, the CABI doesn't expose a way to unregister callbacks. So we just leave stale entries in %CALLBACK_MAP — memory leak of XS level but negligible. Alternatively, we could wrap each mj_value in a struct that stores a reference to its parent env so we can clean up on DESTROY. But minijinja's value structs are opaque — we can't attach metadata to them natively.

Simplification: use a single global HV `%CB_DATA` with key = unique integer ID, value = `{ code => <coderef>, env => <env_ptr> }`. On env DESTROY, scan %CB_DATA and remove entries whose env matches. This is clean enough.

---

## File Layout

```
lib/Minijinja.pm    — updated with @EXPORT_OK, convenience wrappers, POD stub
lib/Minijinja.xs    — complete implementation (~600-800 lines)
t/00-load.t         — load test (minor change)
t/01-render.t       — render smoke tests (rewrite, ~25 tests)
t/02-api.t          — comprehensive API tests (rewrite, ~100+ tests)
t/03-integration.t  — edge cases and integration scenarios (~15 tests)
PLAN.md             — this file
```

---

## Build Verification Steps

After implementation:

```bash
rustup default stable
export MINIJINJA_SRC=$(pwd)/minijinja
export LD_LIBRARY_PATH=$(pwd)/minijinja/target/release
perl Makefile.PL
make clean && make
make test   # all t/*.t pass
```

Then run individual test files to confirm each section works:
```bash
PERL5LIB=blib/lib perl -I blib/arch t/01-render.t
PERL5LIB=blib/lib perl -I blib/arch t/02-api.t  
PERL5LIB=blib/lib perl -I blib/arch t/03-integration.t
```

---

## Risk Mitigations

| Risk | Mitigation |
|------|-----------|
| C ABI mismatch between minijinja-cabi version and header | Header is from `./minijinja/minijinja-cabi/include/minijinja.h` — build against that exact version. If symbols don't match at link time, error message will be explicit. |
| Thread safety of callback HV | Use `dTHX` / Perl's threading context; each XS call has its own thread context. The global HV is accessed within the interpreter context which Perl protects. For true MT-safety would need mutex but CPAN modules rarely need that. |
| Memory leaks from callback closures | Scan and clean up on env DESTROY (walk %CB_DATA by env prefix). |
| mj_value_to_str returns NULL | Check for NULL before using; return undef from Perl in that case. |
| Callbacks returning wrong types | Default to undefined value if return type doesn't match expected string/int/bool. Set CABI error with descriptive message. |
| String encoding (UTF-8) | minijinja uses UTF-8 internally. We pass strings through as-is without byte conversion unless explicitly needed. The C ABI assumes valid UTF-8. Perl strings marked as bytes → convert to UTF-8 before passing to CABI. Strings already UTF-8 → pass through directly. |

---

## Timeline Estimate

| Phase | Effort | Notes |
|-------|--------|-------|
| Phase 1: XS implementation | ~4-6h | Mostly mechanical — one XSUB at a time. Callback handling is the most complex part. |
| Phase 2: PM update | ~30min | Straightforward Exporter setup + convenience wrapper. |
| Phase 3: Test rewrite | ~3-4h | Comprehensive but pattern-driven. Most tests follow same structure: setup → action → assertion → cleanup. |
| Build verification & iteration | ~1-2h | Expected to hit compile errors on first try; fixing those iteratively. |

Total estimated effort: **9-13 hours** of focused work, spread across multiple sessions for compilation verification.
