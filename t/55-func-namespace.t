use strict; use warnings;
use Test::More tests => 1;

use Minijinja qw(minijinja render_str);


my $env = minijinja();

is(render_str($env, 'tpl.j2', "{% set ns = namespace() %}{{ ns is defined ? 1 : 0 }}", {}), '1', 'namespace basic');

done_testing();
