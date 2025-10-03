#!/usr/bin/env starperl

=head1 NAME

query-simbad - Update pointing catalog values from SIMBAD

=head1 DESCRIPTION

Currently only processes entries with proper motion.

Updates the proper motion, parallax, RA and Dec from SIMBAD.

=head2 Data Files

This script makes use of the following files:

=over 4

=item C<misc/simbad-names.yml>

Mapping from JCMT pointing catalog names to names which can be
looked up at SIMBAD.

=item C<simbad-cache.storable> (in current directory)

Cache of SIMBAD query results.

=back

=cut

use strict;
use IO::File;
use YAML::XS qw/LoadFile/;
use Storable qw/nstore retrieve/;
use Astro::Catalog::Query::SIMBAD;


my $NAMES_FILE = 'misc/simbad-names.yml';
my $CACHE_FILE = 'simbad-cache.storable';


my $simbad_names = LoadFile($NAMES_FILE);

my $simbad_cache = {};
$simbad_cache = retrieve($CACHE_FILE) if -e $CACHE_FILE;

my $cat = Astro::Catalog->new(
    File => 'point.cat',
    Format => 'JCMT',
    ReadOpt => {
        incplanets => 0,
        inccomments => 1,
        respacecomments => 0
    });

do {
    local $\ = "\n";

    foreach my $item ($cat->stars) {
        my $id = $item->id;
        my $coord = $item->coords;
        next unless $coord->isa('Astro::Coords::Equatorial');

        my @pm = $coord->pm;
        next unless scalar @pm;

        my $simbad_name = $simbad_names->{$id} // $id;

        print STDERR "Looking up $id (SIMBAD name: $simbad_name)";

        my $simbad_coords;
        if (exists $simbad_cache->{$simbad_name}) {
            $simbad_coords = $simbad_cache->{$simbad_name};
        }
        else {
            my @results = Astro::Catalog::Query::SIMBAD->new(
                Target => $simbad_name,
            )->querydb->stars;

            unless (1 == scalar @results) {
                die "No/multiple result for $id";
            }

            $simbad_cache->{$simbad_name} = $simbad_coords = $results[0]->coords;
            nstore($simbad_cache, $CACHE_FILE);
        }

        my @pm = $simbad_coords->pm;
        unless (scalar @pm) {
            print STDERR "No PM for $id (skipping)";
            next;
        }

        $coord->{'ra2000'} = $simbad_coords->{'ra2000'};
        $coord->{'dec2000'} = $simbad_coords->{'dec2000'};
        $coord->pm(@pm);

        my $parallax = $simbad_coords->parallax;
        if ($parallax) {
            $coord->parallax($parallax);
        }
        else {
            $parallax = $coord->parallax;
            print STDERR "No parallax for $id (retaining previous value of $parallax)";
        }
    }
};

$cat->write_catalog(
    File => \*STDOUT,
    Format => 'JCMT',
    incheader => 0,
    removeduplicates => 0);

__END__

=head1 COPYRIGHT

Copyright (C) 2025 East Asian Observatory
All Rights Reserved.

This program is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation; either version 2 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful,but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
details.

You should have received a copy of the GNU General Public License along with
this program; if not, write to the Free Software Foundation, Inc.,51 Franklin
Street, Fifth Floor, Boston, MA  02110-1301, USA

=cut
