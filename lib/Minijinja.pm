package Minijinja;

use strict; use warnings;

our $VERSION = "0.1.0";

use Exporter 'import';

our @EXPORT_OK = qw(
    new
    
    add_template remove_template clear_templates
    
    render_template render_str eval_expr
    
    add_global
    
    add_filter add_function add_test add_exception_function
    
    set_debug set_fuel clear_fuel set_recursion_limit
    set_trim_blocks get_trim_blocks
    set_lstrip_blocks get_lstrip_blocks  
    set_keep_trailing_newline get_keep_trailing_newline
    set_undefined_behavior get_undefined_behavior
    
    apply_syntax
    
    set_loader set_auto_escape set_path_join
    
    error_exists error_detail error_debug_info 
    error_kind error_line error_template_name error_print
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

1;
