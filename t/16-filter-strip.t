use strict; use warnings;
use Test::More tests => 4;

use Minijinja qw(
    new add_filter render_str
    filter_strip
);


my $env = new();
add_filter($env, 'strip', \&filter_strip);

is(render_str($env, 'tpl.j2', "{% set x = '  hello  ' | strip %}{{ x }}", {}), 'hello', 'strip basic');
is(render_str($env, 'tpl.j2', "{% set x = '\t\nhello\t\n' | strip %}{{ x }}", {}), 'hello', 'strip tabs newlines');
is(render_str($env, 'tpl.j2', "{% set x = 'no_spaces' | strip %}{{ x }}", {}), 'no_spaces', 'strip no change');
is(render_str($env, 'tpl.j2', "{% set x = '!hello!' | strip('!') %}{{ x }}", {}), 'hello', 'strip custom char');

done_testing();
