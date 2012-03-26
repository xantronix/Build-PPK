package Build::PPK::Deptool::HTTP;

# Copyright (c) 2012, cPanel, Inc.
# All rights reserved.
# http://cpanel.net/
#
# This is free software; you can redistribute it and/or modify it under the same
# terms as Perl itself.  See the LICENSE file for further details.

use strict;
use warnings;

use POSIX ();
use Fcntl ();

use Cwd            ();
use File::Basename ();

use Build::PPK::Pipeline ();

use Carp;

sub fetch_dist {
    my ( $class, %args ) = @_;

    return if -e $args{'path'};

    my @filters = (
        sub {
            exec qw(wget -O -), $args{'url'} or confess("Unable to spawn wget: $!");
        }
    );

    if ( $args{'path'} =~ /\.tar/ ) {
        push @filters, sub {
            open( my $fh, '>', $args{'path'} ) or confess("Cannot open $args{'path'} for writing: $!");

            while ( my $len = read( STDIN, my $buf, 4096 ) ) {
                print $fh $buf;
            }

            close $fh;
        };
    }
    else {
        unless ( -d $args{'path'} ) {
            mkdir( $args{'path'} ) or confess("Unable to create distribution directory $args{'path'} : $!");
        }

        push @filters, sub {
            chdir( $args{'path'} ) or confess("Unable to chdir() to $args{'path'}: $!");
            exec qw(tar pzxf -) or confess("Unable to spawn tar: $!");
        };
    }

    my $pipeline = Build::PPK::Pipeline->open(@filters);

    close $pipeline->{'in'};

    sysopen( my $null_fh, '/dev/null', &Fcntl::O_RDONLY ) or confess("Unable to open /dev/null: $!");

    POSIX::dup2( fileno($null_fh), fileno( $pipeline->{'out'} ) );
    POSIX::dup2( fileno($null_fh), fileno( $pipeline->{'err'} ) );

    $pipeline->close;
}

1;
