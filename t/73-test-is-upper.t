use strict; use warnings;
use Test::More tests => 5;

use Minijinja qw(minijinja add_test render_str);

my $env = minijinja();
add_test($env, 'is_upper', \&Minijinja::Test::is_upper);

# Uppercase strings vs others
is(render_str($env, 'tpl.j2', "{% set x = 'HELLO' %}{% if x is is_upper %}1{% else %}0{% endif %}", {}), '1', '"HELLO" IS all uppercase');
is(render_str($env, 'tpl.j2', "{% set x = 'hello' %}{% if x is is_upper %}1{% else %}0{% endif %}", {}), '0', '"hello" is NOT all uppercase');
is(render_str($env, 'tpl.j2', "{% set x = 'Hello' %}{% if x is is_upper %}1{% else %}0{% endif %}", {}), '0', '"Hello" is NOT all uppercase (mixed case)');
is(render_str($env, 'tpl.j2', "{% set x = '' %}{% if x is is_upper %}1{% else %}0{% endif %}", {}), '0', 'empty string is NOT all uppercase (no cased chars)');
is(render_str($env, 'tpl.j2', "{% set x = 'HELLO WORLD' %}{% if x is is_upper %}1{% else %}0{% endif %}", {}), '1', '"HELLO WORLD" IS all uppercase');

done_testing();
