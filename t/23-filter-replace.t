use strict; use warnings;
use Test::More tests => 3;

use Minijinja qw(minijinja add_filter render_str);


my $env = minijinja();
add_filter($env, 'replace', \&Minijinja::Filter::replace);

is(render_str($env, 'tpl.j2', "{% set x = 'this is old text' | replace('old', 'minijinja') %}{{ x }}", {}), 'this is minijinja text');
is(render_str($env, 'tpl.j2', "{% set x = 'hello world' | replace('o', '0') %}{{ x }}", {}), 'hell0 w0rld', 'replace vowels');
is(render_str($env, 'tpl.j2', "{% set x = 'no match here' | replace('xyz', 'abc') %}{{ x }}", {}), 'no match here');

done_testing();
