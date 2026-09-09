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

| Phase | Status | Description | Commit |
|-------|--------|-------------|--------|
| **Phase 1** | ✅ Complete | Created `Minijinja::Functions` package with `tojson`, `items`, `startswith`, `endswith` | `166597d` |
| **Phase 2** | ✅ Complete | Added string filters: `upper`, `lower`, `strip`, `rstrip`, `lstrip`, `title`, `capitalize`, `split`, `rsplit`, `replace`, `length_str` | (current) |
| **Phase 3** | ✅ Complete | Added number filters: `abs`, `int`, `float` | (current) |

### ⏳ Pending

| Phase | Description | Complexity |
|-------|-------------|------------|
| **Phase 4** | Array filters (`first`, `last`, `list`, `slice`, `sort`, `reverse`, `min`, `max`, etc.) | Easy to Complex |
| **Phase 5** | Jinja test functions (`is_*` predicates for `{% if val is ... %}`) | Easy to Harder |
| **Phase 6** | Object filters and methods (`get`, `keys`, `values`, `dictsort`) | Easy/Medium |
| **Phase 7** | Global functions (`namespace`, `strftime_now`, `range`) | Varies |

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

| Filter | Complexity | Notes |
|--------|-----------|-------|
| `first` / `last` | Trivial | Return first/last element or undefined if empty |
| `list` | Trivial | Shallow copy of arrayref |
| `slice` [start:stop:step] | Medium | Python-style slicing — negative indices support optional initially |
| `sort` [reverse] [attribute] | Harder | With optional attribute access for object arrays; reverse flag only for now |
| `reverse` | Easy | Returns reversed copy |
| `min` / `max` [attribute] | Medium | Find min/max; attribute access deferred initially |
| `join` sep attr | Harder | Join with separator; attribute extraction from objects deferred initially |
| `map` attribute | Harder | Extract attribute values into new array; needs callback integration with object types |
| `selectattr` / `rejectattr` | Complex | Requires test predicate system (see Phase 5) |

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
Phase 6 → Phase 4 (trivial first) → Phase 5 → Phase 7
```

**Note**: Phases 1, 2, and 3 are complete. Remaining phases ordered by dependency complexity and user value. The test file should be updated at each phase as new capabilities are tested.
