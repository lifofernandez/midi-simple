#!/usr/bin/env perl

########################################
# Secuenciador Motivocentrico 
# Lisandro Fernández ( Febrero 2017 )

use feature 'say';
use strict;
use warnings;
use Pod::Usage;
use Getopt::Long;

use MIDI;
use YAML::XS 'LoadFile';
use POSIX qw(log10);
 use Data::Dumper;

########################################
# ARGUMENTS
my $secuenciador_VER = '0.00.01';
my $site        = 'http://www.github.com/lifofernandez';
my (
    $help, 
    $verbose,
    $man,
    $info
);
my $salida  = 'secuencia.mid';
my $bpm = '60';

my @entradas = ();
my $entrada = ('tracks');

GetOptions(
    'entradas=s' => \@entradas,
    'salida=s'   => \$salida, 
    'bpm=i'      => \$bpm, 

    'verbose+'   => \$verbose, 
    'help!'      => \$help, 
    'man!'       => \$man,
    'info!'      => \$info,
);
print Dumper (@entradas);
# pod2usage(-verbose => 1) && exit if ($opt_debug !~ /^[01]$/);
pod2usage(-verbose => 1) && exit if defined $help;
pod2usage(-verbose => 2) && exit if defined $man;

########################################
# CONSTANTES

my $tic = 240; 
my $pulso = int( ( 60 / $bpm ) * 1000 ) . '_000';
my $simbolo_prima = "^";

my @CONFIGS = ();
for( @entradas ){
    if( -f $_ ){
      push @CONFIGS, $_;
    }
    if( -d $_ ){
      my @dir = <./$_/*>;
      push @CONFIGS, @dir;
    }
}
print Dumper (@CONFIGS);


my @tracks;
for( @CONFIGS ){

    my $config_file = LoadFile( $_ );
    my %constantes = %{ $config_file->{ constantes } };

    my $metro = $constantes{ metro } // '4/4';
    my (
        $numerador,
        $denominador,
    ) = split '/', $metro;
    # The denominator is a negative power of two: log10( X ) / log10( 2 ) 
    # 2 represents a quarter-note, 3 represents an eighth-note, etc.
    $denominador = log10( $denominador ) / log10( 2 );

    # Track setup
    my $nombre = $constantes{ nombre };
    say "\n" . "#" x 80 if $verbose;
    say "TRACK: ".$nombre;

    # Propiedades generales que heredan todos los motivos
    #  que pueden ser sobreescritas en c/u-
    my %defacto  = prosesar_sets( \%{ $config_file->{ defacto } } );

    my $canal = $defacto{ canal };
    say "CANAL: ".$canal if $verbose;

    my $programa = $defacto{ programa };
    say "PROGRAMA: ".$programa if $verbose;

    my @macroforma = @{ $constantes{ macroforma } };
    print "MACROFORMA: " if $verbose;
    print  "@macroforma\n" if $verbose;

    my $repeticiones = $constantes{ repeticiones };
    say "REPETICIONES: " . $repeticiones if $verbose;

    ########################################
    # Preparar Estructuras > Motivos > Componentes

    my %ESTRUCTURAS = ();
    for my $estructuraID(
        keys %{ $config_file->{ ESTRUCTURAS } }
    ){
        print "\n";
        say "ESTRUCTURA: " . $estructuraID if $verbose;
        my %estructura = %{ $config_file->{ ESTRUCTURAS }{ $estructuraID } };
        print "  FORMA: " if $verbose;
        print "@{ $estructura{ forma } }\n" if $verbose;

        my %MOTIVOS = ();
        for my $motivoID(
            sort
            keys %{ $estructura{ MOTIVOS } }
        ){
            say "  MOTIVO: " . $motivoID if $verbose;
            my %motivo = prosesar_sets( 
                \%{ $estructura{ MOTIVOS }{ $motivoID } } 
            );

            # Motivos que heredan propiedades de otros
            # a^, a^^, a^^^, etc
            my $padreID = $motivoID;
            my $prima = chop( $padreID );
            if( $prima eq $simbolo_prima ){
                 my %prima = %{ $MOTIVOS{ $padreID } };
                 %motivo = heredar( \%prima, \%motivo );
            }
            # Sucesion de bienes...
            %motivo = heredar( \%defacto, \%motivo );

            ########################################
            # Procesar motivos armar componetes
            # combinado parametros ( altura, duracion, dinamicas, etc )

            my @alturas = map {
                  $_ +
                  $motivo{ alturas }{ tonica } +
                  ( 12 * $motivo{ alturas }{ octava } )
            } @{ $motivo{ alturas }{ procesas } };
            print "   ALTURAS: " if $verbose;
            print "@alturas\n" if $verbose;

            my @microforma =  @{ $motivo{ microforma } } ;
            print "   MICROFORMA: " if $verbose;
            print "@microforma\n" if $verbose;

            print "   ORDENADOR: " . $motivo{ ordenador }. "\n" if $verbose;

            my @duraciones = @{ $motivo{ duraciones }{ procesas } };
            my @dinamicas  = @{ $motivo{ dinamicas }{ procesas } };

            my $indice = 0;
            my @COMPONENTES = ();
            say "   COMPONENTES" if $verbose;
            for( @microforma  ){

               my $cabezal = $_ - 1; # posicion en las lista de alturas
               my $altura = @alturas[ ( $cabezal ) % scalar @alturas ];

               my $nota_st = '';
               my @VOCES = ();
               for( 
                   @{ $motivo{ voces }{ procesas } } 
               ){
                    #TODO revisar/usar voz relacion = 0
                    if ( $_ ne 0 ){
                        # pos. en las lista de alturas para la esta voz 
                        my $cabezal_voz = ( $cabezal + $_ ) - 1;
                        my $voz = @alturas[ $cabezal_voz % scalar @alturas ];
                        push @VOCES, $voz;

                        $nota_st  = $nota_st . $voz  . " ";
                    }
               }
               my $voces_st =  "ALTURAS: " . $nota_st;

               my $duracion  = @duraciones[ $indice % scalar @duraciones ];
               my $dinamica  = @dinamicas[ $indice % scalar @dinamicas ];

               if ( $_ eq 0 ){
                   $altura = 0;
                   $dinamica = 0;
                   splice( @VOCES );
                   $voces_st=  "SILENCIO";
               }

               my $componente = {
                  indice   => $indice,
                  altura   => $altura,
                  voces    => \@VOCES,
                  duracion => $duracion,
                  dinamica => $dinamica,
               };
               push @COMPONENTES, $componente;
               $indice++;

               # verbosidad
               print "    " if $verbose;
               print "INDICE: " . $indice . " " if $verbose;
               print "\tCABEZAL: " . ( $cabezal + 1) . " " if $verbose;
               print "\tDINAMICA: " . int( $dinamica * 127 ) if $verbose;
               print "\t" . $voces_st  if $verbose;
               print "\tDURACION: " . $duracion . "qn" if $verbose;
               print "\n" if $verbose;
            }

            # Paso AoH a HoH
            my %temp_comps; 
            @temp_comps{ @COMPONENTES } = @COMPONENTES;

            $motivo{ COMPONENTES } = \%temp_comps;

            $MOTIVOS{ $motivoID } = \%motivo;
        }
        $estructura{ MOTIVOS } = \%MOTIVOS;
        $ESTRUCTURAS{ $estructuraID } = \%estructura;
    }

    # TESTS
    # print Dumper %{ $ESTRUCTURAS{ A }{ MOTIVOS }{ a }{ dinamicas} };
    # print Dumper @{ $ESTRUCTURAS{ A }{ MOTIVOS }{ a }{ voces }{procesas} };
    # print Dumper %{ $ESTRUCTURAS{ A }{ MOTIVOS }{ "a^" } };
    # print Dumper @{ $ESTRUCTURAS{ A }{ MOTIVOS }{ a }{ microforma } };
    # print Dumper @{ $ESTRUCTURAS{ A }{ forma } };
    # print Dumper %{ $ESTRUCTURAS{ A }{ MOTIVOS }{ a }{componentes } };
    # print Dumper @{ $constantes{ macroforma } };


    ########################################
    # SECUENCIAR 

    # Track setup
    my @events = (
        [ 'set_tempo', 0, $pulso ],
        [ 'time_signature', 0, $numerador, $denominador, 24, 8],
        [ 'text_event', 0, "TRACK: " . $nombre ],
        [ 'patch_change', 0, $canal, $programa ],
    );

    my $momento = 0;
    for(
        # reverse
        ( @macroforma )
        x $repeticiones
    ){
          my %E =  %{ $ESTRUCTURAS{ $_ } };
          for(
              # reverse
              @{ $E{ forma } }
          ){
             my %M =  %{ $E{ MOTIVOS }{ $_ } };
             my %C =  %{ $M{ COMPONENTES } };

             my $orden = $M{ ordenador } // 'indice';

             my $retraso =  int( $tic * ( $M{ duraciones }{ retraso } // 0 ) );
             my $recorte =  int( $tic * ( $M{ duraciones }{ recorte } // 0 ) );

             my $fluctuacion = $M{ dinamicas }{ fluctuacion };

             my @compIDs = grep defined $C{ $_ }{ $orden }, keys %C;
             for my $componenteID (
                 sort { $C{ $a }{ $orden } <=> $C{ $b }{ $orden } } 
                 @compIDs # keys %C
             ){
                 my $final = $tic * $C{ $componenteID }{ duracion };

                 my @V = @{ $C{ $componenteID }{ voces } };
                 # Sin Voces = SILENCIO
                 if ( !@V ){
                     $momento = $momento + $final;
                     next;
                 }

                 $momento = $momento + $retraso; 
                 $final = $final - $recorte - $retraso;

                 my $rand = 0;
                 if ( $fluctuacion ){
                     my $min  = -$fluctuacion;
                     my $max  = $fluctuacion;
                     $rand = $min + rand( $max - $min );
                 }

                 my $dinamica = int(
                     127 * ( $C{ $componenteID }{ dinamica } + $rand ) 
                 );

                 for( @V ){
                     my $altura = $_;
                     push @events, (
                         [ 'note_on' , $momento, $canal, $altura, $dinamica ],
                     );
                     $momento = 0;
                 }
                 $momento = $momento + $recorte; 
                 for( @V ){
                     my $altura = $_;
                     push @events, (
                         [ 'note_off', $final,  $canal, $altura, 0 ],
                     );
                     $final = 0;
                 }
            }
        }
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
$opus->write_to_file( $salida );

# SUBS
# Reecorre 1 HASH, evalua custom sets y arrays regulares
sub prosesar_sets{
    my $H = shift;
    for my $v( keys %{ $H } ){
        if(
           ( ref( $H->{ $v } ) eq 'HASH' ) &&
           ( exists $H->{ $v }{ set } )
        ){
            my $grano = $H->{ $v }{ grano } // 1;
            my $operador = $H->{ $v }{ operador } // '*';

            my @array_evaluado = map {
               eval $_
            } @{ $H->{ $v }{ set } };
            my @array_procesado = map { 
               eval( $_ . $operador . $grano ) 
            } @array_evaluado;

            my $reverse = $H->{ $v }{ reverse } // 0;
            @array_procesado = reverse @array_procesado if $reverse;

            $H->{ $v }{ procesas } = \@array_procesado;

        }
        if( ref( $H->{ $v } ) eq 'ARRAY'){ 
            my @array_evaluado = map {
               eval $_
            } @{ $H->{ $v } };
            $H->{ $v } = \@array_evaluado;
        }

    }
    return %{ $H };
}

# Pasar propiedades faltantes de %Ha > %Hb 
sub heredar{
    my( $padre, $hijo ) = @_;

    for my $propiedad(
        keys %{ $padre }
    ){
        if( !$hijo->{ $propiedad } ){
             $hijo->{ $propiedad } = $padre->{ $propiedad };
        }elsif( ref( $hijo->{ $propiedad } ) eq 'HASH' ){ 
            my %nieto = heredar( 
                 \%{ $padre->{ $propiedad } },
                 \%{ $hijo->{ $propiedad } }
            );
            $hijo->{ $propiedad } = \%nieto; 
        }
    }
    return %{ $hijo } 
}



END{
  if(defined $info){
    print
      "\nModules, Perl, OS, Program info:\n",
      "  Pod::Usage            $Pod::Usage::VERSION\n",
      "  Getopt::Long          $Getopt::Long::VERSION\n",
      "  MIDI                  $MIDI::VERSION\n",
      "  YAML::XS              $YAML::XS::VERSION\n",
      "  POSIX                 $POSIX::VERSION \n",
      "  strict                $strict::VERSION\n",
      "  Perl                  $]\n",
      "  OS                    $^O\n",
      "  secuenciador.pl       $secuenciador_VER\n",
      "  $0\n",
      "  $site\n",
      "\n\n";
  }
}


=head1 NAME

 secuenciador.pl

=head1 SYNOPSIS

 secuenciador.pl Buenos Aires, Argentina. 

 Generar secuencia MIDI a partir de hojas de analisis serializadas
 en sintaxis YAML. 
 
 NOTA: 
 Tanto el codigo, como tambien esta documentacion, fue realizada lo maximo 
 posible en espaniol (debemos presindir de carateres latinos) para en un 
 principio favorecer y atraer a usuarios que no leen ingles.
 No se descarta la posibilidad de futuras traducciones.


=head1 DESCRIPTION

 Cada track MIDI es representado por una hoja de analisis con las 
 configuraciones necesarias para obtener una progresion musical.

 La organizacion interna de estas configuraciones de track trata de 
 representar una hoja de analisis musical estandar jerarquizada en 
 Estrcucturas que continenen Motivos. 

 A su vez, se propone acercar a la flexibilidad fomentada por el entorno de
 programacion Perl y su ecosistema.

 Los Motivos pueden heredar propiedades tanto de configuraciones generales
 (defactos) asi como tambien de otros motivos "primos".
 
 Todos los Sets (alturas, duraciones, dinamicas, etc) soportan rangos 
 y operaciones matematicas.

 Mas inforamcion en los ejemplos

 Los argumentos pueden declararse tanto en forma larga como corta.
 ejemplo:
   secuenciador.pl --help
   secuenciador.pl -h

 
=head1 ARGUMENTS

 --help       Imprime esta ayuda en vez de generar secuencia MIDI.
 --man        Imprime la pagina man completa en vez de generar MIDI.


=head1 OPTIONS

 --info       Informacion sobre, modulos, entorno y programa.
 --verbose    Expone los elementos musicales previamente a secuenciarlos. 

=head1 AUTHOR

 Lisandro Fernandez

=head1 CREDITS


=head1 TESTED

 Pod::Usage            1.68
 Getopt::Long          2.48
 MIDI                  0.83
 YAML::XS              0.63
 POSIX                 1.65 
 strict                1.11
 Perl                  5.024001
 OS                    linux
 secuenciador.pl       0.00.01
 ./secuenciador.pl

=head1 BUGS
 
 El pulso no esta funcionando bien en Live, corroborar si esto es asi 
 en otro software.
 
=head1 TODO

 Lista defacto general para todos los tracks/configs.
 Extender herencia a Estructuras.
 Control de superposicion o separacion entre estructuras, motivos 
 y componentes.
 Terminar esta documnetacion.
 Test on ActivePerl
 Agregar informacion de debbugeo en errores

=head1 UPDATES

 2017-04-23   12:00 GTM+3
   Feliz Cumpleanios Complete, es capaz de secuenciar la melodia
   desde la hoja de analisis.

=cut





