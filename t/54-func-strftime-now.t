use strict; use warnings;
use Test::More tests => 2;

use Minijinja qw(minijinja add_filter add_function render_str);


my $env = minijinja();
add_function($env, 'strftime_now', \&Minijinja::Function::strftime_now);

is(render_str($env, 'tpl.j2', "{% set x = strftime_now() %}{% if x is defined and x != '' %}1{% else %}0{% endif %}", {}), '1', 'strftime_now no args');
is(render_str($env, 'tpl.j2', "{% set x = strftime_now('%Y-%m-%d') %}{% if x is defined and x != '' %}1{% else %}0{% endif %}", {}), '1', 'strftime_now with format');

done_testing();

1;
