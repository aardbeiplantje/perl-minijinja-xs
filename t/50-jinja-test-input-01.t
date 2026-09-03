use strict; use warnings;
use Test::More tests => 1;
use lib 't/lib';

use JinjaTest;

# Render a simple template using input from input-01.json as context.
# This demonstrates loading JSON input files and rendering them with Jinja2 templates.
JinjaTest::jinja_test_case_with_input(
    template   => 'template-greeting-input.jinja',
    input      => 'input-01.json',  
    expected   => 'input-01.out',
);
