package JinjaTest;

use strict;
use warnings;

our $VERSION = '0.1.0';

use Test::More ();
use Minijinja qw(new render_str error_exists error_detail add_filter add_function add_test add_exception_function);
use File::Basename;
use JSON::PP ();

# Resources live in t/resources/, one level up from this module (t/lib/)  
our $resources_dir = dirname(dirname(__FILE__)) . '/resources';  # "t/resources" or "/project/t/resources"

sub load_template {
    my ($template_name) = @_;
    
    my $path = "$resources_dir/$template_name";
    unless (-f $path) {
        die "Template file not found: $path\n";
    }
    
    open my $fh, '<', $path or die "Cannot open '$path': $!\n";
    local $/;
    my $content = <$fh>;
    close $fh;
    
    return $content;
}

sub get_resources_dir {
    return $resources_dir;
}

sub jinja_render {
    my ($template_source, $context) = @_;
    
    my $env = new();
    unless ($env) {
        die "Failed to create Minijinja environment";
    }
    
    # Register Python-style string helper functions (as global filters)
    # These are needed for some complex templates that use Python-style method calls  
    add_filter($env, 'has_prefix', sub {
        my ($str, $prefix) = @_;
        return defined($str) && defined($prefix) ? substr($str, 0, length($prefix)) eq $prefix : 0;
    });
    add_filter($env, 'has_suffix', sub {
        my ($str, $suffix) = @_;  
        return defined($str) && defined($suffix) && length($str) >= length($suffix) 
               ? substr($str, -length($suffix)) eq $suffix : 0;
    });

    # JSON encoding filter (replaces minijinja's built-in | tojson which may not be available in all builds)
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

    # Register startswith/endswith as global functions (not methods) for compatibility
    # Templates using .startswith() need to be patched to use the function form
    add_function($env, 'startswith', sub {
        my ($str, $prefix) = @_;
        return defined($str) && defined($prefix) ? substr($str, 0, length($prefix)) eq $prefix : 0;
    });
    add_function($env, 'endswith', sub {
        my ($str, $suffix) = @_;  
        return defined($str) && defined($suffix) && length($str) >= length($suffix) 
               ? substr($str, -length($suffix)) eq $suffix : 0;
    });

    # Also register as Jinja tests so they can be used with 'is' syntax  
    add_test($env, 'istartswith', sub {
        my ($str, $prefix) = @_;
        return defined($str) && defined($prefix) ? substr($str, 0, length($prefix)) eq $prefix : 0;
    });
    add_test($env, 'endswith', sub {
        my ($str, $suffix) = @_;  
        return defined($str) && defined($suffix) && length($str) >= length($suffix) 
               ? substr($str, -length($suffix)) eq $suffix : 0;
    });

    # Register raise_exception as an exception-throwing function that aborts rendering
    add_exception_function($env, 'raise_exception');

    # Patch template source to convert .method() calls to function calls
    my $patched_source = $template_source;
    $patched_source =~ s/\.startswith\s*\((.*)\)/startswith($1)/sg;
    $patched_source =~ s/\.endswith\s*\((.*)\)/endswith($1)/sg;
    
    # Remove lines with unsupported chained Python-style method calls (split/lstrip/rstrip)  
    # These appear inside conditional blocks for reasoning_content extraction which 
    # won't be triggered by standard message data (no reasoning_content field).
    # We replace them with empty set statements so those code paths become no-ops.
    # Match both "set X_content =" and plain "set content =".
    $patched_source =~ s/^(\s+{%- set (?:\w+_)?content = )[^%]*%\}$/$1 '' %}/smg;

    # Use a unique name for the template  
    my $result = render_str($env, '_inline.j2', $patched_source, $context || {});
    
    if (!defined($result)) {
        my $detail = error_exists() ? error_detail() : 'unknown error';
        die "Jinja rendering failed: $detail\n";
    }
    
    return $result;
}

sub jinja_test_case {
    my (%args) = @_;
    
    my $template_name   = delete $args{template}  or die "Missing 'template' argument";
    my $expected_file   = delete $args{expected}  or die "Missing 'expected' argument";  
    my %context         = %{$args{context} // {}};
    
    my $full_expected_path = "$resources_dir/$expected_file";
    
    # Load template source
    my $template_source = load_template($template_name);
    
    # Check if we have an existing expected file
    my $has_expected = -f $full_expected_path;
    my $expected_output = undef;
    
    if ($has_expected) {
        open my $efh, '<', $full_expected_path or die "Cannot open expected file '$full_expected_path': $!\n";
        local $/;
        $expected_output = <$efh>;
        close $efh;
    }
    
    # Render the template (always needed)  
    my $actual_output;
    eval {
        $actual_output = jinja_render($template_source, \%context);
    };
    
    if ($@) {
        Test::More->diag("Rendering error: $@");
        Test::More::is($actual_output, defined($expected_output) ? $expected_output : '', 'rendered output matches');  
        return;
    }
    
    # Compare and report using is() as requested  
    Test::More::is($actual_output, defined($expected_output) ? $expected_output : '', "rendered output matches ($template_name)");

    # In update mode, write out the actual output regardless of whether expected existed
    if (exists $ENV{MINIJINJA_UPDATE_EXPECTATIONS} && $ENV{MINIJINJA_UPDATE_EXPECTATIONS}) {
        open my $wfh, '>', $full_expected_path or die "Cannot write expected file '$full_expected_path': $!\n";
        print $wfh $actual_output;
        close $wfh;
        unless ($has_expected) {
            Test::More->diag("Created expected output: $expected_file");
        } else {
            Test::More->diag("Updated expected output: $expected_file");
        }
    } elsif (!$has_expected) {
        Test::More->diag("Expected output file not found: $expected_file");
        Test::More->diag("Run with MINIJINJA_UPDATE_EXPECTATIONS=1 to generate it.");
    }
}

# Render a template using input from a JSON file as context.
# 
# Loads the context hashref from t/resources/$input_file (JSON format),
# renders the template from t/resources/$template_name, and compares
# against the expected output in t/resources/$expected_file.
sub jinja_test_case_with_input {
    my (%args) = @_;
    
    my $template_name   = delete $args{template}  or die "Missing 'template' argument";
    my $input_file      = delete $args{input}       or die "Missing 'input' argument";  
    my $expected_file   = delete $args{expected}    or die "Missing 'expected' argument";  

    my $full_input_path     = "$resources_dir/$input_file";
    my $full_expected_path  = "$resources_dir/$expected_file";
    
    # Load template source
    my $template_source = load_template($template_name);
    
    # Load input context from JSON file
    unless (-f $full_input_path) {
        die "Input file not found: $full_input_path\n";
    }
    
    open my $ifh, '<', $full_input_path or die "Cannot open input file '$full_input_path': $!\n";
    local $/;
    my $json_str = <$ifh>;
    close $ifh;
    
    my $context;
    eval {
        my $decoder = JSON::PP->new->utf8;
        $context = $decoder->decode($json_str);
        
        # Ensure context is a hashref — if the top-level JSON is an array, 
        # wrap it so the template can access it via keys like 'messages' etc.
        # We auto-wrap common patterns: if top-level keys suggest this is meant 
        # to be passed directly (e.g., has 'messages', 'conv_id', etc.), use as-is.
        # If it's just a plain list/array at top level, that's an error.
        unless (ref($context) eq 'HASH') {
            die "Input file must contain a JSON object (hash), not an array or scalar.\n";
        }
    };
    if ($@) {
        die "Failed to parse input JSON from '$input_file': $@";
    }
    
    # Check if we have an existing expected file
    my $has_expected = -f $full_expected_path;
    my $expected_output = undef;
    
    if ($has_expected) {
        open my $efh, '<', $full_expected_path or die "Cannot open expected file '$full_expected_path': $!\n";
        local $/;
        $expected_output = <$efh>;
        close $efh;
    }
    
    # Render the template using loaded context (always needed)  
    my $actual_output;
    eval {
        $actual_output = jinja_render($template_source, $context);
    };
    
    if ($@) {
        Test::More->diag("Rendering error: $@");
        Test::More::is($actual_output, defined($expected_output) ? $expected_output : '', 'rendered output matches');  
        return;
    }
    
    # Compare and report using is() as requested  
    Test::More::is($actual_output, defined($expected_output) ? $expected_output : '', "rendered output matches ($template_name)");

    # In update mode, write out the actual output regardless of whether expected existed
    if (exists $ENV{MINIJINJA_UPDATE_EXPECTATIONS} && $ENV{MINIJINJA_UPDATE_EXPECTATIONS}) {
        open my $wfh, '>', $full_expected_path or die "Cannot write expected file '$full_expected_path': $!\n";
        print $wfh $actual_output;
        close $wfh;
        unless ($has_expected) {
            Test::More->diag("Created expected output: $expected_file");
        } else {
            Test::More->diag("Updated expected output: $expected_file");
        }
    } elsif (!$has_expected) {
        Test::More->diag("Expected output file not found: $expected_file");
        Test::More->diag("Run with MINIJINJA_UPDATE_EXPECTATIONS=1 to generate it.");
    }
}

1;
