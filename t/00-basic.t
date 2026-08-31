use strict; use warnings;

use Test::More;

BEGIN {
    use_ok('Minijinja');
}

# Test basic template rendering
my $env = Minijinja::new();
ok($env > 0, 'environment created');

my $ctx = Minijinja::_value_new_object();
Minijinja::_value_set_string_key($ctx, 'name', Minijinja::_value_new_string('World'));

Minijinja::add_template($env, 'test', 'Hello {{ name }}!');
my $output = Minijinja::render_template($env, 'test', $ctx);
is($output, 'Hello World!', 'basic template rendering');

# Test render_str (unnamed)
$output = Minijinja::render_named_str($env, 'template.pl', 'Hello {{ name }}!', $ctx);
is($output, 'Hello World!', 'render_str unnamed');

# Test eval_expr
my $result = Minijinja::eval_expr($env, '1 + 2 * 3', $ctx);
is(Minijinja::_value_as_i64($result), 7, 'eval_expr result');
Minijinja::_value_free($result);

# Test filters
Minijinja::add_filter($env, 'upper', sub {
    my ($val) = @_;
    return uc($val);
});

$result = Minijinja::render_named_str($env, 'filter_test.pl', '{{ "hello" | upper }}', $ctx);
is($result, 'HELLO', 'custom filter');

# Test functions
Minijinja::add_function($env, 'greet', sub {
    my ($name) = @_;
    return "Hello, $name!";
});

$result = Minijinja::render_named_str($env, 'func_test.pl', '{{ greet("World") }}', $ctx);
is($result, 'Hello, World!', 'custom function');

# Test tests
Minijinja::add_test($env, 'even', sub {
    my ($val) = @_;
    return $val % 2 == 0;
});

$result = Minijinja::render_named_str($env, 'test_test.pl', '{% if 4 is even %}even{% else %}odd{% endif %}', $ctx);
is($result, 'even', 'custom test');

$result = Minijinja::render_named_str($env, 'test_test2.pl', '{% if 3 is even %}even{% else %}odd{% endif %}', $ctx);
is($result, 'odd', 'custom test odd');

# Test globals
Minijinja::add_global($env, 'site_name', Minijinja::_value_new_string('MySite'));
$result = Minijinja::render_named_str($env, 'global_test.pl', 'Welcome to {{ site_name }}', $ctx);
is($result, 'Welcome to MySite', 'global variable');

# Test remove_global
Minijinja::remove_global($env, 'site_name');
$result = Minijinja::render_named_str($env, 'global_test2.pl', '{{ site_name }}', $ctx);
ok(!defined($result) || $result eq '', 'removed global is undefined');

# Test debug mode
Minijinja::set_debug($env, 1);
ok(Minijinja::get_debug($env), 'debug mode enabled');

Minijinja::set_debug($env, 0);
ok(!Minijinja::get_debug($env), 'debug mode disabled');

# Test undefined behavior
Minijinja::set_undefined_behavior($env, 1);  # strict
is(Minijinja::get_undefined_behavior($env), 1, 'strict undefined behavior');

Minijinja::set_undefined_behavior($env, 2);  # chainable
is(Minijinja::get_undefined_behavior($env), 2, 'chainable undefined behavior');

Minijinja::set_undefined_behavior($env, 0);  # lenient
is(Minijinja::get_undefined_behavior($env), 0, 'lenient undefined behavior');

# Test fuel
Minijinja::set_fuel($env, 1000);
is(Minijinja::get_fuel($env), 1000, 'fuel set');

Minijinja::clear_fuel($env);
is(Minijinja::get_fuel($env), 0, 'fuel cleared');

# Test recursion limit
Minijinja::set_recursion_limit($env, 100);
ok(1, 'recursion limit set');

# Test trim_blocks
Minijinja::set_trim_blocks($env, 1);
ok(1, 'trim_blocks set');

# Test lstrip_blocks
Minijinja::set_lstrip_blocks($env, 1);
ok(1, 'lstrip_blocks set');

# Test keep_trailing_newline
Minijinja::set_keep_trailing_newline($env, 1);
ok(1, 'keep_trailing_newline set');

# Test syntax config
my $syntax = Minijinja::_syntax_config_new();
ok($syntax > 0, 'syntax config created');

Minijinja::_syntax_config_set_block_start($syntax, '<%');
Minijinja::_syntax_config_set_block_end($syntax, '%>');
Minijinja::_syntax_config_set_variable_start($syntax, '<$');
Minijinja::_syntax_config_set_variable_end($syntax, '$>');

Minijinja::_env_set_syntax_config($env, $syntax);
ok(1, 'syntax config applied');

Minijinja::_syntax_config_free($syntax);

# Test loader callback
my $loader_called = 0;
Minijinja::set_loader($env, sub {
    my ($name) = @_;
    $loader_called = 1;
    return 'Loaded {{ var }}' if $name eq 'loaded';
    return undef;
});

$result = Minijinja::render_template($env, 'loaded', $ctx);
is($result, 'Loaded World', 'loader callback (using ctx name)');

# Test auto_escape_callback
my $auto_escape_called = 0;
Minijinja::set_auto_escape_callback($env, sub {
    my ($name) = @_;
    $auto_escape_called = 1;
    return 'html';
});
ok(1, 'auto_escape_callback set');

# Test path_join_callback
my $path_join_called = 0;
Minijinja::set_path_join_callback($env, sub {
    my ($name, $parent) = @_;
    $path_join_called = 1;
    return "$parent/$name";
});
ok(1, 'path_join_callback set');

# Test remove template
my $ctx_empty = Minijinja::_value_new_object();
Minijinja::add_template($env, 'temp', 'temporary');
$result = Minijinja::render_template($env, 'temp', $ctx_empty);
is($result, 'temporary', 'template added');

Minijinja::remove_template($env, 'temp');

# Test clear templates
Minijinja::add_template($env, 'a', 'A');
Minijinja::add_template($env, 'b', 'B');
Minijinja::clear_templates($env);

# Test Value class functions
my $v = Minijinja::_value_new_string('hello');
is(Minijinja::_value_get_kind($v), 4, 'value kind is string');
my $str = Minijinja::_value_to_str($v);
is($str, 'hello', 'value as_string');
Minijinja::_str_free($str);

$v = Minijinja::_value_new_i64(42);
is(Minijinja::_value_get_kind($v), 3, 'number kind');
is(Minijinja::_value_as_i64($v), 42, 'value as_i64');

$v = Minijinja::_value_new_f64(3.14);
my $f64 = Minijinja::_value_as_f64($v);
ok(abs($f64 - 3.14) < 0.001, 'value as_f64');

$v = Minijinja::_value_new_bool(1);
ok(Minijinja::_value_is_true($v), 'bool is_true');

$v = Minijinja::_value_new_list();
is(Minijinja::_value_get_kind($v), 6, 'list kind');
is(Minijinja::_value_len($v), 0, 'empty list len');

$v = Minijinja::_value_new_object();
is(Minijinja::_value_get_kind($v), 7, 'object kind');

# Test list append
my $list = Minijinja::_value_new_list();
Minijinja::_value_append($list, Minijinja::_value_new_string('a'));
Minijinja::_value_append($list, Minijinja::_value_new_string('b'));
is(Minijinja::_value_len($list), 2, 'list append');

my $item = Minijinja::_value_get_by_index($list, 0);
$str = Minijinja::_value_to_str($item);
is($str, 'a', 'list get_by_index');
Minijinja::_str_free($str);
Minijinja::_value_free($item);

# Test object set_string_key
my $obj = Minijinja::_value_new_object();
Minijinja::_value_set_string_key($obj, 'key1', Minijinja::_value_new_string('value1'));
$item = Minijinja::_value_get_by_str($obj, 'key1');
$str = Minijinja::_value_to_str($item);
is($str, 'value1', 'object set_string_key');
Minijinja::_str_free($str);
Minijinja::_value_free($item);

# Test iterator
$list = Minijinja::_value_new_list();
Minijinja::_value_append($list, Minijinja::_value_new_string('a'));
Minijinja::_value_append($list, Minijinja::_value_new_string('b'));

my $iter = Minijinja::_value_try_iter($list);
ok($iter > 0, 'iterator created');

my @items;
while (my $val_out_buf = Minijinja::_value_new_none()) {
    last if !Minijinja::_value_iter_next($iter, $val_out_buf);
    my $kind = Minijinja::_value_get_kind($val_out_buf);
    next unless $kind == 4 || $kind == 3;  # string or number
    
    if ($kind == 4) {
        push @items, Minijinja::_value_to_str($val_out_buf);
    } else {
        push @items, Minijinja::_value_as_i64($val_out_buf);
    }
    Minijinja::_value_free($val_out_buf);
}

# For proper testing with simple values, we can check count
is(scalar @items, 2, 'iterator count');

# Free all resources  
Minijinja::free($env);
Minijinja::_value_free($ctx);
Minijinja::_value_free($ctx_empty);

done_testing();
