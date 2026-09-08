use strict; use warnings;
use Test::More tests => 1;

use lib 't/lib';

use Minijinja qw(new render_str error_exists error_detail add_filter add_function add_test);
use File::Basename;
use JSON ();

# Resolve resource dir — check multiple locations for robustness under make test vs direct execution
my $resources_dir;
if (-d 't/resources') {
    $resources_dir = 't/resources';
} elsif (-d 'resources') {
    $resources_dir = 'resources';
} else {
    # Fallback: resolve relative to script file location
    my $script_path = dirname($0);
    my $candidate = File::Spec->catdir($script_path, '..', 'resources');
    if (-d $candidate) {
        $resources_dir = $candidate;
    } else {
        die "Cannot find t/resources directory (tried 't/resources', 'resources', '$candidate')\n";
    }
}

# Load template source
my $template_path = "$resources_dir/template-01.jinja";
open my $fh, '<', $template_path or die "Cannot open '$template_path': $!\n";
local $/;
my $template_source = <$fh>;
close $fh;

# Load input context from JSON file
my $input_path = "$resources_dir/input-01.json";
open my $ifh, '<', $input_path or die "Cannot open '$input_path': $!\n";
local $/;
my $json_str = <$ifh>;
close $ifh;

my $context = JSON->new->utf8->decode($json_str);

# ===========================================================================
# Pre-create the JSON encoder outside the filter callback.
# Creating it inside the callback causes issues when called from XS context.
# ===========================================================================
my $json_pp = JSON->new->utf8->canonical;

# tojson filter — matches Python minijinja's |tojson behavior exactly.
# Key differences from plain JSON::XS;
#   1. Escapes < > & ' as unicode escapes for XSS safety (matches minijinja)
sub _json_encode_html_safe {
    my ($val) = @_;

    # Use pre-created shared encoder (must NOT create new instance per call)
    my $encoded = $json_pp->encode($val);

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

my $env = new();

# startswith — identical lambda semantics to myjinja.py lines 31-32
add_function($env, 'startswith', sub {
    my ($s, $prefix) = @_;
    return !defined($s) || !defined($prefix) ? 0 : substr($s, 0, length($prefix)) eq $prefix;
});

# endswith — identical lambda semantics to myjinja.py lines 34-36
add_function($env, 'endswith', sub {
    my ($s, $suffix) = @_;
    return !defined($s) || !defined($suffix) ? 0 : length($s) >= length($suffix)
           && substr($s, -length($suffix)) eq $suffix;
});

# Also register as Jinja tests so they work with `is` syntax (line 72 uses `is not mapping`)
add_test($env, 'istartswith', sub {
    my ($s, $prefix) = @_;
    return !defined($s) || !defined($prefix) ? 0 : substr($s, 0, length($prefix)) eq $prefix;
});
add_test($env, 'endswith', sub {
    my ($s, $suffix) = @_;
    return !defined($s) || !defined($suffix) ? 0 : length($s) >= length($suffix)
           && substr($s, -length($suffix)) eq $suffix;
});

# raise_exception — dies so rendering aborts and error_detail() returns the message
add_function($env, 'raise_exception', sub { die $_[0] });

# items — Perl equivalent of Python safe_items (myjinja.py lines 6-17)
add_filter($env, 'items', sub {
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
        return eval {
            my $decoded = JSON->new->utf8->decode($value);
            if (ref($decoded) eq 'HASH') {
                return [map { [$_, $decoded->{$_}] } sort {$a cmp $b} keys %{$decoded}];
            }
        };
        return [];
    }
});

# tojson filter — uses pre-created encoder + HTML escaping post-processing
add_filter($env, 'tojson', sub { _json_encode_html_safe($_[0]) });

# Render the template using input from input-01.json as context
my $result = render_str($env, 'template-01.jinja', $template_source, $context);

if (!defined($result)) {
    my $detail = error_exists() ? error_detail() : 'unknown error';
    die "Jinja rendering failed: $detail\n";
}

# Load expected output and compare (or save if MINIJINJA_UPDATE_EXPECTATIONS=1)
my $expected_path = "$resources_dir/input-01.out";

if (exists $ENV{MINIJINJA_UPDATE_EXPECTATIONS} && $ENV{MINIJINJA_UPDATE_EXPECTATIONS}) {
    open my $wfh, '>', $expected_path or die "Cannot write '$expected_path': $!\n";
    print $wfh $result;
    close $wfh;
    print STDERR "Updated expected output: input-01.out\n";
} else {
    unless (-f $expected_path) {
        die "Expected output file not found: '$expected_path'. Run with MINIJINJA_UPDATE_EXPECTATIONS=1 to generate it.\n";
    }
    open my $efh, '<', $expected_path or die "Cannot open '$expected_path': $!\n";
    local $/;
    my $expected_output = <$efh>;
    close $efh;

    is($result, $expected_output, 'rendered output matches expected');
}
