use strict; use warnings;
use Test::More tests => 2;

use Minijinja qw(
    new add_filter add_function render_str
    strftime_now
);


my $env = new();
add_function($env, 'strftime_now', \&strftime_now);

is(render_str($env, 'tpl.j2', "{% set x = strftime_now() %}{{ x ne '' ? 1 : 0 }}", {}), '1', 'strftime_now no args');
is(render_str($env, 'tpl.j2', "{% set x = strftime_now('%Y-%m-%d') %}{{ x ne '' ? 1 : 0 }}", {}), '1', 'strftime_now with format');

done_testing();
