use strict; use warnings;
use Test::More tests => 6;

use Minijinja qw(minijinja add_test render_str);

my $env = minijinja();
add_test($env, 'is_odd', \&Minijinja::Test::is_odd);

# Odd numbers vs even/other
is(render_str($env, 'tpl.j2', "{% set x = 1 %}{% if x is is_odd %}1{% else %}0{% endif %}", {}), '1', '1 IS odd');
is(render_str($env, 'tpl.j2', "{% set x = 3 %}{% if x is is_odd %}1{% else %}0{% endif %}", {}), '1', '3 IS odd');
is(render_str($env, 'tpl.j2', "{% set x = 2 %}{% if x is is_odd %}1{% else %}0{% endif %}", {}), '0', '2 is NOT odd (even)');
is(render_str($env, 'tpl.j2', "{% set x = -3 %}{% if x is is_odd %}1{% else %}0{% endif %}", {}), '1', '-3 IS odd');
is(render_str($env, 'tpl.j2', "{% set x = 42.5 %}{% if x is is_odd %}1{% else %}0{% endif %}", {}), '0', 'float is NOT odd');
is(render_str($env, 'tpl.j2', "{% if nonexistent_var is is_odd %}1{% else %}0{% endif %}", {}), '0', 'undefined value is NOT odd');

done_testing();
