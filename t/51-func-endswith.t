use strict; use warnings;
use Test::More tests => 2;

use Minijinja qw(
    new add_filter add_function render_str
    func_endswith
);


my $env = new();
add_function($env, 'endswith', \&func_endswith);

is(render_str($env, 'tpl.j2', "{{ endswith('hello world', 'world') }}", {}), '1', 'endswith match');
is(render_str($env, 'tpl.j2', "{{ endswith('hello world', 'xyz') }}", {}), '0', 'endswith no match');

done_testing();
