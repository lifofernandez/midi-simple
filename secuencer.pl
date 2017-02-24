#!/usr/bin/env perl

########################################
# Secuenciador Motivocentrico 
# 
# Lisandro Fernández ( Febrero 2017 )

use feature 'say';
use strict;
use Data::Dumper;
use MIDI;
use YAML::XS 'LoadFile';

########################################
# General setup

my $pulso = 600_000; # mili
my $tic = 240; 
my @confs = ( 
	# 'tracks/drums.yml',
	# 'tracks/cymbals.yml',
	'tracks/bajo.yml',
);
my @tracks;


foreach ( @confs ){
    
    ########################################
    # Load track from YAML
    my $conf = LoadFile( $_ );
    
    # Track setup
    my $nombre = $conf->{ nombre };
    my $canal = $conf->{ canal };
    my $programa = $conf->{ programa };
    
    
    ########################################
    # Configuraciones generales

    my $tonica = $conf->{ tonica };
    my $octava = $conf->{ octava };

    my @escala = map {
        eval $_ # Perl Ranges suport 
    } @{ $conf->{ escala }{ notas } };

    my @alturas = map { 
        $_ + $tonica + ( 12 * $octava ) 
    } @escala;
    
    my @duraciones = @{ $conf->{ duraciones } };
    my $retraso = $conf->{ retraso }; 
    # To do: superposicion de las notas
    
    my @dinamicas = @{ $conf->{ dinamicas } }; 
    my $piso = $conf->{ piso }; 
    my $variacion = $conf->{ variacion }; 
    
    
    ########################################
    # Manipular y definir motivos 

    my %motivos = (); 
    foreach( 
     	# reverse
     	@{ $conf->{ motivos } }
    ){
	my %temp = %{ $_ };

	my $this_id = %temp{ "identificador" }; 
	
	# Sobrescribir las configuraciones generales
	# con las de este motivo, si las hay.
	my $this_tonica = %temp{ "tonica" } ? %temp{ "tonica" } : $tonica;
        my $this_octava = %temp{ "octava" } ? %temp{ "octava" } : $octava;
        
        my @this_escala;
        if( %temp{ "escala" } ){
            @this_escala = map {
                eval $_ # así soporta rangos en los yamls
            } @{ %temp{ "escala" }->{ "notas" } };
	} else {
            @this_escala = @escala;
	}
        my @this_alturas = map { 
            $_ + $this_tonica + ( 12 * $this_octava ) 
        } @this_escala;
	print Dumper(@this_escala);

	my @this_duraciones = %temp{ "duraciones"} ? %temp{ "duraciones" } : @duraciones;
	my @this_dinamicas = %temp{ "dinamicas" }  ? %temp{ "dinamicas" } : @dinamicas;
	my $this_piso = %temp{ "piso" } ? %temp{ "piso" } : $piso;
	my $this_variacion = %temp{ "variacion" } ? %temp{ "variacion" } : $variacion;
        
	# Construir componentes del motivo ( indice, altura, duración y dinámica )
	

	my $n = 1;
        my @temp_comps = ();
	foreach( @{ %temp{ "progresion" } } ){
             my ( 
                  $lector_altura, # posicion en las lista de alturas
         	  $ajuste
             ) = split;

	     my $nota_altura = @this_alturas[ ( $lector_altura - 1 ) % scalar @this_alturas ] + $ajuste;
	     

             #     my $duracion   = $tic * @duraciones[ $index % $cantidad_duraciones ];
             #     my $dinamica   = 127 * @dinamicas[ $index % $cantidad_dinamicas ];
             #     my $compresion = $piso + rand ( $variacion );
             #     
             #     my $inicio = $retraso;
             #     my $final  = $duracion;

	     my $componente = { 
	        indice   => $n,
	        altura   => $nota_altura,
	        duracion => 1,
	        dinamica => .5,
             };
	     
	     push @temp_comps, $componente;
	     $n++;
        }	

	my %componentes = @temp_comps;
	# Agregar motivios
	$motivos{ $this_id }{"componentes"}= \%componentes; 
    }
    

    ########################################
    # Secuenciar motivos ( array de motivos ) 
    # nota: Add super especial feture: control de  gap/superposicion entre motivos
    
    # my $repeticiones = 

    my @secuencia;  
    foreach( @{ $conf->{ secuencia_motivica } } ){
         my $id =  $_;
	 #print Dumper( %motivos{ $id} );
         push @secuencia, %motivos{ $id }->{ "componentes"}  ;
    }
    ## print Dumper( @secuencia );
    # push @secuencia, ( @secuencia ) x $conf->{ repeticiones };
    
    ########################################
    # Convertir Secuencia a MIDI::Events 
    
    # Setup
    my @events = (
        [ 'set_tempo', 0, $pulso ], 
        [ 'text_event', 0, "Track: " . $nombre ], 
        [ 'patch_change', 0, $canal, $programa ], 
    );
    
    my $index = 0;
    foreach ( 
     	# reverse
     	@secuencia 
    ){
        my %nota = @{ $_ };
        say %nota{"duracion"} ;
    #     push @events, (
    #         [ 'note_on' , $inicio, $canal, $altura, $dinamica * $compresion ],
    #         [ 'note_off', $final,  $canal, $altura, 0 ]
    #     );
    #     $index++;

    }
     
    my $track = MIDI::Track->new({ 
        'events' => \@events 
    });
    push @tracks, $track;

}

my $opus = MIDI::Opus->new({
    'format' => 1, 
    'ticks' => $tic,
    'tracks' => \@tracks 
});
$opus->write_to_file( 'output/secuencia.mid' );
