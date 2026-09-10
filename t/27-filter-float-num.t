use strict; use warnings;
use Test::More tests => 2;

use Minijinja qw(
    new add_filter render_str
    float_num
);


my $env = new();
add_filter($env, 'float_num', \&float_num);

is(render_str($env, 'tpl.j2', "{% set x = 42 | float_num %}{{ x }}", {}), '42', 'float already integer');
is(render_str($env, 'tpl.j2', "{% set x = 3.14 | float_num %}{{ x }}", {}), '3.14', 'float preserve decimal');

done_testing();
