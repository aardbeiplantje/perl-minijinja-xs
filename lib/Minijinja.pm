package Minijinja;

use strict; use warnings;

our $VERSION = "0.1.0";

use Exporter 'import';

our @EXPORT_OK = qw(
    minijinja

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

    test_predicate_to_bool

    _extract_attr _compare_values _evaluate_select_pred _can_call_test _get_comparison_ops
);

use XSLoader;
XSLoader::load('Minijinja', $VERSION);

sub minijinja {
    my ($class, %opts) = @_;
    my $_j;
    $_j   = create_minijinja(\%opts) if keys %opts;
    $_j //= create_minijinja();
    return bless $_j, ref($class) || $class || "Minijinja";
}

# --- Filter Package ===

package Minijinja::Filter;

# Pre-create shared JSON encoder instance for reuse in callbacks.
our $json_encoder;

sub _get_json_encoder {
    return $json_encoder // do {
        eval {
            require JSON::PP
        };
        die "Minijinja requires JSON::PP: $@" if $@;
        JSON::PP->new->utf8->canonical;
    };
}

# tojson filter — matches Python minijinja's |tojson behavior exactly.
sub tojson {
    my ($val) = @_;
    my $encoded = _get_json_encoder()->encode($val);
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
sub items {
    my ($value) = @_;

    if (!defined($value)){
        return []
    } elsif (ref($value) eq 'HASH'){
        return [map {[$_, $value->{$_}]} sort {$a cmp $b} keys %{$value}]
    } elsif (ref($value) eq 'ARRAY') {
        return []
    } else {
        my $decoded = eval {
            _get_json_encoder()->decode($value)
        };
        return [] if $@ || ref($decoded) ne 'HASH';
        return [map { [$_, $decoded->{$_}] } sort {$a cmp $b} keys %{$decoded}];
    }
}

# has_prefix — filter version of startswith
sub has_prefix {
    my ($s, $prefix) = @_;

    if (!defined($s) || !defined($prefix)){
        return "0"
    }

    if (substr($s, 0, length($prefix)) eq $prefix){
        return "1"
    } else {
        return "0"
    }
}

# has_suffix — filter version of endswith
sub has_suffix {
    my ($s, $suffix) = @_;

    if (!defined($s) || !defined($suffix)){
        return "0"
    }

    if (length($s) >= length($suffix) && substr($s, -length($suffix)) eq $suffix){
        return "1"
    } else {
        return "0"
    }
}

# upper — convert string to uppercase
sub upper {
    my ($val) = @_;
    return "" unless defined($val);
    return uc($val);
}

# lower — convert string to lowercase
sub lower {
    my ($val) = @_;
    return "" unless defined($val);
    return lc($val);
}

# strip — remove whitespace from both ends of string (optional chars arg)
sub strip {
    my ($val, $chars) = @_;
    return "" unless defined($val);

    my $s = $val;

    if (defined($chars)){
        $s =~ s/^[\Q$chars\E]+//;
        $s =~ s/[\Q$chars\E]+$//;
    } else {
        $s =~ s/^\s+|\s+$//g;
    }

    return $s;
}

# rstrip — remove whitespace from right end of string (optional chars arg)
sub rstrip {
    my ($val, $chars) = @_;
    return "" unless defined($val);

    my $s = $val;

    if (defined($chars)){
        $s =~ s/[\Q$chars\E]+$//;
    } else {
        $s =~ s/\s+$//;
    }

    return $s;
}

# lstrip — remove whitespace from left end of string (optional chars arg)
sub lstrip {
    my ($val, $chars) = @_;
    return "" unless defined($val);

    my $s = $val;

    if (defined($chars)){
        $s =~ s/^[\Q$chars\E]+//;
    } else {
        $s =~ s/^\s+//;
    }

    return $s;
}

# title — convert to title case: first letter of each word uppercase, rest lowercase
sub title {
    my ($val) = @_;
    return "" unless defined($val);
    my $s = $val;
    $s =~ s/(^\w|\s+\w)(\w*)/uc($1).lc($2)/ge;
    return $s;
}

# capitalize — capitalize first letter, make rest lowercase
sub capitalize {
    my ($val) = @_;
    return "" unless defined($val);
    my $s = $val;
    $s =~ s/^(.)(.*)/uc($1).lc($2)/ge;
    return $s;
}

# split — split string by delimiter with optional maxsplit (count from left)
sub split {
    my ($val, $sep, $maxsplit) = @_;
    return [] unless defined($val);
    my $s = $val;
    if (!defined($sep)){
        my @parts = grep {$_ ne ''} split(/\s+/, $s);
        if (defined($maxsplit) && $maxsplit > 0 && @parts > $maxsplit){
            return [splice(@parts, 0, $maxsplit + 1)];
        }
        return \@parts;
    } else {
        my @parts = split(/\Q$sep\E/, $s);
        if (defined($maxsplit) && $maxsplit > 0 && @parts > $maxsplit){
            return [splice(@parts, 0, $maxsplit + 1)];
        }
        return \@parts;
    }
}

# rsplit — split string from the right side with optional maxsplit
sub rsplit {
    my ($val, $sep, $maxsplit) = @_;
    return [] unless defined($val);
    my $s = $val;
    if (!defined($sep)){
        my @parts = grep { $_ ne '' } split(/\s+/, $s);
        if (defined($maxsplit) && $maxsplit > 0 && @parts > $maxsplit){
            return [splice(@parts, -$maxsplit - 1)];
        }
        return \@parts;
    } else {
        if (defined($maxsplit) && $maxsplit > 0){
            my @result;
            while ($maxsplit > 0 && index($s, $sep) >= 0){
                my $pos = rindex($s, $sep);
                unshift @result, substr($s, $pos + length($sep));
                $s = substr($s, 0, $pos);
                $maxsplit--;
            }
            unshift @result, $s;
            return \@result;
        } else {
            return [split(/\Q$sep\E/, $s)];
        }
    }
}

# replace — replace all occurrences of old with new in string
sub replace {
    my ($val, $old, $new) = @_;
    return "" unless defined($val);
    my $s = $val;
    $s =~ s/\Q$old\E/$new/g;
    return $s;
}

# length_str — return character length of string (Unicode-aware)
sub length_str {
    my ($val) = @_;
    return 0 unless defined($val);
    return length($val);
}

# abs — absolute value
sub abs {
    my ($val) = @_;
    return $val unless defined($val);
    my $n = 0 + $val;
    return -$n if $n < 0;
    return $n;
}

# int_num — cast number to integer (truncates toward zero)
sub int_num {
    my ($val) = @_;
    return "" unless defined($val);
    return int(0 + $val);
}

# float_num — convert to floating point (no-op if already float)
sub float_num {
    my ($val) = @_;
    return "" unless defined($val);
    return 0 + $val;
}

# list — shallow copy of arrayref
# renamed from 'list' to avoid conflict with Perl builtin
sub list_fn {
    my ($val) = @_;
    return [] unless defined($val) && ref($val) eq 'ARRAY';
    return [@$val];
}

# first — get first element or undefined if empty/undefined
sub first {
    my ($val) = @_;
    return unless defined($val) && ref($val) eq 'ARRAY';
    return $val->[0] if scalar(@{$val});
    return;
}

# last — get last element or undefined if empty/undefined
sub last {
    my ($val) = @_;
    return unless defined($val) && ref($val) eq 'ARRAY';
    my @arr = @$val;
    return pop @arr;
}

# reverse — returns reversed copy of array
# renamed from 'reverse' to avoid conflict with Perl builtin
sub reverse_fn {
    my ($val) = @_;
    return [] unless defined($val) && ref($val) eq 'ARRAY';
    return [reverse @{$val}];
}

# slice — Python-style [start:stop:step] array slicing
sub array_slice {
    my ($val, $start, $stop, $step) = @_;
    return [] unless defined($val) && ref($val) eq 'ARRAY';
    my @arr = @$val;
    my $len = scalar @arr;
    return [] if $len == 0;
    $step = 1 unless defined($step);
    return [] if $step <= 0;

    my $s;
    if (!defined($start)){
        $s = 0;
    } elsif ($start < 0){
        $s = ($len + $start) > 0 ? ($len + $start) : 0;
    } else {
        $s = $start >= $len ? $len : $start;
    }

    my $e;
    if (!defined($stop)){
        $e = $len;
    } elsif ($stop < 0){
        $e = ($len + $stop) >= 0 ? ($len + $stop) : 0;
    } else {
        $e = $stop > $len ? $len : $stop;
    }

    my @result;
    for (my $i = $s; $i < $e && $i < $len; $i += $step){
        push @result, $arr[$i];
    }
    return \@result;
}

# sort — sorted copy of array with optional reverse and attribute access
# renamed from 'sort' to avoid conflict with Perl builtin
sub sort_fn {
    my ($val, $reverse, $attribute) = @_;
    return [] unless defined($val) && ref($val) eq 'ARRAY';
    my @arr = @$val;
    return [] if @arr == 0;

    my @sorted;
    if (defined($attribute)){
        @sorted = sort {
            my $a_val = Minijinja::_extract_attr($a, $attribute);
            my $b_val = Minijinja::_extract_attr($b, $attribute);
            my $cmp = Minijinja::_compare_values($a_val, $b_val);
            $reverse?-$cmp:$cmp;
        } @arr;
    } else {
        @sorted = sort {
            my $cmp = Minijinja::_compare_values($a, $b);
            $reverse?-$cmp:$cmp;
        } @arr;
    }

    return \@sorted;
}

# min — find minimum value in array with optional attribute access
sub min {
    my ($val, $attribute) = @_;
    return unless defined($val) && ref($val) eq 'ARRAY';

    my @arr = grep {defined($_) && $_ ne ''} @$val;
    return if @arr == 0;

    if (@arr == 1){
        if (defined($attribute)){
            return Minijinja::_extract_attr($arr[0], $attribute);
        } else {
            return $arr[0];
        }
    }

    if (defined($attribute)){
        my @with_vals = map {[$_, Minijinja::_extract_attr($_, $attribute)]} @arr;
        my $min_pair = shift @with_vals;

        foreach my $pair (@with_vals){
            if (Minijinja::_compare_values($pair->[1], $min_pair->[1]) < 0){
                $min_pair = $pair;
            }
        }

        return $min_pair->[1];
    } else {
        my $min_val = $arr[0];

        foreach my $item (@arr[1..$#arr]){
            if (Minijinja::_compare_values($item, $min_val) < 0){
                $min_val = $item;
            }
        }

        return $min_val;
    }
}

# max — find maximum value in array with optional attribute access
sub max {
    my ($val, $attribute) = @_;
    return unless defined($val) && ref($val) eq 'ARRAY';
    my @arr = grep {defined($_) && $_ ne ''} @$val;
    return if @arr == 0;
    if (@arr == 1){
        if (defined($attribute)){
            return Minijinja::_extract_attr($arr[0], $attribute);
        } else {
            return $arr[0];
        }
    }
    if (defined($attribute)){
        my @with_vals = map {[$_, Minijinja::_extract_attr($_, $attribute)]} @arr;
        my $max_pair = shift @with_vals;
        foreach my $pair (@with_vals){
            $max_pair = $pair if Minijinja::_compare_values($pair->[1], $max_pair->[1]) > 0;
        }
        return $max_pair->[1];
    } else {
        my $max_val = $arr[0];
        foreach my $item (@arr[1..$#arr]){
            $max_val = $item if Minijinja::_compare_values($item, $max_val) > 0;
        }
        return $max_val;
    }
}

# join — join array elements with separator, optional attribute extraction
sub join {
    my ($val, $separator, $attribute) = @_;
    return '' unless defined($val);
    my @items;
    if (ref($val) eq 'ARRAY'){
        @items = @$val;
    } elsif (defined($val) && ref($val) ne 'HASH' && ref($val) ne 'CODE'){
        @items = ($val);
    } else {
        return '';
    }
    @items = grep {defined($_)} @items;
    if (!defined($attribute)){
        return join($separator // '', @items);
    } else {
        @items = map {Minijinja::_extract_attr($_, $attribute) // ''} @items;
        return join($separator // '', @items);
    }
}

# map — extract attribute values into new array
# renamed from 'map' to avoid conflict with Perl builtin
sub map_fn {
    my ($val, $attribute) = @_;
    return [] unless defined($val) && ref($val) eq 'ARRAY';
    my @result;
    for my $item (@$val){
        if (!defined($item)){
            push @result, undef;
        } else {
            push @result, Minijinja::_extract_attr($item, $attribute);
        }
    }
    return \@result;
}

# get — safe hash access with default fallback
sub get {
    my ($obj, $key, $default) = @_;
    if (defined($obj) && ref($obj) eq 'HASH' && exists($obj->{$key})){
        return $obj->{$key};
    } else {
        return $default;
    }
}

# keys — return sorted array of hash keys as an arrayref
# renamed from 'keys' to avoid conflict with Perl builtin
sub keys_fn {
    my ($val) = @_;
    return [] unless defined($val) && ref($val) eq 'HASH';
    return [sort {$a cmp $b} keys %{$val}];
}

# values — return array of hash values as an arrayref (in sorted key order)
sub values {
    my ($val) = @_;
    return [] unless defined($val) && ref($val) eq 'HASH';
    return [@{$val}{sort {$a cmp $b} keys %{$val}}];
}

# dictsort — sort dictionary by key or value into a new array of [key, value] pairs
sub dictsort {
    my ($val, $by_value, $reverse) = @_;
    my $by_val = 0;

    if (defined($by_value)){
        if (ref($by_value) eq 'SCALAR' || !ref($by_value)){
            my $s = "$by_value";
            if ($s eq 'true'){
                $by_val = 1;
            } elsif ($s eq 'false'){
                $by_val = 0;
            } else {
                $by_val = 0;
            }
        } elsif (ref($by_value) eq 'ARRAY'){
            $by_val = scalar(@$by_value) > 0 ? 1 : 0;
        } else {
            $by_val = $by_value ? 1 : 0;
        }
    }

    return [] unless defined($val) && ref($val) eq 'HASH';

    my %hash = %{$val};
    my @pairs;
    if ($by_val){
        @pairs = sort {
            my $va = "$a";
            my $vb = "$b";
            my $cmp = $va cmp $vb;
            if ($reverse){
                -$cmp;
            } else {
                $cmp;
            }
        } keys %hash;
        @pairs = map { [$_, $hash{$_}] } @pairs;
    } else {
        @pairs = sort {
            my ($ka, $kb) = ($a, $b);
            my $cmp = $ka cmp $kb;
            if ($reverse){
                -$cmp;
            } else {
                $cmp;
            }
        } keys %hash;
        @pairs = map { [$_, $hash{$_}] } @pairs;
    }

    return \@pairs;
}

# selectattr — filter array items by attribute value/test predicate
sub selectattr {
    my ($val, $attribute, $test_name, @rest_args) = @_;
    return [] unless defined($val) && ref($val) eq 'ARRAY';
    my @result;
    for my $item (@$val){
        next unless defined($item);
        my $matched = 0;

        if (!defined($test_name)){
            if (defined($attribute)){
                my $attr_val = Minijinja::_extract_attr($item, $attribute);
                $matched = Minijinja::Test::test_predicate_to_bool($attr_val);
            } else {
                $matched = Minijinja::Test::test_predicate_to_bool($item);
            }
        } else {
            my @args = @rest_args;

            if ($test_name =~ /^(eq|ne|lt|le|gt|ge|==$|!=|<\d*|<=\d*>|\>=)$/){
                my $op_map = Minijinja::_get_comparison_ops();

                if (defined($op_map->{$test_name})){
                    my $op = $op_map->{$test_name};
                    my @cmp_args = map { $_ } @args;

                    if (@cmp_args){
                        if (defined($attribute)){
                            my $attr_val = Minijinja::_extract_attr($item, $attribute);
                            $matched = $op->($attr_val, $cmp_args[0]);
                        } else {
                            $matched = $op->($item, $cmp_args[0]);
                        }
                    } else {
                        next;
                    }
                } else {
                    my $_ev_result = Minijinja::_evaluate_select_pred(
                        $item, $attribute, $test_name, \@args);
                    $matched = $_ev_result;
                }
            } else {
                my $_ev_result = Minijinja::_evaluate_select_pred(
                    $item, $attribute, $test_name, \@args);
                $matched = $_ev_result;
            }
        }

        if ($matched){
            push @result, defined($attribute) ? Minijinja::_extract_attr($item, $attribute) : $item;
        }
    }

    return \@result;
}

# rejectattr — filter out array items by attribute value/test predicate (inverse of selectattr)
sub rejectattr {
    my ($val, $attribute, $test_name, @rest_args) = @_;

    return [] unless defined($val) && ref($val) eq 'ARRAY';

    my @result;

    for my $item (@$val){
        next unless defined($item);
        my $matched = 0;

        if (!defined($test_name)){
            if (defined($attribute)){
                my $attr_val = Minijinja::_extract_attr($item, $attribute);
                $matched = Minijinja::Test::test_predicate_to_bool($attr_val);
            } else {
                $matched = Minijinja::Test::test_predicate_to_bool($item);
            }
        } else {
            my @args = @rest_args;

            if ($test_name =~ /^(eq|ne|lt|le|gt|ge|==$|!=|<\d*|<=\d*>|\>=)$/){
                my $op_map = Minijinja::_get_comparison_ops();

                if (defined($op_map->{$test_name})){
                    my $op = $op_map->{$test_name};
                    my @cmp_args = map { $_ } @args;

                    if (@cmp_args){
                        if (defined($attribute)){
                            my $attr_val = Minijinja::_extract_attr($item, $attribute);
                            $matched = $op->($attr_val, $cmp_args[0]);
                        } else {
                            $matched = $op->($item, $cmp_args[0]);
                        }
                    } else {
                        next;
                    }
                } else {
                    my $_ev_result = Minijinja::_evaluate_select_pred(
                        $item, $attribute, $test_name, \@args);
                    $matched = $_ev_result;
                }
            } else {
                my $_ev_result = Minijinja::_evaluate_select_pred(
                    $item, $attribute, $test_name, \@args);
                $matched = $_ev_result;
            }
        }

        unless ($matched){
            push @result, defined($attribute) ? Minijinja::_extract_attr($item, $attribute) : $item;
        }
    }

    return \@result;
}

# select — filter array items by test predicate (no attribute access)
# renamed from 'select' to avoid ambiguity
sub select_fn {
    my ($val, $test_name, @rest_args) = @_;

    return [] unless defined($val) && ref($val) eq 'ARRAY';

    my @result;

    for my $item (@$val){
        next unless defined($item);
        my $matched = 0;

        if (!defined($test_name)){
            $matched = Minijinja::Test::test_predicate_to_bool($item);
        } else {
            my @args = @rest_args;

            if ($test_name =~ /^(eq|ne|lt|le|gt|ge|==$|!=|<\d*|<=\d*>|\>=)$/){
                my $op_map = Minijinja::_get_comparison_ops();

                if (defined($op_map->{$test_name})){
                    my $op = $op_map->{$test_name};
                    my @cmp_args = map { $_ } @args;

                    if (@cmp_args){
                        $matched = $op->($item, $cmp_args[0]);
                    } else {
                        next;
                    }
                } else {
                    my $test_fn = "Minijinja::Test::$test_name";

                    if (Minijinja::_can_call_test($test_fn)){
                        $matched = $test_fn->($item, @args);
                    } elsif ($test_name eq 'defined'){
                        $matched = defined($item) ? 1 : 0;
                    } else {
                        $matched = Minijinja::Test::test_predicate_to_bool($item);
                    }
                }
            } else {
                my $test_fn = "Minijinja::Test::$test_name";

                if (Minijinja::_can_call_test($test_fn)){
                    $matched = $test_fn->($item, @args);
                } elsif ($test_name eq 'defined'){
                    $matched = defined($item) ? 1 : 0;
                } else {
                    $matched = Minijinja::Test::test_predicate_to_bool($item);
                }
            }
        }

        push @result, $item if $matched;
    }

    return \@result;
}

# reject — filter out array items by test predicate (inverse of select)
sub reject {
    my ($val, $test_name, @rest_args) = @_;
    return [] unless defined($val) && ref($val) eq 'ARRAY';

    my @result;
    for my $item (@$val){
        next unless defined($item);
        my $matched = 0;

        if (!defined($test_name)){
            $matched = Minijinja::Test::test_predicate_to_bool($item);
        } else {
            my @args = @rest_args;

            if ($test_name =~ /^(eq|ne|lt|le|gt|ge|==$|!=|<\d*|<=\d*>|\>=)$/){
                my $op_map = Minijinja::_get_comparison_ops();

                if (defined($op_map->{$test_name})){
                    my $op = $op_map->{$test_name};
                    my @cmp_args = map { $_ } @args;

                    if (@cmp_args){
                        $matched = $op->($item, $cmp_args[0]);
                    } else {
                        next;
                    }
                } else {
                    my $test_fn = "Minijinja::Test::$test_name";

                    if (Minijinja::_can_call_test($test_fn)){
                        $matched = $test_fn->($item, @args);
                    } elsif ($test_name eq 'defined'){
                        $matched = defined($item) ? 1 : 0;
                    } else {
                        $matched = Minijinja::Test::test_predicate_to_bool($item);
                    }
                }
            } else {
                my $test_fn = "Minijinja::Test::$test_name";

                if (Minijinja::_can_call_test($test_fn)){
                    $matched = $test_fn->($item, @args);
                } elsif ($test_name eq 'defined'){
                    $matched = defined($item) ? 1 : 0;
                } else {
                    $matched = Minijinja::Test::test_predicate_to_bool($item);
                }
            }
        }

        push @result, $item unless $matched;
    }

    return \@result;
}

package Minijinja::Function;

use POSIX ();

# raise_exception — throw a Jinja exception from templates
sub raise_exception {
    my ($msg) = @_;
    $msg //= 'Unknown error';
    die "$msg";
}

# range — Python-style range generating arrayref [start..stop) with optional step
sub range {
    my ($start, $stop, $step) = @_;

    if (!defined($step)){
        if (!defined($stop)){
            $stop = $start;
            $start = 0;
        } else {
            # $stop is defined but $step is not, do nothing
        }

        $step = 1;
    }

    return [] unless defined($start) && defined($stop) && defined($step);

    my @result;

    if ($step > 0){
        push @result, $_ for ($start .. $stop - 1);
    } elsif ($step < 0){
        push @result, $_ for reverse ($stop + 1 .. $start);
    }

    return \@result;
}

# strftime_now — format current time as string using POSIX::strftime
sub strftime_now {
    my ($fmt) = @_;
    return POSIX::strftime($fmt // '%Y-%m-%d %H:%M:%S', localtime());
}

# namespace — create a mutable object from kwargs (like Jinja's namespace())
# renamed to avoid conflict with package name usage
sub namespace_fn {
    my (%kwargs) = @_;
    my $ns = bless {}, 'Minijinja::Namespace';
    $ns->{$_} = $kwargs{$_} for keys %kwargs;
    return $ns;
}

package Minijinja::Test;

# is_string — check if value is a string
sub is_string {
    my ($val) = @_;
    return 0 if _is_undefined($val);
    return 0 if ref($val);
    return 1;
    # TODO: in perl everything is a string if wanted, we probably should "exclude"
    # e.g.: is NOT a float AND is NOT an INT,... etc. We do exclude "ref", as perl
    # auto stringifies refs into a string. Similar like is_float() tries to be smart
    # wrt int vs float
}

# is_integer — check if value is an integer (no decimal point in string form)
sub is_integer {
    my ($val) = @_;
    return 0 if _is_undefined($val);
    return 0 if ref($val);
    return 1 if $val =~ /^-?\d+$/;
    return 0;
}

# is_float — check if value is a float
sub is_float {
    my ($val) = @_;
    return 0 if _is_undefined($val);
    return 0 if ref($val);
    my $is_numeric_str   = ($val =~ /^-?(?:\d+\.\d*|\.\d+)(?:[eE][+-]?\d+)?$/);
    my $is_not_int_float = ($val !~ /^-?(\d+)\.0$/);
    my $has_exp          = ($val =~ /[eE]/);
    return ($is_numeric_str && $is_not_int_float || $has_exp) ? 1 : 0;
}

# is_number — check if value is any numeric type (int or float)
sub is_number {
    my ($val) = @_;
    return 0 if _is_undefined($val);
    return 0 if ref($val);
    return ($val =~ /^-?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?$/) ? 1 : 0;
}

# is_boolean — check if value is a boolean
sub is_boolean {
    my ($val) = @_;
    return 0 unless defined($val);
    return ($val eq 'true' || $val eq 'false') ? 1 : 0;
}

# is_callable — check if value is callable
sub is_callable {
    my ($val) = @_;
    return ref($val) eq 'CODE' ? 1 : 0;
}

# is_none — check if value is None/null/undefined
sub is_none {
    my ($val) = @_;
    return _is_undefined($val) ? 1 : 0;
}

# is_undefined — check if value is undefined
sub is_undefined {
    my ($val) = @_;
    return _is_undefined($val) ? 1 : 0;
}

# is_defined — check if value is defined (opposite of is_undefined)
sub is_defined {
    my ($val) = @_;

    return _is_undefined($val) ? 0 : 1;
}

# is_mapping — check if value is a mapping (hashref)
sub is_mapping {
    my ($val) = @_;
    return ref($val) eq 'HASH' ? 1 : 0;
}

# is_iterable — check if value can be iterated over
sub is_iterable {
    my ($val) = @_;
    return 0 if _is_undefined($val);
    return ref($val) ? (ref($val) eq 'ARRAY' || ref($val) eq 'HASH') : 1;
}

# is_sequence — check if value is a sequence
sub is_sequence {
    my ($val) = @_;
    return 0 if _is_undefined($val);
    return ref($val) ? (ref($val) eq 'ARRAY' || !ref($val)) : 0;
}

# is_lower — check if all cased characters in string are lowercase
sub is_lower {
    my ($val) = @_;
    return 0 unless defined($val) && !ref($val);
    return 0 unless $val =~ /[a-zA-Z]/;
    return ($val eq lc($val)) ? 1 : 0;
}

# is_upper — check if all cased characters in string are uppercase
sub is_upper {
    my ($val) = @_;
    return 0 unless defined($val) && !ref($val);
    return 0 unless $val =~ /[a-zA-Z]/;
    return ($val eq uc($val)) ? 1 : 0;
}

# is_odd — check if integer is odd
sub is_odd {
    my ($val) = @_;
    return 0 if _is_undefined($val);
    my $n = int(0 + $val);
    return ($n % 2 != 0) ? 1 : 0;
}

# is_even — check if integer is even
sub is_even {
    my ($val) = @_;
    return 0 if _is_undefined($val);
    my $n = int(0 + $val);
    return ($n % 2 == 0) ? 1 : 0;
}

# is_false — identity check against False
sub is_false {
    my ($val) = @_;
    return ($val eq 'false' || $val eq 'False') ? 1 : 0;
}

# is_true — identity check against True
sub is_true {
    my ($val) = @_;
    return ($val eq 'true' || $val eq 'True') ? 1 : 0;
}

# is_divisibleby — check if number is divisible by divisor (mod == 0)
sub is_divisibleby {
    my ($val, $divisor) = @_;
    return 0 if _is_undefined($val) || !defined($divisor);
    return 0 if $divisor == 0;
    my $n = 0 + $val;
    return ($n % $divisor == 0) ? 1 : 0;
}

# is_in — membership test: needle in haystack
sub is_in {
    my ($needle, $haystack) = @_;
    return 0 if _is_undefined($needle) || !defined($haystack);
    if (ref($haystack) eq 'ARRAY'){
        for my $item (@{$haystack}){
            return 1 if "$needle" eq "$item";
        }

        return 0;
    } elsif (ref($haystack) eq 'HASH'){
        return exists($haystack->{$needle}) ? 1 : 0;
    } elsif (!ref($haystack)){
        return index("$haystack", "$needle") >= 0 ? 1 : 0;
    } else {
        return 0;
    }
}

# is_eq / is_equalto — equality (==)
sub is_eq {
    my ($va, $vb) = @_;
    return _compare_test($va, $vb, sub { $_[0] eq $_[1] ? 1 : 0 });
}

sub is_equalto {
    my ($va, $vb) = @_;
    return is_eq($va, $vb);
}

# is_ne — not equal (!=)
sub is_ne {
    my ($va, $vb) = @_;
    return _compare_test($va, $vb, sub { $_[0] ne $_[1] ? 1 : 0 });
}

# is_lt — less than (<)
sub is_lt {
    my ($va, $vb) = @_;
    return _compare_test($va, $vb, sub { $_[0] < $_[1] ? 1 : 0 });
}

# is_le — less than or equal (<=)
sub is_le {
    my ($va, $vb) = @_;
    return _compare_test($va, $vb, sub { $_[0] <= $_[1] ? 1 : 0 });
}

# is_gt — greater than (>)
sub is_gt {
    my ($va, $vb) = @_;
    return _compare_test($va, $vb, sub { $_[0] > $_[1] ? 1 : 0 });
}

# is_ge — greater than or equal (>=)
sub is_ge {
    my ($va, $vb) = @_;
    return _compare_test($va, $vb, sub { $_[0] >= $_[1] ? 1 : 0 });
}

# test_predicate_to_bool — convert any value to a boolean (truthy/falsy like Jinja)
sub test_predicate_to_bool {
    my ($val) = @_;
    return 0 if _is_undefined($val);
    if (!defined($val) || $val eq '' || $val eq 'false' || $val eq 'False' || $val eq 'None'){
        return 0;
    }
    return 1;
}

# Helper: determine if a value is "undefined" in Jinja terms
sub _is_undefined {
    my ($val) = @_;
    return !defined($val) || $val eq 'UNDEFINED';
}

# Helper: check if a subroutine can be called
sub _can_call_test {
    my ($name) = @_;
    return defined(\&{$name}) && ref(\&{$name}) eq 'CODE';
}

# Helper: comparison operator wrapper for Jinja tests
sub _compare_test {
    my ($sa, $sb, $cmp_func) = @_;
    return 0 if _is_undefined($a) || _is_undefined($b);
    my $is_numeric_a = ($sa =~ /^-?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?$/);
    my $is_numeric_b = ($sb =~ /^-?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?$/);
    if ($is_numeric_a && $is_numeric_b){
        return $cmp_func->(0 + $sa, 0 + $sb);
    }
    return $cmp_func->($sa, $sb);
}

package Minijinja;

# --- Internal helper functions (used by Filter package) ---

sub _extract_attr {
    my ($obj, $attr) = @_;
    return $obj unless defined($obj) && $attr;

    if (ref($obj) eq 'HASH'){
        return exists($obj->{$attr}) ? $obj->{$attr} : undef;
    } elsif (ref($obj) eq 'ARRAY'){
        if ($attr =~ /^-?\d+$/){
            my $idx = int($attr);
            if ($idx >= 0 && $idx < scalar(@{$obj})){
                return $obj->[$idx];
            }
        }
    }
    return;
}

sub _compare_values {
    my ($sa, $sb) = @_;
    return  0 if !defined($sa) && !defined($sb);
    return  1 if !defined($sa);
    return -1 if !defined($sb);
    my $is_numeric_a = ($sa =~ /^-?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?$/);
    my $is_numeric_b = ($sb =~ /^-?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?$/);
    if ($is_numeric_a && $is_numeric_b){
        return ($sa + 0) <=> ($sb + 0);
    }
    return $sa cmp $sb;
}

sub _evaluate_select_pred {
    my ($item, $attribute, $test_name, $args) = @_;

    if (defined($attribute)){
        my $attr_val = _extract_attr($item, $attribute);
        my $test_fn = "Minijinja::Test::$test_name";

        if (_can_call_test($test_fn)){
            return $test_fn->($attr_val, @$args);
        } elsif ($test_name eq 'defined'){
            return defined($attr_val) && !ref($attr_val) ? 1 : 0;
        } else {
            return defined($attr_val) ? 1 : 0;
        }
    } else {
        my $test_fn = "Minijinja::Test::$test_name";

        if (_can_call_test($test_fn)){
            return $test_fn->($item, @$args);
        } elsif ($test_name eq 'defined'){
            return defined($item) ? 1 : 0;
        } else {
            return defined($item) ? 1 : 0;
        }
    }
}

sub _can_call_test {
    my ($name) = @_;
    return defined(\&{$name}) && ref(\&{$name}) eq 'CODE';
}

sub _get_comparison_ops {
    return {
        'eq'   => sub { "$_[0]" eq "$_[1]" ? 1 : 0 },
        '=='   => sub { "$_[0]" eq "$_[1]" ? 1 : 0 },
        'ne'   => sub { "$_[0]" ne "$_[1]" ? 1 : 0 },
        '!='   => sub { "$_[0]" ne "$_[1]" ? 1 : 0 },
        'lt'   => sub { "$_[0]" < $_[1] ? 1 : 0 },
        '<'    => sub { "$_[0]" < $_[1] ? 1 : 0 },
        'le'   => sub { "$_[0]" <= $_[1] ? 1 : 0 },
        '<='   => sub { "$_[0]" <= $_[1] ? 1 : 0 },
        'gt'   => sub { "$_[0]" > $_[1] ? 1 : 0 },
        '>'    => sub { "$_[0]" > $_[1] ? 1 : 0 },
        'ge'   => sub { "$_[0]" >= $_[1] ? 1 : 0 },
        '>='   => sub { "$_[0]" >= $_[1] ? 1 : 0 },
    };
}

1;
