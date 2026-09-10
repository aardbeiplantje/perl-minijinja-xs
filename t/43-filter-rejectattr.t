use strict; use warnings;
use Test::More tests => 1;

use Minijinja qw(minijinja add_filter render_str);


my $env = minijinja();
add_filter($env, 'rejectattr', \&Minijinja::Filter::rejectattr);

is(render_str($env, 'tpl.j2', "{% set people = [{'active':true},{'active':false},{'active':true}] %}{% for p in people | rejectattr('active') %}{{ p.active }},{% endfor %}", {}), '0,', 'rejectattr filter');

done_testing();
