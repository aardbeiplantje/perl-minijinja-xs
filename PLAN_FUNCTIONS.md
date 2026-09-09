# Minijinja Functions Plan

## Analysis of llama.cpp jinja/value.cpp Functions

### Global Builtins (`global_builtins()`) — lines 352-531

| Function | Type | Purpose |
|----------|------|---------|
| `raise_exception` | global fn | Throws Jinja exception from string message |
| `namespace` | global fn | Creates mutable object from kwargs |
| `strftime_now` | global fn | Formats current time (C++ strftime) |
| `range` | global fn | Python-style range `[start, stop)` or `[start, stop, step]` |
| `tojson` | global filter + per-type | JSON encoding with escape/indent/separators options |

### Test Functions (`test_is_*`) — lines 423-528

| Test | Parameters | Description |
|------|-----------|-------------|
| `is_boolean` / `is_callable` | val | Type check for boolean / function |
| `is_odd` / `is_even` | int | Parity checks |
| `is_false` / `is_true` | bool | Identity checks against True/False |
| `is_divisibleby` | int, int | Modulo zero check |
| `is_string` / `is_integer` / `is_float` / `is_number` | val | Type checks on values |
| `is_iterable` / `is_sequence` | val | Array/string/undefined checks |
| `is_mapping` | val | Object type check |
| `is_lower` / `is_upper` | string | Case checks on strings |
| `is_none` / `is_defined` / `is_undefined` | val | Null/defined checks |
| `is_eq` / `is_equalto` | a, b | Equality comparison (==) |
| `is_ge` / `is_gt` / `is_lt` / `is_ne` | a, b | Comparison operators (>=, >, <, !=) |
| `is_in` | needle, haystack | Membership in array/string/object keys |

### Integer Builtins (`value_int_t::get_builtins`) — lines 534-556

| Filter | Description |
|--------|-------------|
| `default` | Returns self or fallback value |
| `abs` | Absolute value |
| `int` / `float` | No-op conversion to same type |
| `safe` / `string` / `tojson` | JSON encoding passthroughs |

### Float Builtins (`value_float_t::get_builtins`) — lines 559-581

| Filter | Description |
|--------|-------------|
| `default`, `abs` | Same as int |
| `int` | Cast to integer |
| `float` / `safe` / `string` / `tojson` | Passthroughs |

### String Builtins (`value_string_t::get_builtins`) — lines 597-919

| Filter | Description |
|--------|-------------|
| `default` | Empty-string-as-falsy replacement |
| `upper` / `lower` | Case transformation |
| `strip` / `rstrip` / `lstrip` | Whitespace/chars trimming with optional chars arg |
| `title` / `capitalize` | Title case / first-letter capitalize |
| `length` | Character count (Unicode-aware) |
| **`startswith`** / **`endswith`** | Prefix/suffix checks (currently in test file) |
| `split` / `rsplit` | Split by delimiter, maxsplit support |
| `replace` | String replace (count not implemented) |
| `format` | Simple `{}` placeholder formatting |
| `int` / `float` | Parse string to number with default fallback |
| `string` / `safe` / `tojson` | Identity/encoding passthroughs |
| `indent` | Indent lines with configurable width and blank handling |
| `slice` | Python-style `[start:stop:step]` slicing on strings |

### Boolean Builtins (`value_bool_t::get_builtins`) — lines 922-945

| Filter | Description |
|--------|-------------|
| `default`, `int`, `float` | Coercion operations |
| `safe`, `string`, `tojson` | "True"/"False" string conversion or JSON encoding |

### Array Builtins (`value_array_t::get_builtins`) — lines 951-1197

| Filter | Description |
|--------|-------------|
| `default`, `list` | Self/copy or fallback value |
| `first` / `last` | Get first/last element (undefined if empty) |
| **`length`** | Item count |
| `slice` | Python-style `[start:stop:step]` array slicing |
| `selectattr` / `rejectattr` / `select` / `reject` | Filter arrays by attribute presence/value/test predicates |
| **`join`** | Join array items with delimiter, optional attribute access |
| `string`, `tojson` | Encoding passthroughs |
| `map` | Extract attribute values from objects in array as new array |
| `append` / `pop` / `sort` / `reverse` | In-place mutations and sort/reverse copies |
| `min` / `max` | Find min/max of array elements (attribute not implemented initially) |
| **`items`** *(on object)* | Returns sorted [key, value] pairs as array of tuples |

### Object Builtins (`value_object_t::get_builtins`) — lines 1203-1297

| Filter | Description |
|--------|-------------|
| `get` | Safe key access with default fallback |
| **`keys`** / **`values`** | Return arrays of keys or values |
| **`items`** | Return sorted [key, value] tuple pairs *(currently in test file)* |
| `tojson`, `string`, `length` | JSON encoding, identity, and count operations |
| **`dictsort`** | Sort dict by key or value into a copy |

---

## Implementation Status

### ✅ Completed

| Phase | Status | Description | Commit | Functions Added |
|-------|--------|-------------|--------|-----------------|
| **Phase 1** | ✅ Complete | Created `Minijinja::Functions` package with `tojson`, `items`, `startswith`, `endswith` | `166597d` | 4 |
| **Phase 2** | ✅ Complete | Added string filters (case, trim, title, split, replace, length) | `b92bdce` | 12 |
| **Phase 3** | ✅ Complete | Added numeric helper filters (`abs`, `int`, `float`) | `f5a7dec` | 3 |
| **Phase 4** | 🟡 Partial | Array manipulation — trivial/easy done; medium/harder pending | `48cef24` | 5/9 implemented |

### ⏳ Pending

| Phase | Description | Complexity | Remaining Items |
|-------|-------------|------------|-----------------|
| **Phase 4** (cont.) | Array filters: sort, min/max, join, map, selectattr/rejectattr | Medium to Complex | 4 filters + 2 predicates |
| **Phase 5** | Jinja test functions (`is_*` predicates for `{% if val is ... %}`) | Easy to Harder | ~30 test functions |
| **Phase 6** | Object filters and methods (`get`, `keys`, `values`, `dictsort`) | Easy/Medium | 4 methods |
| **Phase 7** | Global functions (`namespace`, `strftime_now`, `range`) | Varies | 4 functions (raise_exception already in use) |

---

## Progress Summary

### Commits

| Commit | Description | Date |
|--------|-------------|------|
| `166597d` | feat: extract tojson/items/startswith/endswith into Minijinja::Functions package | — |
| `b92bdce` | feat(phase 2): add string filters (upper, lower, strip, rstrip, lstrip, title, capitalize, split, rsplit, replace, length_str) | — |
| `f5a7dec` | feat(phase 3): implement number filters (abs, int, float) | — |
| `48cef24` | feat(phase 4): implement array filters (list, first, last, reverse, slice) | — |

### Current State

- **File**: `lib/Minijinja/Functions.pm` — 34 exports across 4 packages (tojson/items/startswith/endswith + string + number + array filters)
- **Tests**: All 99 tests passing across 8 test files
- **Total functions implemented**: ~25 filter/function callbacks

---

## Exported Functions Reference

All functions are registered via `add_filter()` or `add_function()` with the Perl callback name as a prefix.

### Core Functions (Phase 1)

| Filter/Test Name | Perl Function | Type | Notes |
|------------------|---------------|------|-------|
| `tojson` | `filter_tojson` | filter | JSON encoding with HTML-safe escaping (`< > & ' → \u00xx`) |
| `items` | `filter_items` | filter | hashref → sorted `[key, value]` pairs array |
| `startswith` | `func_startswith` | function | `$str starts with $prefix?` |
| `istartswith` / `endswith` (test) | `sub { func_endswith(@_) }` | test | Jinja `is` syntax wrapper for endswith |

### String Filters (Phase 2)

| Filter Name | Perl Function | Description |
|-------------|---------------|-------------|
| `upper` | `filter_upper` | Convert to uppercase (`uc`) |
| `lower` | `filter_lower` | Convert to lowercase (`lc`) |
| `strip` | `filter_strip` | Remove whitespace/chars from both ends (optional chars arg) |
| `rstrip` | `filter_rstrip` | Remove whitespace/chars from right end (optional chars arg) |
| `lstrip` | `filter_lstrip` | Remove whitespace/chars from left end (optional chars arg) |
| `title` | `filter_title` | Title case — first letter of each word uppercase, rest lowercase |
| `capitalize` | `filter_capitalize` | Capitalize first letter only, make rest lowercase |
| `split` | `filter_split` | Split string by delimiter, optional maxsplit support (returns arrayref) |
| `rsplit` | `filter_rsplit` | Split from right side with optional maxsplit (returns arrayref) |
| `replace` | `filter_replace` | Replace all occurrences of old substring with new (`\Q...\E` escaping) |
| `length_str` | `filter_length_str` | Return character length of string |

### Number Filters (Phase 3)

| Filter Name | Perl Function | Description |
|-------------|---------------|-------------|
| `abs` | `filter_abs` | Absolute value (works on int or float) |
| `int` (on number) | `filter_int_num` | Cast to integer via Perl's `int()`, truncating toward zero |
| `float` (on number) | `filter_float_num` | Force numeric scalar (no-op if already numeric) |

### Array Filters (Phase 4 — Partial)

| Filter Name | Perl Function | Description | Status |
|-------------|---------------|-------------|--------|
| `list` | `filter_list` | Shallow copy of arrayref `[ @{$val} ]` | ✅ Done |
| `first` | `filter_first` | Get first element or undef if empty/undefined | ✅ Done |
| `last` | `filter_last` | Get last element or undef if empty/undefined (non-mutating) | ✅ Done |
| `reverse` | `filter_reverse` | Returns reversed copy using Perl's built-in `reverse()` | ✅ Done |
| `slice` [start:stop:step] | `filter_array_slice` | Python-style slicing with full negative index support and optional step parameter | ✅ Done |
| `sort` [reverse] [attribute] | *(pending)* | With optional attribute access for object arrays; reverse flag only for now | ⏳ Pending |
| `min` / `max` [attribute] | *(pending)* | Find min/max; attribute access deferred initially | ⏳ Pending |
| `join` sep attr | *(pending)* | Join array items with separator; attribute extraction from objects deferred initially | ⏳ Pending |
| `map` attribute | *(pending)* | Extract attribute values into new array; needs callback integration with object types | ⏳ Pending |

---

## Implementation Plan

### Phase 1: Move `tojson`, `items`, `startswith`, `endswith` from tests into Minijinja.pm

**Goal**: Create `Minijinja::Functions` package with these 4 functions, removing them from the test file.

**New file**: `lib/Minijinja/Functions.pm`

```perl
# lib/Minijinja/Functions.pm

package Minijinja::Functions;

use strict; use warnings;
use Exporter 'import';
our @EXPORT_OK = qw(
    filter_tojson
    filter_items
    func_startswith
    func_endswith
);

# tojson — JSON encoding with HTML-safe escaping (< > & ' → \u00xx)
sub filter_tojson { ... }

# items — hashref → sorted [key, val] pairs list  
sub filter_items { ... }

# startswith — $str starts with $prefix?
sub func_startswith { ... }

# endswith — $str ends with $suffix?
sub func_endswith { ... }

1;
```

**Changes needed**:
- Create new file `lib/Minijinja/Functions.pm` with the above functions extracted from `t/50-jinja-test-input-01.t`.
- Update `t/50-jinja-test-input-01.t` to import from `Minijinja::Functions` instead of defining inline.
- The test will need `JSON` module or we can implement a minimal JSON serializer in Perl.

**Status: ✅ COMPLETE** (commit `166597d`)

---

### Phase 2: Implement String Filters

**Goal**: Add commonly-used string filters that are currently missing but used in templates.

| Filter | Complexity | Notes |
|--------|-----------|-------|
| `upper` / `lower` | Trivial | Case conversion |
| `strip` / `rstrip` / `lstrip` | Easy | Optional chars argument |
| `title` / `capitalize` | Easy | Word/title case |
| `split` / `rsplit` | Medium | Maxsplit support optional for now |
| `replace` | Medium | Replace all occurrences |
| `length` (string) | Trivial | Return scalar length |

These would be added as new XSUB wrapper functions or registered via existing `add_filter()` API with Perl callback implementations in Minijinja.pm.

**Status: ✅ COMPLETE** 

Implemented in `lib/Minijinja/Functions.pm`:
- `filter_upper`, `filter_lower` — case conversion
- `filter_strip`, `filter_rstrip`, `filter_lstrip` — whitespace trimming (with optional chars arg)
- `filter_title`, `filter_capitalize` — title case and first-letter capitalization  
- `filter_split`, `filter_rsplit` — split by delimiter with optional maxsplit support
- `filter_replace` — replace all occurrences using `\Q...\E` escaping
- `filter_length_str` — character length

---

### Phase 3: Implement Number Type-Specific Filters

**Goal**: Add numeric helper filters.

| Filter | Type | Description |
|--------|------|-------------|
| `abs` | int/float | Absolute value |
| `int` (on float) | float→int | Cast to integer (truncates toward zero) |
| `float` (on int) | int→float | Convert to floating point |

Simple wrappers, can be implemented directly in XS or as callbacks.

**Status: ✅ COMPLETE** 

Implemented in `lib/Minijinja/Functions.pm`:
- `filter_abs` — absolute value using numeric context (`0 + $val`)
- `filter_int_num` — cast to integer via Perl's `int()`, truncating toward zero  
- `filter_float_num` — force numeric scalar via `0 + $val`

---

### Phase 4: Implement Array Filters

**Goal**: Add array manipulation and inspection filters.

| Filter | Complexity | Notes | Status |
|--------|-----------|-------|--------|
| `first` / `last` | Trivial | Return first/last element or undefined if empty | ✅ Done |
| `list` | Trivial | Shallow copy of arrayref | ✅ Done |  
| `reverse` | Easy | Returns reversed copy | ✅ Done |
| `slice` [start:stop:step] | Medium | Python-style slicing — negative indices support | ✅ Done |
| `sort` [reverse] [attribute] | Harder | With optional attribute access for object arrays; reverse flag only for now | ⏳ Pending |
| `min` / `max` [attribute] | Medium | Find min/max; attribute access deferred initially | ⏳ Pending |
| `join` sep attr | Harder | Join with separator; attribute extraction from objects deferred initially | ⏳ Pending |
| `map` attribute | Harder | Extract attribute values into new array; needs callback integration with object types | ⏳ Pending |
| `selectattr` / `rejectattr` | Complex | Requires test predicate system (see Phase 5) | ⏳ Pending (Phase 5) |

**Status: 🟡 PARTIALLY COMPLETE** (trivial/easy items done, commit `48cef24`)

Implemented in `lib/Minijinja/Functions.pm`:
- `filter_list` — shallow copy via `[ @{$val} ]`
- `filter_first` — returns `$val->[0]` or undef for empty/undefined  
- `filter_last` — pops last element from array copy to avoid mutating input
- `filter_reverse` — reversed copy using Perl's built-in `reverse()`
- `filter_array_slice` — Python-style slicing with full negative index support and optional step parameter

---

### Phase 5: Implement Jinja Test Functions

**Goal**: Register all the `is_*` tests as Perl callbacks that work with Jinja's `{% if val is test_name %}` syntax.

Group by complexity:

**Trivial/Easy** (type checks and comparisons):
- `is_string`, `is_integer`, `is_float`, `is_number`, `is_boolean`, `is_none`, `is_undefined`, `is_defined`, `is_mapping`, `is_iterable`, `is_sequence`, `is_callable`, `is_odd`, `is_even`, `is_false`, `is_true`, `is_lower`, `is_upper`, `is_divisibleby`, `is_in`

**Harder** (comparison operators for use in tests):
- `is_eq`, `is_equalto`, `is_ge`, `is_gt`, `is_lt`, `is_ne`

These would need a unified comparison helper in XS or Perl that handles type coercion (numbers vs strings).

---

### Phase 6: Object Filters and dictsort

**Goal**: Implement object-specific methods.

| Filter | Description |
|--------|-------------|
| `get(key, default)` | Safe hash access |
| `keys()` / `values()` | Return array refs of keys/values |
| `items()` | Already planned in Phase 1 but needs refinement to return tuples/arrays |
| `dictsort(by='key', reverse=False)` | Sorted copy of hash by key or value |

---

### Phase 7: Global Functions Beyond Filters

**Goal**: Add global-level functions that aren't attached to specific types.

| Function | Notes |
|----------|-------|
| `raise_exception(msg)` | Already done in test file — move to Minijinja::Functions |
| `namespace(**kwargs)` | Creates mutable object; may not be needed immediately |
| `strftime_now(fmt)` | Requires time/date handling in Perl |
| `range(start [, stop [, step]])` | Generates arrays like Python's range() |

---

## Recommended Implementation Order

```
Phase 6 → Phase 4 (remaining) → Phase 5 → Phase 7  
```

**Current status**: Phases 1–3 complete ✅, Phase 4 partially complete 🟡 (5/9 array filters implemented).

Remaining work sorted by dependency complexity and user value. The test file should be updated at each phase as new capabilities are tested.

### Suggested Next Steps

1. **Phase 6** (Object filters) — Easy wins: `get`, `keys`, `values` are straightforward hashref operations
2. **Phase 4** remaining — Medium complexity but high utility: `sort`, `min`/`max`, `join`  
3. **Phase 5** (Test functions) — ~30 `is_*` predicates needed for Jinja `{% if val is test_name %}` syntax; requires unified comparison helper
4. **Phase 7** (Global functions) — Lower priority unless specifically needed: `namespace`, `strftime_now`, `range`
