#!/usr/bin/env perl
# Perl and MIDI: Simple Languages, Easy Music - The Perl Journal, Spring 1999

use MIDI::Simple;
new_score;
patch_change 1, 8; # set Channel 1 to Patch 8 = Celesta

n c1, f, qn, Cs2; 
n F2; 
n Ds2;

n hn, Gs1;

n qn, Cs2; 
n Ds2; 
n F2; 

n hn, Cs2;

n qn, F2; 
n Cs2; 
n Ds2; 

n hn, Gs1;

n qn, Gs1; 
n Ds2; 
n F2; 
n hn, Cs2;
write_score 'chimes.mid';
