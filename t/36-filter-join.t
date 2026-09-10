use strict; use warnings;
use Test::More tests => 2;

use Minijinja qw(new add_filter render_str);


my $env = new();
add_filter($env, 'join', \&Minijinja::Filter::join);

is(render_str($env, 'tpl.j2', "{% set x = [1, 2, 3] | join(',') %}{{ x }}", {}), '1,2,3', 'join basic');
is(render_str($env, 'tpl.j2', "{% set x = ['a','b'] | join('-') %}{{ x }}", {}), 'a-b', 'join custom separator');

done_testing();
