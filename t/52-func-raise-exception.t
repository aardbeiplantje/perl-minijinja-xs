use strict; use warnings;
use Test::More tests => 1;

use Minijinja qw(
    new add_filter add_function render_str
    func_raise_exception
);


my $env = new();
add_function($env, 'raise_exception', \&func_raise_exception);

my $out = eval { render_str($env, 'tpl.j2', "{{ raise_exception('test error') }}", {}) };
is(defined($out) ? 1 : 0, 0, 'render returns undef on exception');

done_testing();
