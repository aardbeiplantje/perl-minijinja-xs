use strict; use warnings;
use Test::More;

use Minijinja qw(minijinja);

# is_odd - undefined input (line 977)  
ok(!Minijinja::Test::is_odd(undef), 'is_odd undef returns false');
ok(Minijinja::Test::is_odd(3), 'is_odd odd int returns true');
ok(!Minijinja::Test::is_odd(4), 'is_odd even int returns false');

# is_even - undefined input (line 985)
ok(!Minijinja::Test::is_even(undef), 'is_even undef returns false');
ok(Minijinja::Test::is_even(4), 'is_even even int returns true');
ok(!Minijinja::Test::is_even(3), 'is_even odd int returns false');

# is_false - false cases (line 993)
ok(!Minijinja::Test::is_false('True'), 'is_false True returns false (case sensitive)');
ok(!Minijinja::Test::is_false('true'), 'is_false lowercase true returns false');
ok(Minijinja::Test::is_false('false'), 'is_false lowercase false returns true');

# is_true - false cases (line 999)
ok(!Minijinja::Test::is_true('False'), 'is_true False returns false (case sensitive)');  
ok(!Minijinja::Test::is_true('false'), 'is_true lowercase false returns false');
ok(Minijinja::Test::is_true('true'), 'is_true lowercase true returns true');

done_testing();
1;
