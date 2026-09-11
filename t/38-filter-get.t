use strict; use warnings;
use Test::More tests => 2;

use Minijinja qw(minijinja add_filter render_str);


my $env = minijinja();
add_filter($env, 'get', \&Minijinja::Filter::get);

is(render_str($env, 'tpl.j2', "{% set h = {'a': 1, 'b': 2} %}{% set v = h | get('a') %}{% if v is defined %}{{ v }}{% else %}undefined{% endif %}", {}), '1', 'get existing key');
is(render_str($env, 'tpl.j2', "{% set h = {'a': 1} %}{% set v = h | get('missing') %}{% if v is defined %}{{ v }}{% else %}undefined{% endif %}", {}), 'undefined', 'get missing key');

done_testing();

1;
