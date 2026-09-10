use strict; use warnings;
use Test::More tests => 2;

use Minijinja qw(minijinja add_filter add_function render_str);


my $env = minijinja();
add_function($env, 'endswith', \&Minijinja::Filter::has_suffix);

is(render_str($env, 'tpl.j2', "{{ endswith('hello world', 'world') }}", {}), '1', 'endswith match');
is(render_str($env, 'tpl.j2', "{{ endswith('hello world', 'xyz') }}", {}), '0', 'endswith no match');

done_testing();
