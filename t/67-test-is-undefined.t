use strict; use warnings;
use Test::More tests => 5;

use Minijinja qw(minijinja add_test render_str);

my $env = minijinja();
add_test($env, 'is_undefined', \&Minijinja::Test::is_undefined);

# Undefined vs defined values
is(render_str($env, 'tpl.j2', "{% set x = '' %}{% if x is is_undefined %}1{% else %}0{% endif %}", {}), '0', 'empty string is NOT undefined');
is(render_str($env, 'tpl.j2', "{% set x = 42 %}{% if x is is_undefined %}1{% else %}0{% endif %}", {}), '0', 'integer is NOT undefined');
is(render_str($env, 'tpl.j2', "{% set x = [1,2] %}{% if x is is_undefined %}1{% else %}0{% endif %}", {}), '0', 'array is NOT undefined');
is(render_str($env, 'tpl.j2', "{% set x = {'a': 1} %}{% if x is is_undefined %}1{% else %}0{% endif %}", {}), '0', 'hash is NOT undefined');
is(render_str($env, 'tpl.j2', "{% if nonexistent_var is is_undefined %}1{% else %}0{% endif %}", {}), '1', 'missing variable IS undefined');

done_testing();

1;
