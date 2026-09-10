use strict; use warnings;
use Test::More tests => 4;

use Minijinja qw(
    new add_filter render_str
    filter_capitalize
);


my $env = new();
add_filter($env, 'capitalize', \&filter_capitalize);

is(render_str($env, 'tpl.j2', "{% set x = 'hello world' | capitalize %}{{ x }}", {}), 'Hello world', 'capitalize basic');
is(render_str($env, 'tpl.j2', "{% set x = 'h' | capitalize %}{{ x }}", {}), 'H', 'capitalize single char');
is(render_str($env, 'tpl.j2', "{% set x = '' | capitalize %}{{ x }}", {}), '', 'capitalize empty string');
is(render_str($env, 'tpl.j2', "{% set x = 'already Capitalized' | capitalize %}{{ x }}", {}), 'Already capitalized', 'capitalize already capitalized');

done_testing();
