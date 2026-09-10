use strict; use warnings;
use Test::More tests => 1;

use Minijinja qw(minijinja add_function render_str);


my $env = minijinja();
add_function($env, 'namespace', \&Minijinja::Function::namespace_fn);

is(render_str($env, 'tpl.j2', "{% set ns = namespace() %}{{ns is defined}}", {}), 'True', 'namespace basic');

done_testing();
