use strict; use warnings;
use Test::More tests => 5;

use Minijinja qw(minijinja add_test render_str);

my $env = minijinja();
add_test($env, 'is_iterable', \&Minijinja::Test::is_iterable);

# Iterable vs non-iterable types
is(render_str($env, 'tpl.j2', "{% set x = [1,2,3] %}{% if x is is_iterable %}1{% else %}0{% endif %}", {}), '1', 'array IS iterable');
is(render_str($env, 'tpl.j2', "{% set x = {'a': 1} %}{% if x is is_iterable %}1{% else %}0{% endif %}", {}), '1', 'hash IS iterable');
is(render_str($env, 'tpl.j2', "{% set x = 'hello' %}{% if x is is_iterable %}1{% else %}0{% endif %}", {}), '1', 'string IS iterable');
is(render_str($env, 'tpl.j2', "{% set x = 42 %}{% if x is is_iterable %}1{% else %}0{% endif %}", {}), '1', 'integer IS iterable (treated as scalar)');
is(render_str($env, 'tpl.j2', "{% if nonexistent_var is is_iterable %}1{% else %}0{% endif %}", {}), '0', 'undefined value is NOT iterable');

done_testing();

1;
