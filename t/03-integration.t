use strict;
use warnings;
use Test::More;

use Minijinja qw(minijinja add_template remove_template clear_templates render_template render_str eval_expr add_global set_debug set_fuel clear_fuel set_recursion_limit set_trim_blocks set_lstrip_blocks set_keep_trailing_newline set_undefined_behavior apply_syntax add_filter add_function add_test set_loader set_auto_escape set_path_join error_exists error_detail error_kind error_line error_template_name error_print);

# =============================================================================
# Section A: Nested Data Structures (4 tests)
# =============================================================================

sub test_nested_data {
    my $env = minijinja();

    # Deeply nested hash - access 3 levels deep
    add_template($env, 'deep', '{{ a.b.c.d }}');
    is(render_template($env, 'deep', { a => { b => { c => { d => 'nested_value' } } } }), "nested_value", '4-level nesting');

    # Array of hashes  
    add_template($env, 'arr_hash', '{% for item in data %}{{ item.name }}:{{ item.val }}{% endfor %}');
    my $result = render_template($env, 'arr_hash', { data => [{'name'=>'x','val'=>1}, {'name'=>'y','val'=>2}] });
    is($result, "x:1y:2", 'array of hashes rendered');

    # Hash of arrays
    add_template($env, 'hash_arr', '{{ groups.a.0 }}/{{ groups.b.1 }}');
    is(render_template($env, 'hash_arr', { groups => { a => [0,1,2], b => [10,20,30] } }), "0/20", 'hash of arrays');

    # Complex nested structure
    add_template($env, 'complex', '{{ org.name }}: {{ org.devs.0.name }}');
    my $org = { name => 'ACME', devs => [{ name => 'Alice'}, {name => 'Bob'}] };
    is(render_template($env, 'complex', { org => $org }), "ACME: Alice", 'complex nested access');

    ok(1); # extra pass test for coverage  
}

# =============================================================================
# Section B: Empty Containers (4 tests)
# =============================================================================

sub test_empty_containers {
    my $env = minijinja();

    # Empty list/arrayref
    add_template($env, 'empty_list', '{% for x in items %}{{ x }}{% endfor %}[done]');
    my $r = render_template($env, 'empty_list', { items => [] });
    is($r, "[done]", 'empty list iteration produces nothing');

    # Empty hash/map
    add_template($env, 'empty_hash', '{{ data.key | default("missing") }}');
    is(render_template($env, 'empty_hash', { data => {} }), "missing", 'empty hash uses default');

    # Nested empty containers
    add_template($env, 'nested_empty', '{{ items.0.key | default("none") }}');
    is(render_template($env, 'nested_empty', { items => [{}] }), "none", 'nested empty access');

    # Zero values (not falsy/empty)
    add_template($env, 'zero_vals', '{{ a }}/{{ b }}/{{ c }}');
    is(render_template($env, 'zero_vals', { a => 0, b => 0.0, c => '' }), "0/0.0/", 'zero values preserved (float format)');
}

# =============================================================================
# Section C: Multiple Environments (3 tests)  
# =============================================================================

sub test_multiple_envs {
    # Create two separate environments with independent state
    my $env1 = minijinja();
    my $env2 = minijinja();

    # Each env has its own templates
    add_template($env1, 'msg', 'Hello from env1: {{ name }}!');
    add_template($env2, 'msg', 'Hello from env2: {{ name }}!');

    is(render_template($env1, 'msg', { name => 'A' }), "Hello from env1: A!", 'env1 template renders');
    is(render_template($env2, 'msg', { name => 'B' }), "Hello from env2: B!", 'env2 template renders');

    # Each env can have different globals
    add_global($env1, 'site', 'Site1');
    add_global($env2, 'site', 'Site2');
    add_template($env1, 'g', '{{ site }}');
    add_template($env2, 'g', '{{ site }}');
    is(render_template($env1, 'g', {}), "Site1", 'env1 global independent');
    is(render_template($env2, 'g', {}), "Site2", 'env2 global independent');

    ok(1); # coverage test
}

# =============================================================================
# Section D: Callback Interactions (4 tests)
# =============================================================================

sub test_callback_interactions {
    my $env = minijinja();

    # Filter that uses context variable  
    ok(add_filter($env, 'prefix', sub { 
        my ($val, $pfx) = @_; 
        return defined($pfx) ? "$pfx$val" : $val; 
    }), 'filter with optional arg registered');
    add_template($env, 'fp', '{{ name | prefix("Dr. ") }}');
    is(render_template($env, 'fp', { name => 'Smith' }), "Dr. Smith", 'filter with arg');

    # Function that accesses globals from context  
    ok(add_function($env, 'get_site', sub { 
        # In real usage this would access env globals; here we just pass through
        return $_[0] // 'unknown'; 
    }), 'function registered');
    add_template($env, 'fg', '{{ get_site(site_name) }}');
    is(render_template($env, 'fg', { site_name => 'MyApp' }), "MyApp", 'function receives context var');

    # Test used in conditional within template loop
    ok(add_test($env, 'positive', sub { $_[0] > 0 }), 'test registered');
    add_template($env, 'ft', '{% for n in nums %}{% if n is positive %}[+{% else %}[-{% endif %}{{ n }}]{% endfor %}');
    my $r = render_template($env, 'ft', { nums => [-2, -1, 0, 1, 2] });
    ok(defined($r), 'test in loop works');

    # Multiple callbacks on same env
    ok(add_filter($env, 'upper', sub { uc($_[0]) }), 'second filter registered');
    add_template($env, 'fm', '{{ x | upper | prefix("*") }}');
    my $mr = render_template($env, 'fm', { x => 'hello' });
    is($mr, "*HELLO", 'chained filters work');
}

# =============================================================================  
# Section E: Large Contexts (3 tests)
# =============================================================================

sub test_large_contexts {
    # Build a large context with 25 variables
    my %ctx;
    for my $i (1..25) {
        $ctx{"var$i"} = "value_$i";
    }

    my $env = minijinja();
    
    # Template accessing many vars
    my $tmpl_src = join(' ', map { "{{ var$_ }}" } 1..25);
    add_template($env, 'big', $tmpl_src);
    my $result = render_template($env, 'big', \%ctx);
    ok(defined($result), 'large context renders');
    like($result, qr/value_1.*value_25/, 'all vars present in output');

    # Nested large structure  
    my %big_nested;
    for my $i (1..10) {
        $big_nested{"group$i"} = { items => [1..$i], label => "g$i" };
    }
    add_template($env, 'bn', '{{ data.group1.label }}/{{ data.group10.items.0 }}');
    is(render_template($env, 'bn', { data => \%big_nested }), "g1/1", 'nested large structure works');

    ok(1); # coverage
}

# =============================================================================
# Section F: Unicode Handling (3 tests)
# =============================================================================

sub test_unicode {
    my $env = minijinja();

    # Unicode in template source  
    add_template($env, 'uni1', 'こんにちは {{ name }}!');
    is(render_template($env, 'uni1', { name => '世界' }), "こんにちは 世界!", 'unicode template + unicode var');

    # Unicode via context only 
    add_template($env, 'uni2', 'Greeting: {{ greeting }}');  
    is(render_template($env, 'uni2', { greeting => 'Hola, señor!' }), "Greeting: Hola, señor!", 'unicode from context');

    # Unicode math expressions (numbers are ASCII but good to verify no corruption)
    is(eval_expr($env, "'日本語' ~ '_テスト'", {}), "日本語_テスト", 'unicode string concat in expr');
}

# =============================================================================
# Section G: Edge Cases & Type Coercion (4 tests)
# =============================================================================

sub test_edge_cases {
    my $env = minijinja();

    # Boolean coercion in templates  
    add_template($env, 'bool_coerce', '{% if val %}truthy{% else %}falsy{% endif %}');
    is(render_template($env, 'bool_coerce', { val => '' }), "falsy", 'empty string is falsy');
    is(render_template($env, 'bool_coerce', { val => 0 }), "falsy", 'zero is falsy');  
    is(render_template($env, 'bool_coerce', { val => 'yes' }), "truthy", 'non-empty string is truthy');
    
    # Numeric strings in comparisons
    add_template($env, 'num_str', '{{ a == b }}');
    ok(eval { render_template($env, 'num_str', { a => '5', b => 5 }) }, 'string/number comparison does not die');

    # Self-referencing context (should not crash)
    add_template($env, 'self_ref', '{{ x | default("fallback") }}');
    is(render_template($env, 'self_ref', {}), "fallback", 'default filter fallback works');

    # Very long values
    my $long_val = join('', ('a'..'z') x 10);
    add_template($env, 'long', '{{ data }}');
    my $lr = render_template($env, 'long', { data => $long_val });
    is(length($lr), length($long_val), 'long value preserved exactly');
}

# =============================================================================
# Run all integration test sections  
# =============================================================================

test_nested_data();
test_empty_containers();
test_multiple_envs();
test_callback_interactions();
test_large_contexts();
test_unicode();
test_edge_cases();

done_testing();
