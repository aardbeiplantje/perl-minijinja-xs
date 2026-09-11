use strict; use warnings;
use Test::More;

use Minijinja qw(minijinja);

# is_float - all false paths (lines 890-891, 893-895)  
ok(!Minijinja::Test::is_float(undef), 'is_float undef returns false');
ok(!Minijinja::Test::is_float({}), 'is_float hashref returns false');
ok(!Minijinja::Test::is_float('1.0'), 'is_float integer-as-string "1.0" returns false');
ok(!Minijinja::Test::is_float('42'), 'is_float plain int string returns false');
ok(Minijinja::Test::is_float('3.14'), 'is_float valid float returns true');
ok(Minijinja::Test::is_float('1e5'), 'is_float scientific notation returns true');

# is_number - non-numeric strings (lines 901-903)
ok(!Minijinja::Test::is_number('hello'), 'is_number text returns false');
ok(!Minijinja::Test::is_number([]), 'is_number empty array returns false');
ok(Minijinja::Test::is_number('42'), 'is_number int string returns true');
ok(Minijinja::Test::is_number('3.14'), 'is_number float string returns true');

# is_boolean - non-defined values (line 909)
ok(!Minijinja::Test::is_boolean(undef), 'is_boolean undef returns false');
ok(!Minijinja::Test::is_boolean('True'), 'is_boolean True returns false (case sensitive)');  
ok(Minijinja::Test::is_boolean('true'), 'is_boolean true returns true');
ok(Minijinja::Test::is_boolean('false'), 'is_boolean false returns true');

done_testing();
1;
