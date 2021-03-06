package CPAN::Meta::Check;
{
  $CPAN::Meta::Check::VERSION = '0.008';
}
use strict;
use warnings;

use Exporter 5.57 'import';
our @EXPORT = qw//;
our @EXPORT_OK = qw/check_requirements requirements_for verify_dependencies/;
our %EXPORT_TAGS = (all => [ @EXPORT, @EXPORT_OK ] );

use CPAN::Meta::Requirements 2.120920;
use Module::Metadata;

sub _check_dep {
	my ($reqs, $module, $dirs) = @_;

	my $version = $module eq 'perl' ? $] : do { 
		my $metadata = Module::Metadata->new_from_module($module, inc => $dirs);
		return "Module '$module' is not installed" if not defined $metadata;
		eval { $metadata->version };
	};
	return "Missing version info for module '$module'" if $reqs->requirements_for_module($module) and not $version;
	return sprintf 'Installed version (%s) of %s is not in range \'%s\'', $version, $module, $reqs->requirements_for_module($module) if not $reqs->accepts_module($module, $version || 0);
	return;
}

sub _check_conflict {
	my ($reqs, $module, $dirs) = @_;
	my $metadata = Module::Metadata->new_from_module($module, inc => $dirs);
	return if not defined $metadata;
	my $version = eval { $metadata->version };
	return "Missing version info for module '$module'" if not $version;
	return sprintf 'Installed version (%s) of %s is in range \'%s\'', $version, $module, $reqs->requirements_for_module($module) if $reqs->accepts_module($module, $version);
	return;
}

sub requirements_for {
	my ($meta, $phases, $type) = @_;
	my $prereqs = ref($meta) eq 'CPAN::Meta' ? $meta->effective_prereqs : $meta;
	return $prereqs->merged_requirements(ref($phases) ? $phases : [ $phases ], [ $type ]);
}

sub check_requirements {
	my ($reqs, $type, $dirs) = @_;

	my %ret;
	if ($type ne 'conflicts') {
		for my $module ($reqs->required_modules) {
			$ret{$module} = _check_dep($reqs, $module, $dirs);
		}
	}
	else {
		for my $module ($reqs->required_modules) {
			$ret{$module} = _check_conflict($reqs, $module, $dirs);
		}
	}
	return \%ret;
}

sub verify_dependencies {
	my ($meta, $phases, $type, $dirs) = @_;
	my $reqs = requirements_for($meta, $phases, $type);
	my $issues = check_requirements($reqs, $type, $dirs);
	return grep { defined } values %{ $issues };
}

# vi:noet:sts=2:sw=2:ts=2
1;

#ABSTRACT: Verify requirements in a CPAN::Meta object

__END__

=pod

=head1 NAME

CPAN::Meta::Check - Verify requirements in a CPAN::Meta object

=head1 VERSION

version 0.008

=head1 SYNOPSIS

 warn "$_\n" for verify_requirements($meta, [qw/runtime build test/], 'requires');

=head1 DESCRIPTION

This module verifies if requirements described in a CPAN::Meta object are present.

=head1 FUNCTIONS

=head2 check_requirements($reqs, $type, $incdirs)

This function checks if all dependencies in C<$reqs> (a L<CPAN::Meta::Requirements|CPAN::Meta::Requirements> object) are met, taking into account that 'conflicts' dependencies have to be checked in reverse. It returns a hash with the modules as keys and any problems as values; the value for a successfully found module will be undef. Modules are searched for in C<@$incdirs>, defaulting to C<@INC>.

=head2 verify_dependencies($meta, $phases, $types, $incdirs)

Check all requirements in C<$meta> for phases C<$phases> and types C<$types>. Modules are searched for in C<@$incdirs>, defaulting to C<@INC>. C<$meta> should be a L<CPAN::Meta::Prereqs> or L<CPAN::Meta> object.

=head2 requirements_for($meta, $phases, $types)

B<< This function is deprecated and may be removed at some point in the future, please use CPAN::Meta::Prereqs->merged_requirements instead. >>

This function returns a unified L<CPAN::Meta::Requirements|CPAN::Meta::Requirements> object for all C<$type> requirements for C<$phases>. C<$phases> may be either one (scalar) value or an arrayref of valid values as defined by the L<CPAN::Meta spec|CPAN::Meta::Spec>. C<$type> must be a relationship as defined by the same spec. C<$meta> should be a L<CPAN::Meta::Prereqs> or L<CPAN::Meta> object.

=head1 SEE ALSO

=over 4

=item * L<Test::CheckDeps|Test::CheckDeps>

=item * L<CPAN::Meta|CPAN::Meta>

=back

=head1 AUTHOR

Leon Timmermans <leont@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2012 by Leon Timmermans.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
