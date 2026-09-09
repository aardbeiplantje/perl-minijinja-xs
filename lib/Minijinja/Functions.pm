package Minijinja::Functions;

use strict; use warnings;

our $VERSION = "0.1.0";

use Exporter 'import';

our @EXPORT_OK = qw(
    filter_tojson
    filter_items
    func_startswith
    func_endswith

    filter_upper filter_lower
    filter_strip filter_rstrip filter_lstrip
    filter_title filter_capitalize
    filter_split filter_rsplit
    filter_replace
    filter_length_str

    filter_abs
    filter_int_num filter_float_num
);

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

1;
