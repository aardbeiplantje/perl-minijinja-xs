use strict; use warnings;
use Test::More tests => 4;

use Minijinja qw(
    new add_filter render_str
    filter_rstrip
);


my $env = new();
add_filter($env, 'rstrip', \&filter_rstrip);

is(render_str($env, 'tpl.j2', "{% set x = '  hello  ' | rstrip %}{{ x }}", {}), '  hello', 'rstrip basic');
is(render_str($env, 'tpl.j2', "{% set x = '\thello\t\n' | rstrip %}{{ x }}", {}), '\thello', 'rstrip tabs newlines');
is(render_str($env, 'tpl.j2', "{% set x = 'clean   ' | rstrip %}{{ x }}", {}), 'clean', 'rstrip no change');
is(render_str($env, 'tpl.j2', "{% set x = 'hello!!' | rstrip('!') %}{{ x }}", {})), 'hello');

done_testing();
