use strict; use warnings;
use Test::More tests => 4;
use lib 't/lib';

use JinjaTest;

# Test basic namespace usage without kwargs
JinjaTest::jinja_test_case(
    template   => 'template-namespace.jinja',
    expected   => 'template-namespace.jinja.test-01.out',
    context    => {},
);

# Test namespace with initial kwargs
JinjaTest::jinja_test_case(
    template   => 'template-namespace.jinja',
    expected   => 'template-namespace.jinja.test-02.out',
    context    => { use_kwargs => 1 },
);

# Test namespace modification in loops
JinjaTest::jinja_test_case(
    template   => 'template-namespace.jinja',
    expected   => 'template-namespace.jinja.test-03.out',
    context    => { use_loop => 1 },
);

# Test nested namespace access  
JinjaTest::jinja_test_case(
    template   => 'template-namespace.jinja',
    expected   => 'template-namespace.jinja.test-04.out',
    context    => { use_nested => 1 },
);

1;
