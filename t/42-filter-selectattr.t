use strict; use warnings;
use Test::More tests => 1;

use Minijinja qw(minijinja add_filter render_str);


my $env = minijinja();
add_filter($env, 'selectattr', \&Minijinja::Filter::selectattr);

is(render_str($env, 'tpl.j2', "{% for p in [{'active':true},{'active':false},{'active':true}] | selectattr('active') %}{{p}},{% endfor %}", {}), '1.0,1.0,', 'selectattr filter');

done_testing();

1;
