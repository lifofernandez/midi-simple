
use feature 'say';
use Data::Dump qw( dump );
use MIDI;

# new_score;
# set: chanel=1 to patch=1 (a piano)
# patch_change 1, 1;


my $octave = 3;

my @chromatic = ( 0 .. 11 );
my @mayor = ( 0, 2, 4, 5, 7, 9, 11 );
my @minor = ( 0, 2, 3, 5, 7, 8, 10 );

my @transp = map { $_ + ( 12 * $octave ) } @chromatic;
dump( @transp );

# shuffle :)
my %pitches = @transp;  
dump( %pitches );

# setup empty note
my @events = (
    ['text_event',0, 'MORE KLAVIER'],
    ['set_tempo', 0, 450_000], # 1qn = .45 seconds
);
 
for my $pitch ( sort {$a <=> $b} %pitches ){
    say $pitch;
    push @events,
         ['note_on' , 90, 4, $pitch, 127],
         ['note_off',  6, 4, $pitch, 127],
    ;
}

my $klavier_track= MIDI::Track->new({ 
    'events' => \@events 
});
my $opus = MIDI::Opus->new({
    'format' => 0, 
    'ticks' => 96, 
    'tracks' => [ $klavier_track] 
});

$opus->write_to_file( 'serie.mid' );
