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
use POSIX qw( log10 );
use Data::Dumper;

=head1 NAME

 secuenciador.pl

=head1 SYNOPSIS

 Generar secuencia MIDI a partir de multiples hojas de analisis 
 serializadas en sintaxis YAML. 

=head1 ARGUMENTS

 --intput     Multiples Tracks en formato YAML acepta archivos o carpetas.
 --output     Archivo .mid a generar.
 --bpm        Pulsos por minuto para la secuencia.
 --help       Imprime esta ayuda en vez de generar secuencia MIDI.
 --man        Imprime la pagina man completa en vez de generar MIDI.

 Los argumentos pueden declararse tanto en forma larga como corta.
 Por ejemplo:
   secuenciador.pl --intput ejemplos
   secuenciador.pl -i ejemplos -o secuencia.mid

=head1 OPTIONS

 --sistema    Informacion sobrei entorno, modulos, y programa.
 --verbose    Expone los elementos previo a secuenciarlos. 
=cut

my $version = '0.01.00';
my $site    = 'http://www.github.com/lifofernandez/midi-simple';
my (
    $salida,
    $help,
    $verbose,
    $man,
    $info
);
my $bpm = '60';
my @entradas = ();
GetOptions(
    'intput=s'   => \@entradas,
    'output=s'   => \$salida, 
    'bpm=i'      => \$bpm, 
    'verbose+'   => \$verbose, 
    'help!'      => \$help, 
    'man!'       => \$man,
    'sistema!'      => \$info,
);
# pod2usage(-verbose => 1) && exit if ($opt_debug !~ /^[01]$/);
pod2usage( -verbose => 1 ) && exit if defined $help;
pod2usage( -verbose => 2 ) && exit if defined $man;

########################################
# CONSTANTES
my $tic = 240; 
my $pulso = int( ( 60 / $bpm ) * 1000000 );
my $simbolo_prima = "^";
# Carga de archivos o carpetas
# TODO: revisar carpetas andetro de carpetas
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

########################################
# PRE-PROCESO DE ELEMENTOS
my @tracks;
for( @CONFIGS ){
    my $config_file = LoadFile( $_ );
    my %constantes = %{ $config_file->{ constantes } };
    my $metro = $constantes{ metro } // '4/4';
    my (
        $numerador,
        $denominador,
    ) = split '/', $metro;
    # Time Signature event
    # rpm.pbone.net/index.php3/stat/45/idpl/2395553/numer/3/nazwa/MIDI::Filespec
    # The denominator is a negative power of two: log10( X ) / log10( 2 ) 
    # 2 represents a quarter-note, 3 represents an eighth-note, etc.
    $denominador = log10( $denominador ) / log10( 2 );
    # Track setup
    my $nombre = $constantes{ nombre };
    say "\n" . "#" x 80 if $verbose;
    say "TRACK: ".$nombre;
    # Propiedades generales que heredan todos los motivos
    # y que pueden ser sobreescritas en c/u.
    my %defacto  = %{ $config_file->{ defacto } };
    my $canal = $defacto{ canal };
    say "CANAL: ".$canal if $verbose;
    my $programa = $defacto{ programa };
    say "PROGRAMA: ".$programa if $verbose;
    my @macroforma = @{ $constantes{ macroforma } };
    @macroforma = reverse @macroforma if $constantes{ revertir };
    print "MACROFORMA: " if $verbose;
    print  "@macroforma\n" if $verbose;
    my $repetir = $constantes{ repetir } // 1;
    say "repetir: " . $repetir if $verbose;

    ########################################
    # Preparar Estructuras > Motivos > Componentes
    my %ESTRUCTURAS = %{ $config_file->{ ESTRUCTURAS } };
    for my $estructuraID(
        sort
        keys %ESTRUCTURAS 
    ){
        print "\n";
        say "ESTRUCTURA: " . $estructuraID if $verbose;
        my %estructura = %{ $ESTRUCTURAS{ $estructuraID } };
        # Estructuras que heredan propiedades de otros
        # A^^ hereda de A^ que hereda de A.
        my $madreID = $estructuraID;
        my $prima = chop( $madreID );
        if( $prima eq $simbolo_prima ){
             my %prima = %{ $ESTRUCTURAS{ $madreID } };
             %estructura = heredar( \%prima, \%estructura);
        }
        print "  FORMA: " if $verbose;
        print "@{ $estructura{ forma } }\n" if $verbose;

        my %MOTIVOS = ();
        for my $motivoID(
            sort
            keys %{ $estructura{ MOTIVOS } }
        ){
            say "  MOTIVO: " . $motivoID if $verbose;
            my %motivo = %{ $estructura{ MOTIVOS }{ $motivoID } };
            # Motivos que heredan propiedades de otros
            # a^^ hereda de a^ que hereda de a.
            my $padreID = $motivoID;
            my $primo = chop( $padreID );
            if( $primo eq $simbolo_prima ){
                 my %primo = %{ $MOTIVOS{ $padreID } };
                 %motivo = heredar( \%primo, \%motivo );
            }
            # Carga configuraciones generales 
            %motivo = heredar( \%defacto, \%motivo );
            # Procesar Custom Sets 
            %motivo = prosesar_sets( \%motivo );

            ########################################
            # Procesar motivos armar componetes
            # combinado parametros ( altura, duracion, dinamicas, etc )
            my @alturas = map {
                  $_ +
                  $motivo{ tonica } +
                  ( 12 * $motivo{ octava } )
            } @{ $motivo{ intervalos }{ factura } };

            my $transponer = 0; 
            $transponer = $motivo{ transponer } if $motivo{ transponer };
            my @microforma =  @{ $motivo{ microforma } } ;
            @microforma = reverse @microforma if $motivo{ revertir_microforma };
            my $repetir_motivo =   $motivo{ repetir } // 1;
            my @duraciones = @{ $motivo{ duraciones }{ factura } };
            my @dinamicas  = @{ $motivo{ dinamicas }{ factura } };
            my $indice = 0;
            my @COMPONENTES = ();

	    if( $verbose ){ 
                print "   ALTURAS: " . 
                     "@alturas\n" .
                     "   MICROFORMA: " .
                     "@microforma\n" .
                     "   ORDENADOR: " . $motivo{ ordenador }. "\n" ;
                print "   REVERTIR: " . $motivo{ revertir } . "\n" if $motivo{ revertir };
                print "   TRASPONER: " . $transponer . "\n" if $transponer;
                say "   COMPONENTES";
	     }

            for( ( @microforma ) x $repetir_motivo ){
               # posicion en set de intervalos
               my $cabezal = $_ - 1; 
               # reservar un elemento ( 0 ) para representar  silencio.
               # esto es solo para poder ordenar por altura, 
               my $altura = @alturas[ ( $cabezal ) % scalar @alturas ];
               my $nota_st = '';
               my @VOCES = ();
               for( @{ $motivo{ voces }{ factura } }[0] ){
		    print Dumper( $_ );
                    if ( $_ ne 0 ){
                        # posicion en en set de intervalos para esta voz 
                        my $cabezal_voz = ( $cabezal + $_ + $transponer ) - 1;
                        my $voz = @alturas[ $cabezal_voz % scalar @alturas ];
                        push @VOCES, $voz;
                        $nota_st  = $nota_st . $voz  . " ";
                    }
               }
               my $voces_st =  "ALTURAS: " . $nota_st;
               my $duracion  = @duraciones[ $indice % scalar @duraciones ];
               my $dinamica  = @dinamicas[ $indice % scalar @dinamicas ];
               # Redundante, ya que dinamica 0 = silencio...
               if ( $_ eq 0 ){
                   $altura = 0;
                   $dinamica = 0;
                   splice( @VOCES );
                   $voces_st = "SILENCIO";
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
	       if( $verbose ){ 
               print "    " .
                    "INDICE: " . $indice . " " .
                    "\tCABEZAL: " . ( $cabezal + 1) . " " .
                    "\tDINAMICA: " . int( $dinamica * 127 ) .
                    "\t" . $voces_st .
                    "\tDURACION: " . $duracion . "qn" .
                    "\n"; 
              }
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
    # print Dumper @{ $ESTRUCTURAS{ A }{ MOTIVOS }{ a }{ voces }{factura } };
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
    for( ( @macroforma ) x $repetir ){
          my %E =  %{ $ESTRUCTURAS{ $_ } };

          my @forma = @{ $E{ forma } };
          my $repetir_estructura = $E{ repetir } // 1;
          @forma = reverse @forma if $E{ revertir };
          for( ( @forma ) x $repetir_estructura ){
             my %M =  %{ $E{ MOTIVOS }{ $_ } };
             my %C =  %{ $M{ COMPONENTES } };
             my $orden = $M{ ordenador } // 'indice';
             my $retraso =  int( $tic * ( $M{ duraciones }{ retraso } // 0 ) );
             my $recorte =  int( $tic * ( $M{ duraciones }{ recorte } // 0 ) );
             my $fluctuacion = $M{ dinamicas }{ fluctuacion };

             my $revertir = $M{ revertir};
             for my $componenteID ( 
                 $revertir ? 
                     reverse sort { $C{ $a }{ $orden } <=> $C{ $b }{ $orden } } keys %C:
                     sort { $C{ $a }{ $orden } <=> $C{ $b }{ $orden } } keys %C
             ){
                 my $final = $tic * $C{ $componenteID }{ duracion };
                 my @V = @{ $C{ $componenteID }{ voces } }; # esto va ser un AoA
                 # Sin Voces = SILENCIO
                 if ( !@V ){
                     $momento = $momento + $final;
                     next;
                 }
                 $momento = $momento + $retraso; 
                 $final = $final - $recorte - $retraso;
                 my $rand = 0;
                 if( $fluctuacion ){
                     my $min  = -$fluctuacion;
                     my $max  = $fluctuacion;
                     $rand = $min + rand( $max - $min );
                 }
                 my $dinamica = int(
                     127 * ( $C{ $componenteID }{ dinamica } + $rand ) 
                 );
                 # Polifonia 
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
    my $HASH = shift;
    for my $item( keys %{ $HASH } ){
        if(
           ( ref( $HASH->{ $item } ) eq 'HASH' ) &&
           ( exists $HASH->{ $item }{ set } )
        ){
            my $grano = $HASH->{ $item }{ grano } // 1;
            my $operador = $HASH->{ $item }{ operador } // '*';
            my @array_evaluado = map {
               eval $_
            } @{ $HASH->{ $item }{ set } };
            my @array_procesado = map { 
               eval( $_ . $operador . $grano ) 
            } @array_evaluado;
            my $reverse = $HASH->{ $item }{ revertir } // 0;
            @array_procesado = reverse @array_procesado if $reverse;
            $HASH->{ $item }{ factura } = \@array_procesado;
        }
        # "Perl's range" suport
        if( ref( $HASH->{ $item } ) eq 'ARRAY'){ 
            my @array_evaluado = map {
               eval $_
            } @{ $HASH->{ $item } };
            $HASH->{ $item } = \@array_evaluado;
        }
    }
    return %{ $HASH };
}

# Pasar propiedades ausentes de %Ha a %Hb 
sub heredar{
    my( $padre, $hijo ) = @_;
    my $c = 1;
    for my $propiedad(
        keys %{ $padre }
    ){
        if( !$hijo->{ $propiedad } ){
             $hijo->{ $propiedad } = $padre->{ $propiedad };
        }elsif(
            ( ref( $hijo->{ $propiedad } ) eq 'HASH' ) &&
            ( $propiedad ne "COMPONENTES" ) 
        ){
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
  if( defined $info ){
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
      "  secuenciador.pl       $version\n",
      "  $0\n",
      "  $site\n",
      "\n\n";
  }
}

=head1 DESCRIPTION

 Cada track MIDI es representado por una ficha  con las configuraciones
necesarias para obtener una progresion musical.

 La organizacion interna de estas configuraciones de track trata de 
 ser lo mas autodescriptiva posible y representar una hoja de analisis 
 musical jerarquizada en Estrcucturas que continenen Motivos.

 Los Motivos heredan propiedades de configuraciones generales
 (defacto) asi como tambien de otros motivos "primos".

 Los elementos principales de los motivos (Alturtas, Voces, Duraciones y Dinamicas)
 tienen ciertas propiedades que son tratadas iguales en todos: set, operador, grano y
 revertir). Soportan rangos y operaciones matematicas (necesita explicacion)

 Ciertas propiedades son particulares de cada elemento:

 Para los intervalos, 
 la referencia esta declarada con la propiedad "tonica" y
 y podemos mover todo el set con la propiedad octava.
 Las duraciones pueden ser acotadas usando las propiedades recorte y retraso   
 Las dinamicas pueden ser "humanizadas" usando la propiedad fluctuacion.

 Explicar Componentes (combinacion de las propidades principales
 (altura, duraciones, voces y dinamicas)

 Un ejemplo de configuracion de track basica puede ser algo como esto:

 ########################################
 # Cofiguraciones generales del Track
 constantes:
   nombre       : Feliz Cumpleanios,  melodia
   metro        : 9/8
   macroforma   : [ A ]
   repetir : 1
 
 ########################################
 # Cofiguraciones Generales 
 defacto:
   canal      : 1 
   programa   : 1
   ordenador  : indice
   octava     : 0  
   tonica     : 60 # C central
   intervalos:
     set         : [ 0, 2, 4, 5, 7, 9, 11,
                    12, 2+12, 4+12, 5+12, 7+12, 9+12, 11+12 ] # Diatonica Mayor 
   voces:
     set         : [ 1 ] 
     # set         : [ 5, 8, 10 ]  # armonizacion diatonica 6/4 
   duraciones:
     set         : [ 1,.5, (1.5)x2 ]
   dinamicas:
     set         : [ .8 ] 
     fluctuacion : .1
 
 ESTRUCTURAS:
   A:
     forma: [ a, b, a, b^, a^, a^^, a^^^, b^ ]
     MOTIVOS:
       a:
         microforma : [ 5, 5, 6, 5 ]
       a^:
         microforma : [ 5, 5, 12, 10 ]
       a^^:
         microforma : [ 8, 8, 7, 6 ]
       a^^^:
         microforma : [ 11, 11, 10, 8 ]
       b:
         duraciones:
           set        : [ 1.5, 3 ]
         microforma : [ 8, 7 ]
       b^:
         microforma : [ 9, 8 ]

 Esta no es la unica manera de represantar esta melodia y 
 existen otras opciones a la expuesta.

 Mas inforamcion en los ejemplos.

=head1 Utilidades

=head2 Polifonia
 Las voces son posiciones en el set de intervalos

 Explicar

=head2 herencia

  Estructuras y Motivos pueden compartir propiedades vinculandose mediante 
  el simbolo "^" final del nombre d ela estructura

=head2 repetir

 Todas las listas formales de elementos (Macroforma, Forma y Microforma) pueden
 ser repetidas N veces segun el el valor declarado.

=head2 revertir

 Todos los Sets listas de elementos formales pueden ser revertidos  
 con la propiedad "revertir" con un valor como true o 1 
 En el caso de los motivos, se revierte el orden de los componentes. 

 Para revertir la microforma en si, el orden de la lista de posiciones en el set
 de intervalos, usar la propiedad revertir_microforma;

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
 OS                    linux & darwin
 secuenciador.pl       0.00.01

=head1 BUGS


=head1 TODO

 Agregar soporte para cambio de:  metro, chanel y programa entre MOTIVOS
 Revisar ordenador 'intervalos' y  propiedad altura de los componentes
 Control de superposicion o separacion entre Estructuras, Motivos y Componentes.
 Lista defacto general para todos los tracks/configs.
 Terminar esta documnetacion.
 Test on ActivePerl
 Agregar informacion de debbugeo en errores

=head1 UPDATES

 2017-04-23   12:00 GTM+3
   Feliz Cumpleanios Complete; es capaz de genrar esta melodia
   a partir de la hoja de analisis.

=cut
