# Geo::E00
# 
# Perl class for dealing with E00 files.
#
#	Copyright (c) 2002 Tower Technologies s.r.l.
#	All Rights Reserved

package Geo::E00;

use strict;

use Carp;
use IO::File;
use Data::Dumper;

$Geo::E00::VERSION = '0.01';

# Constructor
sub new
{
	my($proto) = @_;

	my $class = ref($proto) || $proto;

	return bless {
		'FH'	=> undef,
	}, $class;
}

sub open
{
	my($self, $file) = @_;

	return undef unless defined $file;

	$self->{'FH'} = new IO::File $file, 'r';

	return $self->{'FH'};	
}

sub parse
{
	my($self) = @_;

	my $fh = $self->{'FH'};

	return undef unless defined $fh;

	# Read the first line
	my $headline = $fh->getline;

	return undef unless defined $headline;

	#print $headline;

	return undef unless $headline =~ m|^EXP\s+(\d+)\s+(.+)\s*$|;

	$self->{'VERSION'} = $1;
	$self->{'EXPFILE'} = $2;

	my $data = {};

	while (my $line = $fh->getline)
	{
		if ($line =~ m|^([A-Z]{3})\s+(\d+)$|)
		{
			# Section start

			my $section = $1;
			my $param = $2;

			#print "Got section: $section, $param\n";

			$data->{'arc'} = $self->parse_arc($fh) if $section eq 'ARC';
		}
	}

	return $data;
}

sub parse_arc
{
	my($self, $fh) = @_;

	my @sets = ();

	while (my $line = $fh->getline)
	{
		# Check for termination pattern
		last if $line =~ m|^\s*-1(\s+0){6}|;

		# Set header
		if ($line =~ m|^\s*(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)|)
		{
			my $arc = {
				'cov-num'	=> $1,
				'cov-id'	=> $2,
				'node-from'	=> $3,
				'node-to'	=> $4,
				'poly-left'	=> $5,
				'poly-right'	=> $6,
				'npoints'	=> $7,
			};
			
			my @coords = ();

			# print "NUM: $arc->{'cov-num'}, ID: $arc->{'cov-id'}, PAIRS: $arc->{'npoints'}\n"; 

			for (my $i = 0; $i < $arc->{'npoints'};)
			{
				# Get a new line

				my $cline = $fh->getline;

				# Check if this is a 2 pairs line

				if ($cline =~ m|^\s*([\d\.+E]+)\s+([\d\.+E]+)\s+([\d\.+E]+)\s+([\d\.+E]+)|)
				{
					push(@coords, $1, $2, $3, $4);

#					print " got 2 pairs line\n";
					$i += 2;

					next;
				}

				# 1 pair line

				if ($cline =~ m|^\s*([\d\.+E]+)\s+([\d\.+E]+)|)
				{
					push(@coords, $1, $2);

#					print " got 1 pair line\n";
					$i += 1;

					next;
				}

				Carp::croak "Unknown pair line: $cline\n";
			}

			Carp::croak "Wrong number of x-y pairs\n"
				 unless ((scalar @coords) / 2 ) eq $arc->{'npoints'};

			$arc->{'points'} = \@coords;

			push(@sets, $arc);

			next;
		}
	
		Carp::croak "Unknown set line: $line";	
	}
		
#	print Data::Dumper->Dump( [ \@sets ] );

#	print "END ARC SECTION\n";

	return \@sets;
}

1;


