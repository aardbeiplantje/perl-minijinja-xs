# Plan: Implement Minijinja Perl XS Module

## Current State Assessment

| File | Status | Notes |
|------|--------|-------|
| `lib/Minijinja.xs` | Stub (~39 lines) | Only `M_new()` and `M_DESTROY()` with TODO bodies |
| `lib/Minijinja.pm` | Minimal | Just `XSLoader::load()`, no exports, no wrappers |
| `t/00-basic.t` | 242 lines, broken API | Tests full API using functions that don't exist yet — rewrite needed |
| `t/01-render.t` | 31 lines, OO style | Calls `$mj_env->add_template()` etc. — methods don't exist — rewrite needed |
| `t/00-load.t` | 21 lines, OK | Basic load test — minor changes only |
| `minijinja/` | Built ✅ | Library at `./minijinja/target/release/libminijinja_cabi.so` |

---

## Architecture Decisions

### 1. No heavy OO hierarchy
Bless a scalar ref to an env pointer for cleanup tracking (`$env`). All XSUBs are functional-style: `Minijinja::render_template($env, $name, %ctx?)`.

### 2. Plain Perl types everywhere — auto-conversion is invisible
**This is the biggest change.** The user passes plain Perl scalars, hashrefs, arrayrefs directly to XS. Internally, XS converts them to/from `mj_value` automatically and invisibly. Users never call creation or query functions — the conversion happens transparently in render/template/eval/call paths.

Input (Perl → mj_value):
- Scalar string → `mj_value_new_string()`
- Scalar int → `mj_value_new_i64()`  
- Scalar float → `mj_value_new_f64()`
- Undef → undefined value
- Arrayref → list (recursively convert each element)
- Hashref → map/object (iterate keys, recursively convert values)

Output (mj_value → Perl):
- String → Perl scalar (UTF-8 marked if needed)
- Number → Perl int or float
- Bool → Perl true/false
- Undefined/None → undef
- List → arrayref (recursively unwrap elements)
- Map/Object → hashref (recursively unwrap values)

No exported functions for value creation, no exported value query/accessors (`value_is_true`, `value_kind`, etc.). These are internal implementation details of the conversion layer.

### 3. No explicit `free()` needed
`M_DESTROY` handles cleanup when the blessed env ref goes out of scope. Perl garbage collection takes care of it:

```perl
{ my $env = Minijinja::new(); ... } # M_DESTROY fires here automatically
```

Users can also let `$env` simply fall out of scope naturally — no explicit free call required.

### 4. Context as hashref or plain key-value pairs
Instead of manually constructing mj_value objects and calling `set_key` XSUBs:

```perl
# Before (old approach — removed):
my $ctx = Minijinja::value_new_object();
Minijinja::value_set_key($ctx, 'name', Minijinja::value_new_string('World'));
render_template($env, 'hello', $ctx);

# After (new approach):
render_template($env, 'hello', { name => 'World' });
```

Hashrefs with string keys pass through auto-conversion to an mj_value object internally. XS loops over the hash keys/values automatically.

### 5. Callback registration pattern
Store Perl coderef userdata in a global HV keyed by unique callback ID. The C callback wrapper looks up the coderef, converts `mj_value* args` → Perl scalars via the auto-conversion layer, calls the coderef, then converts return value back to mj_value via auto-conversion.

---

## Phase 1: XS Implementation (`lib/Minijinja.xs`)

### Internal Conversion Helpers (NOT exported — used internally only)

These are static C functions called by rendering/callback/template functions:

| Function | Purpose | Notes |
|----------|---------|-------|
| `perl_to_mj_value(SV *sv)` | Converts any Perl type to mj_value | Scalar → string/int/float/undefined; arrayref → list (recursive); hashref → map/object (recursive). Handles undef gracefully. |
| `mj_value_to_perl(mj_value val)` | Converts any mj_value to appropriate Perl type | Returns newly created SV. String → scalar PV; number → IV/NV; bool → boolean; undefined → undef; list → new arrayref (recursive); map → new hashref (recursive). |

These are **not XSUBs** — they're plain C helper functions called from within XSUB implementations. Users never see or call them.

### Exported XSUBs

#### Environment management

| XSUB | CABI call | Notes |
|------|-----------|-------|
| `new(%opts)` | `mj_env_new()` + setters | Returns blessed `Minijinja::Env` scalar ref containing `mj_env*` pointer. Optional `%opts` hash applies config on creation. DESTROY via M_DESTROY handles cleanup automatically — no explicit free needed. |

M_DESTROY is registered in XS BOOT section: when the blessed env ref's refcount drops to zero, it calls `mj_env_free()`.

#### Template management

| XSUB | CABI call | Notes |
|------|-----------|-------|
| `add_template($env, $name, $source)` | `mj_env_add_template()` | Returns true/false. Simple passthrough. |
| `remove_template($env, $name)` | `mj_env_remove_template()` | Returns true/false. |
| `clear_templates($env)` | `mj_env_clear_templates()` | Returns true/false. |

#### Rendering (core functionality)

These use auto-conversion for context parameters and return values:

| XSUB | CABI call | Notes |
|------|-----------|-------|
| `render_template($env, $name, %ctx?)` | `mj_env_render_template()` | `%ctx?` is optional hashref passed as template variables. If omitted or empty, renders with no context (no errors). Returns rendered string or undef on error (error info available via error_* functions). Auto-converts hashref keys/values to mj_value internally. |
| `render_str($env, $name, $source, %ctx?)` | `mj_env_render_named_str()` | Inline template rendering. Same ctx handling as above. Returns string or undef+error. |
| `eval_expr($env, $expr, %ctx?)` | `mj_env_eval_expr()` | Evaluate a minijinja expression. %ctx is optional variable binding hashref. Returns plain Perl value — auto-unwrapped from mj_value (scalar/string/number/bool/arrayref/hashref depending on result type), or undef on error. |

**Context parameter format:** `{ key1 => 'value1', key2 => 42 }`. XS converts this hashref to an mj_object by looping over keys and converting each value through `perl_to_mj_value()`. This happens transparently in the render/eval XSUB implementations.

#### Globals

| XSUB | CABI call | Notes |
|------|-----------|-------|
| `add_global($env, $name, $value)` | `mj_env_add_global()` | `$value` is any plain Perl type — auto-converted to mj_value by internal helper. Takes ownership per CABI spec. Returns true/false. |

#### Configuration setters/getters

CABI only provides setters for these; getters stored in Perl-side HV keyed by env pointer:

| Setter / Getter pair | CABI setter | Stored state |
|---------------------|-------------|--------------|
| `set_debug($env, $bool)` / `get_debug($env)` | `mj_env_set_debug()` | Boolean in config map |
| `set_fuel($env, $n)` / `get_fuel($env)` | `mj_env_set_fuel()` | Integer in config map; `clear_fuel()` also updates stored value to 0 |
| `clear_fuel($env)` | `mj_env_clear_fuel()` | Updates stored value to 0 |
| `set_recursion_limit($env, $n)` / `get_recursion_limit($env)` | `mj_env_set_recursion_limit()` | Integer in config map |
| `set_trim_blocks($env, $bool)` / `get_trim_blocks($env)` | `mj_env_set_trim_blocks()` | Boolean in config map |
| `set_lstrip_blocks($env, $bool)` / `get_lstrip_blocks($env)` | `mj_env_set_lstrip_blocks()` | Boolean in config map |
| `set_keep_trailing_newline($env, $bool)` / `get_keep_trailing_newline($env)` | `mj_env_set_keep_trailing_newline()` | Boolean in config map |
| `set_undefined_behavior($env, $mode)` / `get_undefined_behavior($env)` | `mj_env_set_undefined_behavior()` | Integer (0/1/2) in config map — no CABI getter so we store it ourselves |

**Config storage**: Global HV `%ENV_CONFIGS` keyed by stringified `mj_env*` address. Each entry is a hashref: `{ debug => bool, fuel => int, recursion_limit => int, trim_blocks => bool, lstrip_blocks => bool, trailing_newline => bool, undefined_behavior => int }`.

#### Custom callbacks (filters, functions, tests)

| XSUB | CABI call | Notes |
|------|-----------|-------|
| `add_filter($env, $name, \&coderef)` | `mj_env_add_filter()` | Returns true/false. Stores coderef in global HV `%CB_DATA` with unique ID derived from env pointer + callback type + counter. On env DESTROY, clean up entries matching that env pointer. Callback wrapper: receives args as Perl scalars via auto-conversion → calls coderef → converts return value to mj_value via auto-conversion. |
| `add_function($env, $name, \&coderef)` | `mj_env_add_function()` | Same pattern as filter. |
| `add_test($env, $name, \&coderef)` | `mj_env_add_test()` | Same pattern as filter. Test callbacks receive the test subject as first arg and return boolean. |

**Callback argument conversion**: When minijinja invokes our registered callback with `const mj_value* args`, we iterate over each arg and convert it using the internal `mj_value_to_perl()` helper, producing a list of plain Perl scalars/refs. These are pushed onto the Perl stack for `call_sv()`. The return value is converted back through `perl_to_mj_value()`.

#### Syntax configuration

Only inline approach needed (explicit handle management removed — unnecessary complexity):

```perl
apply_syntax($env, %opts)  # opts = { block_start => '<%', variable_start => '<$', ... }
```

| XSUB | CABI call | Notes |
|------|-----------|-------|
| `apply_syntax($env, %opts)` | `mj_env_set_syntax_config()` + `mj_syntax_config_default()` | Build syntax config internally from `%opts` hash, filling unspecified fields with defaults from `mj_syntax_config_default()`, then apply to env. No explicit handle or free needed. Unrecognized keys in `%opts` are silently ignored. Fields: block_start, block_end, variable_start, variable_end, comment_start, comment_end, line_statement_prefix, line_comment_prefix. All optional strings. |

#### Callback-based environment configuration

| XSUB | CABI call | Notes |
|------|-----------|-------|
| `set_loader($env, \&coderef)` | `mj_env_set_loader()` | Returns true/false. Wrapper receives template name string, calls coderef, returns strdup'd result (minijinja frees via mj_str_free). Coderef returns template source string or undef if not found. |
| `set_auto_escape($env, \&coderef)` | `mj_env_set_auto_escape_callback()` | Returns true/false. Wrapper receives template name, calls coderef, returns MJ_AUTO_ESCAPE_NONE or MJ_AUTO_ESCAPE_HTML. Coderef returns 'html' or '' (or any truthy/falsy value). |
| `set_path_join($env, \&coderef)` | `mj_env_set_path_join_callback()` | Returns true/false. Wrapper receives `(name, parent)`, calls coderef, returns strdup'd result. |

**Callback userdata storage**: Global HV `%CB_DATA` with key = unique integer ID derived from env pointer + callback type index. Each entry maps to a hashref: `{ code => <SV* coderef> }`. On env DESTROY (M_DESTROY), scan %CB_DATA for keys matching this env's prefix and remove them.

#### Error handling

| XSUB | CABI call | Notes |
|------|-----------|-------|
| `error_exists()` | `mj_err_is_set()` | Returns 1/0 |
| `error_detail()` | `mj_err_get_detail()` + frees internally | Returns error detail string or undef. Frees C string automatically — caller never needs to free. |
| `error_debug_info()` | `mj_err_get_debug_info()` + frees internally | Returns debug info string or undef. Frees automatically. |
| `error_kind()` | `mj_err_get_kind()` → enum int | Returns integer kind or -1 if no error. Kinds map to numeric values from mj_err_kind enum. |
| `error_line()` | `mj_err_get_line()` → uint32_t | Returns line number or 0 if no error. |
| `error_template_name()` | `mj_err_get_template_name()` + frees internally | Returns template name string or undef. Frees automatically. |
| `error_print()` | `mj_err_print()` | Prints error to stderr via CABI. Returns true/false. |

---

## Phase 2: Update Minijinja.pm

Current file is minimal (10 lines). Changes needed:

1. Add `%EXPORT_OK` listing all exported functions (use Exporter::import for standard export support)
2. Add convenience wrapper for `new(%opts)` that chains env creation with config setters
3. Add basic POD documentation stub

Exported functions:
```perl
our @EXPORT_OK = qw(
    new
    
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
    
    apply_syntax
    
    set_loader set_auto_escape set_path_join
    
    error_exists error_detail error_debug_info 
    error_kind error_line error_template_name error_print
);
```

Convenience `new(%opts)` in Perl wrapper: creates environment, then conditionally applies configuration options from the `%opts` hash before returning the blessed env handle.

---

## Phase 3: Rewrite Tests

### `t/00-load.t` — minimal changes
- Keep structure as-is (basic load test)
- Update test count to match actual tests run

### `t/01-render.t` — rewrite (~8-12 tests)
Functional API smoke tests for the most common rendering workflow:

```perl
use strict; use warnings;
use Test::More;
use Minijinja qw(new add_template render_template render_str 
                  error_exists error_detail);

# Smoke test: environment creation and destruction (no explicit free needed)
my $env = new();
ok($env, 'environment created');

# Smoke test: template registration + rendering with hashref context
add_template($env, 'hello', 'Hello {{ name }}!');
is(render_template($env, 'hello', { name => 'World' }), 'Hello World!', 'basic render');

# Smoke test: inline template rendering  
is(render_str($env, 'inline.pl', '{{ greeting }}!', { greeting => 'Hi!' }), 'Hi there!', 'inline render');

# No cleanup needed — DESTROY on $env handles it automatically when it falls out of scope
done_testing();
```

### `t/02-api.t` — comprehensive but simplified (~70-80 tests total)
Replaces old `t/00-basic.t`. Organized by feature section. SKIP blocks handle optional features that depend on library availability.

Sections and test counts:

1. **Environment** (5 tests): new returns blessed ref, config options in `%opts`, M_DESTROY fires on undef
2. **Template management** (6 tests): add/remove/clear templates, verify errors on duplicate/missing names
3. **Rendering basics** (10 tests): named templates with various context shapes (empty ctx, single var, multiple vars, nested hashes), inline rendering with variables
4. **Expression evaluation** (8 tests): eval_expr with simple expressions (`1+2`, `'a' ~ 'b'`, boolean ops), eval_expr with context bindings, auto-unwrapped return types (numbers, strings, booleans, lists as arrayrefs, maps as hashrefs)
5. **Globals** (6 tests): add_global with scalar values, add_global with complex values (hashref/arrayref), verify globals accessible in templates, remove_template interaction, global override vs context precedence
6. **Config setters/getters** (14 tests): each setter/getter pair tested independently — set value, get it back; default values verified; edge cases (zero fuel, max recursion limit, etc.)
7. **Custom filters/functions/tests** (12 tests): register filter → use `{{ x | upper }}` in template; register function → use `{{ greet("World") }}`; register test → use `{% if n is even %}`; callback receives correct Perl types; callback returns correct types; undefined behavior for wrong arg counts
8. **Syntax config** (4 tests): apply custom block/variable/comment delimiters, render template using custom syntax, defaults when no opts passed
9. **Callback-based loaders** (6 tests): set_loader returning static content, loader called with correct template name, loader returning undef for missing template, chained template loading
10. **Error handling** (8 tests): error_exists after failure scenarios, error_detail contains useful message, error_kind identifies type (syntax error/not found/etc.), error_line gives correct line number, error_template_name identifies which template failed

### `t/03-integration.t` — edge cases and realistic usage (~15-20 tests)
- Recursive/nested data structures: hashref containing arrayrefs containing more hashrefs → auto-conversion handles nesting depth correctly
- Empty containers: empty list/arrayref, empty map/hashref
- Type coercion at rendering time: passing int where string expected, etc.
- Multiple envs coexisting: create two separate envs, each with own templates/globals/callbacks
- Callback interaction: filter that calls another filter, function that uses context variables
- Large contexts: 20+ variable bindings in single render call
- Unicode strings through the pipeline

---

## Implementation Order

Build incrementally so each chunk compiles and can be tested independently:

1. **Environment**: `new()` + M_DESTROY via XS BOOT section → test with t/00-load.t modified to actually create env
   - Verify blessed ref is returned, M_FREE fires on undef
    
2. **Internal conversion helpers**: Static C functions `perl_to_mj_value()` and `mj_value_to_perl()`
   - Not exported XSUBs — just internal utilities. Test by building them into the environment code.

3. **Template management**: add/remove/clear templates → verify with simple add_template call (no rendering yet)

4. **Rendering**: render_template, render_str, eval_expr using the conversion helpers for ctx parameters
   - This is the big integration step — template registration + auto-conversion of hashref context + rendering + auto-unwrapping of results
   - Smoke test basic "Hello {{ name }}!" rendering

5. **Globals**: add_global + config setters/getters
   - Add a global variable, verify it's accessible in templates
   - Set debug mode, get it back

6. **Callbacks**: filter/function/test registration + wrapper logic
   - Register a filter, use it in a template; register function, call it from template
   - The callback wrapper is the trickiest part — converting mj_value args ↔ Perl scalars through auto-conversion

7. **Syntax config application**: apply_syntax inline approach

8. **Loader/auto_escape/path_join callbacks**

9. **Error handling**: all error_* wrappers

Each step: `perl Makefile.PL && make` and check for compilation errors before moving on.

---

## Wrapper Struct Design

```c
#define THIS(sv)      INT2PTR(void *, SvIV(SvRV(sv)))

typedef struct perl_mj_env {
    mj_env *env;           /* CABI environment handle */
} perl_mj_env_t;
```

No validity flag needed. After free, set `pe->env = NULL`. All access checks `if (pe->env != NULL)` before use. Simple and clean — no extra state to track.

### Allocation pattern (Perl malloc)

Structs are allocated via Perl's `Newxz()` which integrates with Perl's memory management:

```c
perl_mj_env_t *pe = NULL;
Newxz(pe, 1, perl_mj_env_t);    /* allocate & zero-initialize */
if (!pe) croak("out of memory"); /* allocation failure is fatal */
```

`Newxz` zero-initializes the allocation (`z` suffix), so `pe->env` starts as NULL automatically. No manual initialization needed. Zeroed pointer also means double-free protection is handled by the NULL check alone — after freeing, set the pointer to NULL so subsequent accesses become no-ops.

### Blessed SV construction

We bless a scalar ref containing the **wrapper struct pointer** directly (not the raw CABI handle). The wrapper IS the blessed reference — there's only one type of stored object in Minijinja, so we need no separate namespaces like curl's `"http::curl::easy"` vs `"http::curl::multi"`. Package name is simply `"Minijinja"`.

```c
SV *sv = sv_newmortal();
SvPOK_only(sv);                     /* opaque scalar — not a string we manipulate */
sv_setref_pv(sv, "Minijinja", pe);  /* bless + store wrapper ptr as IV */
ST(0) = sv;                         /* return to caller */
XSRETURN(1);
```

`sv_setref_pv()` does two things: sets the RV flag (making it a ref), stores the pointer as an IV in the referent, and blesses into the specified package. The XS loader recognizes the `"Minijinja"` package name and will call our `M_DESTROY()` when refcount reaches zero.

### M_DESTROY pattern

Nullify the env pointer first (double-free protection via explicit NULL check), then free the entire wrapper struct:

```c
void M_DESTROY(SV *sv)
    CODE:
        dTHX;
        if (!THISSvOK(sv)) return;        /* not a blessed ref → nothing to do */

        perl_mj_env_t *pe = THIS(sv);     /* extract wrapper ptr via THIS() macro */
        if (pe->env != NULL) {            /* explicit NULL check — double-free protection */
            mj_env_free(pe->env);         /* CABI cleanup */
            pe->env = NULL;               /* nullify so further calls are no-ops */
        }
        Safefree(pe);                     /* free entire wrapper struct */
```

Key points:
- Check `pe->env != NULL` — after first free, env is set to NULL so subsequent calls are no-ops. No validity flag needed.
- `Safefree()` is Perl's safe free that handles NULL pointers gracefully.
- After `pe->env = NULL`, any further access through `THIS(sv)` gets a valid struct pointer but with NULL env — the NULL check prevents calling `mj_env_free(NULL)`.
- The entire wrapper struct is freed on destruction — no leak.

### Example XSUBs using these patterns

**new():**

```c
SV *M_new(...)
    CODE:
        dTHX; dSP;

        /* Allocate wrapper struct via Perl malloc */
        perl_mj_env_t *pe = NULL;
        Newxz(pe, 1, perl_mj_env_t);      /* allocate & zero-init */
        if (!pe) croak("out of memory");

        pe->env = mj_env_new();           /* CABI call */
        if (!pe->env) {                   /* allocation failure */
            Safefree(pe);                 /* free wrapper on failure */
            XSRETURN_UNDEF;
        }

        /* Apply optional config from %opts hashref */
        HV *hv = NULL;
        if (items > 1 && SvROK(ST(1)) && SvTYPE(SvRV(ST(1))) == SVt_PVHV) {
            hv = (HV*)SvRV(ST(1));
            // iterate hv keys to apply settings...
        }

        /* Bless and return */
        SV *sv = sv_newmortal();
        SvPOK_only(sv);
        sv_setref_pv(sv, "Minijinja", pe);/* bless + store wrapper ptr */
        ST(0) = sv;
        XSRETURN(1);
```

**M_DESTROY():**

```c
void M_DESTROY(SV *sv)
    CODE:
        dTHX;
        if (!THISSvOK(sv)) return;

        perl_mj_env_t *pe = THIS(sv);     /* extract via macro */
        if (pe->env != NULL) {            /* explicit NULL check → double-free protection */
            mj_env_free(pe->env);         /* CABI cleanup */
            pe->env = NULL;               /* nullify so further calls are no-ops */
        }
        Safefree(pe);                     /* free entire wrapper struct */
```

**add_template() as example:**

```c
bool M_add_template(SV *env_sv, char *name, char *source)
    PREINIT:
        perl_mj_env_t *pe;
    CODE:
        dTHX;
        if (!THISSvOK(env_sv)) XSRETURN_UNDEF;
        pe = THIS(env_sv);                /* extract wrapper ptr via THIS() macro */
        if (pe->env == NULL) croak("Minijinja environment already freed");
        RETVAL = mj_env_add_template(pe->env, name, source);
    OUTPUT: RETVAL
```

### render_template() using auto-conversion

Context parameter is a hashref or undef — XS loops over keys/values and converts each through `perl_to_mj_value()` internally:

```c
SV *M_render_template(SV *env_sv, char *name, SV *ctx_sv=PL_sv_undef)
    PREINIT:
        perl_mj_env_t *pe;
        mj_value ctx;                    /* built internally from %ctx hashref or empty object */
    CODE:
        dTHX;

        /* Validate env handle */
        if (!THISSvOK(env_sv)) XSRETURN_UNDEF;
        pe = THIS(env_sv);
        if (pe->env == NULL) croak("Minijinja environment already freed");

        /* Convert optional context to mj_object value */
        if (!ctx_sv || !SvOK(ctx_sv) || ctx_sv == PL_sv_undef) {
            ctx = mj_value_new_object();  /* empty context — no variables available */
        } else if (SvROK(ctx_sv) && SvTYPE(SvRV(ctx_sv)) == SVt_PVHV) {
            HV *hv = (HV*)SvRV(ctx_sv);
            HE *he;
            I32 key_len;
            const char *key;

            ctx = mj_value_new_object();
            hv_iterinit(hv);
            while ((he = hv_iternext(hv))) {
                key = hv_iterkey(he, &key_len);
                SV *val = hv_iterval(hv, he);

                /* Recursively convert Perl value → mj_value via internal helper */
                mj_value mv = perl_to_mj_value(val);

                /* Set as string key on object */
                mj_value_set_string_key(&ctx, key, mv);
                /* Note: mj_value_set_string_key takes ownership of 'mv' per CABI spec */
            }
        } else {
            /* ctx is not a hashref — treat as single-value context */
            ctx = perl_to_mj_value(ctx_sv);
        }

        /* Render template */
        RETVAL = mj_env_render_template(pe->env, name, ctx);

        /* Convert returned char* to Perl SV and free internally */
        if (RETVAL) {
            SV *result = sv_newmortal();
            sv_setsv(result, sv_2mortal(newSVpv(RETVAL, 0)));  /* copy string into SV */
            mj_str_free(RETVAL);                              /* free minijinja-allocated string */
            ST(0) = result;
            XSRETURN(1);
        } else {
            XSRETURN_UNDEF;   /* render failed — error info available via error_*() */
        }

    OUTPUT: RETVAL
```

### Iterator wrapper struct (if needed)

For iterators, use same pattern but store iterator pointer:

```c
typedef struct perl_mj_iter {
    mj_value_iter *iter;     /* iterator handle */
} perl_mj_iter_t;
```

Allocate with `Newxz`, bless scalar ref containing pointer, M_DESTROY calls `mj_value_iter_free()`. On access, check `iter != NULL` before use.

---
## File Layout

```
lib/Minijinja.pm    — updated with @EXPORT_OK, convenience wrappers, POD stub
lib/Minijinja.xs    — complete implementation (~350-450 lines)
t/00-load.t         — load test (minor change)
t/01-render.t       — render smoke tests (rewrite, ~10 tests)
t/02-api.t          — comprehensive API tests (rewrite, ~75 tests)
t/03-integration.t  — edge cases and integration scenarios (~18 tests)
PLAN.md             — this file
```

**Line count reduction**: From estimated 600-800 lines down to ~350-450 because:
- No value creation XSUBs (~8 functions removed)
- No value query/accessor XSUBs (~6 functions removed)  
- No container operation XSUBs (~4 functions removed)
- No iterator XSUBs (~2 functions removed)
- No free() function removed (handled by M_DESTROY)
- Internal conversion helpers are static C functions, not exported XSUBs

---

## Build Verification Steps

After implementation:

```bash
export MINIJINJA_SRC=$(pwd)/minijinja
export LD_LIBRARY_PATH=$(pwd)/minijinja/target/release
perl Makefile.PL
make clean && make
make test   # all t/*.t pass
```

Then run individual test files:
```bash
PERL5LIB=blib/lib perl -I blib/arch t/01-render.t
PERL5LIB=blib/lib perl -I blib/arch t/02-api.t  
PERL5LIB=blib/lib perl -I blib/arch t/03-integration.t
```

---

## Risk Mitigations

| Risk | Mitigation |
|------|-----------|
| Auto-conversion of deeply nested structures causes stack overflow or performance issues | Add recursion depth limit in `perl_to_mj_value` and `mj_value_to_perl` (e.g., 64 levels). Log warning if hit. |
| UTF-8 encoding mismatch between Perl strings and minijinja's internal UTF-8 | Use `SvUTF8(sv)` to detect encoding; ensure strings are properly marked as UTF-8 when passed to CABI. minijinja expects valid UTF-8. |
| Memory leaks from callback closures not cleaned up on env free | Walk `%CB_DATA` on M_DESTROY, remove entries whose key prefix matches this env pointer. Test with valgrind or similar. |
| mj_value_to_str returns NULL for some value types | Internal helper checks for NULL before using result; returns undef from Perl side in that case. |
| Callbacks returning wrong types cause undefined behavior | Auto-conversion handles type mismatches gracefully — unrecognized return types become undefined values. Set CABI error only on actual errors, not type mismatches. |
| Hash iteration order non-deterministic in Perl | Irrelevant for template rendering — Jinja2/minijinja iterates hash keys in insertion order which is preserved by our conversion. For test assertions, use explicit key access rather than iterating maps. |

---

## Timeline Estimate

| Phase | Effort | Notes |
|-------|--------|-------|
| Phase 1: XS implementation (core) | ~3-4h | Simpler than original plan due to removal of value-level XSUBs. Conversion helpers add complexity but are internal-only. |
| Phase 2: PM update | ~15min | Straightforward Exporter setup + convenience wrapper. |
| Phase 3: Test rewrite | ~2-3h | Fewer test sections now (~9 instead of 11), fewer total tests (~75 instead of 100+). Pattern-driven. |
| Build verification & iteration | ~1-2h | Expected compile iterations; fixing those iteratively. |

Total estimated effort: **7-10 hours** of focused work.

---

## Functions Summary (replaces PLAN_FUNCTIONS.md)

`lib/Minijinja/Functions.pm` — ~85 exported subs across 7 categories. All registered via `add_filter()`, `add_function()`, or `add_test()` in Perl callbacks (not XSUBs). See `lib/Minijinja/Functions.pm` for full source.

### What's implemented (all complete ✅)

| Category | Count | Examples |
|----------|-------|---------|
| Core helpers | 4 | `tojson`, `items`, `startswith`, `endswith` |
| String filters | 12 | `upper`, `lower`, `strip`/`rstrip`/`lstrip`, `title`, `capitalize`, `split`/`rsplit`, `replace`, `length_str` |
| Number filters | 3 | `abs`, `int`, `float` |
| Array filters | 9 | `list`, `first`, `last`, `reverse`, `slice`, `sort`, `min/max`, `join`, `map` |
| Object filters | 4 | `get`, `keys`, `values`, `dictsort` |
| Test functions | ~30 | Type checks (`is_string`, `is_integer`, ...), comparison ops (`eq/ne/lt/le/gt/ge`), membership (`is_in`) |
| Select/reject filters | 4 | `selectattr`, `rejectattr`, `select`, `reject` |
| Global functions | 4 | `raise_exception`, `range`, `strftime_now`, `namespace` |

### Key architectural note

These Perl callbacks **shadow** minijinja's native builtins when registered (e.g., calling `add_filter($env, 'upper', \&filter_upper)` overwrites the native Rust implementation). The only auto-registered functions in test harnesses that don't exist in Rust are: `has_prefix`, `has_suffix`, and `raise_exception`. Everything else should be left to the native implementations or explicitly registered per-test.

### Not implemented (minimal gap)

~21 Rust builtins not covered (mostly advanced features): `safe/escape`, `default`, `round`, `batch/slice`(Jinja-style), `sum/indent/string/bool/unique/chain/zip/groupby/pprint/format/urlencode`. These are rarely needed in typical template usage.
