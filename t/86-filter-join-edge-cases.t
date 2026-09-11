use strict; use warnings;
use Test::More tests => 2;

use Minijinja qw(minijinja add_filter render_str);

my $env = minijinja();
add_filter($env, 'join', \&Minijinja::Filter::join);

# Join with default (empty) separator (line 476)
is(render_str($env, 'tpl.j2', "{% set x = [1,2,3] | join %}{{x}}", {}), '123', 'join without separator');

# Join with attribute parameter (lines 478-479)
is(render_str($env, 'tpl.j2', "{% set x = [{'n':'a'},{'n':'b'}] | join(',', 'n') %}{{x}}", {}), 'a,b', 'join with attr');

done_testing();
1;
