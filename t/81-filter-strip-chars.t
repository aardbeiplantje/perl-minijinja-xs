use strict; use warnings;
use Test::More tests => 2;

use Minijinja qw(minijinja add_filter render_str);

my $env = minijinja();
add_filter($env, 'rstrip', \&Minijinja::Filter::rstrip);
add_filter($env, 'lstrip', \&Minijinja::Filter::lstrip);

# rstrip with $chars parameter (line 171)  
is(render_str($env, 'tpl.j2', "{% set x = 'hello!!!' | rstrip('!') %}{{ x }}", {}), 'hello', 'rstrip custom chars');

# lstrip with $chars parameter (line 187)  
is(render_str($env, 'tpl.j2', "{% set x = '!!!hello' | lstrip('!') %}{{ x }}", {}), 'hello', 'lstrip custom chars');

done_testing();
1;
