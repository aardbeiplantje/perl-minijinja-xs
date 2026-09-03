use strict;
use warnings;
use Test::More tests => 7;

use Minijinja qw(
    new add_template remove_template clear_templates
    render_template render_str eval_expr
    error_exists error_detail error_debug_info
    error_kind error_line error_template_name error_print
);

# Smoke test: environment creation and destruction (no explicit free needed)
my $env = new();
ok($env, 'environment created');

# Smoke test: template registration + rendering with hashref context  
add_template($env, 'hello', 'Hello {{ name }}!');
is(render_template($env, 'hello', { name => 'World' }), "Hello World!", 'basic render');

# Smoke test: inline template rendering  
is(render_str($env, 'inline.pl', '{{ greeting }}!', { greeting => 'Hi there' }), "Hi there!", 'inline render');

# Smoke test: expression evaluation without context
is(eval_expr($env, '1 + 2 * 3', {}), 7, 'eval_expr arithmetic');
is(eval_expr($env, "'Hello, ' ~ name ~ '!'", { name => 'World' }), 'Hello, World!', 'eval_expr string concat');

# Smoke test: boolean expressions in templates
add_template($env, 'bool_test', "{% if n is even %}even{% else %}odd{% endif %}");
is(render_template($env, 'bool_test', { n => 4 }), "even", 'boolean condition true');
is(render_template($env, 'bool_test', { n => 3 }), "odd", 'boolean condition false');
