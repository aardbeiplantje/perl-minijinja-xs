use strict; use warnings;
use Test::More tests => 4;

use Minijinja qw(
    new add_filter render_str
    filter_title
);


my $env = new();
add_filter($env, 'title', \&filter_title);

is(render_str($env, 'tpl.j2', "{% set x = 'hello world' | title %}{{ x }}", {}), 'Hello World', 'title basic');
is(render_str($env, 'tpl.j2', "{% set x = "let's go" | render_str($env, 'tpl.j2', "{% set x = "let's go" | title %}{{ x }}", {}), 'Let'S Go');
is(render_str($env, 'tpl.j2', "{% set x = '' | title %}{{ x }}", {}), '', 'title empty string');
is(render_str($env, 'tpl.j2', "{% set x = 'already Title Case' | title %}{{ x }}", {}), 'Already Title Case', 'title already capitalized');

done_testing();
