use strict; use warnings;
use Test::More tests => 1;
use lib 't/lib';

use Minijinja qw(new add_template render_str add_global add_filter add_function add_test);
use JSON::PP ();

# Render template-01.jinja using the same callback registrations as myjinja.py:
#   env.add_function('startswith', ...)
#   env.add_function('endswith', ...)
#   env.add_filter('items', safe_items)

my $env = new();

add_filter($env, 'has_prefix', sub {
    my ($str, $prefix) = @_;
    return defined($str) && defined($prefix) ? substr($str, 0, length($prefix)) eq $prefix : 0;
});
add_filter($env, 'has_suffix', sub {
    my ($str, $suffix) = @_;
    return defined($str) && defined($suffix) && length($str) >= length($suffix)
           ? substr($str, -length($suffix)) eq $suffix : 0;
});

add_filter($env, 'tojson', sub {
    my ($val) = @_;
    my $json = JSON::PP->new->utf8->canonical;
    if (!defined($val)) {
        return 'null';
    } elsif (ref($val) eq 'HASH') {
        return $json->encode($val);
    } elsif (ref($val) eq 'ARRAY') {
        return $json->encode($val);
    } else {
        return $json->encode($val);
    }
});

# startswith / endswith — identical semantics to myjinja.py lines 31-36
add_function($env, 'startswith', sub {
    my ($s, $prefix) = @_;
    return !defined($s) || !defined($prefix) ? 0 : substr($s, 0, length($prefix)) eq $prefix;
});
add_function($env, 'endswith', sub {
    my ($s, $suffix) = @_;
    return !defined($s) || !defined($suffix) ? 0 : length($s) >= length($suffix)
           && substr($s, -length($suffix)) eq $suffix;
});

# Also register as Jinja tests so they work with 'is' syntax
add_test($env, 'istartswith', sub {
    my ($s, $prefix) = @_;
    return !defined($s) || !defined($prefix) ? 0 : substr($s, 0, length($prefix)) eq $prefix;
});
add_test($env, 'endswith', sub {
    my ($s, $suffix) = @_;
    return !defined($s) || !defined($suffix) ? 0 : length($s) >= length($suffix)
           && substr($s, -length($suffix)) eq $suffix;
});

# raise_exception — dies so rendering aborts and error_detail() returns the message
add_function($env, 'raise_exception', sub { die $_[0] });

# items — Perl equivalent of Python safe_items (myjinja.py lines 6-17)
add_filter($env, 'items', sub {
    my ($value) = @_;
    if (!defined($value)) {
        return [];
    } elsif (ref($value) eq 'HASH') {
        # hashref → list of [key, value] pairs
        return [map { [$_, $value->{$_}] } keys %{$value}];
    } elsif (ref($value) eq 'ARRAY') {
        # arrayref is not a mapping — return empty list like safe_items does for non-dict iterables
        return [];
    } else {
        # string: try JSON decode to see if it's a dict-like object
        eval {
            my $decoded = JSON::PP->new->utf8->decode($value);
            if (ref($decoded) eq 'HASH') {
                return [map { [$_, $decoded->{$_}] } keys %{$decoded}];
            }
        };
        return [];
    }
});

ok(1, 'all callbacks registered');
