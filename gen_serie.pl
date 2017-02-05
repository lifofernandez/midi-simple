
use feature 'say';
use Data::Dump qw( dump );
use MIDI::Simple;

new_score;
# set: chanel=1 to patch=1 (a piano)
patch_change 1, 1;

my $octave = 3;

my @chromatic = ( 0 .. 11 );
my @diatonic = ( "A".."G" );
my @mayor = ( 0, 2, 4, 5, 7, 9, 11 );
my @minor = ( 0, 2, 3, 5, 7, 8, 10 );

my @transp = map { $_ + ( 12 * $octave ) } @mayor;

# shuffle :)
my %pitches = @transp;  
dump( %pitches );

# setup empty note
noop c1, f, hn, "o".$octave; 

for my $pitch ( %pitches ){
     n $pitch, "o".$octave;
}

write_score 'serie.mid';
