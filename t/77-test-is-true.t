use strict; use warnings;
use Test::More tests => 5;

use Minijinja qw(minijinja add_test render_str);

my $env = minijinja();
add_test($env, 'is_true', \&Minijinja::Test::is_true);

# True values vs others
is(render_str($env, 'tpl.j2', "{% set x = 'true' %}{% if x is is_true %}1{% else %}0{% endif %}", {}), '1', '"true" IS true (identity)');
is(render_str($env, 'tpl.j2', "{% set x = 'True' %}{% if x is is_true %}1{% else %}0{% endif %}", {}), '1', '"True" IS true (identity)');
is(render_str($env, 'tpl.j2', "{% set x = 'false' %}{% if x is is_true %}1{% else %}0{% endif %}", {}), '0', '"false" is NOT true');
is(render_str($env, 'tpl.j2', "{% set x = '' %}{% if x is is_true %}1{% else %}0{% endif %}", {}), '0', 'empty string is NOT true (identity check)');
is(render_str($env, 'tpl.j2', "{% set x = 1 %}{% if x is is_true %}1{% else %}0{% endif %}", {}), '0', 'integer 1 is NOT true (identity check)');

done_testing();
