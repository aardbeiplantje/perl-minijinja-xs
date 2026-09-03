use strict; use warnings;
use Test::More tests => 1;
use lib 't/lib';

use JinjaTest;

JinjaTest::jinja_test_case(
    template   => 'template-simple.greeting.jinja',
    expected   => 'template-simple.greeting.jinja.test-01.out',
    context    => {
        name   => 'World',
        count  => 42,
    },
);
