use strict; use warnings;
use Test::More tests => 4;

use Minijinja qw(
    new add_filter render_str
    abs
);


my $env = new();
add_filter($env, 'abs', \&abs);

is(render_str($env, 'tpl.j2', "{% set x = (-5) | abs %}{{ x }}", {}), '5', 'abs positive result');
is(render_str($env, 'tpl.j2', "{% set x = 5 | abs %}{{ x }}", {}), '5', 'abs already positive');
is(render_str($env, 'tpl.j2', "{% set x = 0 | abs %}{{ x }}", {}), '0', 'abs zero');
is(render_str($env, 'tpl.j2', "{% set x = -3.14 | abs %}{{ x }}", {}), '3.14', 'abs negative float');

done_testing();
