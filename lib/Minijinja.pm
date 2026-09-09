package Minijinja;

use strict; use warnings;

our $VERSION = "0.1.0";

use Exporter 'import';

our @EXPORT_OK = qw(
    new

    add_template remove_template clear_templates

    render_template render_str eval_expr

    add_global

    add_filter add_function add_test

    set_debug set_fuel clear_fuel set_recursion_limit
    set_trim_blocks get_trim_blocks
    set_lstrip_blocks get_lstrip_blocks
    set_keep_trailing_newline get_keep_trailing_newline
    set_undefined_behavior get_undefined_behavior

    apply_syntax

    set_loader set_auto_escape set_path_join

    error_exists error_detail error_debug_info
    error_kind error_line error_template_name error_print

    register_all_functions

    filter_tojson
    filter_items
    func_startswith
    func_endswith

    filter_has_prefix filter_has_suffix

    filter_upper filter_lower
    filter_strip filter_rstrip filter_lstrip
    filter_title filter_capitalize
    filter_split filter_rsplit
    filter_replace
    filter_length_str

    filter_abs
    filter_int_num filter_float_num

    filter_array_slice filter_first filter_last
    filter_list filter_sort filter_reverse
    filter_join filter_map
    filter_min filter_max

    filter_get filter_keys filter_values filter_dictsort

    func_is_string func_is_integer func_is_float func_is_number
    func_is_boolean func_is_callable func_is_none func_is_undefined func_is_defined
    func_is_mapping func_is_iterable func_is_sequence
    func_is_lower func_is_upper
    func_is_odd func_is_even
    func_is_false func_is_true
    func_is_divisibleby func_is_in
    func_is_eq func_is_equalto func_is_ne func_is_lt func_is_le func_is_gt func_is_ge
    test_predicate_to_bool

    filter_selectattr filter_rejectattr filter_select filter_reject


    func_raise_exception func_range filter_strftime_now func_namespace
);

use XSLoader;
XSLoader::load('Minijinja', $VERSION);

sub new {
    my (%opts) = @_;
    if (keys %opts) {
        return M_new(\%opts);
    } else {
        return M_new();
    }
}

# Register all functions from Minijinja::Functions onto an environment in one call.
# Usage: use Minijinja qw(new register_all_functions); my $env = new(); register_all_functions($env);
sub register_all_functions {
    my ($env) = @_;
    my %map = exportable_map();
    while (my ($name, $type) = each %map) {
        if ($type eq 'filter')      { add_filter($env, $name, \&{$name}); }
        elsif ($type eq 'function') { add_function($env, $name, \&{$name}); }
        elsif ($type eq 'test')     { add_test($env, $name, \&{$name}); }
    }
}

# POSIX::strftime for strftime_now (core module)
use POSIX qw(strftime);

# Pre-create shared JSON encoder instance for reuse in callbacks.
# Creating new instances per call causes issues when called from XS context.
my $json_encoder = undef;

sub _get_json_encoder {
    unless ($json_encoder) {
        eval { require JSON::PP };
        if ($@) {
            die "Minijinja::Functions requires JSON::PP: $@";
        }
        $json_encoder = JSON::PP->new->utf8->canonical;
    }
    return $json_encoder;
}

# tojson filter — matches Python minijinja's |tojson behavior exactly.
# Escapes < > & ' as unicode escapes for XSS safety (matches minijinja).
sub filter_tojson {
    my ($val) = @_;

    # Use pre-created shared encoder (must NOT create new instance per call)
    my $encoded = _get_json_encoder()->encode($val);

    # Escape HTML-sensitive chars inside JSON string values only.
    # Match "..." quoted strings and replace < > & with unicode escapes.
    $encoded =~ s/"([^"\\]*(?:\\.[^"\\]*)*)"/
        my $s = $1;
        $s =~ s{<}{\\u003c}g;
        $s =~ s{>}{\\u003e}g;
        $s =~ s{&}{\\u0026}g;
        $s =~ s{'}{\\u0027}g;
        "\"$s\"";
    /ge;

    return $encoded;
}

# items — Perl equivalent of Python dict.items() returning sorted [key, value] pairs.
# Returns empty list for undefined/array inputs, tries JSON decode for strings.
sub filter_items {
    my ($value) = @_;

    if (!defined($value)) {
        return [];
    } elsif (ref($value) eq 'HASH') {
        # hashref → list of [key, value] pairs (mirrors dict.items())
        return [map { [$_, $value->{$_}] } sort {$a cmp $b} keys %{$value}];
    } elsif (ref($value) eq 'ARRAY') {
        # arrayref is not a mapping — return empty list like safe_items for non-dict iterables
        return [];
    } else {
        # string: try JSON decode to see if it's a dict-like object
        my $decoded = eval { _get_json_encoder()->decode($value); };
        if ($@ || ref($decoded) ne 'HASH') {
            return [];
        }
        return [map { [$_, $decoded->{$_}] } sort {$a cmp $b} keys %{$decoded}];
    }
}

# startswith — identical lambda semantics to llama.cpp jinja parser.
# Checks if the given string starts with the specified prefix.
sub func_startswith {
    my ($s, $prefix) = @_;
    return !defined($s) || !defined($prefix) ? 0 : substr($s, 0, length($prefix)) eq $prefix;
}

# endswith — identical lambda semantics to llama.cpp jinja parser.
# Checks if the given string ends with the specified suffix.
sub func_endswith {
    my ($s, $suffix) = @_;
    return !defined($s) || !defined($suffix) ? 0 : length($s) >= length($suffix)
           && substr($s, -length($suffix)) eq $suffix;
}

# has_prefix — filter version of startswith (same logic)
sub filter_has_prefix {
    my ($s, $prefix) = @_;
    return !defined($s) || !defined($prefix) ? 0 : substr($s, 0, length($prefix)) eq $prefix;
}

# has_suffix — filter version of endswith (same logic)
sub filter_has_suffix {
    my ($s, $suffix) = @_;
    return !defined($s) || !defined($suffix) ? 0 : length($s) >= length($suffix)
           && substr($s, -length($suffix)) eq $suffix;
}

# --- String Filters ---

# upper — convert string to uppercase (matches Python's str.upper())
sub filter_upper {
    my ($val) = @_;
    return "" unless defined($val);
    uc("$val");
}

# lower — convert string to lowercase (matches Python's str.lower())
sub filter_lower {
    my ($val) = @_;
    return "" unless defined($val);
    lc("$val");
}

# strip — remove whitespace from both ends of string (optional chars arg)
sub filter_strip {
    my ($val, $chars) = @_;
    return "" unless defined($val);
    my $s = "$val";
    if (defined($chars)) {
        $s =~ s/^[\Q$chars\E]+//;
        $s =~ s/[\Q$chars\E]+$//;
    } else {
        $s =~ s/^\s+|\s+$//g;
    }
    return $s;
}

# rstrip — remove whitespace from right end of string (optional chars arg)
sub filter_rstrip {
    my ($val, $chars) = @_;
    return "" unless defined($val);
    my $s = "$val";
    if (defined($chars)) {
        $s =~ s/[\Q$chars\E]+$//;
    } else {
        $s =~ s/\s+$//;
    }
    return $s;
}

# lstrip — remove whitespace from left end of string (optional chars arg)
sub filter_lstrip {
    my ($val, $chars) = @_;
    return "" unless defined($val);
    my $s = "$val";
    if (defined($chars)) {
        $s =~ s/^[\Q$chars\E]+//;
    } else {
        $s =~ s/^\s+//;
    }
    return $s;
}

# title — convert to title case: first letter of each word uppercase, rest lowercase
sub filter_title {
    my ($val) = @_;
    return "" unless defined($val);
    my $s = "$val";
    $s =~ s/(^\w|\s+\w)(\w*)/uc($1).lc($2)/ge;
    return $s;
}

# capitalize — capitalize first letter, make rest lowercase
sub filter_capitalize {
    my ($val) = @_;
    return "" unless defined($val);
    my $s = "$val";
    $s =~ s/^(.)(.*)/uc($1) . lc($2)/ge;
    return $s;
}

# split — split string by delimiter with optional maxsplit (count from left)
sub filter_split {
    my ($val, $sep, $maxsplit) = @_;
    return [] unless defined($val);
    my $s = "$val";

    if (!defined($sep)) {
        # No separator: split on whitespace, skip empty strings
        my @parts = grep { $_ ne '' } split(/\s+/, $s);
        if (defined($maxsplit) && $maxsplit > 0 && @parts > $maxsplit) {
            return [splice(@parts, 0, $maxsplit + 1)];
        }
        return \@parts;
    } else {
        # Split on specific separator using \Q...\E for regex safety
        my @parts = split(/\Q$sep\E/, $s);
        if (defined($maxsplit) && $maxsplit > 0 && @parts > $maxsplit) {
            return [splice(@parts, 0, $maxsplit + 1)];
        }
        return \@parts;
    }
}

# rsplit — split string from the right side with optional maxsplit
sub filter_rsplit {
    my ($val, $sep, $maxsplit) = @_;
    return [] unless defined($val);
    my $s = "$val";

    if (!defined($sep)) {
        # No separator: split on whitespace, skip empty strings
        my @parts = grep { $_ ne '' } split(/\s+/, $s);
        if (defined($maxsplit) && $maxsplit > 0 && @parts > $maxsplit) {
            return [splice(@parts, -$maxsplit - 1)];
        }
        return \@parts;
    } else {
        # Split on specific separator from the right side
        if (defined($maxsplit) && $maxsplit > 0) {
            my @result;
            while ($maxsplit > 0 && index($s, $sep) >= 0) {
                my $pos = rindex($s, $sep);
                unshift @result, substr($s, $pos + length($sep));
                $s = substr($s, 0, $pos);
                $maxsplit--;
            }
            unshift @result, $s;
            return \@result;
        } else {
            my @parts = split(/\Q$sep\E/, $s);
            return \@parts;
        }
    }
}

# replace — replace all occurrences of old with new in string
sub filter_replace {
    my ($val, $old, $new) = @_;
    return "" unless defined($val);
    my $s = "$val";
    $s =~ s/\Q$old\E/$new/g;
    return $s;
}

# length_str — return character length of string (Unicode-aware)
sub filter_length_str {
    my ($val) = @_;
    return 0 unless defined($val);
    length("$val");
}

# --- Number Filters ---

# abs — absolute value (works on int or float, matches Python's abs())
sub filter_abs {
    my ($val) = @_;
    return $val unless defined($val);
    my $n = 0 + $val;  # force numeric context
    $n < 0 ? -$n : $n;
}

# int (on float) — cast number to integer (truncates toward zero, like Python's int())
sub filter_int_num {
    my ($val) = @_;
    return "" unless defined($val);
    int(0 + $val);  # force numeric, then truncate to int
}

# float (on int) — convert to floating point (no-op if already float)
sub filter_float_num {
    my ($val) = @_;
    return "" unless defined($val);
    0 + $val;  # force numeric scalar (float)
}

# --- Array Filters ---

# list — shallow copy of arrayref (mirrors Jinja's |list filter)
sub filter_list {
    my ($val) = @_;
    return [] unless defined($val) && ref($val) eq 'ARRAY';
    [@$val];
}

# first — get first element or undefined if empty/undefined
sub filter_first {
    my ($val) = @_;
    return undef unless defined($val) && ref($val) eq 'ARRAY';
    return scalar(@{$val}) > 0 ? $val->[0] : undef;
}

# last — get last element or undefined if empty/undefined
sub filter_last {
    my ($val) = @_;
    return undef unless defined($val) && ref($val) eq 'ARRAY';
    my @arr = @$val;
    return pop @arr;
}

# reverse — returns reversed copy of array
sub filter_reverse {
    my ($val) = @_;
    return [] unless defined($val) && ref($val) eq 'ARRAY';
    [reverse @{$val}];
}

# slice — Python-style [start:stop:step] array slicing
sub filter_array_slice {
    my ($val, $start, $stop, $step) = @_;
    return [] unless defined($val) && ref($val) eq 'ARRAY';

    my @arr = @$val;
    my $len = scalar @arr;
    return [] if $len == 0;

    # Handle default values for optional parameters
    $step = 1 unless defined($step);
    return [] if $step <= 0;

    # Calculate start index (handle negative indices)
    my $s;
    if (!defined($start)) {
        $s = 0;
    } elsif ($start < 0) {
        $s = ($len + $start) > 0 ? ($len + $start) : 0;
    } else {
        $s = $start >= $len ? $len : $start;
    }

    # Calculate stop index (handle negative indices and undef)
    my $e;
    if (!defined($stop)) {
        $e = $len;
    } elsif ($stop < 0) {
        $e = ($len + $stop) >= 0 ? ($len + $stop) : 0;
    } else {
        $e = $stop > $len ? $len : $stop;
    }

    # Extract elements with step
    my @result;
    for (my $i = $s; $i < $e && $i < $len; $i += $step) {
        push @result, $arr[$i];
    }

    return \@result;
}

# sort — sorted copy of array with optional reverse and attribute access
sub filter_sort {
    my ($val, $reverse, $attribute) = @_;
    return [] unless defined($val) && ref($val) eq 'ARRAY';

    my @arr = @$val;

    if (@arr == 0) {
        return [];
    }

    my @sorted;

    if (defined($attribute)) {
        # Sort by attribute value extracted from each element
        @sorted = sort {
            my $a_val = _extract_attr($a, $attribute);
            my $b_val = _extract_attr($b, $attribute);
            my $cmp = _compare_values($a_val, $b_val);
            $reverse ? -$cmp : $cmp;
        } @arr;
    } else {
        # Sort elements directly with smart comparison
        @sorted = sort {
            my $cmp = _compare_values($a, $b);
            $reverse ? -$cmp : $cmp;
        } @arr;
    }

    return \@sorted;
}

# min — find minimum value in array with optional attribute access
sub filter_min {
    my ($val, $attribute) = @_;

    return undef unless defined($val) && ref($val) eq 'ARRAY';

    my @arr = grep { defined($_) && $_ ne '' } @$val;
    return undef if @arr == 0;

    if (@arr == 1) {
        return defined($attribute) ? _extract_attr($arr[0], $attribute) : $arr[0];
    }

    if (defined($attribute)) {
        my @with_vals = map { [$_, _extract_attr($_, $attribute)] } @arr;
        my $min_pair = shift @with_vals;
        for my $pair (@with_vals) {
            if (_compare_values($pair->[1], $min_pair->[1]) < 0) {
                $min_pair = $pair;
            }
        }
        return $min_pair->[1];
    } else {
        my $min_val = $arr[0];
        for my $item (@arr[1..$#arr]) {
            if (_compare_values($item, $min_val) < 0) {
                $min_val = $item;
            }
        }
        return $min_val;
    }
}

# max — find maximum value in array with optional attribute access
sub filter_max {
    my ($val, $attribute) = @_;

    return undef unless defined($val) && ref($val) eq 'ARRAY';

    my @arr = grep { defined($_) && $_ ne '' } @$val;
    return undef if @arr == 0;

    if (@arr == 1) {
        return defined($attribute) ? _extract_attr($arr[0], $attribute) : $arr[0];
    }

    if (defined($attribute)) {
        my @with_vals = map { [$_, _extract_attr($_, $attribute)] } @arr;
        my $max_pair = shift @with_vals;
        for my $pair (@with_vals) {
            if (_compare_values($pair->[1], $max_pair->[1]) > 0) {
                $max_pair = $pair;
            }
        }
        return $max_pair->[1];
    } else {
        my $max_val = $arr[0];
        for my $item (@arr[1..$#arr]) {
            if (_compare_values($item, $max_val) > 0) {
                $max_val = $item;
            }
        }
        return $max_val;
    }
}

# join — join array elements with separator, optional attribute extraction
sub filter_join {
    my ($val, $separator, $attribute) = @_;

    return '' unless defined($val);

    my @items;

    if (ref($val) eq 'ARRAY') {
        @items = @$val;
    } elsif (defined($val) && ref($val) ne 'HASH' && ref($val) ne 'CODE') {
        @items = ($val);
    } else {
        return '';
    }

    # Filter out undefined values
    @items = grep { defined($_) } @items;

    if (!defined($attribute)) {
        # Convert all items to strings and join
        @items = map { "$_" } @items;
        return join($separator || '', @items);
    } else {
        # Extract attribute from each item and join
        @items = map { _extract_attr($_, $attribute) // '' } @items;
        return join($separator || '', @items);
    }
}

# map — extract attribute values into new array
sub filter_map {
    my ($val, $attribute) = @_;

    return [] unless defined($val) && ref($val) eq 'ARRAY';

    my @result;

    for my $item (@$val) {
        if (!defined($item)) {
            push @result, undef;
        } else {
            push @result, _extract_attr($item, $attribute);
        }
    }

    return \@result;
}

# --- Helper functions (internal) ---

# extract_attr — extract attribute value from object/hashref/scalar
sub _extract_attr {
    my ($obj, $attr) = @_;

    return $obj unless defined($obj) && $attr;

    if (ref($obj) eq 'HASH') {
        return exists($obj->{$attr}) ? $obj->{$attr} : undef;
    } elsif (ref($obj) eq 'ARRAY') {
        # Try numeric index first
        if ($attr =~ /^-?\d+$/) {
            my $idx = int($attr);
            return $idx >= 0 && $idx < scalar(@{$obj}) ? $obj->[$idx] : undef;
        }
        return undef;
    } else {
        # Scalar: try to treat as string key (unlikely but handle gracefully)
        return undef;
    }
}

# compare_values — smart comparison between two values for sort/min/max
sub _compare_values {
    my ($a, $b) = @_;

    # Handle undefined values
    if (!defined($a) && !defined($b)) { return 0; }
    if (!defined($a)) { return 1; }   # undef sorts last
    if (!defined($b)) { return -1; }

    # Force scalar context
    my $sa = "$a";
    my $sb = "$b";

    # If both look like numbers, do numeric comparison
    if ($sa =~ /^-?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?$/ && $sb =~ /^-?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?$/) {
        return ($sa + 0) <=> ($sb + 0);
    }

    # String comparison
    return $sa cmp $sb;
}

# --- Test Functions (Phase 5) ---

# Helper: determine if a value is "undefined" in Jinja terms (Perl undef or no ref)
sub _is_undefined {
    my ($val) = @_;
    return !defined($val) || $val eq 'UNDEFINED';
}

# Helper: type name for debugging/testing (maps to minijinja types)
sub _type_name {
    my ($val) = @_;
    return 'undefined' unless defined($val);
    return ref($val) if ref($val) eq 'HASH' || ref($val) eq 'ARRAY' || ref($val) eq 'CODE';
    my $s = "$val";
    if ($s =~ /^-?(?:\d+)(?:\.0)?$/ && $s !~ /\./) {
        return 'integer';
    } elsif ($s =~ /^-?(?:\d+\.\d*|\.\d+)(?:[eE][+-]?\d+)?$/) {
        return 'float';
    } else {
        return 'string';
    }
}

# is_string — check if value is a string (not undefined, not array/hashref/coderef)
sub func_is_string {
    my ($val) = @_;
    return 0 if _is_undefined($val);
    return ref($val) ? 0 : 1;  # scalar string = no ref
}

# is_integer — check if value is an integer (no decimal point in string form)
sub func_is_integer {
    my ($val) = @_;
    return 0 if _is_undefined($val);
    my $s = "$val";
    if (ref($val)) { return 0; }  # hashref/arrayref/coderef are not integers
    return ($s =~ /^-?\d+$/) ? 1 : 0;
}

# is_float — check if value is a float (has decimal or exponent)
sub func_is_float {
    my ($val) = @_;
    return 0 if _is_undefined($val);
    my $s = "$val";
    if (ref($val)) { return 0; }
    return ($s =~ /^-?(?:\d+\.\d*|\.\d+)(?:[eE][+-]?\d+)?$/ && $s !~ /^-?(\d+)\.0$/ || $s =~ /[eE]/) ? 1 : 0;
}

# is_number — check if value is any numeric type (int or float)
sub func_is_number {
    my ($val) = @_;
    return 0 if _is_undefined($val);
    my $s = "$val";
    if (ref($val)) { return 0; }
    return ($s =~ /^-?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?$/) ? 1 : 0;
}

# is_boolean — check if value is a boolean (string "true" or "false")
sub func_is_boolean {
    my ($val) = @_;
    return 0 unless defined($val);
    my $s = "$val";
    return ($s eq 'true' || $s eq 'false') ? 1 : 0;
}

# is_callable — check if value is callable (coderef)
sub func_is_callable {
    my ($val) = @_;
    return ref($val) eq 'CODE' ? 1 : 0;
}

# is_none — check if value is None/null/undefined
sub func_is_none {
    my ($val) = @_;
    return 0 unless defined($val);
    my $s = "$val";
    return ($s eq 'None' || $s eq '' && !ref($val)) ? 1 : 0;
}

# is_undefined — check if value is undefined
sub func_is_undefined {
    my ($val) = @_;
    return _is_undefined($val) ? 1 : 0;
}

# is_defined — check if value is defined (opposite of is_undefined)
sub func_is_defined {
    my ($val) = @_;
    return _is_undefined($val) ? 0 : 1;
}

# is_mapping — check if value is a mapping (hashref)
sub func_is_mapping {
    my ($val) = @_;
    return ref($val) eq 'HASH' ? 1 : 0;
}

# is_iterable — check if value can be iterated over (arrayref, string, hashref)
sub func_is_iterable {
    my ($val) = @_;
    return 0 if _is_undefined($val);
    return ref($val) ? (ref($val) eq 'ARRAY' || ref($val) eq 'HASH') : 1;  # strings are iterable too
}

# is_sequence — check if value is a sequence (arrayref or string)
sub func_is_sequence {
    my ($val) = @_;
    return 0 if _is_undefined($val);
    return ref($val) ? (ref($val) eq 'ARRAY' || !ref($val)) : 0;  # scalars and arrays are sequences
}

# is_lower — check if all cased characters in string are lowercase
sub func_is_lower {
    my ($val) = @_;
    return 0 unless defined($val) && !ref($val);
    my $s = "$val";
    return 0 unless $s =~ /[a-zA-Z]/;  # must have at least one cased char
    return ($s eq lc($s)) ? 1 : 0;
}

# is_upper — check if all cased characters in string are uppercase
sub func_is_upper {
    my ($val) = @_;
    return 0 unless defined($val) && !ref($val);
    my $s = "$val";
    return 0 unless $s =~ /[a-zA-Z]/;  # must have at least one cased char
    return ($s eq uc($s)) ? 1 : 0;
}

# is_odd — check if integer is odd
sub func_is_odd {
    my ($val) = @_;
    return 0 if _is_undefined($val);
    my $n = int(0 + $val);
    return ($n % 2 != 0) ? 1 : 0;
}

# is_even — check if integer is even
sub func_is_even {
    my ($val) = @_;
    return 0 if _is_undefined($val);
    my $n = int(0 + $val);
    return ($n % 2 == 0) ? 1 : 0;
}

# is_false — identity check against False
sub func_is_false {
    my ($val) = @_;
    my $s = "$val";
    return ($s eq 'false' || $s eq 'False') ? 1 : 0;
}

# is_true — identity check against True
sub func_is_true {
    my ($val) = @_;
    my $s = "$val";
    return ($s eq 'true' || $s eq 'True') ? 1 : 0;
}

# is_divisibleby — check if number is divisible by divisor (mod == 0)
sub func_is_divisibleby {
    my ($val, $divisor) = @_;
    return 0 if _is_undefined($val) || !defined($divisor);
    if ($divisor == 0) { return 0; }  # division by zero not allowed
    my $n = 0 + $val;
    return ($n % $divisor == 0) ? 1 : 0;
}

# is_in — membership test: needle in haystack (arrayref, string, or hashref keys)
sub func_is_in {
    my ($needle, $haystack) = @_;
    return 0 if _is_undefined($needle) || !defined($haystack);

    if (ref($haystack) eq 'ARRAY') {
        for my $item (@{$haystack}) {
            return 1 if "$needle" eq "$item";
        }
        return 0;
    } elsif (ref($haystack) eq 'HASH') {
        return exists($haystack->{$needle}) ? 1 : 0;
    } elsif (!ref($haystack)) {
        # String membership check
        return index("$haystack", "$needle") >= 0 ? 1 : 0;
    } else {
        return 0;
    }
}

# Comparison-based tests

# Helper: comparison operator wrapper for Jinja tests
# Accepts two values and a Perl comparison function
sub _compare_test {
    my ($a, $b, $cmp_func) = @_;
    return 0 if _is_undefined($a) || _is_undefined($b);

    # Force numeric context for numbers, string otherwise
    my $sa = "$a";
    my $sb = "$b";

    # If both are numeric strings, compare numerically
    if ($sa =~ /^-?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?$/ && $sb =~ /^-?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?$/) {
        return $cmp_func->(0 + $sa, 0 + $sb);
    }

    # String comparison
    return $cmp_func->($sa, $sb);
}

# is_eq / is_equalto — equality (==)
sub func_is_eq {
    my ($a, $b) = @_;
    return _compare_test($a, $b, sub { $_[0] eq $_[1] ? 1 : 0 });
}

sub func_is_equalto {
    my ($a, $b) = @_;
    return func_is_eq($a, $b);
}

# is_ne — not equal (!=)
sub func_is_ne {
    my ($a, $b) = @_;
    return _compare_test($a, $b, sub { $_[0] ne $_[1] ? 1 : 0 });
}

# is_lt — less than (<)
sub func_is_lt {
    my ($a, $b) = @_;
    return _compare_test($a, $b, sub { $_[0] < $_[1] ? 1 : 0 });
}

# is_le — less than or equal (<=)
sub func_is_le {
    my ($a, $b) = @_;
    return _compare_test($a, $b, sub { $_[0] <= $_[1] ? 1 : 0 });
}

# is_gt — greater than (>)
sub func_is_gt {
    my ($a, $b) = @_;
    return _compare_test($a, $b, sub { $_[0] > $_[1] ? 1 : 0 });
}

# is_ge — greater than or equal (>=)
sub func_is_ge {
    my ($a, $b) = @_;
    return _compare_test($a, $b, sub { $_[0] >= $_[1] ? 1 : 0 });
}

# test_predicate_to_bool — convert any value to a boolean (truthy/falsy like Jinja)
# Used internally by select/reject when passing predicates from templates
sub test_predicate_to_bool {
    my ($val) = @_;
    return 0 if _is_undefined($val);
    if (!defined($val) || $val eq '' || $val eq 'false' || $val eq 'False' || $val eq 'None') {
        return 0;
    }
    return 1;
}

# --- Select/Reject Filters (Phase 5 continuation) ---

# Helper: evaluate a test predicate on a single item for selectattr/rejectattr/select/reject
sub _evaluate_select_pred {
    my ($item, $attribute, $test_name, $args) = @_;

    if (defined($attribute)) {
        # Extract attribute value first
        my $attr_val = _extract_attr($item, $attribute);
        # Check if the test name exists and call it with attr_val + args
        my $test_fn = "func_$test_name";
        if (can_call_test($test_fn)) {
            return $test_fn->($attr_val, @$args);
        } elsif ($test_name eq 'defined') {
            return defined($attr_val) && !ref($attr_val) ? 1 : 0;
        } else {
            return defined($attr_val) ? 1 : 0;
        }
    } else {
        # Test applied to the item directly
        my $test_fn = "func_$test_name";
        if (can_call_test($test_fn)) {
            return $test_fn->($item, @$args);
        } elsif ($test_name eq 'defined') {
            return defined($item) ? 1 : 0;
        } else {
            return defined($item) ? 1 : 0;
        }
    }
}

# Helper: check if a subroutine can be called (exists and is coderef)
sub can_call_test {
    my ($name) = @_;
    return defined(\&{$name}) && ref(\&{$name}) eq 'CODE';
}

# selectattr — filter array items by attribute value/test predicate
# Usage: {{ items | selectattr('active') }} - items where active is truthy
#        {{ items | selectattr('score', '==', 5) }} - items where score == 5
sub filter_selectattr {
    my ($val, $attribute, $test_name, @rest_args) = @_;

    return [] unless defined($val) && ref($val) eq 'ARRAY';

    my @result;

    for my $item (@$val) {
        next unless defined($item);

        my $matched = 0;

        if (!defined($test_name)) {
            # Simple truthiness check on the attribute
            if (defined($attribute)) {
                my $attr_val = _extract_attr($item, $attribute);
                $matched = test_predicate_to_bool($attr_val);
            } else {
                $matched = test_predicate_to_bool($item);
            }
        } else {
            # Test predicate with optional arguments
            my @args = @rest_args;

            # Handle string comparison operators as tests (like 'eq', '==', '>', etc.)
            if ($test_name =~ /^(eq|ne|lt|le|gt|ge|==$|!=|<\d*|<=\d*>|\>=)$/) {
                my $op_map = {
                    'eq' => sub { "$_[0]" eq "$_[1]" ? 1 : 0 },
                    '==' => sub { "$_[0]" eq "$_[1]" ? 1 : 0 },
                    'ne' => sub { "$_[0]" ne "$_[1]" ? 1 : 0 },
                    '!=' => sub { "$_[0]" ne "$_[1]" ? 1 : 0 },
                    'lt' => sub { "$_[0]" < $_[1] ? 1 : 0 },
                    '<' => sub { "$_[0]" < $_[1] ? 1 : 0 },
                    'le' => sub { "$_[0]" <= $_[1] ? 1 : 0 },
                    '<=' => sub { "$_[0]" <= $_[1] ? 1 : 0 },
                    'gt' => sub { "$_[0]" > $_[1] ? 1 : 0 },
                    '>' => sub { "$_[0]" > $_[1] ? 1 : 0 },
                    'ge' => sub { "$_[0]" >= $_[1] ? 1 : 0 },
                    '>=' => sub { "$_[0]" >= $_[1] ? 1 : 0 },
                };

                if (defined($op_map->{$test_name})) {
                    my $op = $op_map->{$test_name};
                    my @cmp_args = map { $_ } @args;
                    if (@cmp_args) {
                        $matched = ($attribute) ? $op->(_extract_attr($item, $attribute), $cmp_args[0]) : $op->($item, $cmp_args[0]);
                    } else {
                        # No comparison value provided — skip this item
                        next;
                    }
                } else {
                    $matched = _evaluate_select_pred($item, $attribute, $test_name, \@args);
                }
            } else {
                $matched = _evaluate_select_pred($item, $attribute, $test_name, \@args);
            }
        }

        if ($matched) {
            push @result, defined($attribute) ? _extract_attr($item, $attribute) : $item;
        }
    }

    return \@result;
}

# rejectattr — filter out array items by attribute value/test predicate (inverse of selectattr)
# Usage: {{ items | rejectattr('active') }} - items where active is falsy
sub filter_rejectattr {
    my ($val, $attribute, $test_name, @rest_args) = @_;

    return [] unless defined($val) && ref($val) eq 'ARRAY';

    my @result;

    for my $item (@$val) {
        next unless defined($item);

        my $matched = 0;

        if (!defined($test_name)) {
            # Simple truthiness check on the attribute
            if (defined($attribute)) {
                my $attr_val = _extract_attr($item, $attribute);
                $matched = test_predicate_to_bool($attr_val);
            } else {
                $matched = test_predicate_to_bool($item);
            }
        } else {
            # Test predicate with optional arguments
            my @args = @rest_args;

            # Handle string comparison operators as tests (like 'eq', '==', '>', etc.)
            if ($test_name =~ /^(eq|ne|lt|le|gt|ge|==$|!=|<\d*|<=\d*>|\>=)$/) {
                my $op_map = {
                    'eq' => sub { "$_[0]" eq "$_[1]" ? 1 : 0 },
                    '==' => sub { "$_[0]" eq "$_[1]" ? 1 : 0 },
                    'ne' => sub { "$_[0]" ne "$_[1]" ? 1 : 0 },
                    '!=' => sub { "$_[0]" ne "$_[1]" ? 1 : 0 },
                    'lt' => sub { "$_[0]" < $_[1] ? 1 : 0 },
                    '<' => sub { "$_[0]" < $_[1] ? 1 : 0 },
                    'le' => sub { "$_[0]" <= $_[1] ? 1 : 0 },
                    '<=' => sub { "$_[0]" <= $_[1] ? 1 : 0 },
                    'gt' => sub { "$_[0]" > $_[1] ? 1 : 0 },
                    '>' => sub { "$_[0]" > $_[1] ? 1 : 0 },
                    'ge' => sub { "$_[0]" >= $_[1] ? 1 : 0 },
                    '>=' => sub { "$_[0]" >= $_[1] ? 1 : 0 },
                };

                if (defined($op_map->{$test_name})) {
                    my $op = $op_map->{$test_name};
                    my @cmp_args = map { $_ } @args;
                    if (@cmp_args) {
                        $matched = ($attribute) ? $op->(_extract_attr($item, $attribute), $cmp_args[0]) : $op->($item, $cmp_args[0]);
                    } else {
                        next;
                    }
                } else {
                    $matched = _evaluate_select_pred($item, $attribute, $test_name, \@args);
                }
            } else {
                $matched = _evaluate_select_pred($item, $attribute, $test_name, \@args);
            }
        }

        # Reject items that matched the predicate
        unless ($matched) {
            push @result, defined($attribute) ? _extract_attr($item, $attribute) : $item;
        }
    }

    return \@result;
}

# select — filter array items by test predicate (no attribute access)
# Usage: {{ items | select('odd') }} - odd numbers only
#        {{ items | select('equalto', 5) }} - items equal to 5
sub filter_select {
    my ($val, $test_name, @rest_args) = @_;

    return [] unless defined($val) && ref($val) eq 'ARRAY';

    my @result;

    for my $item (@$val) {
        next unless defined($item);

        my $matched = 0;

        if (!defined($test_name)) {
            # Simple truthiness check on the item
            $matched = test_predicate_to_bool($item);
        } else {
            my @args = @rest_args;

            # Handle string comparison operators as tests
            if ($test_name =~ /^(eq|ne|lt|le|gt|ge|==$|!=|<\d*|<=\d*>|\>=)$/) {
                my $op_map = {
                    'eq' => sub { "$_[0]" eq "$_[1]" ? 1 : 0 },
                    '==' => sub { "$_[0]" eq "$_[1]" ? 1 : 0 },
                    'ne' => sub { "$_[0]" ne "$_[1]" ? 1 : 0 },
                    '!=' => sub { "$_[0]" ne "$_[1]" ? 1 : 0 },
                    'lt' => sub { "$_[0]" < $_[1] ? 1 : 0 },
                    '<' => sub { "$_[0]" < $_[1] ? 1 : 0 },
                    'le' => sub { "$_[0]" <= $_[1] ? 1 : 0 },
                    '<=' => sub { "$_[0]" <= $_[1] ? 1 : 0 },
                    'gt' => sub { "$_[0]" > $_[1] ? 1 : 0 },
                    '>' => sub { "$_[0]" > $_[1] ? 1 : 0 },
                    'ge' => sub { "$_[0]" >= $_[1] ? 1 : 0 },
                    '>=' => sub { "$_[0]" >= $_[1] ? 1 : 0 },
                };

                if (defined($op_map->{$test_name})) {
                    my $op = $op_map->{$test_name};
                    my @cmp_args = map { $_ } @args;
                    if (@cmp_args) {
                        $matched = $op->($item, $cmp_args[0]);
                    } else {
                        next;
                    }
                } else {
                    # Use registered test function
                    my $test_fn = "func_$test_name";
                    if (can_call_test($test_fn)) {
                        $matched = $test_fn->($item, @args);
                    } elsif ($test_name eq 'defined') {
                        $matched = defined($item) ? 1 : 0;
                    } else {
                        $matched = test_predicate_to_bool($item);
                    }
                }
            } else {
                # Use registered test function (is_string, is_odd, etc.)
                my $test_fn = "func_$test_name";
                if (can_call_test($test_fn)) {
                    $matched = $test_fn->($item, @args);
                } elsif ($test_name eq 'defined') {
                    $matched = defined($item) ? 1 : 0;
                } else {
                    $matched = test_predicate_to_bool($item);
                }
            }
        }

        if ($matched) {
            push @result, $item;
        }
    }

    return \@result;
}

# reject — filter out array items by test predicate (inverse of select)
# Usage: {{ items | reject('odd') }} - even numbers only
sub filter_reject {
    my ($val, $test_name, @rest_args) = @_;

    return [] unless defined($val) && ref($val) eq 'ARRAY';

    my @result;

    for my $item (@$val) {
        next unless defined($item);

        my $matched = 0;

        if (!defined($test_name)) {
            # Simple truthiness check on the item
            $matched = test_predicate_to_bool($item);
        } else {
            my @args = @rest_args;

            # Handle string comparison operators as tests
            if ($test_name =~ /^(eq|ne|lt|le|gt|ge|==$|!=|<\d*|<=\d*>|\>=)$/) {
                my $op_map = {
                    'eq' => sub { "$_[0]" eq "$_[1]" ? 1 : 0 },
                    '==' => sub { "$_[0]" eq "$_[1]" ? 1 : 0 },
                    'ne' => sub { "$_[0]" ne "$_[1]" ? 1 : 0 },
                    '!=' => sub { "$_[0]" ne "$_[1]" ? 1 : 0 },
                    'lt' => sub { "$_[0]" < $_[1] ? 1 : 0 },
                    '<' => sub { "$_[0]" < $_[1] ? 1 : 0 },
                    'le' => sub { "$_[0]" <= $_[1] ? 1 : 0 },
                    '<=' => sub { "$_[0]" <= $_[1] ? 1 : 0 },
                    'gt' => sub { "$_[0]" > $_[1] ? 1 : 0 },
                    '>' => sub { "$_[0]" > $_[1] ? 1 : 0 },
                    'ge' => sub { "$_[0]" >= $_[1] ? 1 : 0 },
                    '>=' => sub { "$_[0]" >= $_[1] ? 1 : 0 },
                };

                if (defined($op_map->{$test_name})) {
                    my $op = $op_map->{$test_name};
                    my @cmp_args = map { $_ } @args;
                    if (@cmp_args) {
                        $matched = $op->($item, $cmp_args[0]);
                    } else {
                        next;
                    }
                } else {
                    # Use registered test function
                    my $test_fn = "func_$test_name";
                    if (can_call_test($test_fn)) {
                        $matched = $test_fn->($item, @args);
                    } elsif ($test_name eq 'defined') {
                        $matched = defined($item) ? 1 : 0;
                    } else {
                        $matched = test_predicate_to_bool($item);
                    }
                }
            } else {
                # Use registered test function (is_string, is_odd, etc.)
                my $test_fn = "func_$test_name";
                if (can_call_test($test_fn)) {
                    $matched = $test_fn->($item, @args);
                } elsif ($test_name eq 'defined') {
                    $matched = defined($item) ? 1 : 0;
                } else {
                    $matched = test_predicate_to_bool($item);
                }
            }
        }

        # Reject items that matched the predicate
        unless ($matched) {
            push @result, $item;
        }
    }

    return \@result;
}

# --- Object Filters ---

# get — safe hash access with default fallback (like Python's dict.get())
sub filter_get {
    my ($obj, $key, $default) = @_;
    return $default unless defined($obj) && ref($obj) eq 'HASH';
    if (!exists($obj->{$key})) {
        return defined($default) ? $default : undef;
    }
    return $obj->{$key};
}

# keys — return sorted array of hash keys as an arrayref
sub filter_keys {
    my ($val) = @_;
    return [] unless defined($val) && ref($val) eq 'HASH';
    [sort {$a cmp $b} keys %{$val}];
}

# values — return array of hash values as an arrayref (in sorted key order)
sub filter_values {
    my ($val) = @_;
    return [] unless defined($val) && ref($val) eq 'HASH';
    my @sorted = sort {$a cmp $b} keys %{$val};
    [@{$val}{@sorted}];
}

# dictsort — sort dictionary by key or value into a new array of [key, value] pairs
# Usage: {{ my_dict | dictsort }}  (default: sort by key, case-sensitive)
#        {{ my_dict | dictsort:true }}  (case-insensitive comparison)
#        {{ my_dict | dictsort:value }}  (sort by value instead of key)
sub filter_dictsort {
    my ($val, $by_value, $reverse) = @_;

    # Handle optional boolean arguments that might be passed as strings "true"/"false"
    my $by_val = 0;
    if (defined($by_value)) {
        if (ref($by_value) eq 'SCALAR' || !ref($by_value)) {
            my $s = "$by_value";
            $by_val = ($s eq 'true') ? 1 : (($s eq 'false') ? 0 : 0);
        } elsif (ref($by_value) eq 'ARRAY') {
            $by_val = scalar(@$by_value) > 0 ? 1 : 0;
        } else {
            $by_val = $by_value ? 1 : 0;
        }
    }

    my $rev = defined($reverse) ? ($reverse ? 1 : 0) : 0;

    return [] unless defined($val) && ref($val) eq 'HASH';

    my %hash = %{$val};
    my @pairs;

    if ($by_val) {
        # Sort by value
        @pairs = sort {
            my $va = "$a"; my $vb = "$b";
            my $cmp = $va cmp $vb;
            $rev ? -$cmp : $cmp;
        } keys %hash;
        @pairs = map { [$_, $hash{$_}] } @pairs;
    } else {
        # Sort by key (default)
        @pairs = sort {
            my ($ka, $kb) = ($a, $b);
            my $cmp = $ka cmp $kb;
            $rev ? -$cmp : $cmp;
        } keys %hash;
        @pairs = map { [$_, $hash{$_}] } @pairs;
    }

    return \@pairs;
}

# --- Phase 7: Global Functions ---

# raise_exception — throw a Jinja exception from templates (dies with message)
# Usage in template: {{ raise_exception('error message') }}
# The die() is caught by XS layer and propagated as rendering error.
sub func_raise_exception {
    my ($msg) = @_;
    $msg //= 'Unknown error';
    die "$msg";
}

# range — Python-style range generating arrayref [start..stop) with optional step
# Usage: {{ range(5) }} → [0, 1, 2, 3, 4]
#        {{ range(2, 8) }} → [2, 3, 4, 5, 6, 7]
#        {{ range(1, 10, 2) }} → [1, 3, 5, 7, 9]
sub func_range {
    my ($start, $stop, $step) = @_;

    if (!defined($step)) {
        # Two-arg form: range(stop) → [0..stop) or range(start, stop)
        if (!defined($stop)) {
            # Single arg: range(stop) — start=0
            $stop = $start;
            $start = 0;
        } else {
            # Two args: range(start, stop)
            # nothing to do
        }
        $step = 1;
    }

    return [] unless defined($start) && defined($stop) && defined($step);

    my @result;
    if ($step > 0) {
        push @result, $_ for ($start .. $stop - 1);
    } elsif ($step < 0) {
        push @result, $_ for reverse ($stop + 1 .. $start);
    }

    return \@result;
}

# strftime_now — format current time as string using POSIX::strftime
# Usage: {{ strftime_now('%Y-%m-%d %H:%M:%S') }} → "2024-01-15 14:30:00"
sub filter_strftime_now {
    my ($fmt) = @_;
    $fmt //= '%Y-%m-%d %H:%M:%S';

    # Format current local time
    my @t = localtime();
    strftime($fmt, @t);
}

# namespace — create a mutable object from kwargs (like Jinja's namespace())
# Usage in template: {% set ns = namespace() %} or {% set ns = namespace(foo='bar', baz=1) %}
# Returns a blessed hashref that can be used with {% set ns.key = value %} syntax.
sub func_namespace {
    my (%kwargs) = @_;

    # Create a blessed hashref to act as a mutable namespace object
    my $ns = bless({}, 'Minijinja::Namespace');

    # Initialize with any provided keyword arguments
    for my $key (keys %kwargs) {
        $ns->{$key} = $kwargs{$key};
    }

    return $ns;
}

# Namespace package — provides accessor methods for the blessed namespace objects.
# This allows templates to access and modify namespace attributes.

package Minijinja::Namespace;

use strict; use warnings;

# Allow access to any key via hash dereferencing (handled by XS layer)
# The XS layer will call this when accessing ns.key in templates

package Minijinja;

sub exportable_map {
    return (
        # Core (Phase 1)
        filter_tojson         => 'filter',
        filter_items          => 'filter',
        func_startswith       => 'function',
        func_endswith         => 'function',
        filter_has_prefix     => 'filter',
        filter_has_suffix     => 'filter',

        # String Filters (Phase 2)
        filter_upper          => 'filter',
        filter_lower          => 'filter',
        filter_strip          => 'filter',
        filter_rstrip         => 'filter',
        filter_lstrip         => 'filter',
        filter_title          => 'filter',
        filter_capitalize     => 'filter',
        filter_split          => 'filter',
        filter_rsplit         => 'filter',
        filter_replace        => 'filter',
        filter_length_str     => 'filter',

        # Number Filters (Phase 3)
        filter_abs            => 'filter',
        filter_int_num        => 'filter',
        filter_float_num      => 'filter',

        # Array Filters (Phase 4)
        filter_list           => 'filter',
        filter_first          => 'filter',
        filter_last           => 'filter',
        filter_reverse        => 'filter',
        filter_array_slice    => 'filter',
        filter_sort           => 'filter',
        filter_min            => 'filter',
        filter_max            => 'filter',
        filter_join           => 'filter',
        filter_map            => 'filter',

        # Object Filters (Phase 6)
        filter_get            => 'filter',
        filter_keys           => 'filter',
        filter_values         => 'filter',
        filter_dictsort       => 'filter',

        # Global Functions (Phase 7)
        func_raise_exception   => 'function',
        func_range             => 'function',
        filter_strftime_now    => 'function',
        func_namespace         => 'function',

        # Test Functions (Phase 5) — type checks & comparisons (~28 tests)
        func_is_string         => 'test',
        func_is_integer        => 'test',
        func_is_float          => 'test',
        func_is_number         => 'test',
        func_is_boolean        => 'test',
        func_is_callable       => 'test',
        func_is_none           => 'test',
        func_is_undefined      => 'test',
        func_is_defined        => 'test',
        func_is_mapping        => 'test',
        func_is_iterable       => 'test',
        func_is_sequence       => 'test',
        func_is_lower          => 'test',
        func_is_upper          => 'test',
        func_is_odd            => 'test',
        func_is_even           => 'test',
        func_is_false          => 'test',
        func_is_true           => 'test',
        func_is_divisibleby    => 'test',
        func_is_in             => 'test',
        func_is_eq             => 'test',
        func_is_equalto        => 'test',
        func_is_ne             => 'test',
        func_is_lt             => 'test',
        func_is_le             => 'test',
        func_is_gt             => 'test',
        func_is_ge             => 'test',

        # Select/Reject Filters (Phase 5 continuation) — 4 filters with internal helpers (~26 lines)
        filter_selectattr      => 'filter',
        filter_rejectattr      => 'filter',
        filter_select          => 'filter',
        filter_reject          => 'filter',

        # Internal helpers used by select/reject (not registered with minijinja, but exported for reuse)
    );
}

1;
