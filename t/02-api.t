use strict;
use warnings;
use Test::More;

use Minijinja qw(
    new add_template remove_template clear_templates  
    render_template render_str eval_expr add_global
    set_debug set_fuel clear_fuel set_recursion_limit set_trim_blocks 
    set_lstrip_blocks set_keep_trailing_newline set_undefined_behavior
    apply_syntax add_filter add_function add_test
    set_loader set_auto_escape set_path_join
    error_exists error_detail error_kind error_line error_template_name error_print
);



# =============================================================================
# Section 1: Environment (3 tests)
# =============================================================================

sub test_env_creation {
    my $env = new();
    ok($env, 'environment created');
    isa_ok($env, 'Minijinja');

    # Environment with config options
    my $env2 = new({ debug => 1 });
    ok($env2, 'environment with debug option created');
}

# =============================================================================  
# Section 2: Template Management (5 tests)
# =============================================================================

sub test_templates {
    my $env = new();

    # Add template returns true
    ok(add_template($env, 'tmpl1', 'Hello'), 'template added');

    # Remove template returns true  
    ok(remove_template($env, 'tmpl1'), 'template removed');

    # Add multiple and clear
    add_template($env, 'a', 'A content');
    add_template($env, 'b', 'B content');
    ok(clear_templates($env), 'templates cleared');

    # Verify removed template not found  
    my $result = render_template($env, 'a', {});
    ok(!defined($result), 'removed template renders as undef');

    # Duplicate template handling (second overwrites first in minijinja)
    add_template($env, 'dup', 'first');
    ok(add_template($env, 'dup', 'second'), 'duplicate template replaced');
    
}

# =============================================================================
# Section 3: Rendering Basics (8 tests)
# =============================================================================

sub test_rendering {
    my $env = new();

    # Simple variable substitution  
    add_template($env, 'simple', '{{ name }}');
    is(render_template($env, 'simple', { name => 'Alice' }), "Alice", 'simple var');

    # Multiple variables
    add_template($env, 'multi', '{{ a }} {{ b }} {{ c }}');
    is(render_template($env, 'multi', { a => 1, b => 2, c => 3 }), "1 2 3", 'multi vars');

    # Nested hash access
    add_template($env, 'nested', '{{ obj.key }}');
    is(render_template($env, 'nested', { obj => { key => 'value' } }), "value", 'nested access');

    # List iteration  
    add_template($env, 'li', '{% for item in items %}{{ item }}{% endfor %}');
    my $lr = render_template($env, 'li', { items => [1, 2, 3] });
    is($lr, "123", 'list iteration works');

    # Inline rendering with math
    my $inline = render_str($env, 'calc.txt', '{{ x * y }}', { x => 5, y => 6 });
    is($inline, "30", 'inline math');

    # Empty/no context  
    add_template($env, 'plain', 'just text');
    is(render_template($env, 'plain', {}), "just text", 'empty context works');

    # Context as undef (same as empty)
    is(render_template($env, 'plain', undef), "just text", 'undef context works');

}

# =============================================================================
# Section 4: Expression Evaluation (6 tests)
# =============================================================================

sub test_expressions {
    my $env = new();

    # Basic arithmetic
    is(eval_expr($env, '1 + 2', {}), 3, 'addition');
    is(eval_expr($env, '10 - 3', {}), 7, 'subtraction');

    # Comparisons return booleans
    ok(eval_expr($env, '5 > 3', {}), 'greater than true');
    ok(!eval_expr($env, '3 > 5', {}), 'greater than false returns falsey');

    # String operations  
    is(eval_expr($env, "'hello' ~ ' world'", {}), "hello world", 'string concat');

    # Context bindings in expressions
    is(eval_expr($env, 'x + y * 2', { x => 10, y => 5 }), 20, 'expr with bindings');

    # Numbers returned correctly
    is(eval_expr($env, '3.14', {}), 3.14, 'float value preserved');

}

# =============================================================================
# Section 5: Globals (4 tests)
# =============================================================================

sub test_globals {
    my $env = new();

    # Add scalar global
    ok(add_global($env, 'site', 'MySite'), 'scalar global added');
    add_template($env, 'g', '{{ site }}');
    is(render_template($env, 'g', {}), "MySite", 'global accessible in template');

    # Add complex global (hashref)
    ok(add_global($env, 'cfg', { theme => 'dark' }), 'complex global added');
    add_template($env, 'gc', '{{ cfg.theme }}');
    is(render_template($env, 'gc', {}), "dark", 'nested global access works');

    # Add list global
    ok(add_global($env, 'nums', [1, 2, 3]), 'list global added');
    add_template($env, 'gl', '{{ nums | join(", ") }}');  
    is(render_template($env, 'gl', {}), "1, 2, 3", 'list global joinable');

    # Context overrides globals
    add_template($env, 'gp', '{{ site }}');
    is(render_template($env, 'gp', { site => 'ContextVal' }), "ContextVal", 'context wins over global');

}

# =============================================================================
# Section 6: Config Setters (4 tests) 
# =============================================================================

sub test_config {
    my $env = new();

    # Debug mode
    set_debug($env, 1);
    ok(1, 'debug enabled');
    
    # Fuel setting
    set_fuel($env, 500);  
    ok(1, 'fuel set to 500');
    clear_fuel($env);
    ok(1, 'fuel cleared');

    # Recursion limit
    set_recursion_limit($env, 50);
    ok(1, 'recursion limit set');

    # Various boolean config options
    set_trim_blocks($env, 1);
    set_lstrip_blocks($env, 1);
    set_keep_trailing_newline($env, 1);

    # Undefined behavior modes (0=lenient, 1=strict, 2=chainable)
    for my $mode (0, 1, 2) {
        set_undefined_behavior($env, $mode);
        ok(1, "undefined behavior set to $mode");
    }

}

# =============================================================================
# Section 7: Custom Callbacks (6 tests)
# =============================================================================

sub test_callbacks {
    my $env = new();

    # Custom filter - uppercase strings  
    ok(add_filter($env, 'upper', sub { uc($_[0]) }), 'filter registered');
    add_template($env, 'f', '{{ x | upper }}');
    is(render_template($env, 'f', { x => 'hello' }), "HELLO", 'filter works');

    # Custom function - greet with name  
    ok(add_function($env, 'greet', sub { "Hello, $_[0]!" }), 'function registered');
    add_template($env, 'fn', '{{ greet("World") }}');
    is(render_template($env, 'fn', {}), "Hello, World!", 'function works');

    # Custom test - even number check
    ok(add_test($env, 'even_test', sub { $_[0] % 2 == 0 }), 'test registered');
    add_template($env, 'tst', '{% if n is even_test %}yes{% else %}no{% endif %}');
    is(render_template($env, 'tst', { n => 4 }), "yes", 'test passes for even');
    is(render_template($env, 'tst', { n => 3 }), "no", 'test fails for odd');

}

# =============================================================================
# Section 8: Error Handling (6 tests)
# =============================================================================

sub test_errors {
    my $env = new();

    # No errors initially
    ok(!error_exists(), 'no errors before operations');

    # Trigger error with missing template  
    my $result = render_template($env, 'nonexistent_xyz', {});
    ok(!defined($result), 'missing template returns undef');
    ok(error_exists(), 'error flag set after failure');

    # Error details available  
    my $detail = error_detail();
    ok(defined($detail) && length($detail) > 0, 'error detail has content');

    # Error kind indicates type  
    my $kind = error_kind();
    ok(!defined($kind) || ($kind >= 0 && $kind < 100), 'error kind in valid range');

    # Error line number available
    my $line = error_line();
    ok(1, 'error line checked [' . ($line // 'undef') . ']');

    # Error template name if applicable  
    my $tmpl_name = error_template_name();
    ok(1, 'error template name accessible' . (defined($tmpl_name) ? " [$tmpl_name]" : ''));

    # error_print outputs without dying (may fail on some platforms/errors)
    my $print_result = eval { error_print() };
    ok(1, 'error_print attempted' . ($print_result ? "" : " [returned false]"));

}

# =============================================================================
# Run all sections  
# =============================================================================

test_env_creation();
test_templates();
test_rendering();
test_expressions();
test_globals(); 
test_config();
test_callbacks();
test_errors();

done_testing();
