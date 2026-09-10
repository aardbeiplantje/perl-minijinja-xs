use strict; use warnings;
use Test::More tests => 2;

use Minijinja qw(minijinja add_filter render_str);


my $env = minijinja();
add_filter($env, 'last', \&Minijinja::Filter::last);

is(render_str($env, 'tpl.j2', "{% set x = [1, 2, 3] | last %}{% if x is defined %}{{ x }}{% else %}undefined{% endif %}", {}), '3', 'last basic');
is(render_str($env, 'tpl.j2', "{% set x = [] | last %}{% if x is defined %}{{ x }}{% else %}undefined{% endif %}", {}), 'undefined', 'last empty');

done_testing();
