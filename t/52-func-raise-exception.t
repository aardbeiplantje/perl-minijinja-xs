use strict; use warnings;
use Test::More tests => 6;

use Minijinja qw(minijinja add_function add_filter render_str error_exists error_detail);


my $env = minijinja();
add_function($env, 'raise_exception', \&Minijinja::Function::raise_exception);

# A callback that dies aborts the rendering; error_detail() returns its message
my $out = render_str($env, 'tpl.j2', "{% set x = 1 %}{{ raise_exception('test error') }}{% if true %}[after]{% endif %}", {});
ok(!defined($out), 'render aborts on raise_exception');
ok(error_exists(), 'error_exists after the abort');
like(error_detail(), qr/^test error/, 'error_detail returns the message');

# The same for a filter that dies, and a die with a non-ASCII message
add_filter($env, 'boom', sub { die "kapot \x{2013} $_[0]\n" });
ok(!defined(render_str($env, 'tpl.j2', "a{{ 'x'|boom }}b", {})), 'render aborts on a dying filter');
is(error_detail(), "kapot \x{2013} x\n", 'error_detail returns the message as characters');

# The next successful render does not report the old message
render_str($env, 'tpl.j2', "ok", {});
isnt(error_detail() // '', "kapot \x{2013} x\n", 'no stale message after a successful render');

done_testing();

1;
