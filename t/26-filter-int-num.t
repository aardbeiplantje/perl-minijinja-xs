use strict; use warnings;
use Test::More tests => 3;

use Minijinja qw(minijinja add_filter render_str);


my $env = minijinja();
add_filter($env, 'int_num', \&int_num);

is(render_str($env, 'tpl.j2', "{% set x = 3.7 | int_num %}{{ x }}", {}), '3', 'int truncate positive');
is(render_str($env, 'tpl.j2', "{% set x = -3.7 | int_num %}{{ x }}", {}), '-3', 'int truncate negative');
is(render_str($env, 'tpl.j2', "{% set x = 42 | int_num %}{{ x }}", {}), '42', 'int already integer');

done_testing();
