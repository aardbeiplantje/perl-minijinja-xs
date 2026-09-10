use strict; use warnings;
use Test::More tests => 5;

use Minijinja qw(minijinja add_test render_str);

my $env = minijinja();
add_test($env, 'is_mapping', \&Minijinja::Test::is_mapping);

# Hashref vs non-hash types
is(render_str($env, 'tpl.j2', "{% set x = {'a': 1, 'b': 2} %}{% if x is is_mapping %}1{% else %}0{% endif %}", {}), '1', 'hash IS a mapping');
is(render_str($env, 'tpl.j2', "{% set x = [1,2,3] %}{% if x is is_mapping %}1{% else %}0{% endif %}", {}), '0', 'array is NOT a mapping');
is(render_str($env, 'tpl.j2', "{% set x = 'hello' %}{% if x is is_mapping %}1{% else %}0{% endif %}", {}), '0', 'string is NOT a mapping');
is(render_str($env, 'tpl.j2', "{% set x = 42 %}{% if x is is_mapping %}1{% else %}0{% endif %}", {}), '0', 'integer is NOT a mapping');
is(render_str($env, 'tpl.j2', "{% set x = '' %}{% if x is is_mapping %}1{% else %}0{% endif %}", {}), '0', 'empty string is NOT a mapping');

done_testing();
