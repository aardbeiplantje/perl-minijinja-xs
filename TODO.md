# Minijinja Perl XS - Testing TODO

## Coverage Analysis

### Filters (Minijinja::Filter — 35 implemented)
All 35 filters have dedicated unit test files. **100% coverage.**

### Functions (Minijinja::Function — 4 implemented)
**BUG FIXED:** `jinja_render()` in JinjaTest.pm referenced non-existent `_startswith_impl` / `_endswith_impl`. Fixed by using `\&Minijinja::Filter::has_prefix` and `\&Minijinja::Filter::has_suffix` directly. Updated expected outputs for affected templates.

### Tests (Minijinja::Test — 27 implemented)

#### ✅ COMPLETED — All 27 now tested!

| Test | Test File | Status |
|------|-----------|--------|
| is_string | t/60-test-is-string.t | ✅ expanded → 5 tests |
| is_integer | t/61-test-is-integer.t | ✅ expanded → 8 tests |
| is_float | t/62-test-is-float.t | ✅ expanded + BUG FIX → 8 tests |
| is_number | t/63-test-is-number.t | ✅ expanded → 8 tests |
| is_boolean | t/64-test-is-boolean.t | ✅ expanded → 7 tests |
| is_callable | t/65-test-is-callable.t | ✅ expanded → 7 tests |
| is_none | t/66-test-is-none.t | ✅ expanded → 7 tests |
| ~~is_undefined~~ | **t/67-test-is-undefined.t** | ✅ NEW — 5 tests comprehensive |
| ~~is_defined~~ | **t/68-test-is-defined.t** | ✅ NEW — 5 tests comprehensive |
| ~~is_mapping~~ | **t/69-test-is-mapping.t** | ✅ NEW — 5 tests comprehensive |
| ~~is_iterable~~ | **t/70-test-is-iterable.t** | ✅ NEW — 5 tests comprehensive |
| ~~is_sequence~~ | **t/71-test-is-sequence.t** | ✅ NEW — 5 tests (fixed expectations) |
| ~~is_lower~~ | **t/72-test-is-lower.t** | ✅ NEW — 5 tests comprehensive |
| ~~is_upper~~ | **t/73-test-is-upper.t** | ✅ NEW — 5 tests comprehensive |
| ~~is_odd~~ | **t/74-test-is-odd.t** | ✅ NEW — 6 tests including negative numbers |
| ~~is_even~~ | **t/75-test-is-even.t** | ✅ NEW — 6 tests (fixed float truncation) |
| ~~is_false~~ | **t/76-test-is-false.t** | ✅ NEW — 5 tests identity check coverage |
| ~~is_true~~ | **t/77-test-is-true.t** | ✅ NEW — 5 tests identity check coverage |
| ~~is_divisibleby~~ | **t/78-test-is-divisibleby.t** | ✅ NEW — 6 tests including zero divisor edge case |
| ~~is_in~~ | **t/79-test-is-in.t** | ✅ NEW — 6 tests array/hash/string haystacks |

---

## TODO List Completed:

### Priority 0: Fix latent bug in JinjaTest.pm ✅ DONE

Replaced references to non-existent `_startswith_impl` / `_endswith_impl` with actual `\&Minijinja::Filter::has_prefix` and `\&Minijinja::Filter::has_suffix`. Updated expected output for `template-01.jinja.test-02.out` which was stale.

### P1a: Create missing test unit files ✅ DONE

Created 13 new comprehensive test files covering all previously untested Minijinja::Test predicates. All 69 new assertions pass through Test::Harness.

### P2: Expand smoke test coverage ✅ DONE

Expanded t/60-t/66 with additional edge cases (negative numbers, empty strings, undef handling, scientific notation). 

**Also discovered and fixed a bug in is_float():**
The `$has_exp = ($val =~ /[eE]/)` check matched ANY string containing 'e' or 'E', not just scientific notation like `1e5`. This caused `'hello'` to incorrectly return as float because it contains 'e'. Fixed by changing to `$has_exp = ($val =~ /[eE]\d/)` which only matches when 'e'/'E' is followed by digits.

---

## Current Stats (COMPLETED)

- **Total test files:** 71 (was 58)
- **Total assertions:** 326 (was 223)  
- **New files created:** 13
- **Bugs found & fixed:** 2 (P0 startwind_impl + P2 is_float regex)
- **All tests passing through Test::Harness:** ✅ yes
