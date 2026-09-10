use strict; use warnings;
use Test::More tests => 6;

use Minijinja qw(minijinja add_test render_str);

my $env = minijinja();
add_test($env, 'is_divisibleby', \&Minijinja::Test::is_divisibleby);

# Divisible by checks
is(render_str($env, 'tpl.j2', "{% set x = 6 %}{% if x is is_divisibleby(3) %}1{% else %}0{% endif %}", {}), '1', '6 IS divisible by 3');
is(render_str($env, 'tpl.j2', "{% set x = 7 %}{% if x is is_divisibleby(3) %}1{% else %}0{% endif %}", {}), '0', '7 is NOT divisible by 3');
is(render_str($env, 'tpl.j2', "{% set x = 10 %}{% if x is is_divisibleby(5) %}1{% else %}0{% endif %}", {}), '1', '10 IS divisible by 5');
is(render_str($env, 'tpl.j2', "{% set x = -6 %}{% if x is is_divisibleby(3) %}1{% else %}0{% endif %}", {}), '1', '-6 IS divisible by 3');
is(render_str($env, 'tpl.j2', "{% set x = 0 %}{% if x is is_divisibleby(5) %}1{% else %}0{% endif %}", {}), '1', '0 IS divisible by any non-zero number');
is(render_str($env, 'tpl.j2', "{% set x = 5 %}{% if x is is_divisibleby(0) %}1{% else %}0{% endif %}", {}), '0', 'nothing IS divisible by zero');

done_testing();
