package MooseX::Declare::Context::WithOptions;
{
  $MooseX::Declare::Context::WithOptions::VERSION = '0.38';
}
BEGIN {
  $MooseX::Declare::Context::WithOptions::AUTHORITY = 'cpan:FLORA';
}

use Moose::Role;
use Carp qw/croak/;
use MooseX::Types::Moose 0.20 qw/HashRef/;

use namespace::clean -except => 'meta';

has options => (
    is      => 'rw',
    isa     => HashRef,
    default => sub { {} },
    lazy    => 1,
);

sub strip_options {
    my ($self) = @_;
    my %ret;

    # Make errors get reported from right place in source file
    local $Carp::Internal{'MooseX::Declare'} = 1;
    local $Carp::Internal{'Devel::Declare'} = 1;

    $self->skipspace;
    my $linestr = $self->get_linestr;

    while (substr($linestr, $self->offset, 1) !~ /[{;]/) {
        my $key = $self->strip_name;
        if (!defined $key) {
            croak 'expected option name'
              if keys %ret;
            return; # This is the case when { class => 'foo' } happens
        }

        croak "unknown option name '$key'"
            unless $key =~ /^(extends|with|is)$/;

        my $val = $self->strip_name;
        if (!defined $val) {
            if (defined($val = $self->strip_proto)) {
                $val = [split /\s*,\s*/, $val];
            }
            else {
                croak "expected option value after $key";
            }
        }

        $ret{$key} ||= [];
        push @{ $ret{$key} }, ref $val ? @{ $val } : $val;
    } continue {
        $self->skipspace;
        $linestr = $self->get_linestr();
    }

    my $options = { map {
        my $key = $_;
        $key eq 'is'
            ? ($key => { map { ($_ => 1) } @{ $ret{$key} } })
            : ($key => $ret{$key})
    } keys %ret };

    $self->options($options);

    return $options;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

MooseX::Declare::Context::WithOptions

=head1 AUTHOR

Florian Ragwitz <rafl@debian.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2008 by Florian Ragwitz.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
