use Minijinja qw(minijinja add_test render_str);
use strict; use warnings;
use Test::More tests => 5;

is(Minijinja::Test::is_string('hello'), 1, 'is_string plain string');
is(Minijinja::Test::is_string([1,2]), 0, 'is_string arrayref rejected');
is(Minijinja::Test::is_string(''), 1, 'is_string empty string');
is(Minijinja::Test::is_string("0"), 1, 'is_string "0" (string not int)');
is(Minijinja::Test::is_string(), 0, 'is_string undef rejected');

done_testing();

1;
