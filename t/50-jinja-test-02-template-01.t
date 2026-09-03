use strict; use warnings;
use Test::More tests => 1;
use lib 't/lib';

use JinjaTest;

# Test with different name only  
JinjaTest::jinja_test_case(
    template   => 'template-01.jinja',
    expected   => 'template-01.jinja.test-02.out',
    context    => {
        name   => 'Alice',
        count  => 42,
        messages => [
            {'role' => 'user', 'content' => 'Hello!'},
            {'role' => 'assistant', 'content' => "Hi there!"},
        ],
    },
);
