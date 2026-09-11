use strict; use warnings;
use Test::More tests => 2;

use Minijinja qw(minijinja add_filter render_str);

my $env = minijinja();
add_filter($env, 'items', \&Minijinja::Filter::items);

# Array input - should return empty arrayref  
is(render_str($env, 'tpl.j2', "{% for x in arr | items %}X{% endfor %}", { arr => [1,2,3] }), '', 'array to items yields nothing');

# Empty array ref - returns empty arrayref
is(render_str($env, 'tpl.j2', "{% for x in [] | items %}Y{% endfor %}", {}), '', 'empty list to items');

done_testing();
1;
