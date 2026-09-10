use strict; use warnings;
use Test::More tests => 3;

use Minijinja qw(new add_filter render_str);


my $env = new();
add_filter($env, 'length_str', \&Minijinja::Filter::length_str);

is(render_str($env, 'tpl.j2', "{% set x = 'hello' | length_str %}{{ x }}", {}), '5', 'length string');
is(render_str($env, 'tpl.j2', "{% set x = '' | length_str %}{{ x }}", {}), '0', 'length empty string');
is(render_str($env, 'tpl.j2', "{% set x = 42 | length_str %}{{ x }}", {}), '2', 'length from number');

done_testing();
