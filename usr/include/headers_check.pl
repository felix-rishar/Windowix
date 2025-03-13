#!/usr/bin/env perl
# SPDX-License-Identifier: GPL-2.0
#
# Optimized headers_check.pl
#
use warnings;
use strict;
use File::Basename;

my ($dir, @files) = @ARGV;
my $ret = 0;

foreach my $filename (@files) {
    open(my $fh, '<', $filename) or die "$filename: $!\n";
    
    my ($lineno, $linux_asm_types, $linux_types) = (0, 0, 0);
    my %import_stack;
    
    while (my $line = <$fh>) {
        $lineno++;
        check_include($filename, $lineno, $line);
        check_asm_types($filename, $lineno, $line, \$linux_asm_types);
        check_sizetypes($filename, $lineno, $line, \$linux_types, \%import_stack);
        check_declarations($filename, $lineno, $line);
    }
    close $fh;
}
exit $ret;

sub check_include {
    my ($filename, $lineno, $line) = @_;
    if ($line =~ /^\s*#\s*include\s+<((asm|linux).*?)>/) {
        my $inc = $1;
        unless (-e "$dir/$inc") {
            print STDERR "$filename:$lineno: included file '$inc' is not exported\n";
            $ret = 1;
        }
    }
}

sub check_declarations {
    my ($filename, $lineno, $line) = @_;
    return if $line =~ /^void seqbuf_dump\(void\);/ || $line =~ /^extern "C"/;
    if ($line =~ /^\s*(extern|unsigned|char|short|int|long|void)\b/) {
        print STDERR "$filename:$lineno: userspace cannot reference function or variable defined in the kernel\n";
    }
}

sub check_asm_types {
    my ($filename, $lineno, $line, $linux_asm_types_ref) = @_;
    return if $filename =~ /types.h|int-l64.h|int-ll64.h/;
    return if $$linux_asm_types_ref;
    if ($line =~ /^\s*#\s*include\s+<asm\/types.h>/) {
        $$linux_asm_types_ref = 1;
        print STDERR "$filename:$lineno: include of <linux/types.h> is preferred over <asm/types.h>\n";
    }
}

sub check_sizetypes {
    my ($filename, $lineno, $line, $linux_types_ref, $import_stack_ref) = @_;
    return if $filename =~ /types.h|int-l64.h|int-ll64.h/;
    return if $$linux_types_ref;
    if ($line =~ /^\s*#\s*include\s+<linux\/types.h>/) {
        $$linux_types_ref = 1;
        return;
    }
    if ($line =~ /^\s*#\s*include\s+[<"](\S+)[>"]/) {
        check_include_typesh($1, $import_stack_ref, $linux_types_ref);
    }
    if ($line =~ /__[us](8|16|32|64)\b/) {
        print STDERR "$filename:$lineno: found __[us]{8,16,32,64} type without #include <linux/types.h>\n";
        $$linux_types_ref = 2;
    }
}

sub check_include_typesh {
    my ($path, $import_stack_ref, $linux_types_ref) = @_;
    return if $$linux_types_ref;
    my @file_paths = ($path, "$dir/$path", dirname($ARGV[0]) . "/$path");
    
    foreach my $possible (@file_paths) {
        next if $import_stack_ref->{$possible};
        if (open(my $fh, '<', $possible)) {
            $import_stack_ref->{$possible} = 1;
            while (my $line = <$fh>) {
                if ($line =~ /^\s*#\s*include\s+<linux\/types.h>/) {
                    $$linux_types_ref = 1;
                    last;
                }
                if ($line =~ /^\s*#\s*include\s+[<"](\S+)[>"]/) {
                    check_include_typesh($1, $import_stack_ref, $linux_types_ref);
                }
            }
            close $fh;
            delete $import_stack_ref->{$possible};
        }
    }
}
