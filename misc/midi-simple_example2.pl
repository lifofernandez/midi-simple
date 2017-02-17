# fluidsynth -aalsa /usr/share/soundfonts/FluidR3_GM.sf2 round2c.mid
use MIDI::Simple .68;
use Data::Dump qw(dump);
my $measure = 0; # changed by &amp;counter

my @phrases =(
   [ Cs, F, Ds, Gs_d1 ], [Cs, Ds, F, Cs],
   [ F, Cs, Ds, Gs_d1 ], [Gs_d1, Ds, F, Cs]
);

@bass_line = ( F, Cs, Ds, Gs_d1, Gs_d1, Ds, F, Cs);

new_score;

# Some MIDI meta-information:
copyright_text_event "1998 Sean M. Burke";
text_event "Title: Westminster Round";
# Patch inits:
# patch 16 = Drawbar Organ. 8 = Celesta.
patch_change 0, 16;
patch_change 1, 8; patch_change 2, 8;
patch_change 3, 8; patch_change 4, 8;

for (1 .. 8) {
     synch(
	    \&count, 
	    \&bass, 
	    \&first,
            \&second, 
	    \&third, 
	    \&fourth
	);
}

r hn; # pause. take a bow!
write_score("round2c.mid");
dump_score;
exit;

sub count {
    my $it = shift;
    ++$measure;
    $it->r(wn); # whole rest
}

 sub first {
     my $it = shift;
     $it->noop(c1,mf,o3,qn);
     my $phrase_number = ($measure + -1) % 4;
     my @phrase = @{$phrases[$phrase_number]};
     foreach my $note (@phrase) { $it->n($note) }
 }

 sub second {
     my $it = shift;
     return if $measure < 2 or $measure > 5;
     $it->noop(c2,mf,o4,qn);
     my $phrase_number = ($measure + 0) % 4;
     my @phrase = @{$phrases[$phrase_number]};
     foreach my $note (@phrase) { $it->n($note) }
 }

 sub third {
     my $it = shift;
     return if $measure < 3 or $measure > 6;
     $it->noop(c3,mf,o5,qn);
     my $phrase_number = ($measure + 1) % 4;
     my @phrase = @{$phrases[$phrase_number]};
     # foreach my $note (@phrase) { $it->($note) }
     foreach my $note (@phrase) { $it->n($note) }
 }

 sub fourth {
     my $it = shift;
     return if $measure < 4 or $measure > 7;
     $it->noop(c4,mf,o6,qn);
     my $phrase_number = ($measure + 2) % 4;
     my @phrase = @{$phrases[$phrase_number]};
     foreach my $note (@phrase) { $it->n($note) }
 }

 sub bass {
     my $it = shift;
     my $basis_note = $bass_line[($measure - 1) % 4];
     $it->noop(c0,fff,o3, wn); 
     dump($it);
     $it->n($basis_note);
 }
