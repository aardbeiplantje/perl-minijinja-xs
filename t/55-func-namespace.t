use strict; use warnings;
use Test::More tests => 1;

use Minijinja qw(new add_filter render_str namespace_fn);


my $env = new();

is(render_str($env, 'tpl.j2', "{% set ns = namespace() %}{{ ns is defined ? 1 : 0 }}", {}), '1', 'namespace basic');

done_testing();
