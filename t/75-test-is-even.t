use strict; use warnings;
use Test::More tests => 6;

use Minijinja qw(minijinja add_test render_str);

my $env = minijinja();
add_test($env, 'is_even', \&Minijinja::Test::is_even);

# Even numbers vs odd/other (truncates floats to int before check)
is(render_str($env, 'tpl.j2', "{% set x = 2 %}{% if x is is_even %}1{% else %}0{% endif %}", {}), '1', '2 IS even');
is(render_str($env, 'tpl.j2', "{% set x = 4 %}{% if x is is_even %}1{% else %}0{% endif %}", {}), '1', '4 IS even');
is(render_str($env, 'tpl.j2', "{% set x = 3 %}{% if x is is_even %}1{% else %}0{% endif %}", {}), '0', '3 is NOT even (odd)');
is(render_str($env, 'tpl.j2', "{% set x = -2 %}{% if x is is_even %}1{% else %}0{% endif %}", {}), '1', '-2 IS even');
is(render_str($env, 'tpl.j2', "{% set x = 42.5 %}{% if x is is_even %}1{% else %}0{% endif %}", {}), '1', '42.5 truncates to 42 which IS even');
is(render_str($env, 'tpl.j2', "{% if nonexistent_var is is_even %}1{% else %}0{% endif %}", {}), '0', 'undefined value is NOT even');

done_testing();
