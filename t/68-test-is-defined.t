use strict; use warnings;
use Test::More tests => 5;

use Minijinja qw(minijinja add_test render_str);

my $env = minijinja();
add_test($env, 'is_defined', \&Minijinja::Test::is_defined);

# Defined vs undefined values (opposite of is_undefined)
is(render_str($env, 'tpl.j2', "{% set x = '' %}{% if x is is_defined %}1{% else %}0{% endif %}", {}), '1', 'empty string IS defined');
is(render_str($env, 'tpl.j2', "{% set x = 42 %}{% if x is is_defined %}1{% else %}0{% endif %}", {}), '1', 'integer IS defined');
is(render_str($env, 'tpl.j2', "{% set x = [1,2] %}{% if x is is_defined %}1{% else %}0{% endif %}", {}), '1', 'array IS defined');
is(render_str($env, 'tpl.j2', "{% set x = {'a': 1} %}{% if x is is_defined %}1{% else %}0{% endif %}", {}), '1', 'hash IS defined');
is(render_str($env, 'tpl.j2', "{% if nonexistent_var is is_defined %}1{% else %}0{% endif %}", {}), '0', 'missing variable is NOT defined');

done_testing();
