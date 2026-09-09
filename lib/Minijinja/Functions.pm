package Minijinja::Functions;

use strict; use warnings;

our $VERSION = "0.1.0";

use Exporter 'import';

our @EXPORT_OK = qw(
    filter_tojson
    filter_items
    func_startswith
    func_endswith
);

# Pre-create shared JSON encoder instance for reuse in callbacks.
# Creating new instances per call causes issues when called from XS context.
my $json_encoder = undef;

sub _get_json_encoder {
    unless ($json_encoder) {
        eval { require JSON::XS };
        if ($@) {
            die "Minijinja::Functions requires JSON::XS: $@";
        }
        $json_encoder = JSON::XS->new->utf8->canonical;
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

1;
