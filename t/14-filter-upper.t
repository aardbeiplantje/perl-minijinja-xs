use strict; use warnings;
use Test::More tests => 5;

use Minijinja qw(minijinja add_filter render_str);


my $env = minijinja();
add_filter($env, 'upper', \&Minijinja::Filter::upper);

is(render_str($env, 'tpl.j2', "{% set x = 'hello' | upper %}{{ x }}", {}), 'HELLO');
is(render_str($env, 'tpl.j2', "{% set x = 'Hello World!' | upper %}{{ x }}", {}), 'HELLO WORLD!');
is(render_str($env, 'tpl.j2', "{% set x = '' | upper %}{{ x }}", {}), '');
is(render_str($env, 'tpl.j2', "{% set x = 'ALREADY' | upper %}{{ x }}", {}), 'ALREADY');
is(render_str($env, 'tpl.j2', "{% set x = 42 | upper %}{{ x }}", {}), '42');

done_testing();
