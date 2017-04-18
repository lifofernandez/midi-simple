#!/usr/bin/env perl

########################################
# Secuenciador Motivocentrico 
# Lisandro Fernández ( Febrero 2017 )

use feature 'say';
use strict;
use Data::Dumper;
use MIDI;

########################################
# CONSTANTES

my $pulso = 1000_000; # mili
my $tic = 240; 

my $canal = 1;
my $programa = 1;

my $nombre = "piano";

# Track setup
my @events = (
    [ 'set_tempo', 0,$pulso ],
    [ 'text_event', 0, "Track: " . $nombre ],
    [ 'patch_change', 0, $canal, $programa ],
);

my $inicio  = 0;
my $duracion   = $tic;

my $altura  = 60;
my $dinamica = 127;

push @events, (
     [ 'note_on',   $inicio,    $canal, $altura,     $dinamica ],
     [ 'note_on',   0,    $canal, $altura + 2, $dinamica ],
     [ 'note_on',   0,    $canal, $altura + 4, $dinamica ],

     [ 'note_off',  $duracion,     $canal, $altura,     0 ],
     [ 'note_off',  0,     $canal, $altura + 2, 0 ],
     [ 'note_off',  0,     $canal, $altura + 4, 0 ],


     [ 'note_on',   $duracion * 2 ,    $canal, $altura,     $dinamica ],
     [ 'note_on',   0,    $canal, $altura + 2, $dinamica ],
     [ 'note_on',   0,    $canal, $altura + 4, $dinamica ],

     [ 'note_off',  $duracion * 3,     $canal, $altura,     0 ],
     [ 'note_off',  0,     $canal, $altura + 2, 0 ],
     [ 'note_off',  0,     $canal, $altura + 4, 0 ],


);
my @tracks;
my $track = MIDI::Track->new({
    'events' => \@events
});
push @tracks, $track;
my $opus = MIDI::Opus->new({
    'format' => 1,
    'ticks' => $tic,
    'tracks' => \@tracks
});
print Dumper($opus);


$opus->write_to_file( 'output/secuencia.mid' );

