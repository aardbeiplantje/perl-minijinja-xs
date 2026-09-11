use strict; use warnings;
use Test::More tests => 2;

use Minijinja qw(minijinja add_filter render_str);


my $env = minijinja();
add_filter($env, 'max', \&Minijinja::Filter::max);

is(render_str($env, 'tpl.j2', "{% set x = [3, 1, 2] | max %}{% if x is defined %}{{ x }}{% else %}undefined{% endif %}", {}), '3', 'max basic');
is(render_str($env, 'tpl.j2', "{% set x = [] | max %}{% if x is defined %}{{ x }}{% else %}undefined{% endif %}", {}), 'undefined', 'max empty');

done_testing();

1;
