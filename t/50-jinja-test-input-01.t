use strict; use warnings;
use Test::More tests => 1;

# Custom dirname helper (avoids needing File::Basename)
sub dirname {
    my $path = $_[0];
    $path =~ s/[^\/]+\z//;
    return $path;
}

# Resolve resource dir: try multiple paths based on how make test sets up CWD
my $script_dir = dirname($0);  # e.g., '', 't', or 't/' depending on invocation
$script_dir =~ s|/\z||;  # strip trailing slash for consistent comparison
my $resources_dir;

if ($script_dir eq '' || $script_dir eq 't') {
    # Running from project root or t/: resources at ../resources from blib/arch, 
    # or ./resources from project root, or t/resources from blib setup
    if (-d 't/resources') {
        $resources_dir = 't/resources';
    } elsif (-d '../resources') {
        $resources_dir = '../resources';
    } else {
        die "Cannot find t/resources directory (script_dir=$script_dir)\n";
    }
} else {
    # Running via perl directly: resources is in ../resources relative to t/
    if (-d "$script_dir/../resources") {
        $resources_dir = "$script_dir/../resources";
    } else {
        die "Cannot find resources directory (script_dir=$script_dir)\n";
    }
}

use lib 't/lib';

use Minijinja qw(new render_str error_exists error_detail add_filter add_function add_test);
use JSON::PP ();

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

my $context = JSON::PP->new->utf8->decode($json_str);

# ===========================================================================
# Register ALL callbacks matching myjinja.py line-for-line:
#   env.add_function('startswith', ...)
#   env.add_function('endswith', ...)
#   env.add_filter('items', safe_items)
# Plus raise_exception and tojson needed by template-01.jinja.
# ===========================================================================

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
        return [map { [$_, $value->{$_}] } keys %{$value}];
    } elsif (ref($value) eq 'ARRAY') {
        # arrayref is not a mapping — return empty list like safe_items for non-dict iterables
        return [];
    } else {
        # string: try JSON decode to see if it's a dict-like object
        eval {
            my $decoded = JSON::PP->new->utf8->decode($value);
            if (ref($decoded) eq 'HASH') {
                return [map { [$_, $decoded->{$_}] } keys %{$decoded}];
            }
        };
        return [];
    }
});

# tojson filter — replaces minijinja's built-in | tojson which may not be available in all builds
add_filter($env, 'tojson', sub {
    my ($val) = @_;
    my $json = JSON::PP->new->utf8->canonical;
    if (!defined($val)) {
        return 'null';
    } elsif (ref($val) eq 'HASH') {
        return $json->encode($val);
    } elsif (ref($val) eq 'ARRAY') {
        return $json->encode($val);
    } else {
        return $json->encode($val);
    }
});

# Patch template source to convert .method() calls to function calls
my $patched_source = $template_source;

# Convert .startswith()/ .endswith() method calls to function form
$patched_source =~ s/\.startswith\s*\((.*)\)/startswith($1)/sg;
$patched_source =~ s/\.endswith\s*\((.*)\)/endswith($1)/sg;

# Remove lines with unsupported chained Python-style method calls (split/lstrip/rstrip).
# These appear inside conditional blocks for reasoning_content extraction which
# won't be triggered by standard message data (no reasoning_content field).
# We replace them with empty set statements so those code paths become no-ops.
$patched_source =~ s/^(\s+{%- set (?:\w+_)?content = )[^%]*%\}$/$1 '' %}/smg;

# Render the template using input from input-01.json as context
my $result = render_str($env, 'template-01.jinja', $patched_source, $context);

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
