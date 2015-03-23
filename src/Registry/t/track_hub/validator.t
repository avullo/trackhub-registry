use strict;
use warnings;

use Test::More;
use Test::Exception;

BEGIN {
  use FindBin qw/$Bin/;
  use lib "$Bin/../../lib";
}

local $SIG{__WARN__} = sub {};

use File::Temp qw/tempfile/;
use Registry::Utils;
use Registry::GenomeAssembly::Schema;
use Registry::TrackHub::Translator;

use_ok 'Registry::TrackHub::Validator';

my $version = '1.0';

throws_ok { Registry::TrackHub::Validator->new() } qr/Undefined/, "Throws if required arg is undefined";

my $validator = Registry::TrackHub::Validator->new(schema => "$Bin/../../../../docs/trackhub-schema/v1.0/trackhub-schema_1_0.json");
isa_ok($validator, 'Registry::TrackHub::Validator');

SKIP: {
  skip "No Internet connection: cannot test TrackHub validation on public Track Hubs", 9
    unless Registry::Utils::internet_connection_ok();

  # my $translator = Registry::TrackHub::Translator->new(version => $version);
  # isa_ok($translator, 'Registry::TrackHub::Translator');

  # my ($URL, $json_docs);

  # # Validate Bluprint Track Data Hub
  # note "Validating translation of Bluprint trackhub";
  # $URL = "ftp://ftp.ebi.ac.uk/pub/databases/blueprint/releases/current_release/homo_sapiens/hub";
  # $json_docs = $translator->translate($URL, 'hg19');

  # # print the translation to file so we can fire the validator
  # my ($fh, $filename) = tempfile( DIR => '.', SUFFIX => '.json');
  # print $fh $json_docs->[0];
  
  ok($validator->validate("$Bin/blueprint.json"), "Validate correct document");
  
}

done_testing();
