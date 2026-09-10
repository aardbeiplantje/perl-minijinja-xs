use strict; use warnings;
use Test::More tests => 2;

use Minijinja qw(new add_filter render_str);


my $env = new();
add_filter($env, 'get', \&Minijinja::Filter::get);

is(render_str($env, 'tpl.j2', "{% set h = {'a': 1, 'b': 2} %}{% set v = h | get('a') %}{% if v is defined %}{{ v }}{% endif %}{% else %}undef{% endif %}", {}), '1', 'get existing key');
is(render_str($env, 'tpl.j2', "{% set h = {'a': 1} %}{% set v = h | get('missing') %}{% if v is defined %}{{ v }}{% endif %}{% else %}undef{% endif %}", {}), 'undef', 'get missing key');

done_testing();
