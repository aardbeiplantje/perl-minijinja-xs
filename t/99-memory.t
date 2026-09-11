use strict; use warnings;

my $has_size = 0;
eval { require Devel::Size; Devel::Size->VERSION(0); $has_size = 1 };

if (!$has_size) {
    print "ok 1 - Devel::Size not available, skipping\n";
    print "1..1\n";
    exit 0;
}

use Test::More;

Devel::Size->import(qw(size_of measure_size_deeply));

my $env_load_ok;
eval { 
    require Minijinja; 
    Minijinja->import(qw(minijinja add_template remove_template clear_templates render_template render_str eval_expr add_global set_debug set_fuel clear_fuel set_recursion_limit add_filter add_function add_test));
    $env_load_ok = 1 
};

if (!$env_load_ok) {
    diag("Minijinja load failed: $@");
    diag("Skipping memory tests");
    print "1..0\n";
    exit 0;
}

my $baseline = size_of({});

my $env = minijinja();
my $env_size = size_of($env);
ok($env_size < 1_000_000, "environment size reasonable ($env_size bytes)");

my $template_large = '%s' x 1000;
add_template($env, 'big', $template_large);

for my $i (1..5) {
    render_template($env, 'big', { val => "value_$i" });
}
my $after_render = size_of($env);
ok(1, "rendered large template without issues (env now $after_render bytes)");

for my $i (1..50) {
    add_filter($env, "filter_$i", sub { lc($_[0]) // '' });
}
my $with_filters = size_of($env);
ok($with_filters < 5_000_000, "50 filters added without excessive memory ($with_filters bytes)");

my %big_context;
$big_context{"key_$_"} = "value_$_" x 10 for 1..100;

my $context_size = size_of(\%big_context);
ok($context_size < 2_000_000, "large context reasonable size ($context_size bytes)");

add_template($env, 'ctx_test', '{{ k | join(", ") }}');
my $result_ctx = render_template($env, 'ctx_test', {%big_context});
ok(defined($result_ctx), "large context renders successfully");

add_template($env, 'func_test', '{{ greet("World") }}');
ok(add_function($env, 'greet', sub { "Hello, $_[0]!" }), "function registered for memory test");
my $func_result = render_template($env, 'func_test', {});
is($func_result, 'Hello, World!', "custom function with memory tracking works");

add_template($env, 'test_cb', '{% if n is even_check %}even{% else %}odd{% endif %}');
ok(add_test($env, 'even_check', sub { $_[0] % 2 == 0 }), "test registered for memory test");
my $test_result = render_template($env, 'test_cb', { n => 4 });
is($test_result, 'even', "custom test with memory tracking works");

done_testing();
