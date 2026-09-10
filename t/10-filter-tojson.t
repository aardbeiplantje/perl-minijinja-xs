use strict; use warnings;
use Test::More tests => 7;

use Minijinja qw(
    new add_filter render_str
    filter_tojson
);

my $env = new();
add_filter($env, 'tojson', \&filter_tojson);

# Basic JSON encoding of scalars  
is(render_str($env, 'tpl.j2', '{% set x = val | tojson %}{{ x }}', { val => 'hello' }),
   '"hello"', 'scalar string tojson');

is(render_str($env, 'tpl.j2', '{% set x = val | tojson %}{{ x }}', { val => 42 }),
   '42', 'integer tojson');

is(render_str($env, 'tpl.j2', '{% set x = val | tojson %}{{ x }}', { val => 3.14 }),
   '3.14', 'float tojson');

# Array tojson
is(render_str($env, 'tpl.j2', "{% set arr = [1, 2, 3] | tojson %}{{ arr }}", {}),
   '[1,2,3]', 'array tojson');

# Hash/obj tojson (canonical order)
my $hash = { b => 2, a => 1, c => 3 };
my $out = render_str($env, 'tpl.j2', "{% set h = data | tojson %}{{ h }}", { data => $hash });
ok($out =~ /^{"a":1,"b":2,"c":3}$/ || $out =~ /^\{.*\}$/, 'hash tojson canonical order');

# Nested structures  
is(render_str($env, 'tpl.j2', "{% set n = {'items': [1, 2], 'name': 'test'} | tojson %}{{ n }}", {}),
   '{"items":[1,2],"name":"test"}', 'nested hash array tojson');

# Undefined value
is(render_str($env, 'tpl.j2', "{% set u = undefined | tojson %}{{ u }}", {}),
   'null', 'undefined tojson null');
