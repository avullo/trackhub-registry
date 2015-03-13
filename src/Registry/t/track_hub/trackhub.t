use strict;
use warnings;

use Test::More;
use Test::Exception;

BEGIN {
  use FindBin qw/$Bin/;
  use lib "$Bin/../../lib";
}

use Registry::Utils;

use_ok 'Registry::TrackHub';

throws_ok { Registry::TrackHub->new() } qr/Undefined/, 'Throws if URL not passed';

my $WRONG_URL = "ftp://ftp.ebi.ac.uk/pub/databases/do_no_exist";
throws_ok { Registry::TrackHub->new(url => $WRONG_URL) } qr/check the source URL/, 'Throws with incorrect URL'; 

#
# TODO: Tests more exceptions, e.g. 
# - hub without genomesFile
# - hub without trackDb files referenced in genomesFile
#

SKIP: {
  skip "No Internet connection: cannot test TrackHub access", 8
    unless Registry::Utils::internet_connection_ok();

  my $URL = "ftp://ftp.ebi.ac.uk/pub/databases/blueprint/releases/current_release/homo_sapiens/hub";
  my $th = Registry::TrackHub->new(url => $URL);
  isa_ok($th, 'Registry::TrackHub');

  like($th->hub, qr/Blueprint_Hub/, 'Hub name');
  is($th->shortLabel, 'Blueprint Hub', 'Hub short label');
  is($th->longLabel, 'Blueprint Epigenomics Data Hub', 'Hub long label');
  is($th->genomesFile, 'genomes.txt', 'Hub genomes file');
  is($th->email, "blueprint-info\@ebi.ac.uk", 'Hub contact email');
  like($th->descriptionUrl, qr/http:\/\/www.blueprint-epigenome.eu\/index.cfm/, 'Hub description URL');

  is(scalar $th->assemblies, 1, 'Number of genomes');
  is(($th->assemblies)[0], 'hg19', 'Stored genome assembly data');
  #
  # Should probably do the following as Registry::TrackHub::Genome
  # specific tests. I presume this is ok since the specific trackDb
  # attribute information is created and manipulated by the module
  # tested here.
  #
  my $genome = $th->get_genome('hg19');
  isa_ok($genome, 'Registry::TrackHub::Genome');
  is_deeply($genome->trackDb, [ "$URL/hg19/tracksDb.txt" ], 'Hub trackDb assembly info');
}

done_testing();