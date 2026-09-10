use strict; use warnings;
use Test::More tests => 4;

use Minijinja qw(new add_filter render_str has_suffix);

my $env = new();
add_filter($env, 'has_suffix', \&Minijinja::Filter::has_suffix);

is(render_str($env, 'tpl.j2', "{{ val | has_suffix('world') }}", { val => 'hello world' }), '1', 'has_suffix true match');
is(render_str($env, 'tpl.j2', "{{ val | has_suffix('xyz') }}", { val => 'hello world' }), '', 'has_suffix false no match');

done_testing();
