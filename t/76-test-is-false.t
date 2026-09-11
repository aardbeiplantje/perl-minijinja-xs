use strict; use warnings;
use Test::More tests => 5;

use Minijinja qw(minijinja add_test render_str);

my $env = minijinja();
add_test($env, 'is_false', \&Minijinja::Test::is_false);

# False values vs others  
is(render_str($env, 'tpl.j2', "{% set x = 'false' %}{% if x is is_false %}1{% else %}0{% endif %}", {}), '1', '"false" IS false (identity)');
is(render_str($env, 'tpl.j2', "{% set x = 'False' %}{% if x is is_false %}1{% else %}0{% endif %}", {}), '1', '"False" IS false (identity)');
is(render_str($env, 'tpl.j2', "{% set x = 'true' %}{% if x is is_false %}1{% else %}0{% endif %}", {}), '0', '"true" is NOT false');
is(render_str($env, 'tpl.j2', "{% set x = '' %}{% if x is is_false %}1{% else %}0{% endif %}", {}), '0', 'empty string is NOT false (identity check)');
is(render_str($env, 'tpl.j2', "{% set x = 0 %}{% if x is is_false %}1{% else %}0{% endif %}", {}), '0', 'integer 0 is NOT false (identity check)');

done_testing();

1;
