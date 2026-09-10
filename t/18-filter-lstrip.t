use strict; use warnings;
use Test::More tests => 4;

use Minijinja qw(new add_filter render_str);


my $env = new();
add_filter($env, 'lstrip', \&Minijinja::Filter::lstrip);

is(render_str($env, 'tpl.j2', "{% set x = '  hello  ' | lstrip %}{{ x }}", {}), 'hello  ', 'lstrip basic');
is(render_str($env, 'tpl.j2', "{% set x = '\thello\t\n' | lstrip %}{{ x }}", {}), 'hello\t\n', 'lstrip tabs newlines');
is(render_str($env, 'tpl.j2', "{% set x = '   clean' | lstrip %}{{ x }}", {}), 'clean', 'lstrip no change');
is(render_str($env, 'tpl.j2', "{% set x = '!!!hello' | lstrip('!') %}{{ x }}", {}), 'hello', 'lstrip custom char');

done_testing();
