use strict; use warnings;
use Test::More tests => 6;

use Minijinja qw(minijinja add_test render_str);

my $env = minijinja();
add_test($env, 'is_in', \&Minijinja::Test::is_in);

# Membership test: needle in array haystack
is(render_str($env, 'tpl.j2', "{% set items = [1, 2, 3] %}{% set x = 2 %}{% if x is is_in(items) %}1{% else %}0{% endif %}", {}), '1', '2 IS IN [1,2,3]');
is(render_str($env, 'tpl.j2', "{% set items = [1, 2, 3] %}{% set x = 4 %}{% if x is is_in(items) %}1{% else %}0{% endif %}", {}), '0', '4 NOT IN [1,2,3]');
is(render_str($env, 'tpl.j2', "{% set items = ['a', 'b', 'c'] %}{% set x = 'b' %}{% if x is is_in(items) %}1{% else %}0{% endif %}", {}), '1', '"b" IS IN ["a","b","c"]');

# Membership test: needle in hash (key check)
is(render_str($env, 'tpl.j2', "{% set h = {'x': 1, 'y': 2} %}{% set k = 'x' %}{% if k is is_in(h) %}1{% else %}0{% endif %}", {}), '1', '"x" IS key in {"x":1,"y":2}');
is(render_str($env, 'tpl.j2', "{% set h = {'x': 1, 'y': 2} %}{% set k = 'z' %}{% if k is is_in(h) %}1{% else %}0{% endif %}", {}), '0', '"z" NOT key in {"x":1,"y":2}');

# Membership test: substring in string
is(render_str($env, 'tpl.j2', "{% set s = 'hello world' %}{% set sub = 'world' %}{% if sub is is_in(s) %}1{% else %}0{% endif %}", {}), '1', '"world" IS substring of "hello world"');

done_testing();

1;
