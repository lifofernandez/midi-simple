#!/usr/bin/env perl
use Data::Dump qw( dump );
use MIDI;


foreach $one (@ARGV) {
    my $opus = MIDI::Opus->new({ 
       'from_file' => $one, 
    });
    print "$one has ", scalar( $opus->tracks ), " tracks\n";


    dump ($opus);
}

exit;

