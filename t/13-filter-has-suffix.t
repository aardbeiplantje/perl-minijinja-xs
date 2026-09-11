use strict; use warnings;
use Test::More tests => 2;

use Minijinja qw(minijinja add_filter render_str);

my $env = minijinja();
add_filter($env, 'has_suffix', \&Minijinja::Filter::has_suffix);

is(render_str($env, 'tpl.j2', "{{ val | has_suffix('world') }}", { val => 'hello world' }), '1', 'has_suffix true match');
is(render_str($env, 'tpl.j2', "{{ val | has_suffix('xyz') }}", { val => 'hello world' }), '0', 'has_suffix false no match');

done_testing();

1;
