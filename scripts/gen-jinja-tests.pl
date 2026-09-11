#!/usr/bin/env perl
# gen-jinja-tests.pl - List and scaffold Jinja test cases
#
# Usage:
#   perl scripts/gen-jinja-tests.pl [--scan] [--generate TEMPLATE_NAME]
#
# Options:
#   --scan            List all .jinja templates and their associated tests
#   --generate NAME   Scaffold new tests for a specific template (or all if omitted)

use strict;
use warnings;
use File::Basename;
use Getopt::Long;

my $scan_only = 0;
my $gen_template = undef;

GetOptions(
    'scan'           => \$scan_only,
    'generate=s'     => \$gen_template,
) or die "Usage: $0 [--scan] [--generate [template_name]]\n";

my $resources_dir = 't/resources';

sub scan_templates {
    opendir my $dh, $resources_dir or die "Cannot open '$resources_dir': $!\n";
    my @templates;
    while (my $entry = readdir($dh)) {
        next unless $entry =~ /\.jinja$/;
        push @templates, $entry;
    }
    closedir($dh);
    my @result = sort @templates;
    return @result;
}

sub list_expected_outputs {
    my ($template) = @_;
    opendir my $dh, $resources_dir or return [];
    my @outputs;
    while (my $entry = readdir($dh)) {
        if ($entry =~ /^\Q$template\E\.test-(\d+)\.out$/) {
            push @outputs, { test_num => int($1), file => $entry };
        }
    }
    closedir($dh);
    my @sorted_outputs = sort { $a->{test_num} <=> $b->{test_num} } @outputs;
    return @sorted_outputs;
}

if ($scan_only) {
    print "=== Jinja Templates in $resources_dir ===\n\n";
    for my $tmpl (scan_templates()) {
        print "  $tmpl\n";
        my @outs = list_expected_outputs($tmpl);
        if (@outs) {
            for my $o (@outs) {
                print "    -> test-$o->{test_num}: $o->{file}\n";
            }
        } else {
            print "    (no tests yet)\n";
        }
    }
    exit 0;
}

# Generate mode: scaffold tests for given template(s)
for my $tmpl_to_gen (@$gen_template || scan_templates()) {
    unless (-f "$resources_dir/$tmpl_to_gen") {
        warn "Template not found: $resources_dir/$tmpl_to_gen\n";
        next;
    }

    my @existing = list_expected_outputs($tmpl_to_gen);
    my $next_test = scalar(@existing) + 1;

    if (@existing) {
        printf "Found %d existing test(s) for '%s':\n", scalar(@existing), $tmpl_to_gen;
        for my $e (@existing) {
            printf "  - test-%d: %s\n", $e->{test_num}, $e->{file};
        }
    } else {
        printf "No existing tests for '%s'.\n", $tmpl_to_gen;
    }

    # Create a blank test file as scaffold
    my $test_file = "t/50-jinja-test-${next_test}-${tmpl_to_gen}";
    
    open my $tfh, '>', $test_file or die "Cannot create '$test_file': $!\n";
    
    print $tfh <<PERL_EOF;
use strict; use warnings;
use Test::More;
use lib 't/lib';

use JinjaTest qw(jinja_test_case);

# Template: $tmpl_to_gen
# Expected output: ${tmpl_to_gen}.test-${next_test}.out
# 
# To update the expected output, run with MINIJINJA_UPDATE_EXPECTATIONS=1:
#   MINIJINJA_UPDATE_EXPECTATIONS=1 perl $test_file

jinja_test_case(
    template   => '$tmpl_to_gen',
    expected   => '${tmpl_to_gen}.test-${next_test}.out',
    context    => {
        # TODO: Fill in the context based on what your template expects.
        # The template is a chat message formatter. It typically takes:
        #   messages  - list of message hashes with 'role' and 'content' keys
        # Example:
        #     messages => [
        #         { role => 'user', content => 'Hello!' },
        #         { role => 'assistant', content => 'Hi there!' },
        #     ],
    },
);
PERL_EOF
    
    close $tfh;
    printf "Created scaffold: %s\n", $test_file;
}

exit 0;
