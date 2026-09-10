use strict; use warnings;
use Test::More tests => 2;

use Minijinja qw(minijinja add_filter add_function render_str);


my $env = minijinja();
add_function($env, 'startswith', \&Minijinja::Filter::has_prefix);

is(render_str($env, 'tpl.j2', "{{ startswith('hello world', 'hel') }}", {}), '1', 'startswith match');
is(render_str($env, 'tpl.j2', "{{ startswith('hello world', 'xyz') }}", {}), '0', 'startswith no match');

done_testing();
