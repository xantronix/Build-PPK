package Build::PPK::Exec;

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

use Carp ('confess');

sub lazyrun {
    my ( $class, $command, @args ) = @_;
    pipe my ( $out, $in ) or confess("Unable to pipe(): $!");

    my $pid = fork();

    if ( $pid == 0 ) {
        sysopen( my $err, '/dev/null', &Fcntl::O_RDWR ) or die("Unable to open /dev/null: $!");

        close $out;
        close STDIN;

        POSIX::dup2( fileno($in),  fileno(STDOUT) ) or confess("Unable to dup2(): $!");
        POSIX::dup2( fileno($err), fileno(STDERR) ) or confess("Unable to dup2(): $!");
    }
    elsif ( !defined($pid) ) {
        confess("Unable to fork(): $!");
    }

    close $in;

    my $ret;

    while ( my $len = sysread( $out, my $buf, 512 ) ) {
        $ret .= $buf;
    }

    chomp $ret if defined $ret;

    close $out;
    waitpid( $pid, 0 );

    return $ret;
}

sub call {
    my ( $class, $verbosity, $command, @args ) = @_;

    pipe my ( $error_out, $error_in ) or die("Unable to create STDERR pipe(): $!");
    my $pid = fork();

    if ( $pid == 0 ) {
        close $error_out;

        if ( $verbosity < 2 ) {
            sysopen( my $stdin,  '/dev/null', &Fcntl::O_RDONLY ) or die("Unable to open /dev/null for reading: $!");
            sysopen( my $stdout, '/dev/null', &Fcntl::O_WRONLY ) or die("Unable to open /dev/null for writing: $!");

            POSIX::dup2( fileno($stdin),  fileno(STDIN) )  or die("Unable to redirect standard input: $!");
            POSIX::dup2( fileno($stdout), fileno(STDOUT) ) or die("Unable to redirect standard output: $!");
        }

        POSIX::dup2( fileno($error_in), fileno(STDERR) ) or die("Unable to redirect standard error: $!");

        exec( $command, @args ) or die("Unable to exec() $command: $!");
    }
    elsif ( !defined($pid) ) {
        die("Unable to fork(): $!");
    }

    close $error_in;
    my $errors;

    while ( my $len = sysread( $error_out, my $buf, 512 ) ) {
        $errors .= $buf;

        if ( $verbosity > 0 ) {
            print STDERR $buf;
        }
    }

    close $error_out;
    waitpid( $pid, 0 );

    if ($?) {
        if ($errors) {
            chomp $errors;
            $@ = $errors;
        }
        else {
            $@ = $!;
        }
    }

    return $?;
}

sub silent {
    my ( $class, $command, @args ) = @_;
    return $class->call( 0, $command, @args );
}

sub quiet {
    my ( $class, $command, @args ) = @_;
    return $class->call( 1, $command, @args );
}

sub verbose {
    my ( $class, $command, @args ) = @_;
    return $class->call( 2, $command, @args );
}

1;
