use strict; use warnings;
use Test::More tests => 5;

use Minijinja qw(minijinja add_test render_str);

my $env = minijinja();
add_test($env, 'is_lower', \&Minijinja::Test::is_lower);

# Lowercase strings vs others
is(render_str($env, 'tpl.j2', "{% set x = 'hello' %}{% if x is is_lower %}1{% else %}0{% endif %}", {}), '1', '"hello" IS all lowercase');
is(render_str($env, 'tpl.j2', "{% set x = 'HELLO' %}{% if x is is_lower %}1{% else %}0{% endif %}", {}), '0', '"HELLO" is NOT all lowercase');
is(render_str($env, 'tpl.j2', "{% set x = 'Hello' %}{% if x is is_lower %}1{% else %}0{% endif %}", {}), '0', '"Hello" is NOT all lowercase (mixed case)');
is(render_str($env, 'tpl.j2', "{% set x = '' %}{% if x is is_lower %}1{% else %}0{% endif %}", {}), '0', 'empty string is NOT all lowercase (no cased chars)');
is(render_str($env, 'tpl.j2', "{% set x = 'hello world' %}{% if x is is_lower %}1{% else %}0{% endif %}", {}), '1', '"hello world" IS all lowercase');

done_testing();

1;
