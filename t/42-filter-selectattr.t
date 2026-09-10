use strict; use warnings;
use Test::More tests => 1;

use Minijinja qw(new add_filter render_str selectattr);


my $env = new();
add_filter($env, 'selectattr', \&Minijinja::Filter::selectattr);

is(render_str($env, 'tpl.j2', "{% set people = [{'active':true},{'active':false},{'active':true}] %}{% for p in people | selectattr('active') %}{{ p.active }},{% endfor %}", {}), '1,1,', 'selectattr filter');

done_testing();
