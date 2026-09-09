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
);

use XSLoader;
XSLoader::load('Minijinja', $VERSION);

# Pre-import all Functions.pm subs into our own namespace so users can call
# register_all() without importing anything from Minijinja::Functions themselves.
BEGIN {
    use Minijinja::Functions ();  # import nothing, just load the package

    my %exports = Minijinja::Functions->exportable_map();
    for my $name (keys %exports) {
        no strict 'refs';
        *$name = \&{"Minijinja::Functions::$name"};
    }
}

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
    my %map = Minijinja::Functions->exportable_map();
    while (my ($name, $type) = each %map) {
        if ($type eq 'filter')      { add_filter($env, $name, \&{$name}); }
        elsif ($type eq 'function') { add_function($env, $name, \&{$name}); }
        elsif ($type eq 'test')     { add_test($env, $name, \&{$name}); }
    }
}

1;
