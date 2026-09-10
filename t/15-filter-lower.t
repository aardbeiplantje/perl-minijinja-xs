use strict; use warnings;
use Test::More tests => 3;

use Minijinja qw(new add_filter render_str);


my $env = new();
add_filter($env, 'lower', \&Minijinja::Filter::lower);

is(render_str($env, 'tpl.j2', "{% set x = 'HELLO' | lower %}{{ x }}", {}), 'hello', 'lower basic case');
is(render_str($env, 'tpl.j2', "{% set x = 'Hello World!' | lower %}{{ x }}", {}), 'hello world!', 'lower with spaces punctuation');
is(render_str($env, 'tpl.j2', "{% set x = '' | lower %}{{ x }}", {}), '', 'lower empty string');

done_testing();
