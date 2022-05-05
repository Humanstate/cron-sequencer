#!perl

use v5.20.0;
use warnings;

package Cron::Sequencer;

our $VERSION = '0.01';

use Carp qw(croak confess);

require Cron::Sequencer::Parser;

# scalar -> filename
# ref to scalar -> contents
# hashref -> fancy

sub new {
    my ($class, @args) = @_;
    confess('new() called as an instance method')
        if ref $class;

    my @self;
    for my $arg (@args) {
        $arg = Cron::Sequencer::Parser->new($arg)
            unless UNIVERSAL::isa($arg, 'Cron::Sequencer::Parser');
        push @self, $arg->entries();
    }

    return bless \@self, $class;
}

# The intent is to avoid repeatedly calling ->next_time() on every event on
# every loop, which would make next() have O(n) performance, and looping a range
# O(n**2)

sub start {
    my ($self, $start) = @_;

    croak('start($epoch_seconds)')
        unless $start =~ /\A[1-9][0-9]*\z/;

    # As we have to call ->next_time(), which returns the next time *after* the
    # epoch time we pass it.
    --$start;

    for my $entry (@$self) {
        # Cache the time (in epoch seconds) for the next firing for this entry
        $entry->{next} = $entry->{whenever}->next_time($start);
    }

    return;
}

sub next {
    my $self = shift;

    return
        unless @$self;

    my $when = $self->[0]{next};
    my @found;

    for my $entry (@$self) {
        if ($entry->{next} < $when) {
            # If this one is earlier, discard everything we found so far
            $when = $entry->{next};
            @found = $entry;
        } elsif ($entry->{next} == $when) {
            # If it's a tie, add it to the list of found
            push @found, $entry;
        }
    }

    my @retval;

    for my $entry (@found) {
        push @retval, {
            %$entry{qw(lineno when command env)},
            time => $when,
        };

        # We've "consumed" this firing, so update the cached value
        $entry->{next} = $entry->{whenever}->next_time($when);
    }

    return @retval;
}

=head1 LICENSE

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself. If you would like to contribute documentation,
features, bug fixes, or anything else then please raise an issue / pull request:

    https://github.com/Humanstate/cron-sequencer

=head1 AUTHOR

Nicholas Clark - C<nick@ccl4.org>

=cut

1;
