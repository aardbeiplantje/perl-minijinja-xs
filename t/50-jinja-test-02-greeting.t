use strict; use warnings;
use Test::More tests => 1;
use lib 't/lib';

use JinjaTest;

# Test with different name only  
JinjaTest::jinja_test_case(
    template   => 'template-simple.greeting.jinja',
    expected   => 'template-simple.greeting.jinja.test-02.out',
    context    => {
        name   => 'Alice',
        count  => 42,
    },
);

1;
