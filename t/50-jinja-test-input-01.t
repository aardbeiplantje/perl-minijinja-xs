use strict; use warnings;
use Test::More tests => 1;

use lib 't/lib';

use Minijinja qw(new render_str error_exists error_detail add_filter add_function add_test);

# Fully-qualified namespaced references for clarity:
my $fn_startswith  = \&Minijinja::Function::_startswith_impl;
my $fn_endswith    = \&Minijinja::Function::_endswith_impl;
my $filter_tojson  = \&Minijinja::Filter::tojson;
my $filter_items   = \&Minijinja::Filter::items;

use File::Basename;
use JSON::PP ();

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

my $context = JSON::PP->new->utf8->decode($json_str);
my $env = new();

# startswith — identical lambda semantics to llama.cpp jinja parser
add_function($env, 'startswith', $fn_startswith);

# endswith — identical lambda semantics to llama.cpp jinja parser
add_function($env, 'endswith', $fn_endswith);

# Also register as Jinja tests so they work with `is` syntax (line 72 uses `is not mapping`)
add_test($env, 'istartswith', sub { $fn_startswith->(@_) });
add_test($env, 'endswith', sub { $fn_endswith->(@_) });

# raise_exception — dies so rendering aborts and error_detail() returns the message
add_function($env, 'raise_exception', \&Minijinja::Function::raise_exception);

# items — Perl equivalent of Python safe_items (myjinja.py lines 6-17)
add_filter($env, 'items', $filter_items);

# tojson filter — uses pre-created encoder + HTML escaping post-processing
add_filter($env, 'tojson', $filter_tojson);

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
