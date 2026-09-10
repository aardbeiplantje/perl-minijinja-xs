use strict; use warnings;
use Test::More tests => 3;

use Minijinja qw(
    new add_filter render_str
    filter_replace
);


my $env = new();
add_filter($env, 'replace', \&filter_replace);

is(render_str($env, 'tpl.j2', "{% set x = 'this is old text' | replace('old', 'new') %}{{ x }}", {})), 'this is new text');
is(render_str($env, 'tpl.j2', "{% set x = 'hello world' | replace('o', '0') %}{{ x }}", {})), 'h3ll0 w0rld');
is(render_str($env, 'tpl.j2', "{% set x = 'no match here' | replace('xyz', 'abc') %}{{ x }}", {})), 'no match here');

done_testing();
