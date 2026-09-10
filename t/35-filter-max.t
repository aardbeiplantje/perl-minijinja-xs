use strict; use warnings;
use Test::More tests => 2;

use Minijinja qw(new add_filter render_str);


my $env = new();
add_filter($env, 'max', \&Minijinja::Filter::max);

is(render_str($env, 'tpl.j2', "{% set x = [3, 1, 2] | max %}{% if x is defined %}{{ x }}{% endif %}{% else %}undef{% endif %}", {}), '3', 'max basic');
is(render_str($env, 'tpl.j2', "{% set x = [] | max %}{% if x is defined %}{{ x }}{% endif %}{% else %}undef{% endif %}", {}), 'undef', 'max empty');

done_testing();
