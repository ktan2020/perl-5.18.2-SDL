@rem = '--*-Perl-*--
@echo off
if "%OS%" == "Windows_NT" goto WinNT
perl -x -S "%0" %1 %2 %3 %4 %5 %6 %7 %8 %9
goto endofperl
:WinNT
perl -x -S %0 %*
if NOT "%COMSPEC%" == "%SystemRoot%\system32\cmd.exe" goto endofperl
if %errorlevel% == 9009 echo You do not have Perl in your PATH.
if errorlevel 1 goto script_failed_so_exit_with_non_zero_val 2>nul
goto endofperl
@rem ';
#!perl.exe 
#line 15
#*****************************************************************************
#
#                          Frozen-Bubble
#
# Copyright (c) 2000-2012 The Frozen-Bubble Team
#
# Originally sponsored by Mandriva <http://www.mandriva.com/>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2, as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
#
#******************************************************************************
#
# Design & Programming by Guillaume Cottenceau between Oct 2001 and Jan 2002.
# Level Editor parts by Kim Joham and David Joham between Oct 2002 and Jan 2003.
# Network game by Guillaume Cottenceau in 2004, 2006 (blah!).
#
# Check official home: http://www.frozen-bubble.org/
#
#******************************************************************************
#
# Yes it uses Perl, you non-believer :-).
#

#use diagnostics;
use strict;

use vars qw($TARGET_ANIM_SPEED $BUBBLE_SIZE $ROW_SIZE $LAUNCHER_SPEED $BUBBLE_SPEED $MALUS_BUBBLE_SPEED $TIME_APPEARS_NEW_ROOT
            %POS %POS_1P %POS_2P %MENUPOS $KEYS %actions %angle %pdata $app %apprects $event %rects %sticked_bubbles %root_bubbles
            $background $background_orig @bubbles_images $gcwashere %bubbles_anim %launched_bubble %tobe_launched %next_bubble $recorddir %recorddata $playdata
            $shooter_lowgfx $sdl_flags $mixer $mixer_enabled $music_disabled $sfx_disabled $no_echo @playlist %sound %music %pinguin %canon
            $graphics_level @update_rects $CANON_ROTATIONS_NB %malus_bubble %falling_bubble %exploding_bubble %malus_gfx %pangocontext $private $no_time_limit
            %sticking_bubble $time %imgbin $TIME_HURRY_WARN $TIME_HURRY_MAX $TIMEOUT_PINGUIN_SLEEP $FREE_FALL_CONSTANT @joysticks $joysticksinfo $nojoysticks
            $direct @PLAYERS @ALL_PLAYERS %levels $display_on_app_disabled $addicted_time $start_time $time_1pgame $time_netgame $fullscreen $rcfile %hiscorefiles
            $HISCORES $HISCORES_MPTRAIN $HISCORES_MPTRAIN_CHAINREACTION
            $total_launched_bubbles $noinstantdeath
            $lev_number $playermalus $mptrainingdiff $loaded_levelset $direct_levelset $chainreaction %chains %img_mini $frame $sock $gameserver $mynick
            $continuegamewhenplayersleave $singleplayertargetting $mylatitude $mylongitude %autokick $replayparam $autorecord $comment $saveframes $saveframesbase $saveframescounter);

use Getopt::Long;
use Data::Dumper;
use Locale::Maketext::Simple;
use POSIX();
use Math::Trig;
use IO::File;
use Time::HiRes qw(gettimeofday);
use Compress::Bzip2;

use SDL;
use SDL::Rect;
use SDL::Surface;
use SDL::Video;
use SDL::Event;
use SDL::Events;
use SDL::Color;
use SDL::Cursor;
use SDL::Mixer;
use SDL::Mixer::Samples;
use SDL::Mixer::Channels;
use SDL::Mixer::Music;
use SDL::Mixer::MixChunk;
use SDL::Mixer::MixMusic;
use SDL::Joystick;
use SDL::Mouse;
use SDL::Image;
use Games::FrozenBubble::Config;
use Games::FrozenBubble::Stuff;
use Games::FrozenBubble::Net;
use Games::FrozenBubble::NetDiscover;
use Games::FrozenBubble::Symbols;
use Games::FrozenBubble::LevelEditor;


$| = 1;

$FPATH = $Games::FrozenBubble::Config::FPATH;
$FLPATH = $Games::FrozenBubble::Config::FLPATH;


Locale::Maketext::Simple->import(Path => "$FPATH/locale", Style => 'gettext', Export => 'gettext');

$TARGET_ANIM_SPEED = 20;        # number of milliseconds that should last between two animation frames
$LAUNCHER_SPEED = 0.03;         # speed of rotation of launchers
$BUBBLE_SPEED = 10;             # speed of movement of launched bubbles
$MALUS_BUBBLE_SPEED = 30;       # speed of movement of "malus" launched bubbles
$CANON_ROTATIONS_NB = 100;      # number of rotations of images for canon

$TIMEOUT_PINGUIN_SLEEP = 200;
$FREE_FALL_CONSTANT = 0.5;
$KEYS                           = {
        p1   => { left => SDLK_LEFT, right => SDLK_RIGHT, fire => SDLK_UP, center => SDLK_DOWN },
        p2   => { left => SDLK_x,    right => SDLK_v,     fire => SDLK_c,  center => SDLK_d },
        misc => { fs   => SDLK_f, chat => SDLK_RETURN, send_malus_to_rp1 => SDLK_F1, send_malus_to_rp2 => SDLK_F2, send_malus_to_rp3 => SDLK_F3,
                  send_malus_to_rp4 => SDLK_F4, send_malus_to_all => SDLK_F10, next_playlist_elem => SDLK_TAB, save_record => SDLK_PRINT,
                  toggle_music => SDLK_F11, toggle_sound => SDLK_F12, raise_volume => SDLK_KP_PLUS, lower_volume => SDLK_KP_MINUS }
};
$sdl_flags                      = SDL_HWSURFACE | SDL_DOUBLEBUF | SDL_HWACCEL | SDL_ASYNCBLIT;
$mixer                          = 0;
$graphics_level                 = 3;
@PLAYERS                        = qw(p1 p2);
@ALL_PLAYERS                    = qw(p1 p2 rp1 rp2 rp3 rp4);
$playermalus                    = 0;
$mptrainingdiff                 = 30;
$chainreaction                  = 0;
$noinstantdeath                 = 0;
$mynick                         = (($^O eq 'MSWin32') ? getlogin() : ($ENV{USER} ? $ENV{USER} : 'unnamed'));
$HISCORES                       = [];
$HISCORES_MPTRAIN               = [];
$HISCORES_MPTRAIN_CHAINREACTION = [];

my $RECORD_PROTOCOL_LEVEL = 0;

$rcfile = "$FBHOME/rc";
my $keys_orig = $KEYS;
eval(cat_($rcfile));
$KEYS->{misc}{chat} or ($KEYS->{p1}, $KEYS->{p2}) = ($KEYS->{p2}, $KEYS->{p1});  #- for upgrades
$KEYS->{misc}{$_} ||= $keys_orig->{misc}{$_} foreach keys %{$keys_orig->{misc}}; #-
eval(cat_($hiscorefiles{levels} = "$FBHOME/highscores"));
eval(cat_($hiscorefiles{mptrain} = "$FBHOME/highscores-mptrain"));

###passing language to Locale::Maketext::Simple
my ($lang) = split(':', $ENV{LANGUAGE});
gettext_lang($lang);
our $is_rtl = $ENV{LANGUAGE} =~ /^fa/;

print "        [[ Frozen-Bubble-$Games::FrozenBubble::VERSION ]]\n\n";
print '  http://www.frozen-bubble.org/

  Copyright (c) 2000-2012 The Frozen-Bubble Team.

    Artwork: Alexis Younes
             Amaury Amblard-Ladurantie
    Soundtrack: Matthias Le Bidan
    Design & Programming: Guillaume Cottenceau
    Level Editor: Kim and David Joham
    Additional network programming: Mark Glines

  Originally sponsored by Mandriva <http://www.mandriva.com/>

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License version 2, as
  published by the Free Software Foundation.

';

#- become a friend of BooK
GetOptions("fullscreen|fs!" => \$fullscreen,
           "no-sound|ns" => sub { $mixer = 'SOUND_DISABLED' },
           "no-music|nm" => \$music_disabled,
           "no-sfx" => \$sfx_disabled,
           "playlist=s" => sub { @playlist = -d $_[1] ? glob("$_[1]/*") : cat_($_[1]) },
           "slow-machine" => sub { $graphics_level = 2 },
           "very-slow-machine" => sub { $graphics_level = 1 },
           "direct" => \$direct,
           "solo" => sub { $direct = 1; @PLAYERS = ('p1') },
           "chain-reaction" => \$chainreaction,
           "no-instant-death" => \$noinstantdeath,
           "colour-blind|cb" => \$colourblind,
           "player-malus=i" => \$playermalus,
           "mp-training-difficulty=i" => \$mptrainingdiff,
           "level|l=i" => sub { $levels{current} = $_[1]; $direct = 1; @PLAYERS = ('p1') },
           "levelset=s" => sub { $direct_levelset = $_[1]; $levels{current} = 1; $direct = 1; @PLAYERS = ('p1') },
           "no-time-limit" => \$no_time_limit,
           "master-server=s" => \$Games::FrozenBubble::Net::masterserver,
           "gameserver|gs=s" => sub { $gameserver = $_[1]; $direct = 1; @PLAYERS = qw(p1 rp1); $pdata{gametype} = 'net' },
           "no-echo" => \$no_echo,
           "my-nick=s" => \$mynick,
           "private" => \$private,
           "joysticks-info" => \$joysticksinfo,
           "no-joysticks" => \$nojoysticks,
           "record=s" => sub { if (!-d $_[1]) { die("$_[1] does not exist.\n") } else { $recorddir = $_[1] } },
           "auto-record" => \$autorecord,
           "replay=s" => \$replayparam,
           "save-frames=s" => sub { if (!-d $_[1]) { die("$_[1] does not exist.\n") } else { $saveframes = $_[1] } },
           "comment=s" => \$comment,
           "help" => sub { print "Usage: ", basename($0), " [OPTION]...
 --fullscreen           start in fullscreen mode
 --no-fullscreen        don't start in fullscreen mode
 --no-sound             don't try to start any sound stuff
 --no-music             disable music (only)
 --no-sfx               disable sound effects (only)
 --no-joysticks         don't try to detect joysticks
 --playlist <file>      use all files listed in the given file as music files and play them
 --playlist <directory> use all files inside the given directory as music files and play them
 --slow-machine         enable slow machine mode (disable a few animations)
 --very-slow-machine    enable very slow machine mode (disable all that can be disabled)
 --solo                 directly start solo (1p) game, with random levels if no -l<#n> is given
 --direct               directly start (2p) game (don't display menu)
 --gameserver <host[:port]> directly start NET/LAN game connecting to this game server (if port is omitted, default port is used)
 --level <#n>           directly start the n-th level (implies -so)
 --levelset<name>       directly start with the specified levelset name
 --no-time-limit        disable time limit for shooting (e.g. kids mode)
 --chain-reaction       enable chain-reaction (when applicable)
 --no-instant-death     avoid malus bubbles that trigger instant death (when applicable)
 --player-malus <#n>    add a malus of n to the left player (can be negative)
 --mp-training-difficulty <#n> set the average duration between receiving malus bubbles in 1 player multiplayer training (default 30 (= every 30 seconds on average), the lower the harder)
 --colour-blind         use bubbles for colourblind people
 --joysticks-info       print information about detected joystick(s) on startup
 --no-echo              when sound is enabled, disable echoing each typed character with a typewriter sound
 --my-nick <nick>       for net/lan games, use this nick instead of username (max 10 chars, ASCII alphanumeric plus dash and underscore only)
 --private              when starting a net game, don't use http://hostip.info/ to retrieve your geographical position to send it to other players
 --record <dir>         specify the recording directory (normally, records are saved in the directory '$FBHOME/records')
 --auto-record          automatically record all applicable games (normally, a record is triggered by hitting the Print Screen key during a game)
 --comment '...'        add the comment enclosed between simple quotes to records (must not contain anything else than ASCII), it will be shown on console when playing back the record later
 --replay <file|URL>    replay the specified savegame
 --save-frames <dir>    specify a directory where all (game) frames will be recorded; as the game is slowed down, can only be used with --replay; typical use case is then to build a video out of the frames (see manpage)
";
                           exit(0);
           });

$mynick = sanitize_nick($mynick);
$saveframes && !$replayparam and print STDERR "--save-frames can only be used with --replay\n";


#- ------------------------------------------------------------------------

sub i18n_number {
    my ($number) = @_;
    my $out = '';
    foreach my $char (split //, $number) {
           if ($char eq '0') { $out .= loc("0"); }
        elsif ($char eq '1') { $out .= loc("1"); }
        elsif ($char eq '2') { $out .= loc("2"); }
        elsif ($char eq '3') { $out .= loc("3"); }
        elsif ($char eq '4') { $out .= loc("4"); }
        elsif ($char eq '5') { $out .= loc("5"); }
        elsif ($char eq '6') { $out .= loc("6"); }
        elsif ($char eq '7') { $out .= loc("7"); }
        elsif ($char eq '8') { $out .= loc("8"); }
        elsif ($char eq '9') { $out .= loc("9"); }
        elsif ($char eq '.') { $out .= loc("."); }
        else { $out .= $char; }
    }
    return $out;
}

sub format_addiction {
    my ($seconds, $i18n) = @_;
    my $h = int($seconds/3600);
    my $m = int(($seconds-$h*3600)/60);
    my $s = int($seconds-$h*3600-$m*60);
    if (!$i18n) {
        return ($h ? "${h}h " : '') . ($m ? sprintf('%'.($h ? '02' : '').'dm ', $m) : '') . sprintf('%'.($m ? '02' : '').'ds', $s);
    } else {
        if ($h) {
            $m = sprintf("%02d", $m);
        }
        if ($m) {
            $s = sprintf("%02d", $s);
        }
        $h = i18n_number($h);
        $m = i18n_number($m);
        $s = i18n_number($s);
        if ($h) {
            return loc("%sh %sm %ss", $h, $m, $s);
        } elsif ($m) {
            return loc("%sm %ss", $m, $s);
        } else {
            return loc("%ss", $s);
        }
    }
}

END {
    if ($app && $addicted_time) {
        print loc("\nAddicted for %s, %d bubbles were launched.\n", format_addiction($addicted_time/1000, 0), $total_launched_bubbles);
    }
}


#- ----------- sound related stuff ----------------------------------------

sub play_sound($) {
    $mixer_enabled && $mixer && !$sfx_disabled && $sound{$_[0]} and SDL::Mixer::Channels::play_channel(-1, $sound{$_[0]}, 0);
}

our $current_theoretical_music;
my $mus;                                 #- I need to keep a reference on the music or it will be collected at the end of this function, thus I manually collect previous music

sub play_music($) {
    my ($name) = @_;
    $current_theoretical_music = $name;
    $mixer_enabled && $mixer && !$music_disabled or return;
    @playlist && SDL::Mixer::Music::playing_music and return;
    SDL::delay(10) while SDL::Mixer::Music::fading_music;   #- mikmod will deadlock if we try to fade_out while still fading in
    SDL::Mixer::Music::playing_music and SDL::Mixer::Music::fade_out_music(500);
    SDL::delay(400);
    SDL::delay(10) while SDL::Mixer::Music::playing_music;  #- mikmod will segfault if we try to load a music while old one is still fading out
    my %musics = (intro => '/snd/introzik.ogg', main1p => '/snd/frozen-mainzik-1p.ogg', main2p => '/snd/frozen-mainzik-2p.ogg');
    if (@playlist) {
        my $tryanother = sub {
            my $elem = chomp_(shift @playlist);
            $elem or return -1;
            -f $elem or return 0;
            push @playlist, $elem;
            $mus = SDL::Mixer::Music::load_MUS($elem) if -e $elem;
            if ($mus) {
                print STDERR "[Playlist] playing `$elem'\n";
                SDL::Mixer::Music::play_music($mus, 0);
                return 1;
            } else {
                print STDERR "Warning, could not create new music from '$elem' (reason: ", SDL::get_error(), ").\n";
                return 0;
            }
        };
        while ($tryanother->() == 0) {};
    } else {
        $mus = SDL::Mixer::Music::load_MUS("$FPATH$musics{$name}") if -e "$FPATH$musics{$name}";
        if ($mus) {
                SDL::Mixer::Music::play_music($mus, -1);
            $music{current} = $name;
        } else {
            print STDERR "Warning, could not create new music from '$FPATH$musics{$name}' (reason: ", SDL::get_error(), ").\n";
        }
    }
}

sub init_sound() {
	eval {
		my $audio = SDL::Mixer::open_audio( 22050, AUDIO_S16SYS, 2,1024);
		die SDL::get_error if $audio == -1;
		my $init_flags = SDL::Mixer::init(MIX_INIT_OGG);
		if (!($init_flags & MIX_INIT_OGG)) {
			die "OGG support needed to be compiled in SDL::Mixer SDL module. Disabling sound.";
		}
	};
    if ($@) {
        $@ =~ s| at \S+ line.*\n||;
        print STDERR "\nWarning: can't initialize sound (reason: $@).\n";
        return 0;
    }
    $mixer = 1;
    print "[Sound Init] ";
    my @sounds = qw(stick destroy_group newroot newroot_solo lose hurry pause menu_change menu_selected rebound launch malus noh snore cancel typewriter applause chatted);
    foreach (@sounds) {
        my $sound_path = "$FPATH/snd/$_.ogg";
        $sound{$_} = SDL::Mixer::Samples::load_WAV($sound_path);
        if (UNIVERSAL::isa($sound{$_}, 'HASH') ? $sound{$_}{-data} : ${$sound{$_}}) {
            $sound{$_}->volume(100);
        } else {
            print STDERR "Warning, could not create new sound from '$sound_path'.\n";
        }
    }
    return 1;
}


#- ----------- graphics related stuff --------------------------------------

sub add_default_rect($) {
    my ($surface) = @_;
    $rects{$surface} = SDL::Rect->new(0,0,$surface->w, $surface->h);
}

sub mini_graphics {
    my ($p) = @_;
    return @PLAYERS >= 3 && $p =~ /rp/;
}

sub translate_mini_image {
    my ($image) = @_;
    if (mini_graphics($::p_) || ($::p_ eq '' && mini_graphics($::p))) {
        $img_mini{$image} and return $img_mini{$image};
    }
    return $image;
}

sub put_image($$$) {
    my ($image, $x, $y) = @_;
    $image = translate_mini_image($image);
    $rects{$image} or die "please don't call me with no rects\n".backtrace();
    my $drect = SDL::Rect->new($x, $y, $image->w, $image->h);
    SDL::Video::blit_surface($image, $rects{$image}, $app, $drect);
    push @update_rects, $drect;
}

sub put_image_area {
    my ($image, $x, $y, $ofsx, $ofsy, $w, $h) = @_;
    $image = translate_mini_image($image);
    $rects{$image} or die "please don't call me with no rects\n".backtrace();
    $w = $image->w-$ofsx if !$w;
    $h = $image->h-$ofsy if !$h;
    my $drect = SDL::Rect->new($x+$ofsx, $y+$ofsy, $w, $h);
    my $srect = SDL::Rect->new($ofsx, $ofsy, $w, $h);
    SDL::Video::blit_surface($image, $srect, $app, $drect);
    push @update_rects, $drect;
}

sub erase_image_from($$$$) {
    my ($image, $x, $y, $img) = @_;
    $image = translate_mini_image($image);
    my $drect = SDL::Rect->new($x, $y, $image->w,  $image->h);
    SDL::Video::blit_surface( $img, $drect, $app, $drect);
    push @update_rects, $drect;
}

sub erase_image($$$) {
    my ($image, $x, $y) = @_;
    erase_image_from($image, $x, $y, $background);
}

sub put_image_to_background($$$) {
    my ($image, $x, $y) = @_;
    my $drect;
    $image = translate_mini_image($image);
    ($x == 0 && $y == 0) and print "put_image_to_background: warning, X and Y are 0\n".backtrace();
    if ($y > 0) {
        $drect = SDL::Rect->new($x, $y, $image->w, $image->h);
        $display_on_app_disabled or SDL::Video::blit_surface ($image, $rects{$image}, $app, $drect);
        SDL::Video::blit_surface($image , $rects{$image}, $background, $drect);
    } else {  #- clipping seems to not work when from one Surface to another Surface, so I need to do clipping by hand
        $drect = SDL::Rect->new( $x, 0, $image->w, $image->h + $y);
        my $irect = SDL::Rect->new( 0 , -$y , $image->w,  $image->h + $y);
        $display_on_app_disabled or SDL::Video::blit_surface($image, $irect, $app, $drect);
        SDL::Video::blit_surface($image, $irect, $background, $drect);
    }
    push @update_rects, $drect;
}

sub remove_image_from_background($$$) {
    my ($image, $x, $y) = @_;
    $image = translate_mini_image($image);
    ($x == 0 && $y == 0) and print "remove_image_from_background: warning, X and Y are 0\n";
    my $drect = SDL::Rect->new( $x, $y,  $image->w,  $image->h);
    SDL::Video::blit_surface( $background_orig, $drect, $background, $drect);
    SDL::Video::blit_surface( $background_orig, $drect, $app, $drect);
    push @update_rects, $drect;
}

sub remove_images_from_background {
    my ($player, @images) = @_;
    foreach my $image (@images) {
        ($image->{'x'} == 0 && $image->{'y'} == 0) and print "remove_images_from_background: warning, X and Y are 0\n";
        my $img = translate_mini_image($image->{img});
        my $drect = SDL::Rect->new( $image->{'x'}, $image->{'y'}, $img->w, $img->h );
        SDL::Video::blit_surface($background_orig, $drect, $background, $drect);
        SDL::Video::blit_surface($background_orig, $drect, $app, $drect);
        push @update_rects, $drect;
    }
}

sub put_allimages_to_background($) {
    my ($player) = @_;
    put_image_to_background($_->{img}, $_->{'x'}, $_->{'y'}) foreach @{$sticked_bubbles{$player}};
}

sub switch_image_on_background($$$;$) {
    my ($image, $x, $y, $save) = @_;
    my $drect = SDL::Rect->new( $x, $y,  $image->w,  $image->h);
    if ($save) {
        $save = SDL::Surface->new( SDL_SWSURFACE, $image->w, $image->h, 32, 0 , 0, 0, 0);  
        #- grrr... this piece of shit of Amask made the surfaces slightly modify along the print/erase of "Hurry" and "Pause".... took me so much time to debug and find that the problem came from a bug when Amask is set to 0xFF000000 (while it's -supposed- to be set to 0xFF000000 with 32-bit graphics!!)
        SDL::Video::blit_surface($background, $drect, $save, $rects{$image});
    }
    SDL::Video::blit_surface($image, $rects{$image} || SDL::Rect->new(0, 0, $image->w, $image->h), $background, $drect);
    SDL::Video::blit_surface($background, $drect, $app, $drect);
    push @update_rects, $drect;
    return $save;
}

sub add_image_file($) {
    my ($file) = @_;
    my $img;
    eval {
        $img = SDL::Image::load( $file);
    };
    $@ and die "FATAL: Couldn't load '$file' into a SDL::Surface.\n";
    add_default_rect($img);
    return $img;
}

sub add_image($) {
    return add_image_file("$FPATH/gfx/$_[0]");
}

sub add_images {
    return map { add_image_file($_) } glob("$FPATH/gfx/$_[0]");
}

sub add_bubble_image($) {
    my ($file) = @_;
    my $bubble = add_image($file);
    push @bubbles_images, $bubble;
    return $bubble;
}


#- ----------- generic game stuff -----------------------------------------

sub iter_players(&) {
    my ($f, @p) = @_;
    my $bt = backtrace();
    $bt =~ /\nmain::iter_players\b/ and die "iter_players: assert failed -- iter_players can't be called recursively sorry\n$bt";
    @p or @p = @PLAYERS;
    local $::p;
    foreach $::p (@p) {
        mini_graphics($::p) or goto normal_sizes;  #- can't use an if block because of local
        local $BUBBLE_SIZE = $BUBBLE_SIZE / 2;
        local $BUBBLE_SPEED = $BUBBLE_SPEED / 2;
        local $ROW_SIZE = $ROW_SIZE / 2;
        local $FREE_FALL_CONSTANT = $FREE_FALL_CONSTANT / 2;
      normal_sizes:
        &$f;
    }
}
sub iter_players_(&) {  #- so that I can do an iter_players_ from within an iter_players
    my ($f, @p) = @_;
    my $bt = backtrace();
    $bt =~ /\nmain::iter_players_\b/ and die "iter_players_: assert failed -- iter_players_ can't be called recursively sorry\n$bt";
    @p or @p = @PLAYERS;
    local $::p_;
    foreach $::p_ (@p) {
        &$f;
    }
}
sub iter_players_but_first(&) {
    my ($f) = @_;
    my (undef, @p) = @PLAYERS;
    &iter_players($f, @p);
}
sub iter_local_players(&) {
    my ($f) = @_;
    my @p = grep { !/rp/ } @PLAYERS;
    &iter_players($f, @p);
}
sub iter_distant_players(&) {
    my ($f) = @_;
    my @p = grep { /rp/ } @PLAYERS;
    &iter_players($f, @p);
}
sub iter_distant_players_(&) {
    my ($f) = @_;
    my @p = grep { /rp/ } @PLAYERS;
    &iter_players_($f, @p);
}

sub is_1p_game() { @PLAYERS == 1 }
sub is_mp_game() { any { /rp/ } @PLAYERS }
sub is_2p_game() { @PLAYERS == 2 && !is_mp_game() }

sub is_leader() {
    my $me = unpack('C', $pdata{p1}{id});
    my $is_leader = 1;
    iter_players_but_first {
        $pdata{$::p}{left} or $is_leader &&= unpack('C', $pdata{$::p}{id}) > $me;
    };
    return $is_leader;
}
sub is_local_player($) {
    my ($player) = @_;
    $player !~ /rp/;
}
sub is_distant_player($) {
    my ($player) = @_;
    $player =~ /rp/;
}

sub mp_ping_if_needed {
    my ($ticks_ref) = @_;
    if (SDL::get_ticks() - $$ticks_ref > 1000) {
        Games::FrozenBubble::Net::gsend('p');
        $$ticks_ref = SDL::get_ticks();
    }
}

sub mp_propagate {
    my ($key, $value, $ticks_ref) = @_;
    if (is_leader()) {
        dbgnet("as leader, sending $key$value");
        Games::FrozenBubble::Net::gsend("$key$value");
        return $value;
    } else {
        my $m = Games::FrozenBubble::Net::grecv_get1msg();
        mp_ping_if_needed($ticks_ref);
        if ($m->{msg} !~ /^\Q$key\E(.+)/) {
            if ($m->{msg} eq 'l') {
                print "Server said that one of the players left - probably because of too high lag.\n";
            } else {
                print "Network protocol error: waiting for $key, received $m->{msg} - from $pdata{id2p}{$m->{id}}.\n";
            }
            die 'quit';
        } else {
            dbgnet("duly received awaited message $m->{msg} - from $pdata{id2p}{$m->{id}}");
            return $1;
        }
    }
}

sub living_players() {
    my @living;
    iter_players_ {
        if (!$pdata{$::p_}{left} && $pdata{$::p_}{state} eq 'ingame') {
            push @living, $::p_;
        }
    };
    return @living;
}

sub notleft_players() {
    my $amount = 0;
    iter_players_ {
        $pdata{$::p_}{left} or $amount++;
    };
    return $amount;
}

#- ----------- bubble game stuff ------------------------------------------

sub calc_real_pos_given_arraypos($$$) {
    my ($cx, $cy, $player) = @_;
    ($POS{$player}{left_limit} + $cx * $BUBBLE_SIZE + odd($cy+$pdata{$player}{oddswap}) * $BUBBLE_SIZE/2,
     $POS{$player}{top_limit} + $cy * $ROW_SIZE);
}

sub calc_real_pos($$) {
    my ($b, $player) = @_;
    ($b->{'x'}, $b->{'y'}) = calc_real_pos_given_arraypos($b->{cx}, $b->{cy}, $player);
}

sub get_array_yclosest($$) {
    my ($y, $player) = @_;
    return int(($y-$POS{$player}{top_limit}+$ROW_SIZE/2) / $ROW_SIZE);
}

sub get_array_closest_pos($$$) { # roughly the opposite than previous function
    my ($x, $y, $player) = @_;
    my $ny = get_array_yclosest($y, $player);
    my $nx = int(($x-$POS{$player}{left_limit}+$BUBBLE_SIZE/2 - odd($ny+$pdata{$player}{oddswap})*$BUBBLE_SIZE/2)/$BUBBLE_SIZE);
    return ($nx, $ny);
}

sub is_collision($$$) {
    my ($bub, $x, $y) = @_;
    my $DISTANCE_COLLISION_SQRED = sqr($BUBBLE_SIZE * 0.82);
    my $xs = sqr($bub->{x} - $x);
    ($xs > $DISTANCE_COLLISION_SQRED) and return 0;
    return ($xs + sqr($bub->{'y'} - $y)) < $DISTANCE_COLLISION_SQRED;
}

sub create_bubble_given_img($) {
    my ($img) = @_;
    my %bubble;
    ref($img) eq 'SDL::Surface' or die "<$img> seems to not be a valid image\n" . backtrace();
    $bubble{img} = $img;
    $bubble{neighbours} = [];
    return \%bubble;
}

sub create_bubble_given_img_num($) {
    my ($num) = @_;
    return create_bubble_given_img($bubbles_images[$num]);
}

sub validate_nextcolor($$) {
    my ($num, $player) = @_;
    return !is_1p_game() || member($num, map { get_bubble_num($_) } @{$sticked_bubbles{$player}});
}

sub each_index(&@) {
    my $f = shift;
    local $::i = 0;
    foreach (@_) {
        $f->();
        $::i++;
    }
}
sub get_bubble_num {
    my ($b) = @_;
    my $num = -1;
    each_index { $_ eq $b->{img} and $num = $::i } @bubbles_images;
    return $num;
}

sub iter_rowscols(&$) {
    my ($f, $oddswap) = @_;
    local $::row; local $::col;
    foreach $::row (0 .. 11) {
        foreach $::col (0 .. 7 - odd($::row+$oddswap)) {
            &$f;
        }
    }
}

sub each_index(&@) {
    my $f = shift;
    local $::i = 0;
    foreach (@_) {
        &$f($::i);
        $::i++;
    }
}
sub img2numb { my ($i, $f) = @_; each_index { $i eq $_ and $f = $::i } @bubbles_images; return defined($f) ? $f : '-' }

sub bubble_next_to($$$$$) {
    my ($x1, $y1, $x2, $y2, $player) = @_;
    if ($x1 == $x2 && $y1 == $y2) {
        print STDERR "bubble_next_to: assert failed -- same bubbles ($x1:$y1;$player)\n";
        $pdata{inconsistency} = 1;
        die 'quit';
    }
    return to_bool((sqr($x1+odd($y1+$pdata{$player}{oddswap})*0.5 - ($x2+odd($y2+$pdata{$player}{oddswap})*0.5)) + sqr($y1 - $y2)) < 3);
}

sub next_positions($$) {
    my ($b, $player) = @_;
    my $validate_pos = sub {
        my ($x, $y) = @_;
        if_($x >= 0 && $x+odd($y+$pdata{$player}{oddswap}) <= 7 && $y >= 0 && $y >= $pdata{$player}{newrootlevel} && $y <= 11,
            [ $x, $y ]);
    };
    ($validate_pos->($b->{cx} - 1, $b->{cy}),
     $validate_pos->($b->{cx} + 1, $b->{cy}),
     $validate_pos->($b->{cx} - even($b->{cy}+$pdata{$player}{oddswap}), $b->{cy} - 1),
     $validate_pos->($b->{cx} - even($b->{cy}+$pdata{$player}{oddswap}), $b->{cy} + 1),
     $validate_pos->($b->{cx} - even($b->{cy}+$pdata{$player}{oddswap}) + 1, $b->{cy} - 1),
     $validate_pos->($b->{cx} - even($b->{cy}+$pdata{$player}{oddswap}) + 1, $b->{cy} + 1));
}

#- bubble ends its life sticked somewhere
sub real_stick_bubble {
    my ($bubble, $xpos, $ypos, $player, $neighbours_ok) = @_;
    $bubble->{cx} = $xpos;
    $bubble->{cy} = $ypos;
    foreach (@{$sticked_bubbles{$player}}) {
        if (bubble_next_to($_->{cx}, $_->{cy}, $bubble->{cx}, $bubble->{cy}, $player)) {
            push @{$_->{neighbours}}, $bubble;
            $neighbours_ok or push @{$bubble->{neighbours}}, $_;
        }
    }
    push @{$sticked_bubbles{$player}}, $bubble;
    $bubble->{cy} == $pdata{$player}{newrootlevel} and push @{$root_bubbles{$player}}, $bubble;
    calc_real_pos($bubble, $player);
    put_image_to_background($bubble->{img}, $bubble->{'x'}, $bubble->{'y'});
}

sub destroy_bubbles {
    my ($player, @bubz) = @_;
    $graphics_level == 1 and return;
    foreach (@bubz) {
        $_->{speedx} = (rand(3)-1.5) / ( mini_graphics($player) ? 2 : 1 );
        $_->{speedy} = (-rand(4)-2) / ( mini_graphics($player) ? 2 : 1 );
    }
    push @{$exploding_bubble{$player}}, @bubz;
}

sub find_bubble_group($) {
    my ($b) = @_;
    my @neighbours = $b;
    my @group;
    while (1) {
        push @group, @neighbours;
        @neighbours = grep { $b->{img} eq $_->{img} && !member($_, @group) } fastuniq(map { @{$_->{neighbours}} } @neighbours);
        last if !@neighbours;
    }
    @group;
}

sub stick_bubble($$$$$) {
    my ($bubble, $xpos, $ypos, $player, $count_for_root) = @_;
    my @falling;
    my $need_redraw = 0;
    @{$bubble->{neighbours}} = grep { bubble_next_to($_->{cx}, $_->{cy}, $xpos, $ypos, $player) } @{$sticked_bubbles{$player}};

    #- in multiple chain reactions, it's possible that the group doesn't exist anymore in some rare situations :/
    exists $bubble->{chaindestx} && !@{$bubble->{neighbours}} and return;

    my @will_destroy = difference2([ find_bubble_group($bubble) ], [ $bubble ]);

    if (@will_destroy <= 1) {
        #- stick
        play_sound('stick');
        real_stick_bubble($bubble, $xpos, $ypos, $player, 1);
        $sticking_bubble{$player} = $bubble;
        $pdata{$player}{sticking_step} = 0;
    } else {
        #- destroy the group
        play_sound('destroy_group');
        foreach my $b (difference2([ fastuniq(map { @{$_->{neighbours}} } @will_destroy) ], \@will_destroy)) {
            @{$b->{neighbours}} = difference2($b->{neighbours}, \@will_destroy);
        }
        @{$sticked_bubbles{$player}} = difference2($sticked_bubbles{$player}, \@will_destroy);
        @{$root_bubbles{$player}} = difference2($root_bubbles{$player}, \@will_destroy);

        $bubble->{'cx'} = $xpos;
        $bubble->{'cy'} = $ypos;
        calc_real_pos($bubble, $player);
        destroy_bubbles($player, @will_destroy, $bubble);

        #- find falling bubbles
        $_->{distance_to_root} = 0 foreach @{$sticked_bubbles{$player}};
        my @still_sticked;
        my @neighbours = @{$root_bubbles{$player}};
        my $distance_to_root;
        while (1) {
            $_->{distance_to_root} = ++$distance_to_root foreach @neighbours;
            push @still_sticked, @neighbours;
            @neighbours = grep { $_->{distance_to_root} == 0 } map { @{$_->{neighbours}} } @neighbours;
            last if !@neighbours;
        }
        @falling = difference2($sticked_bubbles{$player}, \@still_sticked);
        @{$sticked_bubbles{$player}} = difference2($sticked_bubbles{$player}, \@falling);

        #- chain-reaction on falling bubbles
        if ($chainreaction) {
            my @falling_colors = map { $_->{img} } @falling;
            #- optimize a bit by first calculating bubbles that are next to another bubble of the same color
            my @grouped_bubbles = grep {
                my $b = $_;
                member($b->{img}, @falling_colors) && any { $b->{img} eq $_->{img} } @{$b->{neighbours}}
            } @{$sticked_bubbles{$player}};
            if (@grouped_bubbles) {
                #- all positions on which we can't chain-react
                my @occupied_positions = map { $_->{cy}*8 + $_->{cx} } @{$sticked_bubbles{$player}};
                push @occupied_positions, map { $_->{chaindestcy}*8 + $_->{chaindestcx} } @{$chains{$player}{falling_chained}};
                #- examine groups beginning at the root bubbles, for the case in which
                #- there is a group that will fall from an upper chain-reaction
                foreach my $pos (sort { $a->{distance_to_root} <=> $b->{distance_to_root} } @grouped_bubbles) {
                    #- now examine if there is a free position to chain-react in it
                    foreach my $npos (next_positions($pos, $player)) {
                        #- we can't chain-react somewhere if it explodes a group already chained
                        next if any { $pos->{cx} == $_->{cx} && $pos->{cy} == $_->{cy} }
                                map { @{$chains{$player}{chained_bubbles}{$_}}} keys %{$chains{$player}{chained_bubbles}};
                        if (!member($npos->[1]*8 + $npos->[0], @occupied_positions)) {
                            #- find a suitable falling bubble for that free position
                            foreach my $falling (@falling) {
                                next if member($falling, @{$chains{$player}{falling_chained}});
                                if ($pos->{img} eq $falling->{img}) {
                                    ($falling->{chaindestcx}, $falling->{chaindestcy}) = ($npos->[0], $npos->[1]);
                                    ($falling->{chaindestx}, $falling->{chaindesty}) = calc_real_pos_given_arraypos($npos->[0], $npos->[1], $player);
                                    push @{$chains{$player}{falling_chained}}, $falling;
                                    push @occupied_positions, $npos->[1]*8 + $npos->[0];

                                    #- next lines will allow not to chain-react on the same group from two different positions,
                                    #- and even to not chain-react on a group that will itself fall from a chain-reaction
                                    @{$falling->{neighbours}} = grep { bubble_next_to($_->{cx}, $_->{cy}, $npos->[0], $npos->[1], $player) } @{$sticked_bubbles{$player}};
                                    my @chained_bubbles = find_bubble_group($falling);
                                    $_->{mark} = 0 foreach @{$sticked_bubbles{$player}};
                                    my @still_sticked;
                                    my @neighbours = difference2($root_bubbles{$player}, \@chained_bubbles);
                                    while (1) {
                                        $_->{mark} = 1 foreach @neighbours;
                                        push @still_sticked, @neighbours;
                                        @neighbours = difference2([ grep { $_->{mark} == 0 } map { @{$_->{neighbours}} } @neighbours ],
                                                                  \@chained_bubbles);
                                        last if !@neighbours;
                                    }
                                    @{$chains{$player}{chained_bubbles}{$falling}} = difference2($sticked_bubbles{$player}, \@still_sticked);
                                    last;
                                }
                            }
                        }
                    }
                }
                #- now examine all chaining bubbles. for each one, check that consequences of all other chaining bubbles
                #- do not cancel it. start by the lowest falling as they are likely to be the first to reach destination.
                foreach my $falling (sort { $b->{cy} <=> $a->{cy} } @falling) {
                    next if !exists $falling->{chaindestx};
                    #- is this chain still possible, given all the other chains?
                    #- first calculate all other chained
                    my @other_chained_bubbles;
                    foreach my $falling2 (@falling) {
                        next if $falling eq $falling2 || !exists $falling2->{chaindestx};
                        push @other_chained_bubbles, find_bubble_group($falling2);
                    }
                    #- second calculate the still sticked bubbles given all other chained bubbles removed,
                    #- and check if this chain is still possible
                    $_->{mark} = 0 foreach @{$sticked_bubbles{$player}};
                    my @still_sticked;
                    my @neighbours = difference2($root_bubbles{$player}, \@other_chained_bubbles);
                    while (1) {
                        $_->{mark} = 1 foreach @neighbours;
                        push @still_sticked, @neighbours;
                        @neighbours = difference2([ grep { $_->{mark} == 0 } map { @{$_->{neighbours}} } @neighbours ],
                                                  \@other_chained_bubbles);
                        last if !@neighbours;
                    }
                    my @chained_bubbles = grep { member($_, @still_sticked) } find_bubble_group($falling);
                    if (@chained_bubbles < 2) {
                        #- ok then, suppress this one
                        delete $falling->{chaindestx};
                    }
                }
            }
        }

        #- prepare falling bubbles
        if ($graphics_level > 1 || $chainreaction) {
            my $max_cy_falling = fold_left { $::b->{cy} > $::a ? $::b->{cy} : $::a } 0, @falling;  #- I have a fold_left in my prog! :-)
            my ($shift_on_same_line, $line) = (0, $max_cy_falling);
            foreach (sort { $b->{cy}*8 + $b->{cx} <=> $a->{cy}*8 + $a->{cx} } @falling) {  #- sort bottom-to-up / right-to-left
                $line != $_->{cy} and $shift_on_same_line = 0;
                $line = $_->{cy};
                $_->{wait_fall} = ($max_cy_falling - $_->{cy})*5 + $shift_on_same_line;
                $shift_on_same_line++;
                $_->{speed} = 0;
            }
            push @{$falling_bubble{$player}}, @falling;
        }

        remove_images_from_background($player, @will_destroy, @falling);
        #- redraw neighbours because parts of neighbours have been erased by previous statement
        put_image_to_background($_->{img}, $_->{'x'}, $_->{'y'})
          foreach grep { !member($_, @will_destroy) && !member($_, @falling) } fastuniq(map { @{$_->{neighbours}} } @will_destroy, @falling);
        $need_redraw = 1;
    }

    if ($count_for_root) {
        $pdata{$player}{newroot}++;
        if ($pdata{$player}{newroot} == $TIME_APPEARS_NEW_ROOT-1) {
            $pdata{$player}{newroot_prelight} = 2;
            $pdata{$player}{newroot_prelight_step} = 0;
        }
        if ($pdata{$player}{newroot} == $TIME_APPEARS_NEW_ROOT) {
            $pdata{$player}{newroot_prelight} = 1;
            $pdata{$player}{newroot_prelight_step} = 0;
        }
        if ($pdata{$player}{newroot} > $TIME_APPEARS_NEW_ROOT) {
            my $_1p_mode = is_1p_game() && $levels{current} ne 'mp_train';
            $need_redraw = 1;
            $pdata{$player}{newroot_prelight} = 0;
            play_sound($_1p_mode ? 'newroot_solo' : 'newroot');
            $pdata{$player}{newroot} = 0;
            $pdata{$player}{oddswap} = !$pdata{$player}{oddswap};
            remove_images_from_background($player, @{$sticked_bubbles{$player}});
            foreach (@{$sticked_bubbles{$player}}) {
                $_->{'cy'}++;
                calc_real_pos($_, $player);
            }
            foreach (@{$falling_bubble{$player}}) {
                exists $_->{chaindestx} or next;
                $_->{chaindestcy}++;
                $_->{chaindesty} += $ROW_SIZE;
            }
            put_allimages_to_background($player);
            if ($_1p_mode) {
                $pdata{$player}{newrootlevel}++;
                print_compressor();
            } else {
                @{$root_bubbles{$player}} = ();
                real_stick_bubble(create_bubble_given_img_num($pdata{$player}{nextcolors}[$_]), $_, 0, $player, 0) foreach (0..(7-$pdata{$player}{oddswap}));
                delete $pdata{$player}{nextcolors};
            }
        }
    }

    if ($need_redraw) {
        my $malus_val = @will_destroy + @falling - 2;
        $malus_val > 0 && !is_mp_game() and $malus_val += ($player eq 'p1' ? $playermalus : -$playermalus);
        $malus_val < 0 and $malus_val = 0;
        SDL::Video::blit_surface($background, $apprects{$player}, $app, $apprects{$player});
        malus_change($malus_val, $player);
    }
}

sub redraw_chat_message_if_needed {
    my ($player) = @_;
    if ($pdata{current_chat_messages}{$player}) {
        my $img = @PLAYERS == 2 ? $imgbin{void_chat_small_p2} : member($player, qw(rp1 rp3)) ? $imgbin{void_chat_small_rp1_rp3} : $imgbin{void_chat_small_rp2_rp4};
        put_image_to_background($img, $POS{$player}{chatting}{x}, $POS{$player}{chatting}{'y'});
        print_('ingame_small_chat', $background,
               $POS{$player}{chatting}{x} + 3, $POS{$player}{chatting}{'y'} + 3, $pdata{current_chat_messages}{$player}, $img->w - 6, 'center');
        erase_image($img, $POS{$player}{chatting}{x}, $POS{$player}{chatting}{'y'});
    }
}

sub print_next_bubble($$;$) {
    my ($img, $player, $not_on_top_next) = @_;
    if (is_mp_game() && $player eq 'p1' && $pdata{p1}{chatting}) {
        return;
    }
    put_image_to_background($img, $next_bubble{$player}{'x'}, $next_bubble{$player}{'y'});
    $not_on_top_next or put_image_to_background($bubbles_anim{on_top_next},
                                                $POS{$player}{left_limit} + $POS{$player}{next_bubble}{x} + $POS{$player}{on_top_next_relpos}{x},
                                                $POS{$player}{next_bubble}{'y'} + $POS{$player}{on_top_next_relpos}{'y'});
    redraw_chat_message_if_needed($player);
}

sub generate_new_bubble($$) {
    my ($player, $num) = @_;
    $tobe_launched{$player} = $next_bubble{$player};
    $tobe_launched{$player}{'x'} = ($POS{$player}{left_limit}+$POS{$player}{right_limit})/2 - $BUBBLE_SIZE/2;
    $tobe_launched{$player}{'y'} = $POS{$player}{'initial_bubble_y'};
    $next_bubble{$player} = create_bubble_given_img_num($num);
    $next_bubble{$player}{'x'} = $POS{$player}{left_limit}+$POS{$player}{next_bubble}{x}; #- necessary to keep coordinates, for verify_if_end
    $next_bubble{$player}{'y'} = $POS{$player}{next_bubble}{'y'};
    print_next_bubble($next_bubble{$player}{img}, $player);
}


#- ----------- game stuff -------------------------------------------------

our $smg_lineheight = 16;

sub mp_train_time_left {
    my $seconds = 120.99 - (($recorddata{frame} * $TARGET_ANIM_SPEED) / 1000);
    $seconds < 0 and $seconds = 0;
    return $seconds;
}

our ($mp_train_xpos, $mp_train_ypos) = (32, 177);
sub mp_train_print_time {
    my $drect = SDL::Rect->new($mp_train_xpos, $mp_train_ypos, $imgbin{void_mp_training}->w, 30);
    my $seconds = mp_train_time_left();
    my $m = int($seconds/60);
    my $s = int($seconds-$m*60); length($s) == 1 and $s = "0$s";
    print_('ingame', $background, $mp_train_xpos, $mp_train_ypos, loc("%s'%s\"", i18n_number($m), i18n_number($s)), $imgbin{void_mp_training}->w, 'center');
}

sub handle_progress($) {
    my ($p) = @_;
    if (defined($pdata{$p}{newrootlast})) {
        if ($pdata{$p}{newroot} != $pdata{$p}{newrootlast}) {
            my $height = $imgbin{progress_red}->h + 1;
            my $xpos = $POS{$p}{progress}{x};
            my $ypos = $POS{$p}{progress}{y};
            put_image_to_background($imgbin{progress_green}, $xpos, $ypos + $pdata{$p}{newrootlast}*$height);
            put_image_to_background($imgbin{progress_red}, $xpos, $ypos + $pdata{$p}{newroot}*$height);
            $pdata{$p}{newrootlast} = $pdata{$p}{newroot};
        }

    } else {
        my $height = $imgbin{progress_red}->h + 1;
        my $xpos = $POS{$p}{progress}{x};
        my $ypos = $POS{$p}{progress}{y};
        $pdata{$p}{newrootlast} = 0;
        push @update_rects, SDL::Rect->new($xpos, $ypos, $imgbin{progress_red}->w, $height*(1 + $TIME_APPEARS_NEW_ROOT));
        for (my $i = 0; $i <= $TIME_APPEARS_NEW_ROOT; $i++) {
            put_image_to_background($imgbin{$i ? "progress_green" : "progress_red"}, $xpos, $ypos + $i*$height);
        }
    }
}

sub handle_graphics($) {
    my ($fun) = @_;

    iter_players {
        $pdata{$::p}{state} eq 'left' and next;  #- remote players already left in a previous subgame in mp game
        #- bubbles
        foreach ($launched_bubble{$::p}, if_($fun ne \&erase_image, $tobe_launched{$::p})) {
            $_ and $fun->($_->{img}, $_->{'x'}, $_->{'y'});
        }
        if ($fun eq \&put_image && $pdata{$::p}{newroot_prelight}) {
            if ($pdata{$::p}{newroot_prelight_step}++ > 30*$pdata{$::p}{newroot_prelight}) {
                $pdata{$::p}{newroot_prelight_step} = 0;
            }
            if ($pdata{$::p}{newroot_prelight_step} <= 8) {
                my $hurry_overwritten = 0;
                foreach my $b (@{$sticked_bubbles{$::p}}) {
                    next if ($graphics_level == 1 && $b->{'cy'} > 0);  #- in low graphics, only prelight first row
                    $b->{'cx'}+1 == $pdata{$::p}{newroot_prelight_step} and put_image($b->{img}, $b->{'x'}, $b->{'y'});
                    $b->{'cx'} == $pdata{$::p}{newroot_prelight_step} and put_image($bubbles_anim{white}, $b->{'x'}, $b->{'y'});
                    $b->{'cy'} > 6 and $hurry_overwritten = 1;
                }
                $hurry_overwritten && $pdata{$::p}{hurry_save_img} and print_hurry($::p, 1);  #- hurry was potentially overwritten
            }
        }
        if ($sticking_bubble{$::p} && $graphics_level > 1) {
            my $b = $sticking_bubble{$::p};
            if ($fun eq \&erase_image) {
                put_image($b->{img}, $b->{'x'}, $b->{'y'});
            } else {
                if ($pdata{$::p}{sticking_step} == @{$bubbles_anim{stick}}) {
                    $sticking_bubble{$::p} = undef;
                } else {
                    put_image(${$bubbles_anim{stick}}[$pdata{$::p}{sticking_step}], $b->{'x'}, $b->{'y'});
                    if ($pdata{$::p}{sticking_step_slowdown}) {
                        $pdata{$::p}{sticking_step}++;
                        $pdata{$::p}{sticking_step_slowdown} = 0;
                    } else {
                        $pdata{$::p}{sticking_step_slowdown}++;
                    }
                }
            }
        }

        #- shooter
        if ($graphics_level > 1) {
            my $num = int($angle{$::p}*$CANON_ROTATIONS_NB/($PI/2) + 0.5)-$CANON_ROTATIONS_NB;
            $fun->($canon{mini_graphics($::p) ? 'img_mini' : 'img'}{$num},
                   $POS{$::p}{canon}{x} + $canon{mini_graphics($::p) ? 'data_mini' : 'data'}{$num}->[0],
                   $POS{$::p}{canon}{'y'} + $canon{mini_graphics($::p) ? 'data_mini' : 'data'}{$num}->[1]);
        } else {
            $fun->($shooter_lowgfx,
                   $POS{$::p}{simpleshooter}{x} + $POS{$::p}{simpleshooter}{diameter}*cos($angle{$::p}),
                   $POS{$::p}{simpleshooter}{'y'} - $POS{$::p}{simpleshooter}{diameter}*sin($angle{$::p}));
        }

        #- penguins
        if (!is_mp_game() || $::p ne 'p1' || !$pdata{p1}{chatting}) {
            if ($graphics_level == 3) {
                my $player = @PLAYERS == 2 && $::p eq 'rp1' ? 'p2' : $::p;
                $fun->($pinguin{$player}{$pdata{$::p}{ping_right}{state}}[$pdata{$::p}{ping_right}{img}],
                       $POS{$player}{left_limit}+$POS{$player}{pinguin}{x}, $POS{$player}{pinguin}{'y'});
            }
        }

        handle_progress($::p);

        #- chat message in mp
        if (is_mp_game() && $pdata{$::p}{chat_msg_delay}) {
            $pdata{$::p}{chat_msg_delay}--;
            if (!$pdata{$::p}{chat_msg_delay}) {
                my $img = @PLAYERS == 2 ? $imgbin{void_chat_small_p2} : member($::p, qw(rp1 rp3)) ? $imgbin{void_chat_small_rp1_rp3} : $imgbin{void_chat_small_rp2_rp4};
                remove_image_from_background($img, $POS{$::p}{chatting}{x}, $POS{$::p}{chatting}{'y'});
                $pdata{current_chat_messages}{$::p} = undef;
                print_next_bubble($next_bubble{$::p}{img}, $::p);
                if (member($::p, 'rp3', 'rp4')) {
                    print_scores($background);
                    print_scores($app);
                }
            }
        }

        #- moving bubbles --> I want them on top of the rest
        foreach (@{$malus_bubble{$::p}}, @{$falling_bubble{$::p}}, @{$exploding_bubble{$::p}}) {
            $fun->($_->{img}, $_->{'x'}, $_->{'y'});
        }

    };

    if ($levels{current} eq 'mp_train' && $pdata{state} eq 'game') {
        if ($fun ne \&erase_image) {
            my $drect = SDL::Rect->new($mp_train_xpos, $mp_train_ypos, $imgbin{void_mp_training}->w, 30);
            SDL::Video::blit_surface($background_orig, $drect, $background, $drect);
            mp_train_print_time();
            SDL::Video::blit_surface($background, $drect, $app, $drect);
            push @update_rects, $drect;
            my $seconds = mp_train_time_left();
            if ($seconds == 0) {
                put_image($imgbin{void_panel}, $MENUPOS{xpos_panel}, $MENUPOS{ypos_panel});
                my $y = $MENUPOS{ypos_panel} + 30;
                my @messages = ('', '', '', '', loc("Your score after two minutes:"), '', $pdata{p1}{score}, '', loc("Press any key."));
                foreach (@messages) {
                    print_('menu', $app, $MENUPOS{xpos_panel}, $y, $_, $imgbin{void_panel}->w, 'center');
                    $y += $smg_lineheight;
                }
                SDL::Video::update_rect($app, 0, 0, 0, 0);
                play_sound('cancel');
                Games::FrozenBubble::CStuff::fbdelay(1000);
                SDL::Events::pump_events() while SDL::Events::poll_event($event) != 0;
                grab_key() eq SDLK_ESCAPE() and die 'quit';
                handle_new_hiscores();
                die 'new_game';
            }
        }
    }
}

#- extract it from "handle_graphics" to optimize a bit animations
sub update_malus($$) {
    my ($fun, $p) = @_;
    my $malus_nb = @{$pdata{$p}{malus}};
    my $y_shift = 0;
    while ($malus_nb > 0) {
        my $print = sub($) {
            my ($type) = @_;
            my $type_real = translate_mini_image($type);
            $fun->($type, $POS{$p}{malus}{x} - $type_real->w/2, $POS{$p}{malus}{'y'} - $y_shift - $type_real->h);
            $y_shift += $type_real->h - 1;
        };
        if ($malus_nb >= 7) {
            $print->($malus_gfx{tomate});
            $malus_nb -= 7;
        } else {
            $print->($malus_gfx{banane});
            $malus_nb--;
        }
    }
}

sub malus_change($$) {
    my ($numb, $player) = @_;
    return if $numb == 0 || is_1p_game() && $levels{current} ne 'mp_train';
    if ($levels{current} eq 'mp_train' && $numb > 0) {
        $pdata{p1}{score} += $numb;
        print_scores($app);
        print_scores($background);
        return;
    }
    if ($numb > 0) {
        #- malus are adding up
        if (!is_mp_game()) {
            iter_players_ {
                if ($::p_ ne $player) {
                    update_malus(\&remove_image_from_background, $::p_);
                    push @{$pdata{$::p_}{malus}}, ($frame) x $numb;
                    update_malus(\&put_image_to_background, $::p_);
                }
            };

        } else {
            if (is_local_player($player)) {  #- remote players handled when receiving the 'g' message
                if (!$pdata{sendmalustoone}) {
                    my @living = living_players();
                    if (@living > 1) {
                        $numb = int($numb/(@living-1) + 0.99);
                        iter_players_ {
                            if ($::p_ ne $player && member($::p_, @living)) {
                                is_mp_game() and Games::FrozenBubble::Net::gsend("g$pdata{$::p_}{nick}:$numb");
                                update_malus(\&remove_image_from_background, $::p_);
                                push @{$pdata{$::p_}{malus}}, ($frame) x $numb;
                                update_malus(\&put_image_to_background, $::p_);
                            }
                        };
                    }
                } else {
                    my $p = $pdata{sendmalustoone};
                    is_mp_game() and Games::FrozenBubble::Net::gsend("g$pdata{$p}{nick}:$numb");
                    iter_players_ {  #- get mini graphics
                        if ($::p_ eq $p) {
                            update_malus(\&remove_image_from_background, $::p_);
                            push @{$pdata{$::p_}{malus}}, ($frame) x $numb;
                            update_malus(\&put_image_to_background, $::p_);
                        }
                    };
                }
            }
        }
    } else {
        #- malus are decreasing
        update_malus(\&remove_image_from_background, $player);
        shift @{$pdata{$player}{malus}} while $numb++;
        update_malus(\&put_image_to_background, $player);
    }
}

sub print_compressor() {
    my $x = $POS{compressor_xpos};
    my $y = $POS{p1}{top_limit} + $pdata{$PLAYERS[0]}{newrootlevel} * $ROW_SIZE;
    my ($comp_main, $comp_ext) = ($imgbin{compressor_main}, $imgbin{compressor_ext});

    my $drect = SDL::Rect->new($x - $comp_main->w/2, 0, $comp_main->w, $y);
    SDL::Video::blit_surface($background_orig, $drect, $background, $drect);
    $display_on_app_disabled or SDL::Video::blit_surface($background_orig, $drect, $app, $drect);
    push @update_rects, $drect;

    put_image_to_background($comp_main, $x - $comp_main->w/2, $y - $comp_main->h);

    $y -= $comp_main->h - 3;

    while ($y > 0) {
        put_image_to_background($comp_ext, $x - $comp_ext->w/2, $y - $comp_ext->h);
        $y -= $comp_ext->h;
    }
}

sub print_ {
    my ($kind, $surface, $x, $y, $text, $size, $alignment, $callback) = @_;
        printf("print_: " . join(' ', (caller(1))) . " $text\n") if $ENV{FB_DEBUG};
    exists $pangocontext{$kind} or die "$kind is no kind\n";
    if ($size) {
        #- instead of segfaulting
        my $minsize = width($kind, $text);
        if ($minsize > $size) {
            $size = $minsize;
        }
    }
    my $surf = Games::FrozenBubble::CStuff::sdlpango_draw_givenalignment($pangocontext{$kind}{context_bg}, $text, $size || -1, $alignment || 'left');
    if ($callback) {
        if (!$callback->('about-to-draw', $surf)) {
            #- callback said do not draw
            return;
        }
    }
    SDL::Video::blit_surface($surf, SDL::Rect->new(0, 0, $surf->w, $surf->h), $surface, SDL::Rect->new($x + 1, $y + 1, $surf->w, $surf->h));
    $surf = Games::FrozenBubble::CStuff::sdlpango_draw_givenalignment($pangocontext{$kind}{context_fg}, $text, $size || -1, $alignment || 'left');
        #printf("sdlpango_draw_givenalignment: %s, %s, %s, %s\n", $kind, $text, $size || -1, $alignment || 'left');
        #printf("SDL::Rect->new($x, $y, " . $surf->w . ", " . $surf->h . ")\n");
    SDL::Video::blit_surface($surf, SDL::Rect->new(0, 0, $surf->w, $surf->h), $surface, SDL::Rect->new($x, $y, $surf->w, $surf->h));
}

sub width {
    my ($kind, $text) = @_;
    exists $pangocontext{$kind} or die "$kind is no kind\n";
    my $size = Games::FrozenBubble::CStuff::sdlpango_getsize($pangocontext{$kind}{context_fg}, $text, -1);
    return $size->[0];
}

sub mp_disconnect_with_reason {
    my (@messages) = @_;
    put_image($imgbin{void_panel}, $MENUPOS{xpos_panel}, $MENUPOS{ypos_panel});
    my $y = $MENUPOS{ypos_panel} + 30;
    foreach (@messages) {
        print_('menu', $app, $MENUPOS{xpos_panel} + 10, $y, $_, $imgbin{void_panel}->w - 20, 'center');
        $y += $smg_lineheight;
    }
    SDL::Video::update_rect($app, 0, 0, 0, 0);
    play_sound('cancel');
    Games::FrozenBubble::CStuff::fbdelay(2000);
    SDL::Events::pump_events() while SDL::Events::poll_event($event) != 0;
    grab_key();
    die 'quit';
}

sub check_mp_connection {
    if (!Games::FrozenBubble::Net::isconnected()) {
        if ($pdata{gametype} eq 'lan') {
            mp_disconnect_with_reason('', '', '', '', loc("Lost connection to server!"), '', loc("Hoster aborted the game."));
        } else {
            mp_disconnect_with_reason('', '', '', '', loc("Lost connection to server!"), '', loc("Your lag is probably too high."));
        }
    }
}

sub update_say_mp {
    put_image($imgbin{void_chat}, $POS{p1}{chatting}{x}, $POS{p1}{chatting}{'y'});
    callback_entry('print', { xpos => $POS{p1}{chatting}{x} + 15, ypos => $POS{p1}{chatting}{'y'} + 5, font => 'ingame_chat', maxlen => $imgbin{void_chat}->w - 30 });
    push @update_rects, $apprects{main};
}

sub cleanup_chatting {
    $pdata{p1}{chatting} = 0;
    SDL::Events::enable_key_repeat(0, 0);
    remove_image_from_background($imgbin{void_chat}, $POS{p1}{chatting}{x}, $POS{p1}{chatting}{'y'});
    print_next_bubble($next_bubble{p1}{img}, 'p1');
    redraw_attackingme();
}

sub set_sendmalustoone {
    my ($whoto) = @_;
    $pdata{sendmalustoone} = undef;
    iter_distant_players_ {
        remove_image_from_background($imgbin{attack}{$::p_}, $POS{$::p_}{attack}{x}, $POS{$::p_}{attack}{'y'});
    };
    if (member($whoto, living_players()) && $pdata{p1}{state} ne 'lost') {
        $pdata{sendmalustoone} = $whoto;
        put_image_to_background($imgbin{attack}{$pdata{sendmalustoone}}, $POS{$pdata{sendmalustoone}}{attack}{x}, $POS{$pdata{sendmalustoone}}{attack}{'y'});
    }
    if ($pdata{protocollevel} >= 1) {
        Games::FrozenBubble::Net::gsend("A$pdata{$pdata{sendmalustoone}}{nick}");
    }
}

sub redraw_attackingme {
    $pdata{p1}{chatting} and return;
    my $xpos = $POS{p1}{attackme}{x};
    my $drect = SDL::Rect->new($xpos, $POS{p1}{attackme}{'y'}, 3*24 + $imgbin{attackme}{rp1}->w, $imgbin{attackme}{rp1}->h);
        SDL::Video::blit_surface($background_orig, $drect, $background, $drect);
        SDL::Video::blit_surface($background_orig, $drect, $app, $drect);
    push @update_rects, $drect;
    foreach my $attackingme (@{$pdata{attackingme}}) {
        put_image_to_background($imgbin{attackme}{$attackingme}, $xpos, $POS{p1}{attackme}{'y'});
        $xpos += 24;
    }
}

sub handle_mp_messages {
    my ($msg) = @_;

    #- in order to keep ordering of actions executed in update_game, we must tolerate only one action at a time
    my $check_action_possible = sub {
        my ($m, $player) = @_;
        #- we check also the presence of malus bubbles, because if the malus order has lagged much
        #- we might receive a fire or even a stick command before the malus bubbles are sticked,
        #- this would provoke a local inconsistency; same for chain reacted bubbles not finished yet
        if ($actions{$player}{mp_fire}
            || $actions{$player}{mp_stick}
            || @{$malus_bubble{$player}}
            || $chainreaction && any { exists $_->{chaindestx} } @{$falling_bubble{$player}}) {
            unshift @$msg, $m;
            return 0;
        } else {
            return 1;
        }
    };

    my %latestangle = ();  #- for smoothing, need to handle last angle only

    while (@$msg) {
        my $m = shift @$msg;
        my $player = $pdata{id2p}{$m->{id}};
        if (!$player) {
            printf "Network protocol error: player with id '%d' doesn't exist. You're not a regular Frozen-Bubble client, aren't you?\n", ord($m->{id});
            die 'quit';
        }
        if ($pdata{$player}{left}) {
            print STDERR "$pdata{$player}{nick}: you don't exist (anymore), go away!\n";
            next;
        }
        my ($command, $params) = $m->{msg} =~ /^(.)(.*)/;
        dbgnet("message received: from=$player message=$m->{msg}");
        if ($command eq 'l') {
            iter_players { #- need iter_players to get the small graphics change for free
                if ($::p eq $player) {
                    $pdata{$::p}{left} = 1;
                    $pdata{$::p}{still_game_messages} = 0;
                    lose($::p);
                }
            };
        } elsif ($command eq 'f') {
            $check_action_possible->($m, $player) or last;
            $actions{$player}{mp_fire} = 1;
            ($angle{$player}, $pdata{$player}{nextcolor}) = $params =~ /(.+):(.+)/;
        } elsif ($command eq 'r') {
            $actions{$player}{left} = 0;
            $actions{$player}{right} = 0;
            $actions{$player}{center} = 0;
            if ($params eq 'l') {
                $actions{$player}{left} = 1;
            } elsif ($params eq 'r') {
                $actions{$player}{right} = 1;
            } elsif ($params eq 'c') {
                $actions{$player}{center} = 1;
            }
        } elsif ($command eq 'a') {
            $latestangle{$player} = $params;
        } elsif ($command eq 's') {
            $check_action_possible->($m, $player) or last;
            #- we can't rely on locally animated launched bubble, to ensure game
            #- consistency we transmit stick positions
            $actions{$player}{mp_stick} = 1;
            ($pdata{$player}{stickcx}, $pdata{$player}{stickcy}, $pdata{$player}{stickcol}, my $newrootcols) = $params =~ /(.+):(.+):(.+):(.*)/;
            @{$pdata{$player}{nextcolors}} = split / /, $newrootcols;
        } elsif ($command eq 'g') {
            my ($destplayer, $numb) = $params =~ /(.+):(.+)/;
            iter_players {
                if ($pdata{$::p}{nick} eq $destplayer) {
                    update_malus(\&remove_image_from_background, $::p);
                    push @{$pdata{$::p}{malus}}, ($frame) x $numb;
                    update_malus(\&put_image_to_background, $::p);
                }
            };
        } elsif ($command eq 'm') {
            #- we may receive new malus bubbles after a distant player is dead already
            #- ignore them instead of wrongly overlaying frozen bubbles
            if ($pdata{$player}{state} eq 'ingame') {
                my ($num, $cx, $cy, $sticky) = $params =~ /(.+):(.+):(.+):(.+)/;
                my $b = create_bubble_given_img_num($num);
                $b->{cx} = $cx;
                $b->{cy} = $cy;
                $b->{'stick_y'} = $sticky;
                iter_players { #- need iter_players to get the small graphics change for free
                    if ($::p eq $player) {
                        calc_real_pos($b, $::p);
                        push @{$malus_bubble{$player}}, $b;
                        malus_change(-1, $player);
                    }
                };
            }
        } elsif ($command eq 'M') {
            my ($cx, $sticky) = $params =~ /(.+):(.+)/;
            #- if network cuts several malussticks in two parts, it's possible that
            #- one malusstick from the first part trigger a lose; at next game run,
            #- the player has lost and his malus bubbles were cleaned up, so malusstick
            #- is not possible, but this is no big deal
            if ($pdata{$player}{state} eq 'ingame') {
                foreach (@{$malus_bubble{$player}}) {
                    if ($_->{cx} == $cx && $_->{'stick_y'} == $sticky) {
                        $_->{mp_stick} = 1;
                        goto ok_malusstick;
                    }
                }
                die "could not find malus bubble to malusstick!\n";
              ok_malusstick:
            }
        } elsif ($command eq 'F') {
            #- this is coming too soon. it needs to be collected in the algo to restart a game.
            unshift @$msg, $m;
            last;
        } elsif ($command eq 't') {
            $pdata{current_chat_messages}{$player} = $params;
            $pdata{$player}{chat_msg_delay} = 500;
            play_sound('chatted');
            redraw_chat_message_if_needed($player);
            push @update_rects, $apprects{main};
        } elsif ($command eq 'A') {
            if ($params eq '') {
                @{$pdata{attackingme}} = difference2($pdata{attackingme}, [ $player ]);
            } else {
                if ($params eq $pdata{p1}{nick}) {
                    if (!member($player, @{$pdata{attackingme}})) {
                        push @{$pdata{attackingme}}, $player;
                    }
                } else {
                    @{$pdata{attackingme}} = difference2($pdata{attackingme}, [ $player ]);
                }
            }
            redraw_attackingme();
        } else {
            print STDERR "****** Unrecognized command: $m->{msg}\n";
        }
    }

    foreach my $player (keys %latestangle) {
        #- try to smoothen on network lag
        my $difference = $latestangle{$player} - $angle{$player};
        if (abs($difference) > 0.15) {
            #- we're lagging. ignore that to prevent jerks. hope this is temporary.
            #- I know this will behave bad on high lags but hey I can't do no miracle buddy.
        } else {
            #- we're not lagging so much. but smoothen it up.
            $angle{$player} += $difference / 2;
        }
    }

}

sub handle_whenever_events {
    my ($keypressed) = @_;

    if ($keypressed eq $KEYS->{misc}{fs}) {
        $fullscreen = !$fullscreen;
        SDL::Video::wm_toggle_fullscreen($app);
    }
    if ($keypressed eq $KEYS->{misc}{toggle_sound}) {
        if (!$mixer_enabled) {
            if ($mixer || init_sound()) {
                $mixer_enabled = 1;
                play_music($current_theoretical_music);
            }
        } else {
            if ($mixer_enabled && $mixer && SDL::Mixer::Music::playing_music) {
                SDL::delay(10) while SDL::Mixer::Music::fading_music;   #- mikmod will deadlock if we try to fade_out while still fading in
                SDL::Mixer::Music::playing_music and SDL::Mixer::Music::halt_music;
                SDL::delay(10) while SDL::Mixer::Music::playing_music;  #- mikmod will segfault if we try to load a music while old one is still fading out
            }
            $mixer_enabled = 0;
        }
    }
    if ($mixer_enabled && $mixer && $keypressed eq $KEYS->{misc}{toggle_music}) {
        if ($music_disabled) {
            $music_disabled = undef;
            play_music($current_theoretical_music);
        } else {
            $music_disabled = 1;
	    SDL::Mixer::Music::halt_music;
        }
    }
    if ($mixer_enabled && $mixer && @playlist && $keypressed eq $KEYS->{misc}{next_playlist_elem}) {
	    SDL::Mixer::Music::halt_music;
        play_music('dummy');
    }
    if ($mixer_enabled && $mixer && $keypressed eq $KEYS->{misc}{raise_volume}) {
        my $to = int(min(SDL::Mixer::Music::volume_music(-1) + SDL::Mixer::MIX_MAX_VOLUME()/10, SDL::Mixer::MIX_MAX_VOLUME()));
        SDL::Mixer::Music::volume_music($to);
        SDL::Mixer::Channels::volume(-1, $to);
    }
    if ($mixer_enabled && $mixer && $keypressed eq $KEYS->{misc}{lower_volume}) {
        my $to = int(max(SDL::Mixer::Music::volume_music(-1) - SDL::Mixer::MIX_MAX_VOLUME()/10, 0));
        SDL::Mixer::Music::volume_music($to);
        SDL::Mixer::Channels::volume(-1, $to);
    }
}

sub handle_game_events() {

    if ($levels{current} eq 'mp_train' && @{$malus_bubble{p1}} == 0 && @{$pdata{p1}{malus}} == 0) {
        if (int(rand($mptrainingdiff*(1000/$TARGET_ANIM_SPEED))) == 0) {
            push @{$pdata{p1}{malus}}, ($frame) x (1 + int(rand(6)));
        }
    }

    if ($playdata) {
        play();
        SDL::Events::pump_events();
        while (SDL::Events::poll_event($event) != 0) {
            if ($event->type == SDL_QUIT) {
                cleanup_and_exit();
            }
            my $keypressed = extended_keypress($event);
            handle_whenever_events($keypressed);
            if ($keypressed eq SDLK_ESCAPE) {
                die 'quit';
            }
            if ($keypressed eq SDLK_PAUSE) {
                my $time_pause = SDL::get_ticks();
                SDL::Events::pump_events() while SDL::Events::poll_event($event) != 0;
              pause_playdata:
                while (1) {
                    while (SDL::Events::poll_event($event) != 0) {
                        if ($event->type == SDL_QUIT) {
                            cleanup_and_exit();
                        }
                        my $keypressed = extended_keypress($event);
                        if ($keypressed) {
                            $start_time += SDL::get_ticks() - $time_pause;
                            return;
                        }
                    }
                }
            }
            if ($keypressed && $pdata{demo}) {
                die 'quit';
            }
        }
        return;
    }

    SDL::Events::pump_events();
    while (SDL::Events::poll_event($event) != 0) {
        my $keypressed = extended_keypress($event);
        if ($keypressed) {

            if (is_mp_game() && $pdata{p1}{chatting}) {
                if (($keypressed eq SDLK_RETURN() || $keypressed eq SDLK_KP_ENTER())) {
                    if (callback_entry('gettext') > 0) {
                        Games::FrozenBubble::Net::gsend('t' . join('', callback_entry('gettext')));
                    }
                    cleanup_chatting();
                } elsif ($event->type == SDL_KEYDOWN && !member($keypressed, SDLK_RETURN(), SDLK_KP_ENTER(), SDLK_TAB())) {
                    callback_entry('keypressed', { event => $event, maxlen => $imgbin{void_chat}->w - 30, font => 'ingame_chat' });
                    callback_entry('moved');
                    update_say_mp();
                }

            } else {
                iter_local_players {
                    foreach my $action (qw(left right fire center)) {
                        if ($keypressed eq $KEYS->{$::p}{$action}) {
                            $actions{$::p}{$action} = 1;
                            if (is_mp_game() && $action ne 'fire') {
                                $action =~ /./;  #- first letter
                                Games::FrozenBubble::Net::gsend("r$&");
                            }
                            last;
                        }
                    }
                };

                if ($keypressed eq $KEYS->{misc}{chat} && is_mp_game()) {
                    callback_entry('reset');
                    $pdata{p1}{chatting} = 1;
                    SDL::Events::enable_key_repeat(200, 50);
                    put_image_to_background($imgbin{void_chat}, $POS{p1}{chatting}{x}, $POS{p1}{chatting}{'y'});
                }

                if ($keypressed eq SDLK_PAUSE && !is_mp_game()) {
                    my $time_pause = SDL::get_ticks();
                    play_sound('pause');
                    $mixer_enabled && $mixer and SDL::Mixer::Music::pause_music;
                    my $back_saved = switch_image_on_background($imgbin{back_paused}, 0, 0, 1);
                    my $index;
                  pause_label:
                    while (1) {
                        my $ticks = SDL::get_ticks();
                        erase_image(${$imgbin{paused}}[$index], 320-${$imgbin{paused}}[$index]->w/2-5, 240-${$imgbin{paused}}[$index]->h/2-4);
                        put_image(${$imgbin{paused}}[$index], 320-${$imgbin{paused}}[$index]->w/2-5, 240-${$imgbin{paused}}[$index]->h/2-4);
                        SDL::Video::update_rects($app, @update_rects);
                        @update_rects = ();
                        SDL::delay(20);
                        SDL::Events::pump_events();
                        while (SDL::Events::poll_event($event) != 0) {
                            if ($event->type == SDL_QUIT) {
                                cleanup_and_exit();
                            }
                            my $keypressed = extended_keypress($event);
                            if ($keypressed) {
                                handle_whenever_events($keypressed);
                                if (member($keypressed, SDLK_PAUSE, SDLK_ESCAPE, SDLK_RETURN, SDLK_SPACE)) {
                                    last pause_label;
                                }
                            }
                        }
                        if (++$index == @{$imgbin{paused}}) {
                            $index = 11;
                        }
                        my $to_wait = $TARGET_ANIM_SPEED - (SDL::get_ticks() - $ticks);
                        $to_wait > 0 and Games::FrozenBubble::CStuff::fbdelay($to_wait);
                    }
                    switch_image_on_background($back_saved, 0, 0);
                    iter_local_players { $actions{$::p}{left} = 0; $actions{$::p}{right} = 0; };
                    $mixer_enabled && $mixer and SDL::Mixer::Music::resume_music;
                    SDL::Events::pump_events() while SDL::Events::poll_event($event) != 0;
                    SDL::Video::update_rect($app, 0, 0, 0, 0);
                    $start_time += SDL::get_ticks() - $time_pause;
                    is_1p_game() and $time_1pgame += SDL::get_ticks() - $time_pause;
                    return;
                }

                if (is_mp_game() && @PLAYERS >= 3 && $singleplayertargetting) {
                    foreach my $rp (qw(rp1 rp2 rp3 rp4)) {
                        if ($keypressed eq $KEYS->{misc}{"send_malus_to_$rp"}) {
                            set_sendmalustoone($rp);
                        }
                    }
                    if ($keypressed eq $KEYS->{misc}{send_malus_to_all}) {
                        set_sendmalustoone(undef);
                    }
                }

                if ($levels{current} !~ /^\d+$/ && $keypressed eq $KEYS->{misc}{save_record}) {
                    print "This game will be recorded when it's over.\n";
                    $recorddata{save} = 1;
                }

                handle_whenever_events($keypressed);
            }
        }

        $keypressed = undef;
        if ($event->type == SDL_KEYUP) {
            $keypressed = $event->key_sym;
        } elsif ($event->type == SDL_JOYAXISMOTION || $event->type() == SDL_JOYBUTTONUP) {
            $keypressed = translate_joystick_tokey($event);
            if ($event->type == SDL_JOYAXISMOTION && $keypressed !~ /^joystick\|axisvalue\|\d+\|\d+\|0$/) {  #- we treat position at 0 as KEYUP
                $keypressed = undef;
            }
            $keypressed =~ s/^joystick\|buttonup/joystick|buttondown/;
        }

        if ($keypressed) {
            iter_local_players {
                foreach my $action (qw(left right fire center)) {
                    if ($keypressed eq $KEYS->{$::p}{$action}) {
                        $actions{$::p}{$action} = 0;
                        is_mp_game() && $action ne 'fire' and Games::FrozenBubble::Net::gsend('r');
                        last;
                    } elsif ($keypressed =~ /^joystick\|axisvalue\|(\d+)\|(\d+)\|0$/ && $KEYS->{$::p}{$action} =~ /^joystick\|axisvalue\|$1\|$2\|/) {
                        $actions{$::p}{$action} = 0;
                        is_mp_game() && $action ne 'fire' and Games::FrozenBubble::Net::gsend('r');
                        #- no last, there might be two values of the same axis
                    }
                }
            }
        }

        if ($event->type == SDL_KEYDOWN && $event->key_sym == SDLK_ESCAPE) {
            if (is_mp_game()) {
                if ($pdata{p1}{chatting}) {
                    cleanup_chatting();
                    play_sound('cancel');
                } else {
                    $pdata{p1}{left} = 1;
                    lose('p1');
                    die 'quit';
                }
            } else {
                $pdata{p1}{left} = 1;
                die 'quit';
            }
        }
        if ($event->type == SDL_QUIT) {
            cleanup_and_exit();
        }
    }

    if (is_mp_game()) {
        $pdata{p1}{chatting} && callback_entry('ping') and update_say_mp();

        my @messages = Games::FrozenBubble::Net::grecv();
        check_mp_connection();
        $recorddata{mp_messages} = deep_copy(\@messages);  #- if we don't do a deep copy, the dumped data will be recursive for delayed messages

        handle_mp_messages(\@messages);

        Games::FrozenBubble::Net::gdelay_messages(@messages);
    }

    record();
}

sub record {
    $recorddata{frame}++;
    #- check for differences
    my %newdata;
    iter_players {
        foreach my $action (keys %{$actions{$::p}}) {
            $action =~ /^mp/ and next;  #- mp actions will be generated by saving the mp messages
            if ($recorddata{lastactions}{$::p}{$action} ne $actions{$::p}{$action}) {
                $newdata{actions}{$::p}{$action} = $actions{$::p}{$action};
            }
        }
    };
    #- save if at least one difference or mp messages
    if (%newdata || @{$recorddata{mp_messages} || []}) {
        @{$recorddata{mp_messages} || []} and @{$newdata{mp_messages}} = @{$recorddata{mp_messages}};
        push @{$recorddata{data}}, [ $recorddata{frame}, \%newdata ];
    }
    #- save current state
    iter_players {
        foreach my $action (keys %{$actions{$::p}}) {
            $recorddata{lastactions}{$::p}{$action} = $actions{$::p}{$action};
        }
    };
}

our $recordnumber = 0;
sub save_record_if_needed {
    if (($recorddata{save} || $autorecord) && $levels{current} !~ /^\d+$/ && @{$recorddata{data}} > 1 && !$pdata{p1}{left}) {
        if (!$recorddir) {
            $recorddir = "$FBHOME/records";
            print "Notice: no recorddir was specified on commandline; recording in '$recorddir'\n";
            mkdir $recorddir;
        }
        my $filename = sprintf("$recorddir/fb_record_%08d", $recordnumber++);
        -f $filename || -f "$filename.bz2" and return save_record_if_needed();
        my $record = shift @{$recorddata{data}};
        my $data = "record_protocol:$RECORD_PROTOCOL_LEVEL\n"
                 . "players:" . join(',', @PLAYERS) . "\n"
                 . "gametype:$pdata{gametype}\n"
                 . "current_level:$levels{current}\n"
                 . "chainreaction:$chainreaction\n"
                 . "time:" . time() . "\n"
                 . "srand:$record->{srand}\n";
        if (exists $record->{bubbles}) {
            $data .= "bubbles:" . join(',', @{$record->{bubbles}}) . "\n";
        }
        $comment and $data .= "comment:$comment\n";
        if (is_mp_game()) {
            $data .= "mp_result:$pdata{state}\n";
            iter_players {
                $data .= "player_id:$::p|$pdata{$::p}{id}\n"
                       . "player_nick:$::p|$pdata{$::p}{nick}\n";
            };
        }
        foreach my $item (@{$recorddata{data}}) {
            foreach my $playeractions (keys %{$item->[1]{actions}}) {
                foreach my $action (keys %{$item->[1]{actions}{$playeractions}}) {
                    $data .= "frame_action:$item->[0]|$playeractions|$action|$item->[1]{actions}{$playeractions}{$action}\n";
                }
            }
            if (exists $item->[1]{mp_messages}) {
                foreach my $mpmessage (@{$item->[1]{mp_messages}}) {
                    $data .= "frame_mpmessage:$item->[0]|$mpmessage->{id}|$mpmessage->{msg}\n";
                }
            }
        }
        my $bz = Compress::Bzip2::bzopen($filename . ".bz2", 'w');
        if($bz->bzwrite($data)) {
            $filename .= ".bz2";
        }
        else {
            output($filename, $data);
        }
        $bz->bzclose() if $bz;

        print "Record saved in '$filename'. Start Frozen-Bubble with '--replay $filename' to replay the game.\n";
        return 1;
    }
}

sub play {
    $recorddata{frame}++;
    my $nextdata = $playdata->[0];
    if ($nextdata) {
        if ($nextdata->[0] == $recorddata{frame}) {
            foreach my $p (keys %{$nextdata->[1]{actions}}) {
                my %pnew = %{$nextdata->[1]{actions}{$p}};
                $actions{$p}{$_} = $pnew{$_} foreach keys %pnew;
            }
            $nextdata->[1]{mp_messages} and handle_mp_messages($nextdata->[1]{mp_messages});
            shift @$playdata;
        }
    } else {
        if ($pdata{demo}) {
            die 'quit';
        }
    }
}

sub print_scores($) {
    my ($surface) = @_;
    iter_players_ {  #- sometimes called from within a iter_players so...
        my $score = @PLAYERS == 1 ? ($pdata{$::p_}{score} eq 'random' ? loc("Random level")
                                         : $levels{current} eq 'mp_train' ? loc("Score: %s", i18n_number($pdata{$::p_}{score}))
                                               : loc("Level %s", i18n_number($pdata{$::p_}{score}))) : i18n_number($pdata{$::p_}{score});
        is_mp_game() and $score = sprintf("%s: %s", $pdata{$::p_}{nick}, i18n_number($score));
        my $width = width(mini_graphics($::p_) ? 'ingame_small' : 'ingame', $score);
        my $xpos = $POS{$::p_}{scores}{x} - $width/2;
        my $drect = SDL::Rect->new($xpos, $POS{$::p_}{scores}{'y'}, $width, mini_graphics($::p_) ? 12 : 24);
        SDL::Video::blit_surface($background_orig, $drect, $surface, $drect);
        push @update_rects, $drect;
        if (mini_graphics($::p_)) {
            print_('ingame_small', $surface, $xpos, $POS{$::p_}{scores}{'y'}, $score);
        } else {
            print_('ingame', $surface, $xpos, $POS{$::p_}{scores}{'y'}, $score);
        }
        redraw_chat_message_if_needed($::p_);
    };
}

sub cleanup_player_bubbles {
    my ($player) = @_;
    @{$malus_bubble{$player}} = ();
    #- reverse sort for freezing effect and win effect
    @{$sticked_bubbles{$player}} = sort { $b->{'cx'}+$b->{'cy'}*10 <=> $a->{'cx'}+$a->{'cy'}*10 } @{$sticked_bubbles{$player}};
    remove_hurry($player);
    @{$falling_bubble{$player}} = grep { !exists $_->{chaindestx} } @{$falling_bubble{$player}};
    $sticking_bubble{$player} = undef;
    $launched_bubble{$player} and destroy_bubbles($player, $launched_bubble{$player});
    $launched_bubble{$player} = undef;
    $pdata{$player}{newroot_prelight} = 0;
}

sub win {
    my ($player) = @_;
    if (!$continuegamewhenplayersleave) {
        every { !$pdata{$_}{left} } @PLAYERS and $pdata{$player}{score}++;
    } else {
        $pdata{$player}{score}++;
    }
    $pdata{$player}{ping_right}{state} = 'win';
    $pdata{$player}{ping_right}{img} = 0;
    print_scores($background);
    print_scores($app);
    cleanup_player_bubbles($player);
}

sub lose {
    my ($player) = @_;
    $pdata{$player}{ping_right}{state} = 'lose_to';
    $pdata{$player}{ping_right}{img} = 0;
    if (!$pdata{$player}{left}) {
        foreach ($launched_bubble{$player}, $tobe_launched{$player}, @{$malus_bubble{$player}}) {
            $_ or next;
            $_->{img} = $bubbles_anim{lose};
            $_->{'x'}--;
            $_->{'y'}--;
        }
        print_next_bubble($bubbles_anim{lose}, $player, 1);
    }
    cleanup_player_bubbles($player);

    if (is_mp_game()) {
        $pdata{$player}{state} = 'lost';
        my @living = living_players();
        if (@living == 1) {
            if ((!$continuegamewhenplayersleave && any { $pdata{$_}{left} } @PLAYERS)
                || (every { $pdata{$_}{still_game_messages} == 0 } @PLAYERS)) {
                #- if some players have left and we want to end the game,
                #- or if we've already nothing to wait from others, directly go to won state
                win($living[0]);
                $pdata{state} = "won $living[0]";
            } else {
                #- tentatively suppose we've found the winner, but we need to confirm it by network
                #- first, in rare case of two last players dying at the same time
                my $winnernick = $pdata{$living[0]}{nick};
                $pdata{state} = "finished $living[0]:$winnernick 0";
                #- if I am about to leave, destinations need to receive leave not finished message, else they'll
                #- be waiting forever for it (and there's no point anyway)
                if (!$pdata{p1}{left}) {
                    Games::FrozenBubble::Net::gsend("F$winnernick");
                }
            }
        } else {
            if ($pdata{sendmalustoone} eq $player || $player eq 'p1') {
                set_sendmalustoone(undef);
            }
        }
        if ($pdata{$player}{left}) {
            if (is_distant_player($player)) {
                put_image_to_background(mini_graphics($player) ? $imgbin{"left_${player}_mini"} : $imgbin{left_rp1},
                                        $POS{$player}{left}{x}, $POS{$player}{left}{y}); #}}
            }
            @{$sticked_bubbles{$player}} = ();
            play_sound('cancel');
        } else {
            play_sound('lose');
        }

    } else {
        play_sound('lose');
        $pdata{state} = "lost $player";
        is_2p_game() and win($player eq 'p1' ? 'p2' : 'p1');
    }
  ret:
}

sub verify_if_end {
    iter_players {
        if ($pdata{state} eq 'game' && any { $_->{cy} > 11 } @{$sticked_bubbles{$::p}}) {
            lose($::p);
        }
    };

    if (is_1p_game() && $levels{current} ne 'mp_train' && @{$sticked_bubbles{$PLAYERS[0]}} == 0) {
        put_image_to_background($imgbin{win_panel_1player}, $POS{centerpanel}{x}, $POS{centerpanel}{'y'});
        $pdata{state} = "won $PLAYERS[0]";
        $pdata{$PLAYERS[0]}{ping_right}{state} = 'win';
        $pdata{$PLAYERS[0]}{ping_right}{img} = 0;
        if ($levels{current} ne 'random') {
            $levels{current} and $levels{current}++;
            if ($levels{current} && !$levels{$levels{current}}) {
                $levels{current} = 'WON';
                @{$falling_bubble{$PLAYERS[0]}} = @{$exploding_bubble{$PLAYERS[0]}} = ();
                die 'quit';
            }
        }
    }
}

sub print_hurry($;$) {
    my ($player, $dont_save_background) = @_;
    $player = @PLAYERS == 2 && $player eq 'rp1' ? 'p2' : $player;
    my $t = switch_image_on_background($imgbin{hurry}{$player}, $POS{$player}{left_limit} + $POS{$player}{hurry}{x}, $POS{$player}{hurry}{'y'}, 1);
    $dont_save_background or $pdata{$player}{hurry_save_img} = $t;
}
sub remove_hurry($) {
    my ($player) = @_;
    $player = @PLAYERS == 2 && $player eq 'rp1' ? 'p2' : $player;
    $pdata{$player}{hurry_save_img} and
      switch_image_on_background($pdata{$player}{hurry_save_img}, $POS{$player}{left_limit} + $POS{$player}{hurry}{x}, $POS{$player}{hurry}{'y'});
    $pdata{$player}{hurry_save_img} = undef;
}

sub update_lost {
    my ($player) = @_;

    return if odd($frame);

    if (@{$sticked_bubbles{$player}}) {
        my $b = shift @{$sticked_bubbles{$player}};
        put_image_to_background($bubbles_anim{lose}, --$b->{'x'}, --$b->{'y'});

        if (@{$sticked_bubbles{$player}} == 0) {
            if ($graphics_level == 1 && $pdata{state} =~ /^lost (.*)/ && !is_1p_game()) {
                put_image_to_background($imgbin{win}{$player eq 'p1' ? 'p2' : 'p1'}, $POS{centerpanel}{x}, $POS{centerpanel}{'y'});
            }
            if (is_1p_game()) {
                put_image_to_background($imgbin{lose}, $POS{centerpanel}{'x'}, $POS{centerpanel}{'y'});
                play_sound('noh');
            }
        }
    }

    if (!is_mp_game()) {
        SDL::Events::pump_events();
        while (SDL::Events::poll_event($event) != 0) {
            if ($event->type == SDL_QUIT) {
                cleanup_and_exit();
            }
            if ($event->type == SDL_KEYDOWN && $event->key_sym == SDLK_ESCAPE) {
                die 'new_game';
            }
            if (!@{$sticked_bubbles{$player}}) {
                if ($event->type == SDL_KEYDOWN || $event->type == SDL_JOYBUTTONUP) {
                    die 'new_game';
                }
            }
        }
    }

    my $still_sticked = sum(map { @{$sticked_bubbles{$_}} } @PLAYERS);
    if ($pdata{state} eq 'won ' && $still_sticked == 1) {
        put_image($imgbin{void_panel}, $MENUPOS{xpos_panel}, $MENUPOS{ypos_panel});
        print_('menu', $app, $MENUPOS{xpos_panel}, $MENUPOS{ypos_panel} + 30, loc("Draw game!"), $imgbin{void_panel}->w - 20, 'center');
        SDL::Video::update_rect($app, 0, 0, 0, 0);
    }
}

sub update_won {
    my ($player) = @_;

    return if odd($frame);

    iter_players { #- need iter_players to get the small graphics change for free if we're in multiplayer
        if ($::p eq $player) {
            if (@{$sticked_bubbles{$::p}} && $graphics_level > 1) {
                my $b = shift @{$sticked_bubbles{$::p}};
                destroy_bubbles($::p, $b);
                remove_image_from_background($b->{img}, $b->{'x'}, $b->{'y'});
                #- be sure to redraw at least upper line
                foreach (@{$b->{neighbours}}) {
                    next if !member($_, @{$sticked_bubbles{$::p}});
                    put_image_to_background($_->{img}, $_->{'x'}, $_->{'y'});
                }
            } else {
                @{$sticked_bubbles{$::p}} = ();
            }
        }
    };
}

sub decode_postgame_message($) {
    my ($msg) = @_;
    my $player = $pdata{id2p}{$msg->{id}};
    $player ||= 'UNKNOWN';
    if ($msg->{msg} =~ /^F(.*)/) {
        $pdata{$player}{still_game_messages} = 0;
        dbgnet("decoded postgame message: from=$player msg=finished $1");
        return "$player finished $1";
    } elsif ($pdata{$player}{still_game_messages}) {
        dbgnet("decoded postgame message: from=$player msg=gamemsg");
        return "$player gamemsg";
    } elsif ($msg->{msg} eq 'n') {
        $pdata{$player}{ready4newgame} = 1;
        dbgnet("decoded postgame message: from=$player msg=newgame");
        return "$player newgame";
    } else {
        if ($msg->{msg} ne 'l') {
            print "Postgame 'other' message from $player not a leave - $msg->{msg} - should not!\n";
        }
        dbgnet("decoded postgame message: from=$player msg=other");
        return "$player other";
    }
}

#- ----------- mainloop helper --------------------------------------------

sub update_game() {

    if ($pdata{state} eq 'game') {
        handle_game_events();
        iter_players {
            if ($pdata{$::p}{state} eq 'lost') {
                update_lost($::p);

            } elsif ($pdata{$::p}{state} eq 'ingame') {
                $actions{$::p}{left} and $angle{$::p} += $LAUNCHER_SPEED;
                $actions{$::p}{right} and $angle{$::p} -= $LAUNCHER_SPEED;
                if ($actions{$::p}{center}) {
                    if ($angle{$::p} >= $PI/2 - $LAUNCHER_SPEED
                        && $angle{$::p} <= $PI/2 + $LAUNCHER_SPEED) {
                        $angle{$::p} = $PI/2;
                    } else {
                        $angle{$::p} += ($angle{$::p} < $PI/2) ? $LAUNCHER_SPEED : -$LAUNCHER_SPEED;
                    }
                }
                ($angle{$::p} < 0.1) and $angle{$::p} = 0.1;
                ($angle{$::p} > $PI-0.1) and $angle{$::p} = $PI-0.1;
                if (is_mp_game() && is_local_player($::p) && ($actions{$::p}{left} || $actions{$::p}{right} || $actions{$::p}{center})) {
                    Games::FrozenBubble::Net::gsend(sprintf("a%.2f", $angle{$::p}));
                }
                if (every { ! exists $_->{chaindestx} } @{$falling_bubble{$::p}}) {
                    $pdata{$::p}{hurry}++;
                }
                if ((!$no_time_limit || is_mp_game()) && $pdata{$::p}{hurry} > $TIME_HURRY_WARN) {
                    my $oddness = odd(int(($pdata{$::p}{hurry}-$TIME_HURRY_WARN)/(500/$TARGET_ANIM_SPEED))+1);
                    if ($pdata{$::p}{hurry_oddness} xor $oddness) {
                        if ($oddness) {
                            play_sound('hurry');
                            print_hurry($::p);
                        } else {
                            remove_hurry($::p)
                        }
                    }
                    $pdata{$::p}{hurry_oddness} = $oddness;
                }

                if ($actions{$::p}{mp_fire}
                    || (is_local_player($::p)
                        && ($actions{$::p}{fire} || ((!$no_time_limit || is_mp_game()) && $pdata{$::p}{hurry} == $TIME_HURRY_MAX))
                        && !$launched_bubble{$::p}
                        && !(any { exists $_->{chaindestx} } @{$falling_bubble{$::p}})
                        && !@{$malus_bubble{$::p}})) {
                    play_sound('launch');
                    $total_launched_bubbles++;
                    $launched_bubble{$::p} = $tobe_launched{$::p};
                    $launched_bubble{$::p}->{direction} = $angle{$::p};
                    $tobe_launched{$::p} = undef;
                    $actions{$::p}{fire} = 0;
                    $actions{$::p}{hadfire} = 1;
                    $pdata{$::p}{hurry} = 0;
                    remove_hurry($::p);
                    if (is_local_player($::p)) {
                        do {
                            $pdata{$::p}{nextcolor} = int(rand(@bubbles_images));
                        } while (!validate_nextcolor($pdata{$::p}{nextcolor}, $::p) && @{$sticked_bubbles{$::p}});
                    }
                    if (is_mp_game()) {
                        if (is_local_player($::p)) {
                            Games::FrozenBubble::Net::gsend(sprintf("f%.3f:$pdata{$::p}{nextcolor}", $angle{$::p}));
                        } else {
                            $actions{$::p}{mp_fire} = 0;
                        }
                    }
                }

                if ($launched_bubble{$::p}) {
                    if (!$pdata{$::p}{freezelaunchedbubble}) {
                        $launched_bubble{$::p}->{'x_old'} = $launched_bubble{$::p}->{'x'}; # save coordinates for potential collision
                        $launched_bubble{$::p}->{'y_old'} = $launched_bubble{$::p}->{'y'};
                        $launched_bubble{$::p}->{'x'} += $BUBBLE_SPEED * cos($launched_bubble{$::p}->{direction});
                        $launched_bubble{$::p}->{'y'} -= $BUBBLE_SPEED * sin($launched_bubble{$::p}->{direction});
                        if ($launched_bubble{$::p}->{x} < $POS{$::p}{left_limit}) {
                            play_sound('rebound');
                            $launched_bubble{$::p}->{x} = 2 * $POS{$::p}{left_limit} - $launched_bubble{$::p}->{x};
                            $launched_bubble{$::p}->{direction} -= 2*($launched_bubble{$::p}->{direction}-$PI/2);
                        }
                        if ($launched_bubble{$::p}->{x} > $POS{$::p}{right_limit} - $BUBBLE_SIZE) {
                            play_sound('rebound');
                            $launched_bubble{$::p}->{x} = 2 * ($POS{$::p}{right_limit} - $BUBBLE_SIZE) - $launched_bubble{$::p}->{x};
                            $launched_bubble{$::p}->{direction} += 2*($PI/2-$launched_bubble{$::p}->{direction});
                        }
                    }
                    if (!exists $pdata{$::p}{nextcolors}) {
                        @{$pdata{$::p}{nextcolors}} = map { int(rand(@bubbles_images)) } 0..7;
                    }
                    if ($actions{$::p}{mp_stick}) {
                        $actions{$::p}{mp_stick} = 0;
                        stick_bubble($launched_bubble{$::p}, $pdata{$::p}{stickcx}, $pdata{$::p}{stickcy}, $::p, 1);
                        $launched_bubble{$::p} = undef;
                        $pdata{$::p}{freezelaunchedbubble} = 0;
                    } elsif ($launched_bubble{$::p}->{'y'} <= $POS{$::p}{top_limit} + $pdata{$::p}{newrootlevel} * $ROW_SIZE) {
                        my ($cx, $cy) = get_array_closest_pos($launched_bubble{$::p}->{x}, $launched_bubble{$::p}->{'y'}, $::p);
                        if (is_local_player($::p)) {
                            my $col = get_bubble_num($launched_bubble{$::p});
                            is_mp_game() and Games::FrozenBubble::Net::gsend("s$cx:$cy:$col:@{$pdata{$::p}{nextcolors}}");
                            stick_bubble($launched_bubble{$::p}, $cx, $cy, $::p, 1);
                            $launched_bubble{$::p} = undef;
                        } else {
                            $pdata{$::p}{freezelaunchedbubble} = 1;
                        }
                    } else {
                        foreach (@{$sticked_bubbles{$::p}}) {
                            if (is_collision($launched_bubble{$::p}, $_->{'x'}, $_->{'y'})) {
                                my ($cx, $cy) = get_array_closest_pos(($launched_bubble{$::p}->{'x_old'}+$launched_bubble{$::p}->{'x'})/2,
                                                                      ($launched_bubble{$::p}->{'y_old'}+$launched_bubble{$::p}->{'y'})/2,
                                                                      $::p);
                                if (is_local_player($::p)) {
                                    my $col = get_bubble_num($launched_bubble{$::p});
                                    is_mp_game() and Games::FrozenBubble::Net::gsend("s$cx:$cy:$col:@{$pdata{$::p}{nextcolors}}");
                                    stick_bubble($launched_bubble{$::p}, $cx, $cy, $::p, 1);
                                    $launched_bubble{$::p} = undef;

                                    #- malus generation
                                    if (!any { $_->{chaindestx} } @{$falling_bubble{$::p}}) {
                                        my $malusfreezeframes = 20;
                                        @{$pdata{$::p}{malus}} > 0 && $frame > $pdata{$::p}{malus}[0] + $malusfreezeframes and play_sound('malus');
                                        my @top_of_cx = (0,0,0,0, 0,0,0,0);
                                        foreach (@{$sticked_bubbles{$::p}}) {
                                            if ($_->{'cy'} > $top_of_cx[$_->{'cx'}]) {
                                                $top_of_cx[$_->{'cx'}] = $_->{'cy'};
                                            }
                                        }
                                        while (@{$pdata{$::p}{malus}} > 0 && $frame > $pdata{$::p}{malus}[0] + $malusfreezeframes && @{$malus_bubble{$::p}} < 7) {
                                            my $num = int(rand(@bubbles_images));
                                            my $b = create_bubble_given_img_num($num);
                                            $b->{num} = $num;
                                            my @good_cx;
                                            foreach my $key (keys @top_of_cx) {
                                                if ($top_of_cx[$key] < 11) {
                                                    if (! (even($top_of_cx[$key]+$pdata{$::p}{oddswap}) && $key == 7) ) {
                                                        push @good_cx, $key;
                                                    }
                                                }
                                            }
                                            if ($noinstantdeath && $#good_cx >= 0) {
                                                $b->{'cx'} = $good_cx[rand @good_cx];
                                            } else {
                                                $b->{'cx'} = int(rand(7));
                                            }
                                            $top_of_cx[$b->{'cx'}] += 1;
                                            $b->{'cy'} = 12;
                                            $b->{'stick_y'} = $top_of_cx[$b->{'cx'}];
                                            calc_real_pos($b, $::p);
                                            push @{$malus_bubble{$::p}}, $b;
                                            malus_change(-1, $::p);
                                        }
                                        #- sort them and shift them
                                        @{$malus_bubble{$::p}} = sort { $a->{'cx'} <=> $b->{'cx'} } @{$malus_bubble{$::p}};
                                        my $shifting = 0;
                                        $_->{'y'} += ($shifting += 7) + int(rand(20)) foreach @{$malus_bubble{$::p}};
                                        if (is_mp_game()) {
                                            Games::FrozenBubble::Net::gsend("m$_->{num}:$_->{cx}:$_->{cy}:$_->{stick_y}") foreach @{$malus_bubble{$::p}};
                                        }
                                    }

                                } else {
                                    $pdata{$::p}{freezelaunchedbubble} = 1;
                                }
                                last;
                            }
                        }
                    }
                }

                !$tobe_launched{$::p} and generate_new_bubble($::p, $pdata{$::p}{nextcolor});

                if (!$actions{$::p}{left} && !$actions{$::p}{right} && !$actions{$::p}{hadfire}) {
                    $pdata{$::p}{sleeping}++;
                } else {
                    $pdata{$::p}{sleeping} = 0;
                    $pdata{$::p}{ping_right}{movelatency} = -20;
                }
                if ($pdata{$::p}{sleeping} > $TIMEOUT_PINGUIN_SLEEP && $pdata{$::p}{ping_right}{state} !~ /wait/) {
                    $pdata{$::p}{ping_right}{state} = 'wait_to';
                    $pdata{$::p}{ping_right}{img} = 0;
                }
                if ($pdata{$::p}{sleeping} <= $TIMEOUT_PINGUIN_SLEEP && $pdata{$::p}{ping_right}{state} =~ /wait/) {
                    $pdata{$::p}{ping_right}{state} = 'normal';
                }
                foreach my $direction ('left', 'right') {
                    if ($pdata{$::p}{ping_right}{state} eq "${direction}_to" && !($actions{$::p}{$direction})) {
                        $pdata{$::p}{ping_right}{state} = "${direction}_from";
                        $pdata{$::p}{ping_right}{img} = @{$pinguin{$::p}{$pdata{$::p}{ping_right}{state}}} - $pdata{$::p}{ping_right}{img};
                    }
                    if ($pdata{$::p}{ping_right}{state} eq $direction && !($actions{$::p}{$direction})) {
                        $pdata{$::p}{ping_right}{state} = "${direction}_from";
                        $pdata{$::p}{ping_right}{img} = 0;
                    }
                    if ($actions{$::p}{$direction}) {
                        if ($pdata{$::p}{ping_right}{state} eq "${direction}_to") {
                            #- we're animating towards, nothing to do
                        } elsif ($pdata{$::p}{ping_right}{state} eq $direction) {
                            #- we're there, nothing to do
                        } elsif ($pdata{$::p}{ping_right}{state} eq "${direction}_from") {
                            #- we're coming from there, should not happen that much, flicker no big deal
                            $pdata{$::p}{ping_right}{state} = $direction;
                        } else {
                            $pdata{$::p}{ping_right}{state} = "${direction}_to";
                            $pdata{$::p}{ping_right}{img} = 0;
                        }
                    }
                }
                if ($actions{$::p}{hadfire}) {
                    $pdata{$::p}{ping_right}{state} = 'action';
                    $pdata{$::p}{ping_right}{img} = 0;
                    $actions{$::p}{hadfire} = 0;
                }

                if ($pdata{$::p}{ping_right}{img} >= @{$pinguin{$::p}{$pdata{$::p}{ping_right}{state}}}) {
                    $pdata{$::p}{ping_right}{img} = 0;
                }
            }
        };

        verify_if_end();

    } elsif ($pdata{state} =~ /^lost (.*)/) {
        #- 1p and 2p game only state

        my $loser = $1;
        update_lost($loser);
        is_2p_game() and update_won($loser eq 'p1' ? 'p2' : 'p1');

    } elsif ($pdata{state} =~ /^finished (\S+):(\S+) (\S+)/) {
        my $supposed_winner_player = $1;
        my $supposed_winner_nick = $2;
        my $timeout_counter = $3;

        if ($playdata) {
            $pdata{state} = $recorddata{pdatas}{mp_result};
            if ($pdata{state} eq 'won ') {
                lose($supposed_winner_player);  #- draw game
            } else {
                win($supposed_winner_player);
            }

        } else {
            SDL::Events::pump_events() while SDL::Events::poll_event($event) != 0;
            #- mp game only state when we're trying to figure out if this is not a draw game

            if (my $msg = Games::FrozenBubble::Net::grecv_get1msg_ifdata()) {
                my $result = decode_postgame_message($msg);
                iter_players { dbgnet("\tstill game message of=$pdata{$::p}{nick} value=$pdata{$::p}{still_game_messages}"); };
                if ($result =~ /^(\S+) finished (\S+)/) {
                    my $remote_winner_nick = $2;
                    if ($remote_winner_nick ne $supposed_winner_nick) {
                        #- players don't agree with who won the game, this is a draw game
                        lose($supposed_winner_player);
                        $pdata{state} = "won ";
                    } else {
                        if (every { $pdata{$_}{still_game_messages} == 0 } @PLAYERS) {
                            win($supposed_winner_player);
                            $pdata{state} = "won $supposed_winner_player";
                        }
                    }
                } elsif ($result =~ /^(\S+) other/) {
                    $pdata{$pdata{id2p}{$msg->{id}}}{left} = 1;
                    win($supposed_winner_player);
                    $pdata{state} = "won $supposed_winner_player";
                } elsif ($result !~ /^(\S+) gamemsg/) {
                    #- delay other players already asking for a new game (we're waiting for agreement on winner from others)
                    Games::FrozenBubble::Net::gdelay_messages($msg);
                }

            } else {
                check_mp_connection();
                #- timeout for receiving the winners. it could happen when a client is badly killed.
                $timeout_counter++;
                if ($timeout_counter > 10 * (1000/$TARGET_ANIM_SPEED) ) {  #- 10 seconds
                    mp_disconnect_with_reason('', '', '', '', '', loc("Lost synchronization %s!", 1));
                } else {
                    $pdata{state} = "finished $supposed_winner_player:$supposed_winner_nick $timeout_counter";
                }
            }
        }

    } elsif ($pdata{state} =~ /^won (.*)/) {
        #- mp and 1p game only state

        my $events_pumped;
        my $winner = $1;
        if (is_mp_game()) {
            $winner and update_won($winner);
            iter_players {
                if ($::p ne $winner) {
                    update_lost($::p);
                }
            };
            check_mp_connection();
            $frame % (1000/$TARGET_ANIM_SPEED) == 0 and Games::FrozenBubble::Net::gsend('p');
        }
        if (!$winner || @{$exploding_bubble{$winner}} == 0) {
            my $still_needwait = 0;
            #- still wait if some bubbles are not yet "frozen"
            iter_players {
                $still_needwait += @{$sticked_bubbles{$::p}};
            };
            if (!$still_needwait) {
                SDL::Events::pump_events();
                $events_pumped = 1;

                my $mp_newgame = sub {
                    if ((!$continuegamewhenplayersleave && any { $pdata{$_}{left} } @PLAYERS)
                        || ($continuegamewhenplayersleave && notleft_players() <= 1)
                        || ($pdata{scorelimit} && any { $pdata{$_}{score} == $pdata{scorelimit} } @PLAYERS)) {
                        die 'quit';
                    };
                    dbgnet("send newgame 'n'");
                    Games::FrozenBubble::Net::gsend('n');
                    my $timeout_counter;

                    while (1) {
                        if (my $msg = Games::FrozenBubble::Net::grecv_get1msg_ifdata()) {
                            my $result = decode_postgame_message($msg);
                            if ($result =~ /^(\S+) other/) {
                                $pdata{$pdata{id2p}{$msg->{id}}}{left} = 1;
                                !$continuegamewhenplayersleave || notleft_players() <= 1 and die 'quit';
                            }
                        }
                        iter_distant_players {
                            !$pdata{$::p}{left} && $pdata{$::p}{ready4newgame} == 0 and goto still_waiting;
                        };
                        die 'new_game';
                      still_waiting:
                        SDL::Events::pump_events();
                        while (SDL::Events::poll_event($event) != 0) {
                            if ($event->type == SDL_KEYDOWN && $event->key_sym == SDLK_ESCAPE()) {
                                die 'quit';
                            }
                        }
                        check_mp_connection();
                        Games::FrozenBubble::CStuff::fbdelay($TARGET_ANIM_SPEED);
                        $frame++;
                        $frame % (1000/$TARGET_ANIM_SPEED) == 0 and Games::FrozenBubble::Net::gsend('p');
                        $timeout_counter++;
                        if ($timeout_counter > 10 * (1000/$TARGET_ANIM_SPEED) ) {  #- 10 seconds
                            mp_disconnect_with_reason('', '', '', '', '', loc("Lost synchronization %s!", 2));
                        }
                    }
                };

                while (SDL::Events::poll_event($event) != 0) {
                    if ($event->type == SDL_QUIT) {
                        cleanup_and_exit();
                    }
                    if ($event->type == SDL_KEYDOWN && $event->key_sym == SDLK_ESCAPE()) {
                        die 'quit';
                    }
                    if ($event->type == SDL_KEYDOWN || $event->type == SDL_JOYBUTTONUP) {
                        if ($playdata) {
                            die 'quit';
                        } elsif (is_mp_game()) {
                            $mp_newgame->();
                        } else {
                            die 'new_game';
                        }
                    }
                }

                if (is_mp_game()) {
                    if (my $msg = Games::FrozenBubble::Net::grecv_get1msg_ifdata()) {
                        my $result = decode_postgame_message($msg);
                        if ($result =~ /^(\S+) newgame/) {
                            $mp_newgame->();
                        } elsif ($result =~ /^(\S+) other/) {
                            $pdata{$pdata{id2p}{$msg->{id}}}{left} = 1;
                            !$continuegamewhenplayersleave || notleft_players() <= 1 and die 'quit';
                        }
                    }
                    check_mp_connection();
                }
            }
        }
        if (!$events_pumped) {
            SDL::Events::pump_events();
            while (SDL::Events::poll_event($event) != 0) {
                if ($event->type == SDL_QUIT) {
                    cleanup_and_exit();
                }
                if ($event->type == SDL_KEYDOWN && $event->key_sym == SDLK_ESCAPE) {
                    die 'quit';
                }
            }
        }

    } else {
        die "oops unhandled game state ($pdata{state})\n";
    }

    if (is_mp_game()) {
        $frame % (1000/$TARGET_ANIM_SPEED) == 0 and Games::FrozenBubble::Net::gsend('p');
    }

    #- things that need to be updated in all states of the game
    iter_players {
        my $malus_end = [];
        foreach my $b (@{$malus_bubble{$::p}}) {
            !$b->{freeze} and $b->{'y'} -= $MALUS_BUBBLE_SPEED;
            if (get_array_yclosest($b->{'y'}, $::p) <= $b->{'stick_y'}) {
                if (is_local_player($::p)) {
                    real_stick_bubble($b, $b->{'cx'}, $b->{'stick_y'}, $::p, 0);
                    push @$malus_end, $b;
                    #- remote decode_postgame_message will not like receiving the M command after we sent the F command
                    is_mp_game() && $pdata{state} eq 'game' and Games::FrozenBubble::Net::gsend("M$b->{cx}:$b->{stick_y}");
                } else {
                    $b->{freeze} = 1;
                }
            }
            if ($b->{mp_stick}) {
                real_stick_bubble($b, $b->{'cx'}, $b->{'stick_y'}, $::p, 0);
                push @$malus_end, $b;
            }
        }
        @$malus_end and @{$malus_bubble{$::p}} = difference2($malus_bubble{$::p}, $malus_end);

        my $falling_end = [];
        foreach my $b (@{$falling_bubble{$::p}}) {
            if ($b->{wait_fall}) {
                $b->{wait_fall}--;
            } else {
                my $maxy = @PLAYERS == 2 ? 380 : member($::p, 'rp1', 'rp2') ? 185 : member($::p, 'rp3', 'rp4') ? 415 : 380;
                if (exists $b->{chaindestx} && ($b->{'y'} > $maxy || $b->{chaingoingup})) {
                    my $acceleration = $FREE_FALL_CONSTANT*3;
                    if (!$b->{chaingoingup}) {
                        my $time_to_zero = $b->{speed}/$acceleration;
                        my $distance_to_zero = $b->{speed} * ($b->{speed}/$acceleration + 1) / 2;
                        my $tobe_sqrted = 1 + 8/$acceleration*($b->{'y'}-$b->{chaindesty}+$distance_to_zero);
                        if ($tobe_sqrted < 0) {
                            #- avoid SQRT of a negative number
                            $b->{speedx} = 0;
                        } else {
                            my $time_to_destination = (-1 + sqrt($tobe_sqrted)) / 2;
                            if ($time_to_zero + $time_to_destination == 0) {
                                #- avoid division by zero
                                $b->{speedx} = 0;
                            } else {
                                $b->{speedx} = ($b->{chaindestx} - $b->{x}) / ($time_to_zero + $time_to_destination);
                            }
                        }
                        $b->{chaingoingup} = 1;
                    }
                    $b->{speed} -= $acceleration;
                    $b->{x} += $b->{speedx};
                    if (abs($b->{x} - $b->{chaindestx}) < abs($b->{speedx})) {
                        $b->{'x'} = $b->{chaindestx};
                        $b->{speedx} = 0;
                    }
                    $b->{'y'} += $b->{speed};
                    $b->{'y'} < $b->{chaindesty} and push @$falling_end, $b;
                } else {
                    $b->{'y'} += $b->{speed};
                    $b->{speed} += $FREE_FALL_CONSTANT;
                }
            }
            $b->{'y'} > 470 && !exists $b->{chaindestx} and push @$falling_end, $b;
        }
        @$falling_end and @{$falling_bubble{$::p}} = difference2($falling_bubble{$::p}, $falling_end);
        foreach (@$falling_end) {
            exists $_->{chaindestx} or next;
            @{$chains{$::p}{falling_chained}} = difference2($chains{$::p}{falling_chained}, [ $_ ]);
            delete $chains{$::p}{chained_bubbles}{$_};
            stick_bubble($_, $_->{chaindestcx}, $_->{chaindestcy}, $::p, 0);
        }

        my $exploding_end = [];
        foreach my $b (@{$exploding_bubble{$::p}}) {
            $b->{'x'} += $b->{speedx};
            $b->{'y'} += $b->{speedy};
            $b->{speedy} += $FREE_FALL_CONSTANT;
            push @$exploding_end, $b if $b->{'y'} > 470;
        }
        if (@$exploding_end) {
            @{$exploding_bubble{$::p}} = difference2($exploding_bubble{$::p}, $exploding_end);
            if (!@{$exploding_bubble{$::p}} && !@{$sticked_bubbles{$::p}}) {
                if ($pdata{state} =~ /^lost (.*)/ && $::p ne $1 && !is_1p_game()) {
                    put_image($imgbin{win}{$::p}, $POS{centerpanel}{'x'}, $POS{centerpanel}{'y'});
                }
                if (is_mp_game() && $pdata{state} =~ /^won (.*)/) {
                    my $winner = $1;
                    my $img = $winner eq 'p1' ? $imgbin{win_panel_p1_net} : @PLAYERS == 2 ? $imgbin{win}{rp3} : $imgbin{win}{$winner};
                    put_image($img, $POS{centerpanel}{x}, $POS{centerpanel}{'y'});
                    print_('ingame', $app, 264, 300, $pdata{$winner}{nick}, 198, 'center');
                    my $xpos = @PLAYERS <= 3 ? 352 : @PLAYERS == 4 ? 348 : 322;
                    iter_players_ {
                        if ($::p_ ne $winner) {
                            my $img = @PLAYERS == 2 && $::p_ eq 'rp1' ? $imgbin{net_lose}{rp3} : $imgbin{net_lose}{$::p_};  #- fix colors
                            put_image($img, $xpos, 264);
                            $xpos += 32;
                        }
                    };
                }
            }
        }

        if (member($pdata{$::p}{ping_right}{state}, qw(action right_to right_from left_to left_from wait_to wait win lose_to lose))) {
            $pdata{$::p}{ping_right}{img}++;
#            print "...state $pdata{$::p}{ping_right}{state} image $pdata{$::p}{ping_right}{img}\n";
            if ($pdata{$::p}{ping_right}{img} == @{$pinguin{$::p}{$pdata{$::p}{ping_right}{state}}}) {
#                print "finish images of state $pdata{$::p}{ping_right}{state} (" . int(@{$pinguin{$::p}{$pdata{$::p}{ping_right}{state}}}) . ")\n";
                if ($pdata{$::p}{ping_right}{state} eq 'right_to') {
                    $pdata{$::p}{ping_right}{state} = 'right';
                } elsif ($pdata{$::p}{ping_right}{state} eq 'left_to') {
                    $pdata{$::p}{ping_right}{state} = 'left';
                } elsif ($pdata{$::p}{ping_right}{state} eq 'wait_to') {
                    $pdata{$::p}{ping_right}{state} = 'wait';
                } elsif ($pdata{$::p}{ping_right}{state} eq 'wait') {
                    #- wait loops, don't change state
                } elsif ($pdata{$::p}{ping_right}{state} eq 'win') {
                    #- simple loop, don't change state
                } elsif ($pdata{$::p}{ping_right}{state} eq 'lose_to') {
                    $pdata{$::p}{ping_right}{state} = 'lose';
                } elsif ($pdata{$::p}{ping_right}{state} eq 'lose') {
                    #- lose loops, don't change state
                } else {
                    $pdata{$::p}{ping_right}{state} = 'normal';
                }
                $pdata{$::p}{ping_right}{img} = 0;
#                print "=> state $pdata{$::p}{ping_right}{state}\n";
            }
        }

    };

    #- advance playlist when the current song finished
    $mixer_enabled && $mixer && @playlist && !SDL::Mixer::Music::playing_music and play_music('dummy');
}

#- ----------- init stuff -------------------------------------------------

our $init_step = 0;
sub print_step($) {
    my ($txt) = @_;
    print $txt;
    SDL::Events::pump_events();
    while (SDL::Events::poll_event($event)) {
        if ($event->type == SDL_QUIT || ($event->type == SDL_KEYDOWN && $event->key_sym == SDLK_ESCAPE)) {
            cleanup_and_exit();
        }
    }
    put_image($imgbin{loading_step}, 100 + $init_step*12, 10);
    if ($init_step == 0) {
        put_image($imgbin{loading_step_initial}, 100 + $_*12, 10) foreach 1..11;
    }
    SDL::Video::update_rect($app, 0, 0, 0, 0);
    $init_step++;
}

sub load_levelset {
    my ($levelset_name) = @_;

    -e $levelset_name or die "No such levelset ($levelset_name).\n";

    $loaded_levelset = $levelset_name;
    my $row_numb = 0;
    my $curr_level = $levels{current};

    %levels = ();
    $levels{current} = $curr_level;
    $lev_number = 1;

    foreach my $line (cat_($levelset_name)) {
        if ($line !~ /\S/) {
            if ($row_numb) {
                $lev_number++;
                $row_numb = 0;
            }
        } else {
            my $col_numb = 0;
            foreach (split ' ', $line) {
                /-/ or push @{$levels{$lev_number}}, { cx => $col_numb, cy => $row_numb, img_num => $_ };
                $col_numb++;
            }
            $row_numb++;
        }
    }
}

sub init_game() {
    -r "$FPATH/$_" or die "[*ERROR*] the datafiles seem to be missing! (could not read `$FPATH/$_')\n".
                          "          The datafiles need to go to `$FPATH'.\n"
                            foreach qw(gfx snd data);

    print '[SDL Init] ';
#    $app = SDL::App->new(
#               -icon       => "$FPATH/gfx/pinguins/window_icon_penguin.png",
#               -flags      => $sdl_flags | ($fullscreen ? SDL_FULLSCREEN : 0),
#               -title      => 'Frozen-Bubble 2',
#               -width      => 640,
#               -height     => 480
#       );

        SDL::init(SDL_INIT_EVERYTHING);
        $app = SDL::Video::set_video_mode(640, 480, 24, $sdl_flags | ($fullscreen ? SDL_FULLSCREEN : 0));
	unless ($app)
	{

		warn "Couldn't make app ".SDL::get_error(). "\n Try software fallback";
	        $app = SDL::Video::set_video_mode(640, 480, 24, SDL_SWSURFACE | ($fullscreen ? SDL_FULLSCREEN : 0));
		die "Couldn't make app ".SDL::get_error() unless $app;

	}
        SDL::Video::wm_set_icon(SDL::Video::load_BMP("$FPATH/gfx/pinguins/window_icon_penguin.bmp"));
        SDL::Video::wm_set_caption('Frozen-Bubble 2', 'Frozen-Bubble 2');

    if(!$nojoysticks) {
        my $joys = SDL::Joystick::num_joysticks();
        $joysticksinfo and print "\nfound $joys joystick(s)\n";
        for (my $i = 0; $i < $joys; $i++) {
            push @joysticks, SDL::Joystick->new($i);
            $joysticksinfo and print "\t" . ($i + 1) . ': ' . (SDL::Joystick::name(SDL::Joystick::index($joysticks[$i])) || 'unknown joystick') . "\n";
        }
    }
    $frame = 0;

    $apprects{main} = SDL::Rect->new( 0, 0, $app->w, $app->h);
    $event = SDL::Event->new;
    SDL::Events::enable_unicode(1);
    SDL::Mouse::show_cursor(0);
    $imgbin{loading} = add_image('loading.png');
    put_image($imgbin{loading}, 10, 10);
        SDL::Video::update_rect($app, 0, 0, 0, 0);
    $imgbin{loading_step} = add_image('loading_step.png');
    $imgbin{loading_step_initial} = add_image('loading_step_initial.png');

    print_step('[Graphics');
    $imgbin{back_2p} = SDL::Image::load("$FPATH/gfx/backgrnd.png");
    $imgbin{back_1p} = SDL::Image::load("$FPATH/gfx/back_one_player.png");
    $imgbin{back_mp} = SDL::Image::load("$FPATH/gfx/back_multiplayer.png");
    $background      = SDL::Surface->new( SDL_SWSURFACE, $app->w, $app->h, 32, 0, 0, 0, 0);
    $background_orig = SDL::Surface->new( SDL_SWSURFACE, $app->w, $app->h, 32, 0, 0, 0, 0);

    Games::FrozenBubble::CStuff::sdlpango_init();
    $pangocontext{netdialogs} =           { params => { desc => 'sans 10', fg => 'white', bg => 'black' } };
    $pangocontext{netdialogs_servermsg} = { params => { desc => 'sans italic 10', fg => 'white', bg => 'black' } };
    $pangocontext{menu} =                 { params => { desc => 'sans 11', fg => 'white', bg => 'black' } };
    $pangocontext{bold_menu} =            { params => { desc => 'sans 11 bold', fg => 'white', bg => 'black' } };
    $pangocontext{ingame} =               { params => { desc => 'sans 14', fg => 'white', bg => 'black' } };
    $pangocontext{ingame_chat} =          { params => { desc => 'sans 10', fg => 'black', bg => 'white' } };
    $pangocontext{ingame_small} =         { params => { desc => 'sans 8', fg => 'white', bg => 'black' } };
    $pangocontext{ingame_small_chat} =    { params => { desc => 'sans 8', fg => 'white', bg => 'black' } };
    $pangocontext{$_}{context_fg} = Games::FrozenBubble::CStuff::sdlpango_createcontext($pangocontext{$_}{params}{fg}, $pangocontext{$_}{params}{desc}) foreach keys %pangocontext;
    $pangocontext{$_}{context_bg} = Games::FrozenBubble::CStuff::sdlpango_createcontext($pangocontext{$_}{params}{bg}, $pangocontext{$_}{params}{desc}) foreach keys %pangocontext;

    foreach my $ball (1..8) {
        my $img = add_bubble_image('balls/bubble-'.($colourblind && 'colourblind-')."$ball.gif");
        $img_mini{$img} = add_image('balls/bubble-'.($colourblind && 'colourblind-')."${ball}-mini.png");
    }
    $bubbles_anim{white} = add_image("balls/bubble_prelight.png");
    $img_mini{$bubbles_anim{white}} = add_image("balls/bubble_prelight-mini.png");
    $bubbles_anim{lose} = add_image("balls/bubble_lose.png");
    $img_mini{$bubbles_anim{lose}} = add_image("balls/bubble_lose-mini.png");
    $bubbles_anim{on_top_next} = add_image("on_top_next.png");
    $img_mini{$bubbles_anim{on_top_next}} = add_image("on_top_next-mini.png");
    foreach my $step (0..6) {
        push @{$bubbles_anim{stick}}, my $img = add_image("balls/stick_effect_$step.png");
        $img_mini{$img} = add_image("balls/stick_effect_${step}-mini.png")
    }

    $shooter_lowgfx = add_image("shooter-lowgfx.png");
    my $shooter = add_image("shooter.png");
    my $shooter_mini = add_image("shooter-mini.png");
    foreach my $number (-$CANON_ROTATIONS_NB..$CANON_ROTATIONS_NB) {
        my $angle = $number*($PI/2)/$CANON_ROTATIONS_NB;

                # rendering all high-quality canons
        $canon{img}{$number} = SDL::Surface->new( SDL_SWSURFACE, $shooter->w, $shooter->h, 32, 0xFF000000, 0xFF0000, 0xFF00, 0xFF);
        Games::FrozenBubble::CStuff::rotate_bicubic($canon{img}{$number}, $shooter, $angle);
        $canon{data}{$number} = Games::FrozenBubble::CStuff::autopseudocrop($canon{img}{$number});
        #- now crop (and use native RGBA ordering)
        my $replace = SDL::Surface->new( SDL_SWSURFACE, $canon{data}{$number}[2],  $canon{data}{$number}[3], 32, 0xFF000000, 0xFF0000, 0xFF00, 0xFF);
                SDL::Video::set_alpha($canon{img}{$number}, 0, 0);
                SDL::Video::blit_surface( $canon{img}{$number}, SDL::Rect->new( $canon{data}{$number}[0],  $canon{data}{$number}[1],
                                                                    $canon{data}{$number}[2],  $canon{data}{$number}[3]),
                                                          $replace, SDL::Rect->new(0, 0, $canon{img}{$number}->w, $canon{img}{$number}->h));
        $canon{img}{$number} = $replace;
        add_default_rect($canon{img}{$number});

                # rendering all mid-quality canons
        $canon{img_mini}{$number} = SDL::Surface->new( SDL_SWSURFACE,  $shooter_mini->w,  $shooter_mini->h, 32, 0xFF000000, 0xFF0000, 0xFF00, 0xFF);
        Games::FrozenBubble::CStuff::rotate_bicubic($canon{img_mini}{$number}, $shooter_mini, $angle);
        $canon{data_mini}{$number} = Games::FrozenBubble::CStuff::autopseudocrop($canon{img_mini}{$number});
        #- now crop (and use native RGBA ordering)
        my $replace2 = SDL::Surface->new( SDL_SWSURFACE, $canon{data_mini}{$number}[2], $canon{data_mini}{$number}[3], 32, 0xFF000000, 0xFF0000, 0xFF00, 0xFF);
                SDL::Video::set_alpha($canon{img_mini}{$number}, 0, 0);
                SDL::Video::blit_surface( $canon{img_mini}{$number}, SDL::Rect->new( $canon{data_mini}{$number}[0], $canon{data_mini}{$number}[1],
                                                        $canon{data_mini}{$number}[2], $canon{data_mini}{$number}[3]), $replace2,
                                                                                                                SDL::Rect->new(0,0,$canon{img_mini}{$number}->w,$canon{img_mini}{$number}->h));
        $canon{img_mini}{$number} = $replace2;
        add_default_rect($canon{img_mini}{$number});

        $number eq -$CANON_ROTATIONS_NB/2 and print_step('.');
        $number eq 0 and print_step('.');
        $number eq $CANON_ROTATIONS_NB/2 and print_step('.');
    }

    print_step('.');
    $malus_gfx{banane} = add_image('banane.png');
    $img_mini{$malus_gfx{banane}} = add_image('banane-mini.png');
    $malus_gfx{tomate} = add_image('tomate.png');
    $img_mini{$malus_gfx{tomate}} = add_image('tomate-mini.png');

    $imgbin{back_paused} = add_image('back_paused.png');
    push @{$imgbin{paused}}, add_image("pause_00$_.png") foreach '01'..'35';
    $imgbin{lose} = add_image('lose_panel.png');
    $imgbin{progress_red} = add_image('dot_red.png');
    $imgbin{progress_green} = add_image('dot_green.png');
    $imgbin{win_panel_1player} = add_image('win_panel_1player.png');
    $imgbin{win_panel_p1_net} = add_image('win_panel_p1_net.png');
    $imgbin{compressor_main} = add_image('compressor_main.png');
    $imgbin{compressor_ext} = add_image('compressor_ext.png');

    $imgbin{back_menu} = SDL::Image::load( "$FPATH/gfx/menu/back_start.png");
    $imgbin{stamp} = add_image('menu/stamp.png');
    $imgbin{menu_closedeye_green_left} = add_image('menu/backgrnd-closedeye-left-green.png');
    $imgbin{menu_closedeye_green_right} = add_image('menu/backgrnd-closedeye-right-green.png');
    $imgbin{menu_closedeye_purple_left} = add_image('menu/backgrnd-closedeye-left-purple.png');
    $imgbin{menu_closedeye_purple_right} = add_image('menu/backgrnd-closedeye-right-purple.png');
    $imgbin{menu_logo} = add_image('menu/fblogo.png');
    $imgbin{menu_logo_mask} = add_image('menu/fblogo-mask.png');
    $imgbin{txt_1pgame_off}  = add_image('menu/txt_1pgame_off.png');
    $imgbin{txt_1pgame_over} = add_image('menu/txt_1pgame_over.png');
    $imgbin{txt_2pgame_off}  = add_image('menu/txt_2pgame_off.png');
    $imgbin{txt_2pgame_over} = add_image('menu/txt_2pgame_over.png');
    $imgbin{txt_netgame_off}  = add_image('menu/txt_netgame_off.png');
    $imgbin{txt_netgame_over} = add_image('menu/txt_netgame_over.png');
    $imgbin{txt_langame_off}  = add_image('menu/txt_langame_off.png');
    $imgbin{txt_langame_over} = add_image('menu/txt_langame_over.png');
    $imgbin{txt_editor_off}  = add_image('menu/txt_editor_off.png');
    $imgbin{txt_editor_over} = add_image('menu/txt_editor_over.png');
    $imgbin{txt_keys_off}  = add_image('menu/txt_keys_off.png');
    $imgbin{txt_keys_over} = add_image('menu/txt_keys_over.png');
    $imgbin{txt_graphics_off}  = add_image('menu/txt_graphics_off.png');
    $imgbin{txt_graphics_over} = add_image('menu/txt_graphics_over.png');
    $imgbin{txt_highscores_off}  = add_image('menu/txt_highscores_off.png');
    $imgbin{txt_highscores_over} = add_image('menu/txt_highscores_over.png');
    $imgbin{void_panel} = add_image('menu/void_panel.png');
    $imgbin{'1p_panel'} = add_image('menu/1p_panel.png');
    $imgbin{void_chat} = add_image('void_chat.png');
    $imgbin{void_chat_small_p2} = add_image('void_chat_small_p2.png');
    $imgbin{void_chat_small_rp1_rp3} = add_image('void_chat_small_rp1_rp3.png');
    $imgbin{void_chat_small_rp2_rp4} = add_image('void_chat_small_rp2_rp4.png');
    $imgbin{void_mp_training} = add_image('void_mp_training.png');
    $imgbin{ping_low} = add_image('menu/ping-low.png');
    $imgbin{ping_mid} = add_image('menu/ping-mid.png');
    $imgbin{ping_high} = add_image('menu/ping-high.png');
    $imgbin{menu_cursor}{'1pgame'}   = [ map { add_image("menu/anims/1pgame_00$_.png") }    ('01'..'30') ];
    $imgbin{menu_cursor}{'2pgame'}   = [ map { add_image("menu/anims/p1p2_00$_.png") }      ('01'..'30') ];
    $imgbin{menu_cursor}{langame}    = [ map { add_image("menu/anims/langame_00$_.png") }   ('01'..'70') ];
    $imgbin{menu_cursor}{netgame}    = [ map { add_image("menu/anims/netgame_00$_.png") }   ('01'..'89') ];
    $imgbin{menu_cursor}{editor}     = [ map { add_image("menu/anims/editor_00$_.png") }    ('01'..'67') ];
    $imgbin{menu_cursor}{graphics3}  = [ map { add_image("menu/anims/gfx-l1_00$_.png") }    ('01'..'30') ];
    $imgbin{menu_cursor}{graphics2}  = [ map { add_image("menu/anims/gfx-l2_00$_.png") }    ('01'..'30') ];
    $imgbin{menu_cursor}{graphics1}  = [       add_image("menu/anims/gfx-l3_0001.png")                   ];
    $imgbin{menu_cursor}{keys}       = [ map { add_image("menu/anims/keys_00$_.png") }      ('01'..'80') ];
    $imgbin{menu_cursor}{highscores} = [ map { add_image("menu/anims/highscore_00$_.png") } ('01'..'89') ];
	my $flags = SDL_ALPHA_OPAQUE; 
    foreach my $cursortype (keys %{$imgbin{menu_cursor}}) {
        foreach my $img (@{$imgbin{menu_cursor}{$cursortype}}) {

		my $alpha = SDL::Surface->new( SDL_SWSURFACE,  $img->w,  $img->h,  32, 0xFF000000,0xFF0000,0xFF00,0xFF);
		SDL::Video::set_alpha($img, $flags, 0 );  #- for RGBA->RGBA blits, SDL_SRCALPHA must be removed or destination alpha is preserved
		SDL::Video::blit_surface($img, SDL::Rect->new(0,0,$img->w,$img->h), $alpha, SDL::Rect->new(0,0,$img->w,$img->h));
		Games::FrozenBubble::CStuff::alphaize($alpha);
            push @{$imgbin{menu_cursor}{"${cursortype}alpha"}}, $alpha;
	    SDL::Video::set_alpha($img, SDL_SRCALPHA | SDL_ALPHA_OPAQUE, 0);
        }
    }
    $imgbin{left_rp1}         = add_image('left-rp1.png');
    $imgbin{"left_${_}_mini"} = add_image("left-${_}-mini.png") foreach qw(rp1 rp2 rp3 rp4);
    $imgbin{highlight_server} = add_image('menu/highlight-server.png');

    #- little flags
    foreach my $f (glob("$FPATH/gfx/flags/*.png")) {
        $f =~ /flag-(\S+)\.png/;
        $imgbin{flag}{$1} = add_image_file($f);
    }

    my @levelsets = sort glob("$FBLEVELS/*");

    #- scrolling banner
    $imgbin{banner_artwork} = add_image('menu/banner_artwork.png');
    $imgbin{banner_soundtrack} = add_image('menu/banner_soundtrack.png');
    $imgbin{banner_cpucontrol} = add_image('menu/banner_cpucontrol.png');
    $imgbin{banner_leveleditor} = add_image('menu/banner_leveleditor.png');

    $MENUPOS{xpos_panel} = (640 - $imgbin{void_panel}->w) / 2;
    $MENUPOS{ypos_panel} = (480 - $imgbin{void_panel}->h) / 2;

    #- 1p and 2p menu images
    $imgbin{txt_1pmenu_off} = add_image('menu/txt_menu_1p_off.png');
    $imgbin{txt_1pmenu_over} = add_image('menu/txt_menu_1p_over.png');
    $imgbin{txt_1pmenu_play_all_levels_text} = add_image('menu/txt_play_all_levels_text.png');
    $imgbin{txt_1pmenu_play_all_levels_outlined_text} = add_image('menu/txt_play_all_levels_outlined_text.png');
    $imgbin{txt_1pmenu_pick_start_level_text} = add_image('menu/txt_pick_start_level_text.png');
    $imgbin{txt_1pmenu_pick_start_level_outlined_text} = add_image('menu/txt_pick_start_level_outlined_text.png');
    $imgbin{txt_1pmenu_play_random_levels_text} = add_image('menu/txt_play_random_levels_text.png');
    $imgbin{txt_1pmenu_play_random_levels_outlined_text} = add_image('menu/txt_play_random_levels_outlined_text.png');
    $imgbin{txt_1pmenu_mp_train_text} = add_image('menu/txt_multiplayer_training_text.png');
    $imgbin{txt_1pmenu_mp_train_outlined_text} = add_image('menu/txt_multiplayer_training_outlined_text.png');

    #- net game setup images
    $imgbin{back_netgame} = add_image('back_netgame.png');
    $imgbin{netspot_free} = add_image('netspot.png');
    $imgbin{netspot_playing} = add_image('netspot-playing.png');
    $imgbin{netspot_insamegame} = add_image('netspot-insamegame.png');
    $imgbin{netspot_self} = [ map { add_image("netspot-self-$_.png") } qw(1 2 3 4 5 6 7 8 9 A B C D) ];

    #- hiscore
    $imgbin{back_hiscores} = add_image('back_hiscores.png');
    $imgbin{hiscore_frame} = add_image('hiscore_frame.png');
    $imgbin{hiscore_levelset} = add_image('hiscore-levelset.png');
    $imgbin{hiscore_mptraining} = add_image('hiscore-mptraining.png');

    local @PLAYERS = @ALL_PLAYERS;  #- load all images even if -so commandline option was passed
    iter_players {
        print_step('.');
        $imgbin{hurry}{$::p} = add_image("hurry_$::p.png");
        $imgbin{win}{$::p} = add_image("win_panel_$::p.png");
        $::p ne 'p2' and $imgbin{net_lose}{$::p} = add_image("net_lose_$::p.png");
        if ($::p =~ /^r/) {
            $imgbin{attack}{$::p} = add_image("attack_$::p.png");
            $imgbin{attackme}{$::p} = add_image("attackme_$::p.png");
        }
        $pdata{$::p}{score} = 0;
        my $p = $::p;
        $pinguin{$::p}{normal}     = [       add_image("pinguins/anime-shooter_${p}_0020.png")                          ];
        $pinguin{$::p}{action}     = [ map { add_image("pinguins/anime-shooter_${p}_00$_.png") }         (21..50)       ];
        $pinguin{$::p}{left_to}    = [ map { add_image("pinguins/anime-shooter_${p}_00$_.png") } reverse ('02'..'19')   ];
        $pinguin{$::p}{left}       = [       add_image("pinguins/anime-shooter_${p}_0001.png")                          ];
        $pinguin{$::p}{left_from}  = [ map { add_image("pinguins/anime-shooter_${p}_00$_.png") }         ('02'..'19')   ];
        $pinguin{$::p}{right_to}   = [ map { add_image("pinguins/anime-shooter_${p}_00$_.png") }         (51..70)       ];
        $pinguin{$::p}{right}      = [       add_image("pinguins/anime-shooter_${p}_0071.png")                          ];
        $pinguin{$::p}{right_from} = [ map { add_image("pinguins/anime-shooter_${p}_00$_.png") } reverse (51..71)       ];
        $pinguin{$::p}{wait_to}    = [ map { add_image("pinguins/wait_${p}_00$_.png") }                  ('01'..'74')   ];
        $pinguin{$::p}{wait}       = [ map { add_image("pinguins/wait_${p}_00$_.png") }                  (75..97)       ];
        $pinguin{$::p}{win}        = [ map { add_image("pinguins/win_${p}_00$_.png") }                   ('01'..'68')   ];
        $pinguin{$::p}{lose_to}    = [ map { add_image("pinguins/loose_${p}_00$_.png") }                 ('01'..'64')   ];
        $pinguin{$::p}{lose}       = [ map { add_image("pinguins/loose_${p}_0$_.png") }                  ('065'..'158') ];
    };

    print_step('] ');

    my $video_errors = SDL::get_error();
    print STDERR "\n$video_errors";

    if ($mixer eq 'SOUND_DISABLED') {
        $mixer_enabled = 0;
        $mixer = undef;

    } elsif (!defined($mixer_enabled) || $mixer_enabled) {
            $mixer_enabled = init_sound();
    }

    #- the RGBA effects algorithms assume little endian RGBA surfaces
    #my $replace = SDL::Surface->new( SDL_SWSURFACE, $imgbin{menu_logo}->w,  $imgbin{menu_logo}->h, 32, 0, 0, 0, 0);
    #SDL::Video::set_alpha($imgbin{menu_logo}, SDL_SRCALPHA, 0);  #- for RGBA->RGBA blits, SDL_SRCALPHA must be removed or destination alpha is preserved
    #SDL::Video::blit_surface($imgbin{menu_logo}, SDL::Rect->new(0,0,$imgbin{menu_logo}->w,$imgbin{menu_logo}->h), $replace, SDL::Rect->new(0,0,$imgbin{menu_logo}->w,$imgbin{menu_logo}->h));
    #  $imgbin{menu_logo} = $replace;
    add_default_rect($imgbin{menu_logo} );

    $lev_number = 0;
    load_levelset("$FPATH/data/levels");

    Games::FrozenBubble::CStuff::init_effects($FPATH);
    $addicted_time = 0;
    $total_launched_bubbles = 0;

    $start_time = 0;
    print "Ready.\n";
}

sub open_level($) {
    my ($level) = @_;

    $level eq 'WON' and $level = $lev_number;

    $levels{$level} or die "No such level or void level ($level).\n";
    foreach my $l (@{$levels{$level}}) {
        iter_players {
            my $img = $l->{img_num} =~ /^\d+$/ ? $bubbles_images[$l->{img_num}] : $bubbles_anim{lose};
            real_stick_bubble(create_bubble_given_img($img), $l->{cx}, $l->{cy}, $::p, 0);
        };
    }
}

sub translate_joystick_tokey($) {
    my ($event) = @_;
    my $which = $event->jaxis_which;
    if ($event->type == SDL_JOYAXISMOTION) {
        my $axis = $event->jaxis_axis;
        my $value = $event->jaxis_value;
        if ($value <= -10000) {  #- should work properly with analog joysticks
            return "joystick|axisvalue|$which|$axis|-10000";
        } elsif ($value >= 10000) {
            return "joystick|axisvalue|$which|$axis|10000";
        } else {
            return "joystick|axisvalue|$which|$axis|0";
        }
    } elsif ($event->type() == SDL_JOYBUTTONDOWN) {
        my $button = $event->jbutton_button + 1;
        return "joystick|buttondown|$which|$button";
    } elsif ($event->type() == SDL_JOYBUTTONUP) {
        my $button = $event->jbutton_button + 1;
        return "joystick|buttonup|$which|$button";
    }
}

sub extended_keypress($) {
    my ($event) = @_;
    if ($event->type == SDL_KEYDOWN) {
        return $event->key_sym;
    } elsif ($event->type == SDL_JOYAXISMOTION || $event->type() == SDL_JOYBUTTONDOWN) {
        my $keypressed = translate_joystick_tokey($event);
        if ($keypressed =~ /^joystick\|axisvalue\|\d+\|\d+\|0$/) {  #- we treat position at 0 as KEYUP
            $keypressed = undef;
        }
        return $keypressed;
    }
}

sub grab_key {
    my $keyp;

    do {
        SDL::Events::wait_event($event);
        if ($event->type == SDL_KEYDOWN) {
            $keyp = $event->key_sym;
        } elsif ($event->type == SDL_JOYAXISMOTION || $event->type() == SDL_JOYBUTTONDOWN) {
            $keyp = translate_joystick_tokey($event);
        }
    } while (!defined($keyp));

    #- so that using "capital" letter should work
    if (member($keyp, SDLK_LSHIFT(), SDLK_RSHIFT())) {
        return grab_key();
    } else {
        return $keyp;
    }
}

sub display_highscores {
    my ($type, $new_entry) = @_;

    $display_on_app_disabled = 1;
    @PLAYERS = ('p1');
    %POS = %POS_1P;

    if ($type eq 'levels' || !defined($type)) {
        SDL::Video::blit_surface($imgbin{back_hiscores}, $apprects{main}, $app, $apprects{main});
        put_image($imgbin{hiscore_levelset}, 640 - 10 - $imgbin{hiscore_levelset}->w, 8);

        my $initial_high_posx = 90;
        my ($high_posx, $high_posy) = ($initial_high_posx, 68);
        my $high_rect = SDL::Rect->new($POS{p1}{left_limit} & 0xFFFFFFFC, $POS{p1}{top_limit} & 0xFFFFFFFC,
                                       ($POS{p1}{right_limit}-$POS{p1}{left_limit}) & 0xFFFFFFFC, ($POS{p1}{'initial_bubble_y'}-$POS{p1}{top_limit}-10) & 0xFFFFFFFC);

        my $centered_print = sub($$$) {
            my ($x, $y, $txt, $bold) = @_;
            print_($bold ? 'bold_menu' : 'menu', $app, $x, $y + $imgbin{hiscore_frame}->h - 8, $txt, $imgbin{hiscore_frame}->w + 12, 'center');
        };

        my $old_levelset = $loaded_levelset;

        foreach my $high (ordered_highscores()) {
            @{$sticked_bubbles{p1}} = ();
            @{$root_bubbles{p1}} = ();
            $pdata{p1}{newrootlevel} = 0;
            $pdata{p1}{oddswap} = 0;
            SDL::Video::blit_surface($imgbin{back_1p}, $high_rect, $background, $high_rect);

            # try to get it from the default-levelset. If we can't, default to the
            # last level in the default levelset
            if (!$high->{piclevel}) {
                $loaded_levelset ne "$FPATH/data/levels" and load_levelset("$FPATH/data/levels");

                # handle the case where the user has edited/created a levelset with more levels
                # than the default levelset and then got a high score
                if ($high->{level} > $lev_number) {
                    open_level($lev_number);
                } else {
                    open_level($high->{level});
                }
            } else {
                # this is the normal case. just load the level that the file tells us
                if ($loaded_levelset ne "$FBHOME/highlevelshistory") {
                    load_levelset("$FBHOME/highlevelshistory");
                }
                open_level($high->{piclevel});
            }

            put_image($imgbin{hiscore_frame}, $high_posx - 7, $high_posy - 6);
                        my $tmp = SDL::Surface->new(SDL_SWSURFACE, $high_rect->w/4, $high_rect->h/4, 32);
                        Games::FrozenBubble::CStuff::shrink($tmp, $background, 0, 0, $high_rect, 4);
            SDL::Video::blit_surface($tmp, SDL::Rect->new(0,0,$tmp->w,$tmp->h), $app, SDL::Rect->new($high_posx, $high_posy, $tmp->w, $tmp->h));
            $centered_print->($high_posx - 15, $high_posy, $high->{name}, $new_entry == $high);
            $centered_print->($high_posx - 15, $high_posy + 20, $high->{level} eq 'WON' ? loc("won!") : loc("level %s", i18n_number($high->{level})), $new_entry == $high);
            my $min = int($high->{time}/60);
            my $sec = int($high->{time} - $min*60); length($sec) == 1 and $sec = "0$sec";
            $centered_print->($high_posx - 15, $high_posy + 40, loc("%s'%s\"", i18n_number($min), i18n_number($sec)), $new_entry == $high);
            $high_posx += 98;
            $high_posx > 550 and $high_posx = $initial_high_posx, $high_posy += 175;
            $high_posy > 440 and last;
        }
        load_levelset($old_levelset);

        SDL::Video::update_rect($app, 0, 0, 0, 0);

        SDL::Events::pump_events() while SDL::Events::poll_event($event) != 0;
        grab_key() eq SDLK_ESCAPE() and return;
    }

    if (($type eq 'mptrain' || !defined($type)) && (@$HISCORES_MPTRAIN || @$HISCORES_MPTRAIN_CHAINREACTION)) {
        SDL::Video::blit_surface($imgbin{back_hiscores}, $apprects{main}, $app, $apprects{main});
        put_image($imgbin{hiscore_mptraining}, 640 - 10 - $imgbin{hiscore_mptraining}->w, 8);

        print_('menu', $app, 0, 50, loc("Regular"), 320, 'center');
        my %parts = (rank => { xpos => 80, width => 40 },
                     name => { xpos => 120, width => 150 });
        if ($is_rtl) {
            $parts{$_}{xpos} = 640 - $parts{$_}{xpos} - $parts{$_}{width} foreach keys %parts;
        }
        my $y = 80;
        my $counter = 1;
        my $lastvalue;
        foreach my $high (ordered_mptrain_highscores()) {
            my $font = $new_entry == $high ? 'bold_menu' : 'menu';
            $high->{score} ne $lastvalue and print_($font, $app, $parts{rank}{xpos}, $y, "$counter. ", $parts{rank}{width}, 'right');
            print_($font, $app, $parts{name}{xpos}, $y, "$high->{name}: $high->{score}", $parts{name}{width});
            $y += $smg_lineheight + 2;
            $counter++;
            $lastvalue = $high->{score};
        }

        print_('menu', $app, 320, 50, loc("Chain-reaction enabled"), 320, 'center');
        %parts = (rank => { xpos => 420, width => 40 },
                  name => { xpos => 460, width => 150 });
        if ($is_rtl) {
            $parts{$_}{xpos} = 640 - $parts{$_}{xpos} - $parts{$_}{width} foreach keys %parts;
        }
        $y = 80;
        $counter = 1;
        $lastvalue = undef;
        foreach my $high (ordered_mptrain_highscores_chainreaction()) {
            my $font = $new_entry == $high ? 'bold_menu' : 'menu';
            $high->{score} ne $lastvalue and print_($font, $app, $parts{rank}{xpos}, $y, "$counter. ", $parts{rank}{width}, 'right');
            print_($font, $app, $parts{name}{xpos}, $y, "$high->{name}: $high->{score}", $parts{name}{width});
            $y += $smg_lineheight + 2;
            $counter++;
            $lastvalue = $high->{score};
        }

        SDL::Video::update_rect($app, 0, 0, 0, 0);

        SDL::Events::pump_events() while SDL::Events::poll_event($event) != 0;
        grab_key() eq SDLK_ESCAPE() and die "quit";
    }

    $display_on_app_disabled = 0;
}

sub keysym_to_char($) {
    my ($key) = @_;
    my $name = SDL::Events::get_key_name($key);
    return uc($name) if $name; 
    # we will remove the below and @fbsyms::syms after testing
    eval("$key eq SDLK_$_()") and return uc($_) foreach @Games::FrozenBubble::Symbols::syms;
    if ($key >= 160 && $key <= 255) {
        return 'WORLD_' . ($key - 160);  #- "world" keys are not exported
    }
}

sub ask_from($) {
    my ($w) = @_;
    # $w->{intro} = [ 'text_intro_line1', 'text_intro_line2', ... ]
    # $w->{entries} = [ { q => 'question1?', a => \$var_answer1, f => 'flags' }, {...} ]   flags: ONE_CHAR, SPACE
    # $w->{outro} = 'text_outro_uniline'
    # $w->{erase_background} = $background_right_one

    put_image($imgbin{void_panel}, $MENUPOS{xpos_panel}, $MENUPOS{ypos_panel});

    my $ypos = $MENUPOS{ypos_panel} + 12;
    my $lineheight = 18;
    my %xpos = ( questions => $is_rtl ? $MENUPOS{xpos_panel} + $imgbin{void_panel}->w*1/3 + 10 : $MENUPOS{xpos_panel},
                 echo => $is_rtl ? $MENUPOS{xpos_panel} + $imgbin{void_panel}->w*1/3 - 100 : $MENUPOS{xpos_panel} + $imgbin{void_panel}->w*2/3 );

    foreach my $i (@{$w->{intro}}) {
                print_('menu', $app, $MENUPOS{xpos_panel}, $ypos, $i, $imgbin{void_panel}->w, 'center') if $i;
                $ypos += $lineheight;
    }

    $ypos += 10;

    my $ok = 1;
    SDL::Events::enable_key_repeat(200, 50);
    ask_from_entries:
    foreach my $entry (@{$w->{entries}}) {
        #- in case wrapping occurred
        SDL::Video::blit_surface($imgbin{void_panel}, SDL::Rect->new(10, $ypos - $MENUPOS{ypos_panel}, $imgbin{void_panel}->w - 20, 30), $app,
                                  SDL::Rect->new($MENUPOS{xpos_panel} + 10, $ypos, $imgbin{void_panel}->w, $imgbin{void_panel}->h));
                print_('menu', $app, $xpos{questions}, $ypos, $entry->{'q'}, $imgbin{void_panel}->w*2/3 - 10, @{$w->{entries}} == 1 ? 'center' : 'right');
                SDL::Video::update_rect($app, 0, 0, 0, 0);
                my $srect_mulchar_redraw = SDL::Rect->new($xpos{echo} - 3 - $MENUPOS{xpos_panel}, $ypos - $MENUPOS{ypos_panel}, $imgbin{void_panel}->w*1/3, 30);
                my $drect_mulchar_redraw = SDL::Rect->new($xpos{echo} - 3, $ypos, $imgbin{void_panel}->w, $imgbin{void_panel}->h);
                        my $x_echo = $xpos{echo};
                my $txt;
                        if ($entry->{f} ne 'SPACE') {
                                if ($entry->{f} eq 'ONE_CHAR' || $entry->{f} eq 'ONE_CHAR_DISPLAY') {
                                        if($entry->{f} eq 'ONE_CHAR_DISPLAY')
                                        {
                                                print_('menu', $app, $x_echo, $ypos, "(".keysym_to_char(${$entry->{a}}).")", 100, $is_rtl ? 'right' : 'left');
                                                SDL::Video::update_rect($app, 0, 0, 0, 0);
                                        }
                                        my $k;
                                        while (!defined($k)) {
                                                $k = grab_key();
                                                if ($k =~ /^joystick\|axisvalue\|\d+\|\d+\|0$/) {  #- we treat position at 0 as KEYUP
                                                        $k = undef;
                                                }
                                        }
                                        $no_echo or play_sound('typewriter');
                                        $k == SDLK_ESCAPE and $ok = 0, last ask_from_entries;
                                        $txt = $k;
                                        if ($k =~ /^joystick\|axisvalue\|(\d+)\|(\d+)\|([-\d]+)/) {
                                                my $num = @joysticks > 1 ? $1 + 1 : '';
                                                $k = 'joy' . i18n_number($num) . '-' . (even($2) ? ($3 < 0 ? loc("left") : loc("right")) : ($3 < 0 ? loc("up") : loc("down")));
                                        } elsif ($k =~ /^joystick\|buttondown\|(\d+)\|(\d+)/) {
                                                my $num = @joysticks > 1 ? $1 + 1 : '';
                                                my $button = $2 + 1;
                                                $k = 'joy' . i18n_number($num) . '-' . loc("button") . i18n_number($2);
                                        } else {
                                                $k = keysym_to_char($k);
                                        }
                                        if($entry->{f} eq 'ONE_CHAR_DISPLAY')
                                        {
                                                put_image_area($imgbin{void_panel}, $MENUPOS{xpos_panel}, $MENUPOS{ypos_panel}, $x_echo-$MENUPOS{xpos_panel}, $ypos-$MENUPOS{ypos_panel});
                                        }
                                        print_('menu', $app, $x_echo, $ypos, $k, 100, $is_rtl ? 'right' : 'left');  #- always in ASCII so need to tell it to go right in RTL
                                } else {
                                        callback_entry('reset');
                                  ask_from_main_loop:
                                        while (1) {
                                                if (callback_entry('ping')) {
                                                        SDL::Video::blit_surface($imgbin{void_panel}, $srect_mulchar_redraw, $app, $drect_mulchar_redraw);
                                                        callback_entry('print', { xpos => $x_echo, ypos => $ypos, maxlen => 100, font => 'menu' });
                                                }
                                                SDL::Video::update_rect($app, 0, 0, 0, 0);
                                                SDL::Events::pump_events();
                                                while (SDL::Events::poll_event($event) != 0) {
                                                        if ($event->type == SDL_KEYDOWN) {
                                                                my $k = $event->key_sym;
                                                                if ($k == SDLK_ESCAPE()) {
                                                                        $ok = 0;
                                                                        last ask_from_entries;
                                                                } elsif ($k == SDLK_RETURN() || $k == SDLK_KP_ENTER()) {
                                                                        $txt = join('', callback_entry('gettext'));
                                                                        last ask_from_main_loop;
                                                                } else {
                                                                        callback_entry('keypressed', { event => $event, maxlen => 100, font => 'menu' });
                                                                        SDL::Video::blit_surface($imgbin{void_panel}, $srect_mulchar_redraw, $app, $drect_mulchar_redraw);
                                                                        callback_entry('moved');
                                                                        callback_entry('print', { xpos => $x_echo, ypos => $ypos, maxlen => 100, font => 'menu' });
                                                                }
                                                        }
                                                }
                                                Games::FrozenBubble::CStuff::fbdelay($TARGET_ANIM_SPEED);
                                        }
                                }
                }
                $entry->{answer} = $txt;
                $ypos += $entry->{f} eq 'SPACE' ? $lineheight / 2 : $lineheight;
    }
    SDL::Events::enable_key_repeat(0, 0);

    if ($ok) {
                ${$_->{a}} = $_->{answer} foreach @{$w->{entries}};
                print_('menu', $app, $MENUPOS{xpos_panel}, $MENUPOS{ypos_panel} + $imgbin{void_panel}->h - 35, $w->{outro}, $imgbin{void_panel}->w, 'center');
                SDL::Video::update_rect($app, 0, 0, 0, 0);
                play_sound('menu_selected');
                sleep 2;
    } else {
                play_sound('cancel');
    }

    exists $w->{erase_background} and erase_image_from($imgbin{void_panel}, $MENUPOS{xpos_panel}, $MENUPOS{ypos_panel}, $w->{erase_background});
    SDL::Video::update_rect($app, 0, 0, 0, 0);
    SDL::Events::pump_events() while SDL::Events::poll_event($event) != 0;

    return $ok;
}

sub new_game() {

    my $ticks = SDL::get_ticks();
    $display_on_app_disabled = 1;

    $TIME_APPEARS_NEW_ROOT = 11;
    $TIME_HURRY_WARN = 250;
    $TIME_HURRY_MAX = 375;

    #- reset chat messages from last game, if any
    $pdata{current_chat_messages}{$_} = undef foreach @ALL_PLAYERS;

    my $backgr;
    if (is_mp_game()) {
        $pdata{p1}{chatting} and cleanup_chatting();
        if (@PLAYERS == 2) {  #- in net/lan 2p mode, use bigger graphics and positions
            $backgr = $imgbin{back_2p};
            %POS = %POS_2P;
        } else {
            $backgr = $imgbin{back_mp};
            %POS = %POS_MP;
        }
        $pdata{inconsistency} = undef;
    } elsif (is_2p_game()) {
        $backgr = $imgbin{back_2p};
        %POS = %POS_2P;
    } elsif (is_1p_game()) {
        $backgr = $imgbin{back_1p};
        %POS = %POS_1P;
        if ($levels{current} eq 'mp_train') {
            $pdata{$PLAYERS[0]}{score} = 0;
        } else {
            if ($levels{current} ne 'random') {
                $chainreaction = 0;
            }
            $TIME_APPEARS_NEW_ROOT = 8;
            $TIME_HURRY_WARN = 400;
            $TIME_HURRY_MAX = 525;
            $pdata{$PLAYERS[0]}{score} = $levels{current};
        }
    } else {
        die "oops";
    }

    SDL::Video::blit_surface($backgr, $apprects{main}, $background_orig, $apprects{main});
    if ($levels{current} eq 'mp_train') {
        my $drect = SDL::Rect->new(32, 152, $imgbin{void_mp_training}->w, $imgbin{void_mp_training}->h);
        SDL::Video::blit_surface($imgbin{void_mp_training}, $rects{$imgbin{void_mp_training}}, $background_orig, $drect);
    }
    SDL::Video::blit_surface($background_orig, $apprects{main}, $background, $apprects{main});

    iter_players {
        $actions{$::p}{$_} = 0 foreach qw(left right fire center);
        $angle{$::p} = $PI/2;
        @{$sticked_bubbles{$::p}} = ();
        @{$malus_bubble{$::p}} = ();
        @{$root_bubbles{$::p}} = ();
        @{$falling_bubble{$::p}} = ();
        @{$exploding_bubble{$::p}} = ();
        delete $pdata{$::p}{nextcolors};
        @{$chains{$::p}{falling_chained}} = ();
        %{$chains{$::p}{chained_bubbles}} = ();
        $launched_bubble{$::p} = undef;
        $sticking_bubble{$::p} = undef;
        $pdata{$::p}{$_} = 0 foreach qw(newroot newroot_prelight oddswap hurry newrootlevel);
        @{$pdata{$::p}{malus}} = ();
        $pdata{$::p}{state} = 'ingame';
        $pdata{$::p}{ping_right}{img} = 0;
        $pdata{$::p}{ping_right}{state} = 'normal';
        $pdata{$::p}{hurry_save_img} = undef;
        $apprects{$::p} = SDL::Rect->new( $POS{$::p}{left_limit},  $POS{$::p}{top_limit},
                                          $POS{$::p}{right_limit}-$POS{$::p}{left_limit}, $POS{$::p}{'initial_bubble_y'}-$POS{$::p}{top_limit});
        if (is_distant_player($::p)) {
            if (!$pdata{$::p}{left}) {
                $pdata{$::p}{still_game_messages} = 1;
                $pdata{$::p}{ready4newgame} = 0;
            }
        }
    };

    print_scores($background);
    if ($levels{current} eq 'mp_train') {
        mp_train_print_time();
    }

    iter_players {
        delete $pdata{$::p}{newrootlast};
        if ($pdata{$::p}{left}) {
            #- already left remote players in mp game
            put_image_to_background(mini_graphics($::p) ? $imgbin{"left_".$::p."_mini"} : $imgbin{left_rp1},
                                    $POS{$::p}{left}{x}, $POS{$::p}{left}{y}); #}}
            $pdata{$::p}{state} = 'left';
        } else {
            handle_progress($::p);
        }
    };

    is_1p_game() and print_compressor();

    if (!$playdata) {
        %recorddata = ();
        my $srand = SDL::get_ticks();
        srand $srand;
        push @{$recorddata{data}}, { srand => $srand };  #- the first record entry is used for pdatas (more keys added later)
    }
    if ($levels{current} =~ /^\d+$/) {
        open_level($levels{current});
    } else {
        foreach my $cy (0 .. 4) {
            foreach my $cx (0 .. (6 + even($cy))) {
                my $num = int(rand(@bubbles_images));
                if (is_mp_game()) {
                    if (!$playdata) {
                        check_mp_connection();
                        eval { $num = mp_propagate("b|$cx|$cy", $num, \$ticks); };
                        if ($@) {
                            $@ =~ /^quit/ and return 0;
                            die;
                        }
                        push @{$recorddata{data}[0]{bubbles}}, $num;
                    } else {
                        $num = shift @{$recorddata{pdatas}{bubbles}};
                    }
                }
                my $b = create_bubble_given_img_num($num);
                real_stick_bubble($b, $cx, $cy, $PLAYERS[0], 0);
                if (!is_1p_game()) {
                    iter_players_but_first {
                        $pdata{$::p}{left} or real_stick_bubble(create_bubble_given_img($b->{img}), $cx, $cy, $::p, 0);
                    };
                }
            }
        }
    }

    my ($next_num, $tobe_num);
    do { $next_num = int(rand(@bubbles_images)) } while (!validate_nextcolor($next_num, $PLAYERS[0]));
    do { $tobe_num = int(rand(@bubbles_images)) } while (!validate_nextcolor($tobe_num, $PLAYERS[0]));
    if (is_mp_game()) {
        if (!$playdata) {
            check_mp_connection();
            eval {
                $next_num = mp_propagate("N", $next_num, \$ticks);
                $tobe_num = mp_propagate("T", $tobe_num, \$ticks);
            };
            if ($@) {
                $@ =~ /^quit/ and return 0;
                die;
            }
            push @{$recorddata{data}[0]{bubbles}}, $next_num, $tobe_num;
        } else {
            $next_num = shift @{$recorddata{pdatas}{bubbles}};
            $tobe_num = shift @{$recorddata{pdatas}{bubbles}};
        }
    }
    $next_bubble{$PLAYERS[0]} = create_bubble_given_img_num($next_num);
    generate_new_bubble($PLAYERS[0], $tobe_num);
    if (!is_1p_game()) {
        iter_players_but_first {
            if (!$pdata{$::p}{left}) {
                $next_bubble{$::p} = create_bubble_given_img_num($next_num);
                generate_new_bubble($::p, $tobe_num);
            }
        };
    }

    if ($graphics_level == 1) {
        SDL::Video::blit_surface($background, $apprects{main}, $app, $apprects{main});
        SDL::Video::update_rect($app, 0, 0, 0, 0);
    } else {
        Games::FrozenBubble::CStuff::effect($app, SDL::Video::display_format($background));
    }

    $display_on_app_disabled = 0;

    SDL::Events::pump_events() while SDL::Events::poll_event($event) != 0;
    $pdata{state} = 'game';

    $direct = undef;

    if (is_mp_game() && !$playdata) {
        mp_ping_if_needed(\$ticks);

        #- 1. first wait on a common barrier with others, so that everyone has finished previous things
        dbgnet("send barrier 'n'");
        Games::FrozenBubble::Net::gsend('n');
        check_mp_connection();
        iter_distant_players {
            $pdata{$::p}{barrier4newgame} = 0;
        };

        #- at this point, we can receive first commands of quickies instead of synchro
        my @keep_messages;
        while (1) {
            my $m;
            eval { $m = Games::FrozenBubble::Net::grecv_get1msg(); };  #- blocking
            if ($@) {
                $@ =~ /^quit/ and return 0;
                die;
            }
            mp_ping_if_needed(\$ticks);
            if ($m->{msg} eq 'n') {
                dbgnet("received barrier 'n' from $pdata{id2p}{$m->{id}}");
                $pdata{$pdata{id2p}{$m->{id}}}{barrier4newgame} = 1;
                iter_distant_players {
                    !$pdata{$::p}{left} && $pdata{$::p}{barrier4newgame} == 0 and goto still_waiting;
                };
                dbgnet("all barriers received, carrying on");
                last;
              still_waiting:
            } else {
                push @keep_messages, $m;
            }
        }

        #- 2. now that we're all ready to synchronize, let a unique synchro message be sent, the leader and others will all wait on
        is_leader() and Games::FrozenBubble::Net::gsend('!');
        check_mp_connection();

        while (1) {
            my $m;
            eval { $m = Games::FrozenBubble::Net::grecv_get1msg(); }; #- blocking
            if ($@) {
                $@ =~ /^quit/ and return 0;
                die;
            }
            mp_ping_if_needed(\$ticks);
            if ($m->{msg} eq '!') {
                last;
            } else {
                push @keep_messages, $m;
            }
        }

        Games::FrozenBubble::Net::gdelay_messages(@keep_messages);

        @{$pdata{attackingme}} = ();
    }

    if ($saveframes) {
        $saveframescounter = 0;
        $saveframesbase = gettimeofday();
    }

    $start_time = SDL::get_ticks();
    return 1;
}


my $save;

sub choose_1p_game_mode() {

    my @ordered_names = qw(play_all_levels pick_start_level play_random_levels mp_train);
    my $active_menu = 0;

    my $menu_xpos = $MENUPOS{xpos_panel} + ($imgbin{'1p_panel'}->w - $imgbin{txt_1pmenu_over}->w)/2;
    my $menu_ypos = $MENUPOS{ypos_panel} + 90;
    my $menu_ypos_spacer = $imgbin{txt_1pmenu_over}->h + 4;
    my %name2ypos = (play_all_levels    => $menu_ypos,
                     pick_start_level   => $menu_ypos +     $menu_ypos_spacer,
                     play_random_levels => $menu_ypos + 2 * $menu_ypos_spacer,
                     mp_train           => $menu_ypos + 3 * $menu_ypos_spacer);

    my $overlook_index = 0;
    my $overlook = SDL::Surface->new(SDL_SWSURFACE, $imgbin{txt_1pmenu_pick_start_level_text}->w,
                                                        $imgbin{txt_1pmenu_pick_start_level_text}->h, 32);
    my $redraw = sub {
        my $draw_element = sub {
            my ($name, $mode) = @_;
            put_image($imgbin{"txt_1pmenu_$mode"}, $menu_xpos, $name2ypos{$name});
            SDL::Video::blit_surface($imgbin{"txt_1pmenu_${name}_outlined_text"}, SDL::Rect->new(0,0,$imgbin{"txt_1pmenu_${name}_outlined_text"}->w,$imgbin{"txt_1pmenu_${name}_outlined_text"}->h),
                                                 $app, SDL::Rect->new($menu_xpos, $name2ypos{$name}, $imgbin{"txt_1pmenu_${name}_outlined_text"}->w,
                                                                                                                             $imgbin{"txt_1pmenu_${name}_outlined_text"}->h));
        };

        my $img = $imgbin{'1p_panel'};
        my $drect = SDL::Rect->new($MENUPOS{xpos_panel}, $MENUPOS{ypos_panel}, $img->w, $img->h);
        if ($save) {
            SDL::Video::blit_surface($save, $rects{img}, $app, $drect);
        } else {
            $save = SDL::Surface->new(SDL_SWSURFACE, $img->w, $img->h, 32);
            SDL::Video::blit_surface($app, $drect, $save, $rects{$img});
        }
        put_image($img, $MENUPOS{xpos_panel}, $MENUPOS{ypos_panel});

        my $ypos = $MENUPOS{ypos_panel} + 16;
        print_('menu', $app, $MENUPOS{xpos_panel}, $ypos, loc("Start 1-player game menu"), $imgbin{'1p_panel'}->w, 'center');

        foreach (@ordered_names) {
            $_ ne $ordered_names[$active_menu] and $draw_element->($_, 'off');
        }

        $draw_element->($ordered_names[$active_menu], 'over');

        Games::FrozenBubble::CStuff::overlook_init($overlook);
        $overlook_index = 0;

        SDL::Video::update_rect($app, 0, 0, 0, 0);
    };

    my $draw_overlook = sub {
        my %name2pivot = (play_all_levels => 90, pick_start_level => 135, play_random_levels => 82, mp_train => 105);
        my $name =  $ordered_names[$active_menu];
        put_image($imgbin{txt_1pmenu_over}, $menu_xpos, $name2ypos{$name});
        Games::FrozenBubble::CStuff::overlook($overlook, $imgbin{"txt_1pmenu_${name}_text"}, $overlook_index, $name2pivot{$name});
        SDL::Video::blit_surface($overlook, SDL::Rect->new(0,0,$overlook->w,$overlook->h), $app, SDL::Rect->new($menu_xpos, $name2ypos{$name}, $overlook->w, $overlook->h));
        $overlook_index++;
        if ($overlook_index == 70) {
            $overlook_index = 0;
        }
        SDL::Video::blit_surface($imgbin{"txt_1pmenu_${name}_outlined_text"}, SDL::Rect->new(0,0,$imgbin{"txt_1pmenu_${name}_outlined_text"}->w,$imgbin{"txt_1pmenu_${name}_outlined_text"}->h), $app, SDL::Rect->new($menu_xpos, $name2ypos{$name}, $imgbin{"txt_1pmenu_${name}_outlined_text"}->w, $imgbin{"txt_1pmenu_${name}_outlined_text"}->h));
    };

    $redraw->();

    while (1) {
                my $synchro_ticks = SDL::get_ticks();
# commented out because otherwise we see only a white box instead of highlighted background image
        if ($graphics_level > 1) {
            $draw_overlook->();
            SDL::Video::update_rects($app, @update_rects);
            @update_rects = ();
        }
        SDL::Events::pump_events();
        while (SDL::Events::poll_event($event) != 0) {
            if ($event->type == SDL_KEYDOWN) {
                my $k = $event->key_sym;
                if ($k == SDLK_RETURN() || $k == SDLK_KP_ENTER()) {
                    my $cancel;
                    if ($ordered_names[$active_menu] eq 'pick_start_level') {
                        if ($levels{current}) {
                            choose_levelset(1) or $cancel = 1;
                        }
                    } elsif ($ordered_names[$active_menu] eq 'play_random_levels') {
                        $levels{current} = 'random';
                        my $answ;
                        ask_from({ intro => [ loc("Random level"), '', '', loc("Enable chain-reaction?"), '' ],
                                   entries => [ { 'q' => loc("%s or %s?", 'Y', 'N'), 'a' => \$answ, f => 'ONE_CHAR' } ],
                                   outro => loc("Enjoy the game!") }) or return;
                        $chainreaction = $answ == SDLK_y; #;;
                    } elsif ($ordered_names[$active_menu] eq 'mp_train') {
                        $levels{current} = 'mp_train';
                        my $answ;
                        ask_from({ intro => [ loc("Multiplayer training"), '', '', loc("Enable chain-reaction?"), '' ],
                                   entries => [ { 'q' => loc("%s or %s?", 'Y', 'N'), 'a' => \$answ, f => 'ONE_CHAR' } ],
                                   outro => loc("Enjoy the game!") }) or return;
                        $chainreaction = $answ == SDLK_y; #;;
                    }
                    $cancel or return 1;
                } elsif ($event->key_sym == SDLK_ESCAPE) {
                    $levels{current} = undef;
                    return;
                } elsif ($k == SDLK_DOWN()) {
                    if ($active_menu < @ordered_names - 1) {
                        $active_menu++;
                    } else {
                        $active_menu = 0;
                    }
                    play_sound('menu_change');
                } elsif ($k == SDLK_UP()) {
                    if ($active_menu > 0) {
                        $active_menu--;
                    } else {
                        $active_menu = @ordered_names - 1;
                    }
                    play_sound('menu_change');
                }
                $redraw->();
            }
        }
        my $to_wait = $TARGET_ANIM_SPEED - (SDL::get_ticks() - $synchro_ticks);
        $to_wait > 0 and Games::FrozenBubble::CStuff::fbdelay($to_wait);
    }
}


our $smg_startx = 78;
our $smg_starty = 30;
our $smg_starty_chat = 320;
our $smg_starty_players = $smg_starty_chat + $smg_lineheight;
our $smg_max_messages = 5;
our $smg_statusx = 10;
our $smg_statusy = 435;

sub erase_line($$;$$) {
    my ($pos, $background, $xpos, $width) = @_;
    my $drect = SDL::Rect->new($xpos || 0, $pos, $width || 640, $smg_lineheight + 6);
    SDL::Video::blit_surface($background, $drect, $app, $drect);
}

our @smg_status_messages;
our $smg_status_message_offsetpage = 1;

sub smg_printstatus {
    my $drect = SDL::Rect->new(0, $smg_statusy - $smg_max_messages * $smg_lineheight, 640, 480);
    SDL::Video::blit_surface($imgbin{back_netgame}, $drect, $app, $drect);
    my $y = $smg_statusy;
    my $i = $smg_status_message_offsetpage;
    while ($i < $smg_max_messages + $smg_status_message_offsetpage && @smg_status_messages >= $i) {
        if ($smg_status_messages[-$i]) {
            my $kind = $smg_status_messages[-$i] =~ /^\*\*\*/ ? 'netdialogs_servermsg' : 'netdialogs';
            if ($smg_status_messages[-$i] =~ /^\p{BidiClass:R}/) { #see bi directional regex in perlunicode works from 5.8.8 and above
                #- if text begins with unicode RTL direction, we also need to tell pango to align on the right
                #- (is there another unicode special character which does both?) Yes there is! But we can leave that for later
                print_($kind, $app, $smg_statusx, $y, $smg_status_messages[-$i], 620, 'right');
            } else {
                print_($kind, $app, $smg_statusx, $y, $smg_status_messages[-$i], 620, 'left');
            }
        }
        $y -= $smg_lineheight;
        $i++;
    }
    SDL::Video::update_rect($app, 0, 0, 0, 0);
}

sub smg_add_status_msg {
    push @smg_status_messages, @_;
    $smg_status_message_offsetpage = 1;
    smg_printstatus();
}

sub clean_server {
    if ($pdata{serverpid}) {
        kill 15, $pdata{serverpid};
        waitpid $pdata{serverpid}, 0;
        $pdata{serverpid} = undef;
    }
}

END { clean_server(); }

sub sanitize_nick {
    my ($nick) = @_;
    $nick = substr($nick, 0, 10);
    $nick =~ s/[^a-zA-Z0-9_-]//g;
    return $nick;
}

sub smg_servers() {

    if ($pdata{gametype} eq 'lan') {
        smg_add_status_msg(loc("*** Please wait, probing for available servers on local network..."));
        my $ret = Games::FrozenBubble::Net::discover_lan_servers();
        if ($ret->{failure}) {
            smg_add_status_msg(loc("*** Unable to probe for available servers on local network!"),
                               "*** " . $ret->{failure},
                               loc("*** Verify your network setup"));
            grab_key();
            return;
        } else {
            my @servers = @{$ret->{servers}};
            if (!@servers) {
                my $fb_server = "$FLPATH";
                if (!-x $fb_server) {
                    print STDERR "$fb_server is missing or not executable!\n";
                    smg_add_status_msg(loc("*** No server found, and could not start server"),
                                       loc("*** Verify your installation or contact your vendor"));
                    grab_key();
                    return;
                } else {
                    if (my $pid = fork()) {
                        $pdata{autochooseserver} = 1;
                        $pdata{serverpid} = $pid;
                        smg_add_status_msg(loc("*** No server found, created server for local network game"));
                        sleep 1;
                        return [ { host => 'localhost', port => 1511 } ];
                    } else {
                        unless (exec $fb_server, '-L', '-d', '-n', substr("lan-$mynick", 0, 12), '-z') {
                            print STDERR "Could not create server limited to lan game: $!\n";
                            POSIX::_exit(1);
                        }
                    }
                }
            } else {
                return \@servers;
            }
        }

    } else {
        smg_add_status_msg(loc("*** Contacting master server..."));
        my $serverlist = Games::FrozenBubble::Net::get_server_list();
        my @servers;
        if (defined $serverlist) {
            foreach my $line (split /\n/, $serverlist) {
                if ($line =~ /^(\S+) (\S+)$/) {
                    push @servers, { host => $1, port => $2 };
                } else {
                    print STDERR "Unrecognized line in serverlist:\n\t$line\n";
                }
            }
            smg_add_status_msg(loc("*** Server list received properly"));
        } else {
            smg_add_status_msg(loc("*** Unable to download server list from master server!"),
                               loc("*** Verify your network setup or retry later"));
            grab_key();
            return;
        }
        return \@servers;
    }
}

our $forget_because_kicked;
sub smg_choose_server(@) {
    my (@servers) = @_;
    my $max_lines = 18;
    erase_line($smg_starty_chat, $imgbin{back_netgame});     #- if we return from choose_game
    erase_line($smg_starty_players, $imgbin{back_netgame});  #-

    if ($pdata{autochooseserver}) {
        $pdata{autochooseserver} = 0;
        Games::FrozenBubble::Net::connect($servers[0]{host}, $servers[0]{port});
        return Games::FrozenBubble::Net::isconnected();
    }

    my @sorted_servers;
    my $offset = 0;
    my $redraw = sub {
        my $drect = SDL::Rect->new(0, 0, 640, $smg_statusy-$smg_lineheight*5);
        SDL::Video::blit_surface($imgbin{back_netgame}, $drect, $app, $drect);

        my %parts = (flag =>    { xpos => $smg_startx,                    width => 30 },
                     name =>    { xpos => $smg_startx + 30 + 4,           width => 120 },
                     details => { xpos => $smg_startx + 30 + 4 + 120 + 4, width => 344 });
        if ($is_rtl) {
            $parts{$_}{xpos} = 640 - $parts{$_}{xpos} - $parts{$_}{width} foreach keys %parts;
        }
        my $y = $smg_starty;
        my @show_servers = @sorted_servers;
        my $ofs = @show_servers - $max_lines;
        $ofs = 0 if $ofs < 0;
        $offset = $ofs if $offset > $ofs;
        splice(@show_servers, 0, $offset) if $offset;
        splice(@show_servers, 18) if $ofs-$offset;
        foreach my $server (@show_servers) {
            if ($server->{selected}) {
                put_image($imgbin{highlight_server}, 6, $y - 1);
            }
            exists $imgbin{flag}{$server->{language}} and put_image($imgbin{flag}{$server->{language}}, $parts{flag}{xpos}, $y);
            print_('netdialogs', $app, $parts{name}{xpos}, $y, $server->{name}, $parts{name}{width}, $is_rtl ? 'right' : 'left');  #- ASCII
            my $details = loc("Available players: %s (playing: %s) Ping: %sms", i18n_number($server->{free}), i18n_number($server->{playing}), i18n_number($server->{ping}));
            print_('netdialogs', $app, $parts{details}{xpos}, $y, $details, $parts{details}{width});
            my $pingimg = $server->{ping} < 80 ? "ping_low" : $server->{ping} < 200 ? "ping_mid" : "ping_high";
            put_image($imgbin{$pingimg}, $is_rtl ? $parts{details}{xpos} + $parts{details}{width} - width('netdialogs', $details) - 17
                                                 : $parts{details}{xpos} + width('netdialogs', $details), $y);

            $y += $smg_lineheight + 2;
        }
        SDL::Video::update_rect($app, 0, 0, 0, 0);
    };

    my @potential_servers;
    foreach my $server (@servers) {
        if (!$server->{disabled}) {
            push @potential_servers, $server;
        }
    }
    my $discover = Games::FrozenBubble::NetDiscover->new(@potential_servers);
    my $looped = 0;
    my $init = 0;
    while (1) {
        if ($discover->pending) {
            $discover->work(0.1); #- do networking stuff for 100ms
            $looped++;
            my @found_servers = $discover->found;
            my $weightfunc = sub { my $base = $_[0]->{free} - $_[0]->{ping}/50; $_[0]->{playing} < 100 ? $base + $_[0]->{playing}/3 : $base - $_[0]->{playing}/3; };
            @sorted_servers = sort { $weightfunc->($b) <=> $weightfunc->($a) } @found_servers;
            $redraw->();
            #- wait a bit or user confusion will be large (jumping cursor)
            if ($looped >= 10 && @sorted_servers && !$init) {
                $init = 1;
                $sorted_servers[0]->{selected} = 1;
                smg_add_status_msg(loc("*** Please choose a server"));
                $redraw->();
            }
        } elsif (!$init) {
            $init = 1;
            if (@sorted_servers) {
                $sorted_servers[0]->{selected} = 1;
                smg_add_status_msg(loc("*** Please choose a server"));
                $redraw->();
            } else {
                #- no server discovered. empty servers list so that below code will properly report no servers found.
                @servers = ();
                last;
            }
        }
        SDL::Events::pump_events();
        while (SDL::Events::poll_event($event) != 0) {
            if ($event->type == SDL_QUIT) {
                cleanup_and_exit();
            } elsif ($init) {
                my $k = extended_keypress($event);
                if ($k) {
                    if ($k eq SDLK_ESCAPE()) {
                        return 0;

                    } elsif ($k eq SDLK_DOWN()) {
                        if (@sorted_servers) {
                            each_index {
                                if ($sorted_servers[$::i]->{selected}
                                    && $::i < @sorted_servers - 1
                                    && !$sorted_servers[$::i+1]->{disabled}) {
                                    $sorted_servers[$::i]->{selected} = 0;
                                    $sorted_servers[$::i+1]->{selected} = 1;
                                    $offset++ if $::i + 1 >= $offset + $max_lines;
                                    play_sound('menu_change');
                                    goto done;
                                }
                            } @sorted_servers;
                          done:
                        }

                    } elsif ($k eq SDLK_UP()) {
                        if (@sorted_servers && !$sorted_servers[0]->{selected}) {
                            each_index {
                                if ($sorted_servers[$::i]->{selected}) {
                                    $sorted_servers[$::i]->{selected} = 0;
                                    $sorted_servers[$::i-1]->{selected} = 1;
                                    $offset = $::i - 1 if $::i - 1 < $offset;
                                    play_sound('menu_change');
                                }
                            } @sorted_servers;
                        }

                    } elsif ($k eq SDLK_RETURN() || $k eq SDLK_KP_ENTER()) {
                        play_sound('menu_selected');
                        goto ok_smg_choose_server;

                    } else {
                        handle_whenever_events($k);
                    }
                }
                $redraw->();
            }
        }
        Games::FrozenBubble::CStuff::fbdelay($TARGET_ANIM_SPEED) if $init;
    }

    if (@servers == 0 || every { $_->{disabled} } @servers) {
        smg_add_status_msg(loc("*** No available game server"),
                           loc("*** Please retry later or try a local network game (lan game)"));
        grab_key();
        return 0;
    }

  ok_smg_choose_server:
    foreach my $server (@servers) {
        if ($server->{selected}) {
            Games::FrozenBubble::Net::connect($server);
            if (!Games::FrozenBubble::Net::isconnected()) {
                smg_add_status_msg(loc("*** Impossible to connect to specified server, going back to server list"));
                $server->{selected} = 0;
                return smg_choose_server(@servers);
            }
            smg_add_status_msg(loc("*** Connected to server '%s'", $server->{name}));
            print "Notice! next time you start Frozen-Bubble, you may add the commandline parameter\n".
                  "        -gs $server->{host}:$server->{port} to automatically select this game server\n".
                  "        and save time not listing all available servers\n";
            last;
        }
    }

    my $y = $smg_starty;
    foreach (@servers) {
        erase_line($y, $imgbin{back_netgame});
        $y += $smg_lineheight + 2;
    }

    return 1;
}

sub smg_verify_command($;$) {
    my ($command, $rest) = @_;
    my $answer;
    eval {
        $answer = Games::FrozenBubble::Net::send_and_receive($command, $rest);
    };
    if ($@) {
        smg_add_status_msg(loc("*** Sorry, your computer or the network is too slow, giving up - press any key"));
        SDL::Video::update_rect($app, 0, 0, 0, 0);
        SDL::Events::pump_events() while SDL::Events::poll_event($event) != 0;
        grab_key();
        die 'quit';
    }
    if ($answer ne 'OK') {
        return $answer;
    } else {
        return;
    }
}

our (@entry_typed, $entry_position, $entry_echo_blink_counter);
sub callback_entry {
    my ($action, $params, @rest) = @_;
    if ($action eq 'reset') {
        @entry_typed = ();
        $entry_position = 0;
        $entry_echo_blink_counter = 51;
    }
    if ($action eq 'moved') {
        $entry_echo_blink_counter = 75;
    }
    if ($action eq 'keypressed') {
        if ($params->{event}->key_sym == SDLK_BACKSPACE()) {
            if ($entry_position >= 1) {
                splice @entry_typed, $entry_position - 1, 1;
                $entry_position--;
                $no_echo or play_sound('typewriter');
            } else {
                play_sound('stick');
            }
        } elsif ($params->{event}->key_sym == SDLK_DELETE()) {
            if ($entry_position < $#entry_typed + 1) {
                splice @entry_typed, $entry_position, 1;
                $no_echo or play_sound('typewriter');
            } else {
                play_sound('stick');
            }
        } elsif ($params->{event}->key_sym == SDLK_LEFT()) {
            if ($entry_position >= 1) {
                $entry_position--;
                $no_echo or play_sound('typewriter');
            } else {
                play_sound('stick');
            }
        } elsif ($params->{event}->key_sym == SDLK_RIGHT()) {
            if ($entry_position <= $#entry_typed) {
                $entry_position++;
                $no_echo or play_sound('typewriter');
            } else {
                play_sound('stick');
            }
        } elsif ($params->{event}->key_sym == SDLK_HOME()) {
            $entry_position = 0;
            $no_echo or play_sound('typewriter');
        } elsif ($params->{event}->key_sym == SDLK_END()) {
            $entry_position = $#entry_typed + 1;
            $no_echo or play_sound('typewriter');
        } elsif ($params->{event}->key_sym == SDLK_TAB()) {
            if (my $completion = $params->{completion}) {
                @entry_typed = $completion->(@entry_typed);
                $entry_position = $#entry_typed + 1;
            }
        } else {
            my $utf8char = Games::FrozenBubble::CStuff::utf8key($params->{event});
            if ($utf8char ne '' && $utf8char ne "\n" && $utf8char ne "\r") {
                splice @entry_typed, $entry_position, 0, $utf8char;
                if (width($params->{font}, $params->{prefix} . join('', @entry_typed)) >= $params->{maxlen}) {
                    splice @entry_typed, $entry_position, 1;
                    play_sound('stick');
                } else {
                    $entry_position++;
                    $no_echo or play_sound('typewriter');
                }
            } else {
                handle_whenever_events($params->{event}->key_sym);
            }
        }
    }
    if ($action eq 'gettext') {
        return @entry_typed;
    }
    if ($action eq 'settext') {
        @entry_typed = ($params, @rest);
        $entry_position = $#entry_typed + 1;
        $entry_echo_blink_counter = 51;
        $no_echo or play_sound('typewriter');
    }
    if ($action eq 'print') {
        $params->{maxlen} or die("need maxlen\n".backtrace());
        print_($params->{font}, $app, $params->{xpos}, $params->{ypos}, $params->{prefix} . join('', @entry_typed), $params->{maxlen});
        if ($entry_echo_blink_counter > 25) {
            my @before_echo = @entry_typed;
            splice @before_echo, $entry_position;
            my $width = width($params->{font}, $params->{prefix} . join('', @before_echo)) + ( $is_rtl ? 3 : -3 );
            if ($is_rtl) {
                print_($params->{font}, $app, $params->{xpos} + $params->{maxlen} - $width, $params->{ypos}, '|');
            } else {
                print_($params->{font}, $app, $params->{xpos} + $width, $params->{ypos}, '|');
            }
        }
    }
    if ($action eq 'ping') {
        $entry_echo_blink_counter--;
        $entry_echo_blink_counter or $entry_echo_blink_counter = 50;
        return $entry_echo_blink_counter == 50 || $entry_echo_blink_counter == 25;
    }
}

sub get_spot_location {
    my ($latitude, $longitude) = @_;
    my $x0 = 309;
    my $y0 = 231;
    my $longitude_factor = 1.424;
    my $latitude_factor = -145;
    return ($x0 + $longitude*$longitude_factor,
            $y0 + asinh(tan($latitude*1.4*$PI/360))*$latitude_factor);  #- map seems not to really be mercator but.. approximation is kinda ok
}

sub save_back_spot {
    my ($latitude, $longitude, $surface, $back_ref) = @_;
    my ($x, $y) = get_spot_location($latitude, $longitude);
    $x -= $surface->w/2;
    $y -= $surface->h/2;
    $$back_ref = SDL::Surface->new(20, 20, 32);
    SDL::Video::blit_surface($app, SDL::Rect->new($x, $y, 20, 20), $$back_ref, SDL::Rect->new(0,0,$$back_ref->w,$$back_ref->h));
    add_default_rect($$back_ref);
}
sub print_spot {
    my ($latitude, $longitude, $kind, $surface, $back) = @_;
    $surface ||= $imgbin{"netspot_$kind"};
    my ($x, $y) = get_spot_location($latitude, $longitude);
    $x -= $surface->w/2;
    $y -= $surface->h/2;
    if ($back) {
        put_image($$back, $x, $y);
        pop @update_rects;
    }
    put_image($surface, $x, $y);
}

sub is_only_ascii {
    my ($text) = @_;
    foreach (unpack("C*", $text)) {
        $_ > 127 and return 0;
    }
    return 1;
}

sub smg_choose_game() {
    my @actions = ({ name => loc("Chat"), action => 'CHAT', selected => 1 },
                   { name => loc("Create new game"), action => 'CREATE' });
    my $max_actions = 18;

    my $curaction = sub {
        my $cur;
        each_index {
            if ($actions[$::i]->{selected}) {
                $cur = $::i;
                goto curaction_done;
            }
        } @actions;
      curaction_done:
        return $actions[$cur];
    };

    my $state = 'game_select';

    my $erase = sub {
        my $drect = SDL::Rect->new(0, 0, 640, $smg_starty_players);
        SDL::Video::blit_surface($imgbin{back_netgame}, $drect, $app, $drect);
    };
    callback_entry('reset');
    my @wholist;
    my (@free_geolocs, @playing_geolocs);
    my $index_selfspot = 0;
    my $back_selfspot;
    my $free_players;
    my $ingame = 0;
    my $players_in_game = '';
    my $label_outer_color = SDL::Video::map_RGB( $app->format, 0x7b,  0x2f,  0x03); #Map the color to app format
    my $label_background_color = SDL::Video::map_RGB( $app->format,  0x5b,  0x1f,  0x09); #Map the color to app format
    my $label_line_color = SDL::Color->new( 0x9b,  0x3f,  0x03); #this is sent to line color in CStuff.xs SDL::Color expected
    my $redraw = sub {
        $erase->();

        #- geoloc spots - playing: spots only
        my @rectangles = ();
        foreach (@playing_geolocs) {
            my ($x, $y) = get_spot_location($_->[0], $_->[1]);
            print_spot($_->[0], $_->[1], 'playing');
            push @rectangles, SDL::Rect->new($x - $imgbin{"netspot_free"}->w/2,
                                             $y - $imgbin{"netspot_free"}->h/2,
                                             $imgbin{"netspot_free"}->w,
                                             $imgbin{"netspot_free"}->h);
        }

        #- geoloc spots - free: spots and labels (nicks)
        #- first show spots, we don't want to move them (but we will want to move labels)
        foreach (@free_geolocs) {
            @$_ or next;
            my ($x, $y) = get_spot_location($_->[0], $_->[1]);
	     print_spot($_->[0], $_->[1], $ingame ? 'insamegame' : 'free');
            push @rectangles, SDL::Rect->new($x - $imgbin{"netspot_free"}->w/2,
                                             $y - $imgbin{"netspot_free"}->h/2,
                                             $imgbin{"netspot_free"}->w,
                                             $imgbin{"netspot_free"}->h);
        }
        #- second show labels, managing overlap
        my @labels = ();
        my $linecolor = SDL::Color->new( 0x7b,  0x2f,  0x03);
        mapn {
            if (@{$_[1]}) {
                my ($xspot, $yspot) = get_spot_location($_[1][0], $_[1][1]);
                my ($xc, $yc, $sizing, $wb, $hb, $xoffset, $yoffset, $yoffset_retry);
                my $text = $_[0];
                my $index_positions = 0;
                #- set $x/$y as the next position to try; try positions around, then grow circle of 8 pixels
                my $set_next_position = sub {
                    my $positions = 16;
                    my $grows = int($index_positions / $positions);
                    my $angle = ($index_positions - $grows*$positions) * 2 * $PI / $positions;
                    $xc = $xspot + cos($angle) * ($wb/2 + 4 + ($grows + 1) * 8);
                    $yc = $yspot + sin($angle) * ($hb/2 + 4 + ($grows + 1) * 8);
                    $index_positions++;
                };
                #- find sizing of text
                print_('netdialogs_servermsg', $app, 0, 0, $text, undef, undef, #- coordinates are unimportant, we'll cancel this printing
                       sub {
                           my ($action, $textsurface) = @_;
                           $sizing = Games::FrozenBubble::CStuff::autopseudocrop($textsurface);
                           $wb = $sizing->[2] + 6;
                           $hb = $sizing->[3] + 6;
                           return 0;
                       });
                my $xb;
                my $yb;
                my $r;
                $set_next_position->();
              find_ok_position:
                while (1) {
                    $xb = $xc - $wb/2;
                    $yb = $yc - $hb/2;
                    #- check that background rectangle does not overlap any existing rectangle (spots or other labels)
                    $r = SDL::Rect->new($xb, $yb, $wb, $hb);
                    foreach my $rect (@rectangles) {
                        if ($rect->x >= $xb && $wb > $rect->x - $xb
                            || $xb >= $rect->x && $rect->w > $xb - $rect->x) {
                            #- x overlap
                            if ($rect->y >= $yb && $hb > $rect->y - $yb
                                || $yb >= $rect->y && $rect->h > $yb - $rect->y) {
                                $set_next_position->();
                                while ($xb < 20 || $xb + $wb > 620 || $yb < 20 || $yb + $hb > 320) {
                                    $set_next_position->();
                                    if ($index_positions > 100) {
                                        #- abandon, map is crowded
                                        return;
                                    }
                                }
                                if ($index_positions > 100) {
                                    #- abandon, map is crowded
                                    return;
                                }
                                next find_ok_position;
                            }
                        }
                    }
                    last;
                }
                #- draw a line between the spot and the center of the label
                Games::FrozenBubble::CStuff::draw_line($app, $xspot, $yspot, $xc, $yc, $label_line_color);
                #- draw the label background and the label in another pass to handle overwriting of labels over lines
                push @labels, { x => $xc - $sizing->[2]/2 - $sizing->[0], y => $yc - $sizing->[3]/2 - $sizing->[1], text => $text, backrect1 => $r,
                                backrect2 => SDL::Rect->new($xb + 1, $yb + 1, $wb - 2, $hb - 2) };
                push @rectangles, $r;
            }
        } \@wholist, \@free_geolocs;

        foreach (@labels) {
                SDL::Video::fill_rect($app, $_->{backrect1}, $label_outer_color);
                SDL::Video::fill_rect($app, $_->{backrect2}, $label_background_color);
            print_('netdialogs_servermsg', $app, $_->{x}, $_->{y}, $_->{text});
        }

        #- actions (chat, joins, create)
        my $y = $smg_starty;
        foreach my $action (@actions) {
            if ($action->{selected}) {
                put_image($imgbin{highlight_server}, 6, $y-1);
            }
            print_($action->{readonly} ? 'netdialogs_servermsg' : 'netdialogs', $app, $smg_startx, $y, $action->{name}, 520);
            $y += $smg_lineheight;
        }

        #- selfspot will need to properly erase selection overlay
        if ($mylatitude && !$private) {
            save_back_spot($mylatitude, $mylongitude, $imgbin{netspot_self}[0], \$back_selfspot);
            if ($index_selfspot >= 0) {
                print_spot($mylatitude, $mylongitude, 'free', $imgbin{netspot_self}[$index_selfspot], \$back_selfspot);
            }
        }

        #- chat entry
        erase_line($smg_starty_chat, $imgbin{back_netgame});
        if ($curaction->() && $curaction->()->{action} eq 'CHAT') {
            callback_entry('print', { xpos => $smg_startx, ypos => $smg_starty_chat, maxlen => 520, prefix => loc("Say: "), font => 'netdialogs' });
        }

        #- available players in server, or list of players in game
        erase_line($smg_starty_players, $imgbin{back_netgame});
        if ($ingame) {
            print_('netdialogs', $app, $smg_startx, $smg_starty_players, loc("Players in game: %s", $players_in_game), 520);
        } else {
            print_('netdialogs', $app, $smg_startx, $smg_starty_players, loc("Available Players: %s", i18n_number($free_players)), 520);
        }

        #- status messages
        smg_printstatus();
    };
    my $print_selfspot = sub {
        if ($mylatitude && !$private) {
            $index_selfspot >= 0 and print_spot($mylatitude, $mylongitude, 'free', $imgbin{netspot_self}[$index_selfspot], \$back_selfspot);
            $index_selfspot++;
            if ($index_selfspot == @{$imgbin{netspot_self}}) {
                my ($x, $y) = get_spot_location($mylatitude, $mylongitude);
                put_image($back_selfspot, $x - 10, $y - 10);
                $index_selfspot = -15;
            }
        }
    };

    my $myoldnick;
    my $list = sub {
        my ($firsttime) = @_;
        $state eq 'game_select' or return;
        my @games;
        my @old_wholist = @wholist;
        eval {
            ($free_players, undef, my $freenicks, undef, my $playing_geolocs, @games) = Games::FrozenBubble::Net::list();
            @wholist = ();
            @free_geolocs = ();
            @playing_geolocs = ();
            foreach (split ',', $freenicks) {
                my ($nick, undef, $latitude, $longitude) = $_ =~ /([^:]+)(:([^:]+):([^:]+))?/;
                push @wholist, $nick;
                if (defined($latitude) && $latitude =~ /^-?\d+\.?\d*$/ && $longitude =~ /^-?\d+\.?\d*$/) {
                    push @free_geolocs, [ $latitude, $longitude ];
                } else {
                    push @free_geolocs, [];
                }
            }
            foreach (split ',', $playing_geolocs) {
                my ($latitude, $longitude) = $_ =~ /([^:]+):([^:]+)/;
                $latitude =~ /^-?\d+\.?\d*$/ && $longitude =~ /^-?\d+\.?\d*$/ and push @playing_geolocs, [ $latitude, $longitude ];
            }
        };
        $@ and return;

        if (!$firsttime) {
            my @joined = difference2([ sort(difference2(\@wholist, \@old_wholist)) ], [ $mynick ]);
            my @left = difference2([ sort(difference2(\@old_wholist, \@wholist)) ], [ $myoldnick ]);
            if (@left == 1) {
                smg_add_status_msg(loc("*** %s has left the chat room", @left));
            } else {
                my $send = loc("*** Several players left this chat room: ");
                while (@left) {
                    $send .= shift @left;
                    if (!@left || width('netdialogs', $send) >= 520) {
                        smg_add_status_msg($send);
                        $send = '*** ';
                    } else {
                        $send .= ',';
                    }
                }
            }
            if (@joined == 1) {
                smg_add_status_msg(loc("*** %s has joined the chat room", @joined));
            } else {
                my $send = loc("*** Several players joined this chat room: ");
                while (@joined) {
                    $send .= shift @joined;
                    if (!@joined || width('netdialogs', $send) >= 520) {
                        smg_add_status_msg($send);
                        $send = '*** ';
                    } else {
                        $send .= ',';
                    }
                }
            }
        }

        my ($join, $rest) = partition { $_->{action} eq 'JOIN' } @actions;
        $_->{ok} = 0 foreach @$join;
      listgames:
        foreach my $players (@games) {
            if (@$players < 5 && $players->[0] ne $forget_because_kicked) {
                my $name = loc("Join game: %s", join(', ', @$players));
                foreach my $line (@$join) {
                    if ($line->{name} eq $name) {
                        $line->{ok} = 1;
                        next listgames;
                    }
                }
                push @$join, { name => $name, action => 'JOIN', join => $players->[0], ok => 1 };
            }
        }
        @actions = (@$rest, grep { $_->{ok} } @$join);
        if (!any { $_->{selected} } @actions) {
            $actions[0]{selected} = 1;
        }
        $redraw->();
    };

    my $list_players = sub {
        if (@wholist > 1) {
            my @list = sort @wholist;
            my $send = loc("*** Players listening: ");
            while (@list) {
                $send .= shift @list;
                if (!@list || width('netdialogs', $send) >= 520) {
                    smg_add_status_msg($send);
                    $send = '*** ';
                } else {
                    $send .= ',';
                }
            }
        } else {
            smg_add_status_msg(loc("*** Notice: no one's listening here"));
        }
    };

    Games::FrozenBubble::Net::send_and_receive('NICK', $mynick);

    my $geolocate = sub {
        smg_add_status_msg(loc("*** Please wait, retrieving your geographical location from http://hostip.info/..."));
        eval {
            local $SIG{ALRM} = sub { die "alarm\n" };
            alarm 5;
            my $data = Games::FrozenBubble::Net::http_download('http://api.hostip.info/get_html.php?position=true');
            ($mylatitude) = $data =~ /Latitude: (-?\S{1,5})/;
            ($mylongitude) = $data =~ /Longitude: (-?\S{1,5})/;
            if (defined($mylatitude)) {
                smg_add_status_msg(loc("*** Done, you are positioned as the flashing red dot!"));
            } else {
                smg_add_status_msg(loc("*** hostip.info doesn't know the geographical location of your IP address"));
                smg_add_status_msg(loc("*** If you want that your location appears on the map, fix your entry at http://hostip.info/"));
                smg_add_status_msg(loc("*** Then type /geolocate to see yourself on the map"));
                $mylatitude = '';
            }
            alarm 0;
        };
        if ($@) {
            if ($@ =~ /^alarm/) {
                smg_add_status_msg(loc("*** hostip.info didn't reply within 5 seconds, giving up"));
            }
            $mylatitude = '';
        }
        if ($mylatitude) {
            Games::FrozenBubble::Net::send_and_receive('GEOLOC', "$mylatitude:$mylongitude");
        } else {
            Games::FrozenBubble::Net::send_and_receive('GEOLOC', "");
        }
    };

    if ($pdata{gametype} eq 'net' && !$private) {
        if (!defined($mylatitude)) {
            $geolocate->();
        } else {
            Games::FrozenBubble::Net::send_and_receive('GEOLOC', "$mylatitude:$mylongitude");
        }
    }
    smg_add_status_msg(loc("*** You may now create or join a game"));

    my $need4update;
    my $relist;
    my $can_start = 0;
    my $joined_leader;
    my $chain_reaction_state = loc("enabled");
    my $continue_game_when_players_leave_state = loc("enabled");
    my $single_player_targetting_state = loc("enabled");
    my @victories_limits = ({ value => undef,
                              text => loc("none (unlimited)") },
                            map { { value => $_,
                                    text => i18n_number($_) } } (1..12, 15, 20, 30, 50, 100));
    my $victories_limit_index = 5;
    my @history;
    my $history_position;
    $list->('first time');
    $list_players->();

    my $setoptions = sub {
        my $level = Games::FrozenBubble::Net::send_and_receive('PROTOCOL_LEVEL');
        if ($level < 2) {  #- continue game when players leave available from minor level 2 onwards
            smg_verify_command('SETOPTIONS', 'CHAINREACTION:' . to_bool($chain_reaction_state eq loc("enabled")) . ','
                                           . "VICTORIESLIMIT:$victories_limits[$victories_limit_index]{value}");
        } else {
            smg_verify_command('SETOPTIONS', 'CHAINREACTION:' . to_bool($chain_reaction_state eq loc("enabled")) . ','
                                           . 'CONTINUEGAMEWHENPLAYERSLEAVE:' . to_bool($continue_game_when_players_leave_state eq loc("enabled")) . ','
                                           . 'SINGLEPLAYERTARGETTING:' . to_bool($single_player_targetting_state eq loc("enabled")) . ','
                                           . "VICTORIESLIMIT:$victories_limits[$victories_limit_index]{value}");
        }
    };

    my $toggle_chain_reaction = sub {
        if ($chain_reaction_state eq loc("disabled")) {
            my $level = Games::FrozenBubble::Net::send_and_receive('PROTOCOL_LEVEL');
            if ($level < 1) {  #- available from minor level 1 onwards
                smg_add_status_msg(loc("*** Cannot modify this option, as a player is using a too old version of Frozen-Bubble"));
                play_sound('cancel');
            } else {
                $chain_reaction_state = loc("enabled");
                $actions[1]{name} = loc("Chain-reaction: %s", $chain_reaction_state);
                $redraw->();
                $setoptions->();
            }
        } else {
            $chain_reaction_state = loc("disabled");
            $actions[1]{name} = loc("Chain-reaction: %s", $chain_reaction_state);
            $redraw->();
            $setoptions->();
        }
    };

    my $toggle_continue_game_when_players_leave = sub {
        if ($continue_game_when_players_leave_state eq loc("disabled")) {
            my $level = Games::FrozenBubble::Net::send_and_receive('PROTOCOL_LEVEL');
            if ($level < 2) {  #- available from minor level 2 onwards
                smg_add_status_msg(loc("*** Cannot modify this option, as a player is using a too old version of Frozen-Bubble"));
                play_sound('cancel');
            } else {
                $continue_game_when_players_leave_state = loc("enabled");
                $actions[2]{name} = loc("Continue game when players leave: %s", $continue_game_when_players_leave_state);
                $redraw->();
                $setoptions->();
            }
        } else {
            $continue_game_when_players_leave_state = loc("disabled");
            $actions[2]{name} = loc("Continue game when players leave: %s", $continue_game_when_players_leave_state);
            $redraw->();
            $setoptions->();
        }
    };

    my $toggle_single_player_targetting = sub {
        if ($single_player_targetting_state eq loc("enabled")) {
            my $level = Games::FrozenBubble::Net::send_and_receive('PROTOCOL_LEVEL');
            if ($level < 2) {  #- available from minor level 2 onwards
                smg_add_status_msg(loc("*** Cannot modify this option, as a player is using a too old version of Frozen-Bubble"));
                play_sound('cancel');
            } else {
                $single_player_targetting_state = loc("disabled");
                $actions[3]{name} = loc("Single player targetting: %s", $single_player_targetting_state);
                $redraw->();
                $setoptions->();
            }
        } else {
            $single_player_targetting_state = loc("enabled");
            $actions[3]{name} = loc("Single player targetting: %s", $single_player_targetting_state);
            $redraw->();
            $setoptions->();
        }
    };

    my $change_victories_limit = sub {
        my ($action) = @_;
        my $level = Games::FrozenBubble::Net::send_and_receive('PROTOCOL_LEVEL');
        if ($level < 1) {  #- available from minor level 1 onwards
            smg_add_status_msg(loc("*** Cannot modify this option, as a player is using a too old version of Frozen-Bubble"));
            play_sound('cancel');
        } else {
            if ($action eq 'inc') {
                $victories_limit_index++;
                $victories_limit_index == @victories_limits and $victories_limit_index = 0;
            } elsif ($action eq 'dec') {
                $victories_limit_index--;
                $victories_limit_index == -1 and $victories_limit_index = @victories_limits - 1;
            } else {
                for (my $i = 0; $i < @victories_limits; $i++) {
                    if ((!$action && !$victories_limits[$i]{value})
                        || ($action && $victories_limits[$i]{value} && $victories_limits[$i]{value} eq $action)) {
                        $victories_limit_index = $i;
                    }
                }
            }
            $actions[4]{name} = loc("Victories limit: %s", $victories_limits[$victories_limit_index]{text});
            $redraw->();
            $setoptions->();
        }
    };

    my $kick = sub {
        my ($kicked) = @_;
        my $answer = smg_verify_command('KICK', $kicked);
        if ($answer eq 'NO_SUCH_PLAYER') {
            smg_add_status_msg(loc("*** Can't kick %s: no such player in game", $kicked));
        } elsif ($answer) {
            smg_add_status_msg(loc("*** Can't kick %s: '%s'", $kicked, $answer));
        }
    };

    while (1) {
        $relist++;
        $relist % (5*(1000/$TARGET_ANIM_SPEED)) == 0 and $list->();
        if (callback_entry('ping')) {
            $redraw->();
        } else {
            if ($relist % 3 == 0) {
                $print_selfspot->();
                SDL::Video::update_rects($app, @update_rects);
                @update_rects = ();
            }
        }

        my $need_redraw;
        SDL::Events::pump_events();
        while (SDL::Events::poll_event($event) != 0) {
            if ($event->type == SDL_QUIT) {
                cleanup_and_exit();
            }
            my $k;
            if ($event->type == SDL_KEYDOWN) {
                $k = $event->key_sym;
            } elsif ($curaction->()->{action} ne 'CHAT' && ($event->type == SDL_JOYAXISMOTION || $event->type() == SDL_JOYBUTTONDOWN)) {
                $k = translate_joystick_tokey($event);
            }
            if ($k) {
                if ($k eq SDLK_ESCAPE()) {
                    if ($ingame) {
                        smg_add_status_msg(loc("*** Leaving game..."));
                        Games::FrozenBubble::Net::reconnect();
                        return smg_choose_game();
                    } else {
                        Games::FrozenBubble::Net::disconnect();
                        $erase->();
                        return 0;
                    }

                } elsif ($k eq SDLK_PAGEUP()) {
                    $smg_status_message_offsetpage += 4;
                    $smg_status_message_offsetpage >= @smg_status_messages - $smg_max_messages and $smg_status_message_offsetpage = @smg_status_messages - $smg_max_messages + 1;
                    $smg_status_message_offsetpage < 1 and $smg_status_message_offsetpage = 1;
                    $redraw->();

                } elsif ($k eq SDLK_PAGEDOWN()) {
                    $smg_status_message_offsetpage -= 4;
                    $smg_status_message_offsetpage < 1 and $smg_status_message_offsetpage = 1;
                    $redraw->();

                } elsif ($k eq SDLK_DOWN()) {
                    if ($curaction->()->{action} eq 'CHAT' && $history_position <= $#history) {
                        $history_position++;
                        if ($history_position > $#history) {
                            callback_entry('reset');
                        } else {
                            callback_entry('settext', @{$history[$history_position]});
                        }
                    } else {
                        each_index {
                            if ($actions[$::i]{selected}
                                && $::i < @actions - 1
                                && ! $actions[$::i+1]{readonly}) {
                                $actions[$::i]{selected} = 0;
                                $actions[$::i+1]{selected} = 1;
                                play_sound('menu_change');
                                goto done2;
                            }
                        } @actions;
                      done2:
                    }

                } elsif ($k eq SDLK_UP()) {
                    if ($curaction->()->{action} eq 'CHAT') {
                        $history_position--;
                        if ($history_position == -1) {
                            $history_position = 0;
                        } else {
                            callback_entry('settext', @{$history[$history_position]});
                        }
                    } else {
                        if (!$actions[0]->{selected}) {
                            each_index {
                                if ($actions[$::i]->{selected}) {
                                    $actions[$::i]->{selected} = 0;
                                    $actions[$::i-1]->{selected} = 1;
                                    play_sound('menu_change');
                                }
                            } @actions;
                        }
                    }

                } elsif ($k eq SDLK_RETURN() || $k eq SDLK_KP_ENTER()) {
                    if ($curaction->()->{action} eq 'CHAT' && callback_entry('gettext') > 0) {
                        play_sound('menu_selected');
                        my $text = join('', callback_entry('gettext'));
                        push @history, [ callback_entry('gettext') ];
                        $history_position = $#history + 1;
                        if ($text =~ m|^/me (.*)| || $text =~ m|^/action (.*)|) {
                            $text = "* $mynick $1";
                        } elsif ($text =~ m|^/nick (.*)| && !$ingame) {
                            my $save_mynick = $mynick;
                            $mynick = sanitize_nick($1);
                            if ($mynick) {
                                smg_add_status_msg(loc("*** You are now known as %s", $mynick));
                                Games::FrozenBubble::Net::send_and_receive('NICK', $mynick);
                                $myoldnick = $save_mynick;
                            } else {
                                smg_add_status_msg(loc("*** Erroneous nickname"));
                                $mynick = $save_mynick;
                            }
                            $text = undef;
                        } elsif ($text =~ m|^/list| && !$ingame) {
                            $list_players->();
                            $text = undef;
                        } elsif ($text =~ m|^/server|) {
                            my $servername = Games::FrozenBubble::Net::current_server_name();
                            $servername or $servername = Games::FrozenBubble::Net::current_server_hostport();
                            smg_add_status_msg(loc("*** You're connected to server '%s'", $servername));
                            $text = undef;
                        } elsif ($text =~ m|^/fs|) {
                            $fullscreen = !$fullscreen;
                                                        SDL::Video::wm_toggle_fullscreen($app);
                            $text = undef;
                        } elsif ($text =~ m|^/geolocate|) {
                            $geolocate->();
                            $text = undef;
                        } elsif ($text =~ m|^/kick (\S+)(?: (.+))?| && $can_start) {
                            my $kicked = $1;
                            $2 and Games::FrozenBubble::Net::send_("TALK $kicked <-- $2");
                            if ($kicked eq $mynick) {
                                my $rand = int(rand(3));
                                $rand == 0 and smg_add_status_msg(loc("*** Sado-masochist, hmm?"));
                                $rand == 1 and smg_add_status_msg(loc("*** You like when it hurts, don't you?"));
                                $rand == 2 and smg_add_status_msg(loc("*** Your butt already hurts enough! Stop that!"));
                            } else {
                                $kick->($kicked);
                            }
                            $text = undef;
                        } elsif ($text =~ m|^/autokick (\S+)(?: (.+))?|) {
                            my $kicked = $1;
                            my $message = $2;
                            if ($kicked eq $mynick) {
                                my $rand = int(rand(3));
                                $rand == 0 and smg_add_status_msg(loc("*** Sado-masochist, hmm?"));
                                $rand == 1 and smg_add_status_msg(loc("*** You like when it hurts, don't you?"));
                                $rand == 2 and smg_add_status_msg(loc("*** Your butt already hurts enough! Stop that!"));
                            } else {
                                my $found = 0;
                                if (!$message && exists $autokick{$kicked}) {
                                    delete($autokick{$kicked});
                                    smg_add_status_msg(loc("*** Removing %s from autokick list.", $kicked));
                                } else {
                                    smg_add_status_msg(loc("*** Adding %s to autokick list.", $kicked));
                                    $autokick{$kicked} = $message;
                                    if ($can_start && any { $_ eq $kicked } @wholist) {
                                        $message and Games::FrozenBubble::Net::send_("TALK $kicked <-- $message");
                                        $kick->($kicked);
                                    }
                                }
                            }
                            $text = undef;
                        } elsif ($text =~ m|^/autokick$|) {
                            if (!%autokick) {
                                smg_add_status_msg(loc("*** Nobody in autokick list."));
                            } else {
                                smg_add_status_msg(loc("*** Autokick list members: %s", join(", ", sort keys %autokick)));
                            }
                            $text = undef;
                        } elsif ($text =~ m|^/help|) {
                            smg_add_status_msg(loc("*** Available commands: %s",
                                                 join(', ', loc("%s <action>", '/me'), loc("%s <nick> [<text>]", '/autokick'), '/server')),
                                               '*** ' . join(', ', '/fs', '/geolocate',
                                                                   if_(!$ingame, loc("%s <new_nick>", '/nick'), '/list'),
                                                                   if_($can_start, loc("%s <nick> [<text>]", '/kick'))));
                            $text = undef;
                        } elsif ($text =~ m|^/|) {
                            smg_add_status_msg(loc("*** Unknown command. Try %s for help.", '/help'));
                            $text = undef;
                        } else {
                            #- for RTL language, force beginning on the right, but non RTL content will appear wrongly so at least don't do for pure ASCII
                            if ($is_rtl && !is_only_ascii($text)) {
                                $text = "\x{202b}<$mynick> $text";
                            } else {
                                $text = "<$mynick> $text";
                            }
                        }
                        if ($text) {
                            Games::FrozenBubble::Net::send_("TALK $text");
                            @wholist == 1 and smg_add_status_msg(loc("*** Notice: no one's listening here"));
                        }
                        callback_entry('reset');
                    }

                    if (member($curaction->()->{action}, 'CREATE', 'JOIN')) {
                        my $suffix = 1;
                        my $answer;
                        while (1) {
                            my $message = $curaction->()->{action} eq 'CREATE' ? $mynick
                                                                               : $curaction->()->{join}." $mynick";
                            $answer = smg_verify_command($curaction->()->{action}, $message);
                            if ($answer eq 'NICK_IN_USE') {
                                if ($suffix < 9) {
                                    $suffix++;
                                    $suffix > 2 and $mynick =~ s/.$//;  #- remove suffix added last loop
                                    $mynick = substr($mynick, 0, 9) . $suffix;
                                } else {
                                    #- try to find something that will be accepted, even if it sux
                                    $mynick = substr($mynick, 0, 7);
                                    my @chars = ('a' .. 'z', 'A' .. 'Z');
                                    $mynick .= $chars[rand(@chars)] foreach 1..3;
                                    $suffix = 1;
                                }
                            } elsif ($answer eq 'ALREADY_MAX_OPEN_GAMES') {
                                smg_add_status_msg(loc("*** Open games already full. Join an existing game, or select a different server."));
                                goto not_in_game;
                            } elsif ($curaction->()->{action} eq 'JOIN' && $answer eq 'NO_SUCH_GAME') {
                                smg_add_status_msg(loc("*** Cannot join game, game was just started or aborted"));
                                $list->();
                                goto not_in_game;
                            } elsif ($answer) {
                                smg_add_status_msg(loc("*** Failure: '%s'", $answer));
                                goto not_in_game;
                            } else {
                                if ($curaction->()->{action} eq 'CREATE') {
                                    $can_start = 1;
                                    @wholist = $mynick;
                                    smg_add_status_msg(loc("*** Game created - now you need to wait for players to join"));
                                } else {
                                    $joined_leader = $curaction->()->{join};
                                    smg_add_status_msg(loc("*** Joined game"));
                                }
                                $ingame = 1;
                                last;
                            }
                        }
                        $state = 'wait_for_start';
                        $need4update = 1;
                    }
                  not_in_game:

                    if ($curaction->()->{action} eq 'TOGGLE_CHAIN_REACTION') {
                        $toggle_chain_reaction->();
                    }

                    if ($curaction->()->{action} eq 'TOGGLE_CONTINUE_GAME_WHEN_PLAYERS_LEAVE') {
                        $toggle_continue_game_when_players_leave->();
                    }

                    if ($curaction->()->{action} eq 'TOGGLE_SINGLE_PLAYER_TARGETTING') {
                        $toggle_single_player_targetting->();
                    }

                    if ($curaction->()->{action} eq 'SWITCH_VICTORIES_LIMIT') {
                        $change_victories_limit->('inc');
                    }

                    if ($curaction->()->{action} eq 'START') {
                        my $close = smg_verify_command('CLOSE');
                        if ($close) {
                            smg_add_status_msg(loc("*** Can't start game: '%s'", $close));
                            Games::FrozenBubble::CStuff::fbdelay(2000);
                            return;
                        }
                        #- game is closed, need to check one last time if options are really possible
                        if ($chain_reaction_state eq loc("enabled")
                            || $victories_limit_index > 0
                            || $continue_game_when_players_leave_state eq loc("enabled")
                            || $single_player_targetting_state eq loc("disabled")) {
                            my $level = Games::FrozenBubble::Net::send_and_receive('PROTOCOL_LEVEL');
                            my $isdelay = 0;
                            if ($level < 1) {  #- chain reaction available from minor level 1 onwards
                                if ($chain_reaction_state eq loc("enabled")) {
                                    smg_add_status_msg(loc("*** Must disable chain-reaction, as a player is using a too old version of Frozen-Bubble"));
                                    $chain_reaction_state = loc("disabled");
                                    $isdelay = 1;
                                }
                                if ($victories_limit_index > 0) {
                                    smg_add_status_msg(loc("*** Must reset victories limit as a player is using a too old version of Frozen-Bubble"));
                                    $victories_limit_index = 0;
                                    $isdelay = 1;
                                }
                            }
                            if ($level < 2) {  #- continue game when players leave available from minor level 1 onwards
                                if ($continue_game_when_players_leave_state eq loc("enabled")) {
                                    smg_add_status_msg(loc("*** Cannot enable continue game when players leave, as a player is using an old version"));
                                    $continue_game_when_players_leave_state = loc("disabled");
                                    $isdelay = 1;
                                }
                                if ($single_player_targetting_state eq loc("disabled")) {
                                    smg_add_status_msg(loc("*** Cannot disable single player targetting, as a player is using an old version"));
                                    $single_player_targetting_state = loc("enabled");
                                    $isdelay = 1;
                                }
                            }
                            $isdelay and Games::FrozenBubble::CStuff::fbdelay(2000);
                        }
                        if ($setoptions->()) {
                            smg_add_status_msg(loc("*** Can't start game: '%s'", $setoptions));
                            Games::FrozenBubble::CStuff::fbdelay(2000);
                            return;
                        }
                        my $start = smg_verify_command('START');
                        if ($start) {
                            smg_add_status_msg(loc("*** Can't start game: '%s'", $start));
                            Games::FrozenBubble::CStuff::fbdelay(2000);
                            return;
                        }
                    }


                } elsif ($k eq SDLK_RIGHT() && $curaction->()->{action} ne 'CHAT') {
                    if ($curaction->()->{action} eq 'TOGGLE_CHAIN_REACTION') {
                        $toggle_chain_reaction->();
                    }
                    if ($curaction->()->{action} eq 'TOGGLE_CONTINUE_GAME_WHEN_PLAYERS_LEAVE') {
                        $toggle_continue_game_when_players_leave->();
                    }
                    if ($curaction->()->{action} eq 'TOGGLE_SINGLE_PLAYER_TARGETTING') {
                        $toggle_single_player_targetting->();
                    }
                    if ($curaction->()->{action} eq 'SWITCH_VICTORIES_LIMIT') {
                        $change_victories_limit->('inc');
                    }

                } elsif ($k eq SDLK_LEFT() && $curaction->()->{action} ne 'CHAT') {
                    if ($curaction->()->{action} eq 'TOGGLE_CHAIN_REACTION') {
                        $toggle_chain_reaction->();
                    }
                    if ($curaction->()->{action} eq 'TOGGLE_CONTINUE_GAME_WHEN_PLAYERS_LEAVE') {
                        $toggle_continue_game_when_players_leave->();
                    }
                    if ($curaction->()->{action} eq 'TOGGLE_SINGLE_PLAYER_TARGETTING') {
                        $toggle_single_player_targetting->();
                    }
                    if ($curaction->()->{action} eq 'SWITCH_VICTORIES_LIMIT') {
                        $change_victories_limit->('dec');
                    }

                } else {
                    if ($curaction->()->{action} eq 'CHAT') {
                        callback_entry('keypressed', { event => $event, maxlen => 480, font => 'netdialogs',
                                                       completion => sub {
                                                           my @typed = @_;
                                                           my $end;
                                                           while (1) {
                                                               last if !@typed;
                                                               my $c = pop @typed;
                                                               if ($c eq ' ') {
                                                                   $end or return @_;
                                                                   push @typed, $c;
                                                                   last;
                                                               }
                                                               $end = "$c$end";
                                                           }
                                                           my @matches = grep { lc(substr($_, 0, length($end))) eq lc($end) } @wholist;
                                                           if (@matches == 0) {
                                                               return @_;
                                                           } else {
                                                               my $colon = !@typed ? ': ' : ' ';
                                                               if (@matches == 1) {
                                                                   return @typed, split '', "$matches[0]$colon";
                                                               } else {
                                                                   my @chars = stringchars($matches[0]);
                                                                   my $counter = 0;
                                                                   while ($counter < @chars
                                                                          && every { (stringchars($_))[$counter] eq $chars[$counter] } @matches) {
                                                                       $counter++;
                                                                   }
                                                                   play_sound('stick');
                                                                   return @typed, split '', substr($matches[0], 0, $counter);
                                                               }
                                                           }
                                                       } });

                    } else {
                        if ($curaction->()->{action} eq 'SWITCH_VICTORIES_LIMIT') {
                            my $utf8char = Games::FrozenBubble::CStuff::utf8key($event);
                            $change_victories_limit->($utf8char) if defined $utf8char && $utf8char eq int($utf8char);
                        }

                        handle_whenever_events($k);
                    }
                }

                $need_redraw = 1;
            }
        }
        if ($need_redraw) {
            callback_entry('moved');
            $redraw->();
        }
        Games::FrozenBubble::CStuff::fbdelay($TARGET_ANIM_SPEED);

        while (my $msg = Games::FrozenBubble::Net::readline_ifdata()) {
            my ($command, $message) = Games::FrozenBubble::Net::decode_msg($msg);
            if ($command eq 'PUSH') {
                if ($message =~ /^TALK: (.*)/) {
                    my $message = $1;
                    my (undef, $min, $hour) = localtime();
                    smg_add_status_msg(sprintf("%02d:%02d ", $hour, $min) . $message);
                    play_sound('typewriter');
                } elsif ($message =~ /^JOINED: (.+)/) {
                    my $joined = $1;
                    smg_add_status_msg(loc("*** %s joined the game!", $joined));
                    if ($can_start && exists $autokick{$joined}) {
                        $autokick{$joined} and Games::FrozenBubble::Net::send_("TALK $joined <-- $autokick{$joined}");
                        $kick->($joined);
                    } else {
                        push @wholist, $joined;
                        play_sound('newroot_solo');
                        if ($can_start
                            && ($chain_reaction_state eq loc("enabled")
                                || $victories_limit_index > 0
                                || $continue_game_when_players_leave_state eq loc("enabled")
                                || $single_player_targetting_state eq loc("disabled"))) {
                            my $level = Games::FrozenBubble::Net::send_and_receive('PROTOCOL_LEVEL');
                            if ($level < 1) {  #- available from minor level 1 onwards
                                if ($chain_reaction_state eq loc("enabled")) {
                                    smg_add_status_msg(loc("*** Chain-reaction disabled, %s is using a too old version of Frozen-Bubble", $joined));
                                    $chain_reaction_state = loc("disabled");
                                }
                                if ($victories_limit_index > 0) {
                                    smg_add_status_msg(loc("*** Victories limit reset, %s is using a too old version of Frozen-Bubble", $joined));
                                    $victories_limit_index = 0;
                                }
                            }
                            if ($level < 2) {  #- available from minor level 2 onwards
                                if ($continue_game_when_players_leave_state eq loc("enabled")) {
                                    smg_add_status_msg(loc("*** Continue game when players leave disabled, %s has a too old version", $joined));
                                    $continue_game_when_players_leave_state = loc("disabled");
                                }
                                if ($single_player_targetting_state eq loc("disabled")) {
                                    smg_add_status_msg(loc("*** Single player targetting enabled, %s has a too old version", $joined));
                                    $single_player_targetting_state = loc("disabled");
                                }
                            }
                        }
                        $can_start and $setoptions->();  #- new joiner needs to get parameters anyway
                    }
                } elsif ($message =~ /^PARTED: (.+)/) {
                    if ($1 eq $joined_leader) {
                        smg_add_status_msg(loc("*** Game creator left the game..."));
                        play_sound('cancel');
                        Games::FrozenBubble::Net::reconnect();
                        return smg_choose_game();
                    } else {
                        smg_add_status_msg(loc("*** %s left the game...", $1));
                        @wholist = difference2(\@wholist, [ $1 ]);
                        play_sound('newroot_solo');
                    }
                } elsif ($message =~ /^KICKED: (.+)/) {
                    smg_add_status_msg(loc("*** %s was kicked out of the game...", $1));
                    @wholist = difference2(\@wholist, [ $1 ]);
                    play_sound('newroot_solo');
                } elsif ($message eq 'KICKED') {
                    $forget_because_kicked = $joined_leader;
                    smg_add_status_msg(loc("*** You were kicked out of the game..."));
                    play_sound('cancel');
                    Games::FrozenBubble::Net::reconnect();
                    return smg_choose_game();
                } elsif ($message eq 'NO_ACTIVITY_WITHIN_GRACETIME') {
                    smg_add_status_msg(loc("*** You were disconnected because of too long inactivity"));
                    play_sound('cancel');
                    Games::FrozenBubble::Net::reconnect();
                    return smg_choose_game();
                } elsif ($message =~ /^OPTIONS: (.*)/) {
                    my $options = $1;
                    while ($options =~ /([^,]+),?/g) {
                        my $option = $1;
                        if ($option =~ /^CHAINREACTION:(.)/) {
                            $chainreaction = $1;
                        } elsif ($option =~ /^CONTINUEGAMEWHENPLAYERSLEAVE:(.)/) {
                            $continuegamewhenplayersleave = $1;
                        } elsif ($option =~ /^SINGLEPLAYERTARGETTING:(.)/) {
                            $singleplayertargetting = $1;
                        } elsif ($option =~ /^VICTORIESLIMIT:(\d*)/) {
                            $pdata{scorelimit} = $1;
                        } elsif ($option =~ /^PROTOCOLLEVEL:(\d+)/) {
                            $pdata{protocollevel} = $1;
                            if ($pdata{protocollevel} < 2) {
                                $continuegamewhenplayersleave = 0;
                                $singleplayertargetting = 1;
                            }
                        } else {
                            print "Unrecognized option: $option\n";
                        }
                    }
                    play_sound('menu_selected');
                } elsif ($message =~ /^GAME_CAN_START: (.+)/) {
                    @PLAYERS = qw(p1);
                    my $msg = $1;
                    my @mappings;
                    while ($msg) {
                        my $id = substr($msg, 0, 1);
                        $msg = substr($msg, 1);
                        my ($nick, undef, $rest) = $msg =~ /([^,]+)(,(.*))?/;
                        $msg = $rest;
                        push @mappings, { id => $id, nick => $nick };
                    }
                    foreach (@ALL_PLAYERS) {
                        delete $pdata{$_}{id};
                        delete $pdata{$_}{nick};
                    }
                    %{$pdata{id2p}} = ();
                    foreach my $m (@mappings) {
                        my $player;
                        if ($m->{nick} eq $mynick) {
                            $player = 'p1';
                        } else {
                            foreach (@ALL_PLAYERS) {
                                /rp/ or next;
                                exists $pdata{$_}{id} or $player ||= $_;
                            }
                            push @PLAYERS, $player;
                        }
                        $pdata{$player}{id} = $m->{id};
                        $pdata{$player}{nick} = $m->{nick};
                        $pdata{id2p}{$m->{id}} = $player;
                    }
                    Games::FrozenBubble::Net::setmyid($pdata{p1}{id});
                    $pdata{$_}{score} = 0 foreach @PLAYERS;
                    #- leader must wait for all others being in prio mode before sending a prio message,
                    #- else first messages might not get properly received on the other end and startup fails.
                    if (is_leader()) {
                      leader_check_game_start:
                        my $can_start = smg_verify_command('LEADER_CHECK_GAME_START');
                        if ($can_start eq 'OTHERS_NOT_READY') {
                            Games::FrozenBubble::Net::sleep_reasonably();
                            goto leader_check_game_start;
                        } elsif ($can_start) {
                            smg_add_status_msg(loc("*** Failure: '%s'", $can_start));
                            play_sound('cancel');
                            Games::FrozenBubble::Net::reconnect();
                            return smg_choose_game();
                        }
                    }
                    smg_verify_command('OK_GAME_START');
                    return 1;
                } else {
                    print "unrecognized message received: $msg\n";
                }
                $need4update = 1;
            } else {
                print "non-push received!? $msg\n";
            }
        }

        if (!Games::FrozenBubble::Net::isconnected()) {
            smg_add_status_msg(loc("*** Lost connection to server, abandoning - press any key"));
            @actions = ();
            $redraw->();
            play_sound('cancel');
            SDL::Events::pump_events() while SDL::Events::poll_event($event) != 0;
            grab_key();
            $erase->();
            return 0;
        }

        if ($need4update) {
            if ($state ne 'game_select') {
                my $status = Games::FrozenBubble::Net::send_and_receive('STATUSGEO');
                @wholist = ();
                @free_geolocs = ();
                foreach (split ',', $status) {
                    my ($nick, undef, $latitude, $longitude) = $_ =~ /([^:]+)(:([^:]+):([^:]+))?/;
                    push @wholist, $nick;
                    if ($latitude && $latitude =~ /^-?\d+\.?\d*$/ && $longitude =~ /^-?\d+\.?\d*$/) {
                        push @free_geolocs, [ $latitude, $longitude ];
                    } else {
                        push @free_geolocs, [];
                    }
                }
                $players_in_game = join ', ', @wholist;
                my $selected;
                each_index { $actions[$::i]{selected} and $selected = $::i; } @actions;
                @actions = { name => loc("Chat"), action => 'CHAT' };
                if ($can_start) {
                    #- creator
                    push @actions, { name => loc("Chain-reaction: %s", $chain_reaction_state), action => 'TOGGLE_CHAIN_REACTION' };
                    push @actions, { name => loc("Continue game when players leave: %s", $continue_game_when_players_leave_state), action => 'TOGGLE_CONTINUE_GAME_WHEN_PLAYERS_LEAVE' };
                    push @actions, { name => loc("Single player targetting: %s", $single_player_targetting_state), action => 'TOGGLE_SINGLE_PLAYER_TARGETTING' };
                    push @actions, { name => loc("Victories limit: %s", $victories_limits[$victories_limit_index]{text}), action => 'SWITCH_VICTORIES_LIMIT' };
                    @wholist > 1 and push @actions, { name => loc("Start game!"), action => 'START' };
                } else {
                    #- joiner
                    push @actions, { name => loc("Chain-reaction: %s", $chainreaction ? loc("enabled") : loc("disabled")), readonly => 1};
                    push @actions, { name => loc("Continue game when players leave: %s", $continuegamewhenplayersleave ? loc("enabled") : loc("disabled")), readonly => 1 };
                    push @actions, { name => loc("Single player targetting: %s", $singleplayertargetting ? loc("enabled") : loc("disabled")), readonly => 1 };
                    push @actions, { name => loc("Victories limit: %s", $pdata{scorelimit} ? i18n_number($pdata{scorelimit}) : loc("none (unlimited)")), readonly => 1 };
                }
                $selected-- while $selected > $#actions || $actions[$selected]{readonly};
                $actions[$selected]{selected} = 1;
            }
            $redraw->();
            $need4update = 0;
        }
    }
}

sub show_mp_scores() {
    SDL::Video::blit_surface($imgbin{back_netgame}, $apprects{main}, $app, $apprects{main});

    if ($pdata{inconsistency}) {
        smg_add_status_msg(loc("*** Game finished, because an inconsistency in game state was detected - sorry!"));
    } elsif ($pdata{scorelimit} && any { $pdata{$_}{score} == $pdata{scorelimit} } @PLAYERS) {
        smg_add_status_msg(loc("*** Game finished, because victories limit of %s was reached.", i18n_number($pdata{scorelimit})));
    } else {
        if (!$continuegamewhenplayersleave && any { $pdata{$_}{left} } @PLAYERS) {
            smg_add_status_msg(loc("*** Game finished, because the following player(s) left: %s", join(', ', map { if_($pdata{$_}{left}, $pdata{$_}{nick}) } @PLAYERS)));
        }
    }
    smg_add_status_msg(loc("*** Addicted for: %s", format_addiction((SDL::get_ticks() - $time_netgame)/1000, 1)));
    @PLAYERS = reverse ssort { $pdata{$_}{score} } @PLAYERS;
    if ($pdata{$PLAYERS[0]}{score} > $pdata{$PLAYERS[1]}{score}) {
        smg_add_status_msg(loc("*** Winner: %s", $pdata{$PLAYERS[0]}{nick}));
    } else {
        smg_add_status_msg(loc("*** Draw game!"));
    }
    smg_add_status_msg(loc("*** Scores: %s", join(', ', map { sprintf("%s: %s", $pdata{$_}{nick}, i18n_number($pdata{$_}{score})) } @PLAYERS)));
}

sub setup_mp_game() {

    SDL::Video::blit_surface($imgbin{back_netgame}, $apprects{main}, $app, $apprects{main});

    if (!Games::FrozenBubble::Net::isconnected()) {
        @smg_status_messages = ();
        $smg_status_message_offsetpage = 1;
        if ($gameserver) {
            my ($host, $port) = $gameserver =~ /(\S+):(\S+)/;
            if (!$host) {
                $host = $gameserver;
                $port = 1511;
            }
            Games::FrozenBubble::Net::connect($host, $port);
            if (!Games::FrozenBubble::Net::isconnected()) {
                smg_add_status_msg(loc("*** Cannot connect to specified gameserver, fallbacking to contacting master server"));
                print STDERR "Cannot connect to specified gameserver, fallbacking to contacting master server\n";
                goto choose_server;
            }
        } else {
          choose_server:
            #- 1. get list of servers
            my $servers = smg_servers();
            defined $servers or return;

            #- 2. let user choose server
            smg_choose_server(@$servers) or return;
        }

    } else {
        show_mp_scores();
    }

    #- 3. let user choose/create game
    $forget_because_kicked = undef;
    smg_choose_game() or return;

    save_config();

    $time_netgame = SDL::get_ticks();
    return 1;
}

sub new_game_once {

    if ($direct_levelset) {
        load_levelset("$FBLEVELS/$direct_levelset");
        $direct_levelset = '';
    }
    if (!$direct) {
        if (is_1p_game()) {
            choose_1p_game_mode() or return;
        }
        if (is_2p_game() && $graphics_level > 1) {
            my $answ;
            ask_from({ intro => [ loc("2-player game"), '', '', loc("Enable chain-reaction?"), '' ],
                       entries => [ { 'q' => loc("%s or %s?", 'Y', 'N'), 'a' => \$answ, f => 'ONE_CHAR' } ],
                       outro => loc("Enjoy the game!") }) or return;
            $chainreaction = $answ == SDLK_y; #;;
        }
    }
    $pdata{$_}{left} = 0 foreach @ALL_PLAYERS;
    if (is_mp_game() && !$playdata) {
        SDL::Events::enable_key_repeat(200, 50);
        my $ok_game;
        eval {
            $ok_game = setup_mp_game();
        };
        my $failure = $@;
        SDL::Events::enable_key_repeat(0, 0);
        if ($failure && $failure ne 'quit') {
            die $failure;
        }
        $failure || !$ok_game and return;
    }
    play_music(is_1p_game() ? 'main1p' : 'main2p');
    return 1;
}

sub lvl_cmp($$) { $_[0] eq 'WON' ? ($_[1] eq 'WON' ? 0 : 1) : ($_[1] eq 'WON' ? -1 : $_[0] <=> $_[1]) }

sub ordered_highscores { return sort { lvl_cmp($b->{level}, $a->{level}) || $a->{time} <=> $b->{time} } @$HISCORES }
sub ordered_mptrain_highscores { return sort { $b->{score} <=> $a->{score} } @$HISCORES_MPTRAIN }
sub ordered_mptrain_highscores_chainreaction { return sort { $b->{score} <=> $a->{score} } @$HISCORES_MPTRAIN_CHAINREACTION }

sub handle_new_hiscores() {
    is_1p_game() && $levels{current} && $levels{current} ne 'random' && !$playdata or return;

    if ($levels{current} ne 'mp_train') {
        #- levels hiscores
        my @ordered = ordered_highscores();
        my $worst = pop @ordered;
        my $total_seconds = (SDL::get_ticks() - $time_1pgame)/1000;
        if (@$HISCORES == 10 && (lvl_cmp($levels{current}, $worst->{level}) == -1
                                 || lvl_cmp($levels{current}, $worst->{level}) == 0 && $total_seconds > $worst->{time})) {
            return;
        }
        play_sound('applause');
        append_highscore_level();

        my %new_entry;
        $new_entry{level} = $levels{current};
        $new_entry{time} = $total_seconds;
        $new_entry{piclevel} = count_highscorehistory_levels();
        ask_from({ intro => [ loc("Congratulations!"), loc("You have a highscore!"), '' ],
                   entries => [ { 'q' => loc("Your name?"), 'a' => \$new_entry{name} } ],
                   outro => loc("Great game!"),
                   erase_background => $background,
                 });
        return if $new_entry{name} eq '';

        push @$HISCORES, \%new_entry;
        if (@$HISCORES == 11) {
            my @high = ordered_highscores();
            pop @high;
            $HISCORES = \@high;
        }
        output($hiscorefiles{levels}, Data::Dumper->Dump([$HISCORES], [qw(HISCORES)]));
        display_highscores('levels', \%new_entry);

    } else {
        #- mp training hiscores
        my @ordered;
        if ($chainreaction) {
            @ordered = ordered_mptrain_highscores_chainreaction();
        } else {
            @ordered = ordered_mptrain_highscores();
        }
        my $scores = $chainreaction ? $HISCORES_MPTRAIN_CHAINREACTION : $HISCORES_MPTRAIN;
        my $worst = pop @ordered;
        if (@$scores == 20 && $pdata{p1}{score} < $worst->{score}) {
            return;
        }
        play_sound('applause');

        my %new_entry;
        $new_entry{score} = $pdata{p1}{score};
        ask_from({ intro => [ loc("Congratulations!"), loc("You have a highscore!"), '' ],
                   entries => [ { 'q' => loc("Your name?"), 'a' => \$new_entry{name} } ],
                   outro => loc("Great game!"),
                   erase_background => $background,
                 });
        return if $new_entry{name} eq '';

        push @$scores, \%new_entry;
        if (@$scores == 21) {
            my @high = sort { $b->{score} <=> $a->{score} } @$scores;
            pop @high;
            if ($chainreaction) {
                $HISCORES_MPTRAIN_CHAINREACTION = \@high;
            } else {
                $HISCORES_MPTRAIN = \@high;
            }
        }
        output($hiscorefiles{mptrain}, Data::Dumper->Dump([$HISCORES_MPTRAIN], [qw(HISCORES_MPTRAIN)]) . ' ' .
                                       Data::Dumper->Dump([$HISCORES_MPTRAIN_CHAINREACTION], [qw(HISCORES_MPTRAIN_CHAINREACTION)]));
        display_highscores('mptrain', \%new_entry);
    }
}

# append the new highscore to the $FBHOME/highlevelshistory
sub append_highscore_level() {

    my $row_numb = 0;
    my $lvl = 1;

    my @contents;

    foreach my $line (cat_($loaded_levelset)) {
        if ($line !~ /\S/) {
            if ($row_numb) {
                $lvl++;
                $row_numb = 0;
            }
        } else {
            $row_numb++;
            $lvl == ($levels{current} eq 'WON' ? (keys %levels)-1 : $levels{current})
              and push @contents, $line;
        }
    }

    append_to_file("$FBHOME/highlevelshistory", @contents, "\n\n");
}

sub count_highscorehistory_levels() {
    my $cnt = 0;
    my $row_numb = 0;
    foreach my $line (cat_("$FBHOME/highlevelshistory")) {
        if ($line !~ /\S/) {
            if ($row_numb) {
                $cnt++;
                $row_numb = 0;
            }
        } else {
            $row_numb++;
        }
    }
    return $cnt;
}

sub save_frame() {
    $replayparam and $app->save_bmp(sprintf("$saveframes/frame_\%d_%08d.bmp", $saveframesbase, $saveframescounter++));
}

#- ----------- mainloop ---------------------------------------------------

sub maingame() {
    my $synchro_ticks = SDL::get_ticks();

    handle_graphics(\&erase_image);
    update_game();
    handle_graphics(\&put_image);
    $frame++;

#    print "rects:\n";
#    printf "\t%d:%d %d:%d %s\n", $_->x, $_->y, $_->w, $_->h, $_->{from} foreach @update_rects;
    SDL::Video::update_rects($app, @update_rects);
    @update_rects = ();

    my $to_wait = $TARGET_ANIM_SPEED - (SDL::get_ticks() - $synchro_ticks);
#    print "$to_wait\n";
    $to_wait > 0 and Games::FrozenBubble::CStuff::fbdelay($to_wait);
    $saveframes and save_frame();
}

sub cleanup_and_exit {
    save_config();
    exit 0;
}

#- ----------- menu stuff -------------------------------------------------

our $logo_candy_index = 0;
our $logo_candy_method = int(rand(8));
if ("@ARGV" =~ /winter.season/) {
    $logo_candy_method = 8;
} else {
    my (undef, undef, undef, $day, $month) = localtime(time());
    if ($day == 25 && $month == 11) {
        $logo_candy_method = 8;
    } else {
        if (!defined($mylatitude) || $mylatitude > 0) {
            if ($day >= 21 && $month == 11
                || $month == 0
                || $day <= 21 && $month == 1) {
                rand() < 0.3 and $logo_candy_method = 8;
            }
        } else {
            if ($day >= 21 && $month == 4
                || $month == 5
                || $day <= 24 && $month == 6) {
                rand() < 0.3 and $logo_candy_method = 8;
            }
        }
    }
}
our ($logox, $logoy);
our $candy;
our ($blink_green, $blink_purple);
our %cursor_save_bg;
our $cursor_tmp;
our %broken_cursors;

sub save_config {
    #- for $KEYS, try hard to keep SDLK_<key> instead of integer value in rcfile
    my $KEYS_;
    foreach my $p (keys %$KEYS) {
        foreach my $k (keys %{$KEYS->{$p}}) {
            if ($KEYS->{$p}{$k} =~ /^\d+$/) {
                foreach (@fbsyms::syms) {
                    if (eval("$KEYS->{$p}{$k} eq SDLK_$_")) {
                        $KEYS_->{$p}{$k} = "SDLK_$_";
                        goto nextkey;
                    }
                }
            }
            $KEYS_->{$p}{$k} = $KEYS->{$p}{$k};  #- fallback to numeric
          nextkey:
        }
    }
    #- special hook for $mylatitude as we don't want to save an empty value
    my $dump = Data::Dumper->Dump([$fullscreen, $graphics_level, $mynick, $music_disabled,
                                   $mixer_enabled, $mylatitude || undef, $mylongitude, $KEYS_],
                                  [qw(fullscreen graphics_level mynick music_disabled mixer_enabled
                                      mylatitude mylongitude KEYS)]);
    $dump =~ s/'SDLK_(\w+)'/SDLK_$1/g;
    output($rcfile, $dump);
}
my $banner_pos; 
my $current_pos;   
sub menu {
    my ($firsttime) = @_;

    if (is_1p_game() && $levels{current} ne 'mp_train') {
        handle_new_hiscores();
    }

    play_music('intro');
    clean_server();

    my $back_start   = $imgbin{back_menu};;
    my $display_menu = sub {
                SDL::Video::blit_surface($back_start, $apprects{main}, $app, $apprects{main});

                # stamp is the "frozen bubble since 2002"-logo underneath the (animated) logo
                SDL::Video::blit_surface($imgbin{stamp},SDL::Rect->new(0,0,$imgbin{stamp}->w,$imgbin{stamp}->h), $app, SDL::Rect->new( 490,  142, $imgbin{stamp}->w, $imgbin{stamp}->h));
    };

    $display_menu->();

    my $invalidate_all;

        my $menu_display_highscores = sub {
                display_highscores();
                $display_menu->();
                SDL::Video::update_rect($app, 0, 0, 0, 0);
                $invalidate_all->();
        };

        # Q&A for changing keys
        my $change_keys = sub {
                ask_from({
                        intro => [ loc("Please enter new keys:") ],
                        entries => [
                                { 'q' => loc("Player 1; turn left?"),  'a' => \$KEYS->{p1}{left},   f => 'ONE_CHAR_DISPLAY' },
                                { 'q' => loc("Player 1; turn right?"), 'a' => \$KEYS->{p1}{right},  f => 'ONE_CHAR_DISPLAY' },
                                { 'q' => loc("Player 1; fire?"),       'a' => \$KEYS->{p1}{fire},   f => 'ONE_CHAR_DISPLAY' },
                                { 'q' => loc("Player 1; center?"),     'a' => \$KEYS->{p1}{center}, f => 'ONE_CHAR_DISPLAY' },
                                { f => 'SPACE' },
                                { 'q' => loc("Player 2; turn left?"),  'a' => \$KEYS->{p2}{left},   f => 'ONE_CHAR_DISPLAY' },
                                { 'q' => loc("Player 2; turn right?"), 'a' => \$KEYS->{p2}{right},  f => 'ONE_CHAR_DISPLAY' },
                                { 'q' => loc("Player 2; fire?"),       'a' => \$KEYS->{p2}{fire},   f => 'ONE_CHAR_DISPLAY' },
                                { 'q' => loc("Player 2; center?"),     'a' => \$KEYS->{p2}{center}, f => 'ONE_CHAR_DISPLAY' },
                                { f => 'SPACE' },
                                { 'q' => loc("Toggle fullscreen?"),    'a' => \$KEYS->{misc}{fs},   f => 'ONE_CHAR_DISPLAY' },
                                { 'q' => loc("Chat (net/lan game)?"),  'a' => \$KEYS->{misc}{chat}, f => 'ONE_CHAR_DISPLAY' },
                        ],
                        outro => loc("Thanks!"),
                        erase_background => $back_start
                });
                $invalidate_all->();
#               print Data::Dumper->Dump([$KEYS], [qw(KEYS)]), "\n";
#               die;
    };

    my $launch_editor = sub {
        SDL::Mouse::show_cursor(1);
        Games::FrozenBubble::LevelEditor::init_setup('embedded', $app);
        Games::FrozenBubble::LevelEditor::handle_events();
        SDL::Mouse::show_cursor(0);
                $display_menu->();
        SDL::Video::update_rect($app, 0, 0, 0, 0);
        $invalidate_all->();
    };

    my $speed_ok = 4;

    my $candy_init = sub {
                # calculating positions and creating new surfaces for logo animations
        if (defined($candy)) {
            erase_image_from($imgbin{menu_logo}, $logox, $logoy, $back_start);
            $candy = undef;
            $imgbin{menu_logo} = add_image('menu/fblogo.png');
        }

        ($logox, $logoy) = (400, 15);
        if ($logo_candy_method == 3) {
            #- stretch needs a bit more room
            my $newlogosurface = SDL::Surface->new(SDL_SWSURFACE, $imgbin{menu_logo}->w * 1.1,  $imgbin{menu_logo}->h * 1.1,  32, 0xFF000000, 0xFF0000, 0xFF00, 0xFF);
                        SDL::Video::set_alpha($imgbin{menu_logo}, 0, 0); #- for RGBA->RGBA blits, SDL_SRCALPHA must be removed or destination alpha is preserved
            SDL::Video::blit_surface($imgbin{menu_logo}, SDL::Rect->new(0,0,$imgbin{menu_logo}->w,$imgbin{menu_logo}->h), $newlogosurface, SDL::Rect->new( $imgbin{menu_logo}->w * 0.05, $imgbin{menu_logo}->h * 0.05, $imgbin{menu_logo}->w, $imgbin{menu_logo}->h));
            $logox -= $imgbin{menu_logo}->w * 0.05;
            $logoy -= $imgbin{menu_logo}->h * 0.05;
            $imgbin{menu_logo} = $newlogosurface;
            add_default_rect($imgbin{menu_logo});
            $logo_candy_method = 3.1; #- avoid doing it again at next menu run
        }
        if ($logo_candy_method == 4) {
            #- tilt needs a bit more horizontal room
            my $newlogosurface = SDL::Surface->new(SDL_SWSURFACE, $imgbin{menu_logo}->w * 1.1,  $imgbin{menu_logo}->h * 1.05,  32, 0xFF000000, 0xFF0000, 0xFF00, 0xFF);
                        SDL::Video::set_alpha($imgbin{menu_logo}, 0, 0); #- for RGBA->RGBA blits, SDL_SRCALPHA must be removed or destination alpha is preserved
            SDL::Video::blit_surface($imgbin{menu_logo}, SDL::Rect->new(0,0,$imgbin{menu_logo}->w,$imgbin{menu_logo}->h), $newlogosurface, SDL::Rect->new( $imgbin{menu_logo}->w * 0.05, $imgbin{menu_logo}->h * 0.025, $imgbin{menu_logo}->w, $imgbin{menu_logo}->h));
            $logox -= $imgbin{menu_logo}->w * 0.05;
            $logoy -= $imgbin{menu_logo}->h * 0.025;
            $imgbin{menu_logo} = $newlogosurface;
            add_default_rect($imgbin{menu_logo});
            $logo_candy_method = 4.1; #- avoid doing it again at next menu run
        }
        if ($logo_candy_method == 8) {
            #- snow needs to extend top, and a little more wideness
            my $newlogosurface = SDL::Surface->new( SDL_SWSURFACE, $imgbin{menu_logo}->w * 1.1,  $imgbin{menu_logo}->h + $logoy, 32, 0xFF000000, 0xFF0000, 0xFF00, 0xFF);
                        SDL::Video::set_alpha( $imgbin{menu_logo}, 0, 0); #- for RGBA->RGBA blits, SDL_SRCALPHA must be removed or destination alpha is preserved
            SDL::Video::blit_surface( $imgbin{menu_logo}, SDL::Rect->new(0,0,$imgbin{menu_logo}->w,$imgbin{menu_logo}->h), $newlogosurface, SDL::Rect->new($imgbin{menu_logo}->w * 0.05, $logoy, $imgbin{menu_logo}->w, $imgbin{menu_logo}->h));
            $logox -= $imgbin{menu_logo}->w * 0.05;
            $logoy = 0;
            $imgbin{menu_logo} = $newlogosurface;
            add_default_rect($imgbin{menu_logo});
            $logo_candy_method = 8.1; #- avoid doing it again at next menu run
        }
        $candy = SDL::Surface->new(SDL_SWSURFACE, $imgbin{menu_logo}->w,  $imgbin{menu_logo}->h, 32, 0xFF000000, 0xFF0000, 0xFF00, 0xFF);
    };
    defined($candy) or $candy_init->(); 
        my $draw_logo = sub {
                my ($no_update) = @_;
                erase_image_from($imgbin{menu_logo}, $logox, $logoy, $back_start);

                if ($graphics_level < 3 || !$speed_ok) {
                        # logo is blittet as it is, without animations
                        put_image($imgbin{menu_logo}, $logox, $logoy);
                }
                else { # logo animation
                        # logo effects (snow, water, ...)
                        Games::FrozenBubble::CStuff::rotate_bilinear($candy, $imgbin{menu_logo}, sin($logo_candy_index/40)/20) if $logo_candy_method == 0;
                        Games::FrozenBubble::CStuff::flipflop($candy, $imgbin{menu_logo}, $logo_candy_index)                   if $logo_candy_method == 1;
                        Games::FrozenBubble::CStuff::enlighten($candy, $imgbin{menu_logo}, $logo_candy_index)                  if $logo_candy_method == 2;
                        Games::FrozenBubble::CStuff::stretch($candy, $imgbin{menu_logo}, $logo_candy_index)                    if $logo_candy_method == 3.1;
                        Games::FrozenBubble::CStuff::tilt($candy, $imgbin{menu_logo}, $logo_candy_index)                       if $logo_candy_method == 4.1;
                        Games::FrozenBubble::CStuff::points($candy, $imgbin{menu_logo}, $imgbin{menu_logo_mask})               if $logo_candy_method == 5;
                        Games::FrozenBubble::CStuff::waterize($candy, $imgbin{menu_logo}, $logo_candy_index)                   if $logo_candy_method == 6;
                        Games::FrozenBubble::CStuff::brokentv($candy, $imgbin{menu_logo}, $logo_candy_index)                   if $logo_candy_method == 7;
                        Games::FrozenBubble::CStuff::snow($candy, $imgbin{menu_logo})                                          if $logo_candy_method == 8.1;

                        SDL::Video::blit_surface($candy, SDL::Rect->new(0,0,$candy->w,$candy->h), $app, SDL::Rect->new($logox, $logoy, $candy->w, $candy->h));

                        # next step for the animation
                        $logo_candy_index++;
                }

        if (!$no_update) {
                        SDL::Video::update_rects($app, @update_rects);
            @update_rects = ();
        }
    };

    $imgbin{menu_cursor}{graphics}          = $imgbin{menu_cursor}{"graphics$graphics_level"};
    $imgbin{menu_cursor}{graphicsalpha}     = $imgbin{menu_cursor}{"graphics${graphics_level}alpha"};
    my ($MENU_XPOS, $MENU_FIRSTY, $SPACING) = (89, 14, 56);
        # screen y-position of main menu elements
    my %menu_ypos = (
                '1pgame'     => $MENU_FIRSTY,
                '2pgame'     => $MENU_FIRSTY +     $SPACING,
                'langame'    => $MENU_FIRSTY + 2 * $SPACING,
                'netgame'    => $MENU_FIRSTY + 3 * $SPACING,
                'editor'     => $MENU_FIRSTY + 4 * $SPACING,
                'graphics'   => $MENU_FIRSTY + 5 * $SPACING,
                'keys'       => $MENU_FIRSTY + 6 * $SPACING,
                'highscores' => $MENU_FIRSTY + 7 * $SPACING,
        );

        # menu indexes, and functions that are called before the function behind 'type' is called
        my %menu_entries = (
                '1pgame' => {
                        pos  => 1,
                        type => 'rungame',
                        run  => sub { @PLAYERS = ('p1'); $levels{current} = 1; $time_1pgame = SDL::get_ticks() }
                },
                '2pgame' => {
                        pos  => 2,
                        type => 'rungame',
                        run  => sub { @PLAYERS = qw(p1 p2); $levels{current} = undef; }
                },
                'langame'=> {
                        pos  => 3,
                        type => 'rungame',
                        run  => sub { @PLAYERS = qw(p1 rp1); $pdata{gametype} = 'lan'; $levels{current} = undef; }
                },
                'netgame'=> {
                        pos  => 4,
                        type => 'rungame',
                        run  => sub { @PLAYERS = qw(p1 rp1); $pdata{gametype} = 'net'; $levels{current} = undef; }
                },
                'editor' => {
                        pos => 5,
                        type => 'run',
                        run => sub { $launch_editor->(); }
                },
                'graphics' => {
                        pos      => 6,
                        type     => 'range',
                        valuemin => 1,
                        valuemax => 3,
                        change   => sub {
                                $graphics_level = $_[0];
                                if ($graphics_level < 3) { $draw_logo->() } else { $speed_ok = 4; }
                                $imgbin{menu_cursor}{graphics}      = $imgbin{menu_cursor}{"graphics$graphics_level"};
                                $imgbin{menu_cursor}{graphicsalpha} = $imgbin{menu_cursor}{"graphics${graphics_level}alpha"};
                                $pdata{cursor_img}{graphics}        = 0 if $pdata{cursor_img}{graphics} >= @{$imgbin{menu_cursor}{graphics}};
                        },
                        value => $graphics_level
                },
                'keys' => {
                        pos  => 7,
                        type => 'run',
                        run  => sub { $change_keys->() }
                },
                'highscores' => {
                        pos  => 8,
                        type => 'run',
                        run  => sub { $menu_display_highscores->() }
                },
        );
    $current_pos = 1;  # selected menu entry (1..8) # THIS IS DEPRECEATED
    my @menu_invalids = (); # list of menu item's positions
    $invalidate_all   = sub { push @menu_invalids, $menu_entries{$_}->{pos} foreach keys %menu_entries };

    my $display_cursor = sub {
        my ($m, $alpha, $pixelize) = @_;
        my $cursor_rect = SDL::Rect->new( 248,  $menu_ypos{$m} + 8,
                                          $imgbin{menu_cursor}{$m}[$pdata{cursor_img}{$m}]->w,
                                         $imgbin{menu_cursor}{$m}[$pdata{cursor_img}{$m}]->h);
        if (!defined($cursor_save_bg{$m})) {
            $cursor_save_bg{$m} = SDL::Surface->new(SDL_SWSURFACE, $imgbin{menu_cursor}{$m}[0]->w, $imgbin{menu_cursor}{$m}[0]->h, 32, 0,0,0,0);
                        SDL::Video::blit_surface($app, $cursor_rect, $cursor_save_bg{$m}, SDL::Rect->new( 0,  0,  $imgbin{menu_cursor}{$m}[0]->w, $imgbin{menu_cursor}{$m}[0]->h));
        }
                SDL::Video::blit_surface($cursor_save_bg{$m}, SDL::Rect->new(0,0,$cursor_save_bg{$m}->w,$cursor_save_bg{$m}->h), $app, $cursor_rect);
        if ($alpha) {
            if ($pixelize) {
                                if (!defined($cursor_tmp)) {
                                        $cursor_tmp = SDL::Surface->new( SDL_SWSURFACE, $imgbin{menu_cursor}{$m}[0]->w,  $imgbin{menu_cursor}{$m}[0]->h, 32, 0xFF000000,0xFF0000,0xFF00,0xFF);
                                }
                                # this effect appears randomly on not selected (animated) menu elements
                Games::FrozenBubble::CStuff::pixelize($cursor_tmp, $imgbin{menu_cursor}{"${m}alpha"}[$pdata{cursor_img}{$m}]);
                                SDL::Video::blit_surface( $cursor_tmp, SDL::Rect->new(0,0,$cursor_tmp->w,$cursor_tmp->h), $app, $cursor_rect);
            }
                        else {
                                # not animated menu item
                SDL::Video::blit_surface( $imgbin{menu_cursor}{"${m}alpha"}[$pdata{cursor_img}{$m}], SDL::Rect->new(0,0,$imgbin{menu_cursor}{"${m}alpha"}[$pdata{cursor_img}{$m}]->w,$imgbin{menu_cursor}{"${m}alpha"}[$pdata{cursor_img}{$m}]->h), $app, $cursor_rect);
            }
        }
                else {
                        # blits the animated icon for the selected menu item
                        SDL::Video::blit_surface( $imgbin{menu_cursor}{$m}[$pdata{cursor_img}{$m}], SDL::Rect->new(0,0,$imgbin{menu_cursor}{$m}[$pdata{cursor_img}{$m}]->w,$imgbin{menu_cursor}{$m}[$pdata{cursor_img}{$m}]->h), $app, $cursor_rect);
        }
        return $cursor_rect;
    };

    my $menu_update = sub {
                @update_rects = ();
                foreach my $m (keys %menu_entries) {
                        member($menu_entries{$m}->{pos}, @menu_invalids) or next;
                        my $txt = "txt_$m";
                        $txt .= $menu_entries{$m}->{pos} == $current_pos ? '_over' : '_off';
                        erase_image_from($imgbin{$txt}, $MENU_XPOS, $menu_ypos{$m}, $back_start);
                        put_image($imgbin{$txt}, $MENU_XPOS, $menu_ypos{$m});
                        $cursor_save_bg{$m} = undef;
                        $display_cursor->($m, $menu_entries{$m}->{pos} != $current_pos);
                }
                @menu_invalids = ();
                $draw_logo->('no-update');
                SDL::Video::update_rects($app, @update_rects);
                @update_rects = ();
    };

    $invalidate_all->();
    $menu_update->();
    SDL::Video::update_rect($app, 0, 0, 0, 0);
    SDL::Events::pump_events() while SDL::Events::poll_event($event) != 0;

    my $start_game = 0;
    my ($BANNER_START, $BANNER_SPACING) = (1000, 80);
    my %banners = (artwork => $BANNER_START,
                   soundtrack => $BANNER_START + $imgbin{banner_artwork}->w + $BANNER_SPACING,
                   cpucontrol => $BANNER_START + $imgbin{banner_artwork}->w + $BANNER_SPACING
                                 + $imgbin{banner_soundtrack}->w + $BANNER_SPACING,
                   leveleditor => $BANNER_START + $imgbin{banner_artwork}->w + $BANNER_SPACING
                                 + $imgbin{banner_soundtrack}->w + $BANNER_SPACING
                                 + $imgbin{banner_cpucontrol}->w + $BANNER_SPACING);
    my ($BANNER_MINX, $BANNER_MAXX, $BANNER_Y) = (304, 596, 243);
    my $banners_max = $banners{leveleditor} - (640 - ($BANNER_MAXX - $BANNER_MINX)) + $BANNER_SPACING;
    my $banner_rect = SDL::Rect->new( $BANNER_MINX, $BANNER_Y, $BANNER_MAXX-$BANNER_MINX, 30);
    my $time_counter;

    while (!$start_game) {
        my $synchro_ticks = SDL::get_ticks();

        $graphics_level > 1 and SDL::Video::blit_surface($back_start, $banner_rect, $app, $banner_rect);

        SDL::Events::pump_events();
        while (SDL::Events::poll_event($event)) {
            my $keypressed = extended_keypress($event);
            if ($keypressed) {
                if ($keypressed eq SDLK_PAUSE) {
                    my $time_pause = SDL::get_ticks();
                    SDL::Events::pump_events() while SDL::Events::poll_event($event);
                  pause_menu:
                    while (1) {
                        SDL::Events::wait_event($event);
                        if ($event->type == SDL_QUIT) {
                            cleanup_and_exit();
                        }
                        my $keypressed = extended_keypress($event);
                        if ($keypressed) {
                            $start_time += SDL::get_ticks() - $time_pause;
                            last pause_menu;
                        }
                    }
                }
                                my $keys_ref = SDL::Events::get_key_state();
                if ($keys_ref->[SDLK_LCTRL] == SDL_PRESSED
                    && $keypressed == SDLK_n) {
                    $logo_candy_method = (int($logo_candy_method) + 1) % 9;
                    $candy_init->();
                }
                if (member($keypressed, (SDLK_DOWN, SDLK_RIGHT))) {
                    push @menu_invalids, $current_pos;
                    if ($current_pos < max(map { $menu_entries{$_}->{pos} } keys %menu_entries)) {
                        $current_pos++;
                    } else {
                        $current_pos = 1;
                    }
                    push @menu_invalids, $current_pos;
                    play_sound('menu_change');
                    $menu_update->();
                }
                if (member($keypressed, (SDLK_UP, SDLK_LEFT))) {
                    push @menu_invalids, $current_pos;
                    if ($current_pos > 1) {
                        $current_pos--;
                    } else {
                        $current_pos = max(map { $menu_entries{$_}->{pos} } keys %menu_entries);
                    }
                    push @menu_invalids, $current_pos;
                    play_sound('menu_change');
                    $menu_update->();
                }
                if (member($keypressed, (SDLK_RETURN, SDLK_SPACE, SDLK_KP_ENTER))) {
                    play_sound('menu_selected');
                    push @menu_invalids, $current_pos;
                    foreach my $m (keys %menu_entries) {
                                if ($menu_entries{$m}->{pos} == $current_pos) {
                                        if ($menu_entries{$m}->{type} =~ /^run/) {
                                                $menu_entries{$m}->{run}->();
                                                $menu_entries{$m}->{type} eq 'rungame' and $start_game = 1;
                                        }
                                        if ($menu_entries{$m}->{type} eq 'range') {
                                                $menu_entries{$m}->{value}++;
                                                $menu_entries{$m}->{value} = $menu_entries{$m}->{valuemin} if $menu_entries{$m}->{value} > $menu_entries{$m}->{valuemax};
                                                $menu_entries{$m}->{change}->($menu_entries{$m}->{value});
                                        }
                                }
                    }
                    $menu_update->();
                }
                handle_whenever_events($keypressed);

                if ($keypressed eq SDLK_ESCAPE) {
                    cleanup_and_exit();
                }
                $synchro_ticks = SDL::get_ticks();  #- avoid stopping candy
                $time_counter = 0;  #- reset counter for demos
            }
            if ($event->type == SDL_QUIT) {
                cleanup_and_exit();
            }
        }

        if ($graphics_level > 1) {
            
            $banner_pos ||= 670;
            foreach my $b (keys %banners) {
                my $xpos = $banners{$b} - $banner_pos;
                my $image = $imgbin{"banner_$b"};

                $xpos > $banners_max/2 and $xpos = $banners{$b} - ($banner_pos + $banners_max);

                if ($xpos < $BANNER_MAXX && $xpos + $image->w >= 0) {
                    my $irect = SDL::Rect->new(-$xpos, 0,  min($image->w+$xpos, $BANNER_MAXX-$BANNER_MINX),
                                                $image->h);
                                        SDL::Video::blit_surface( $image, $irect, $app, SDL::Rect->new( $BANNER_MINX,  $BANNER_Y, $image->w, $image->h) );
                }
            }
            $banner_pos++;
            $banner_pos >= $banners_max and $banner_pos = 1;
            SDL::Video::update_rects($app, $banner_rect);

            #- animate and break cursor
            foreach my $m (keys %menu_entries) {
                if ($menu_entries{$m}->{pos} == $current_pos) {
                    $pdata{cursor_img}{$m}++;
                    $pdata{cursor_img}{$m} >= @{$imgbin{menu_cursor}{$m}} and $pdata{cursor_img}{$m} = 0;
                    SDL::Video::update_rects($app, $display_cursor->($m, 0));

                } else {
                    if ($broken_cursors{$m}) {
                        $broken_cursors{$m}--;
                        if ($broken_cursors{$m}) {
                                SDL::Video::update_rects($app, $display_cursor->($m, 1, 1));
                        } else {
                           SDL::Video::update_rects($app, $display_cursor->($m, 1));
                        }
                    } else {
                        rand() < 0.001 and $broken_cursors{$m} = int(20 + 10 * cos(rand(2*$PI)));
                    }
                }
            }

            #- blinking handling follows
            my $blink_green_left = [ 411, 385 ];
            my $blink_green_right = [ 434, 378 ];
            my $green_left = SDL::Rect->new( $blink_green_left->[0], $blink_green_left->[1],
                                             $imgbin{menu_closedeye_green_left}->w,  $imgbin{menu_closedeye_green_left}->h);
            my $green_right = SDL::Rect->new( $blink_green_right->[0], $blink_green_right->[1],
                                              $imgbin{menu_closedeye_green_right}->w, $imgbin{menu_closedeye_green_right}->h);
            my $blink_purple_left = [ 522, 356 ];
            my $blink_purple_right = [ 535, 356 ];
            my $purple_left = SDL::Rect->new($blink_purple_left->[0], $blink_purple_left->[1],
                                             $imgbin{menu_closedeye_purple_left}->w, $imgbin{menu_closedeye_purple_left}->h);
            my $purple_right = SDL::Rect->new($blink_purple_right->[0], $blink_purple_right->[1],
                                             $imgbin{menu_closedeye_purple_right}->w,  $imgbin{menu_closedeye_purple_right}->h);
            if ($blink_green > 0) {
                $blink_green--;
                if (!$blink_green) {
                        SDL::Video::blit_surface ( $back_start, $green_left, $app, $green_left);
                        SDL::Video::blit_surface ( $back_start, $green_right, $app, $green_right);
                        SDL::Video::update_rects ($app, $green_left, $green_right);
                    if (rand(3) <= 1) {  #- reblink
                        $blink_green = -5;
                    }
                }
            } elsif ($blink_green < 0) {
                $blink_green++;
                if (!$blink_green) {
                    $blink_green = 3;
                        SDL::Video::blit_surface ( $imgbin{menu_closedeye_green_left}, SDL::Rect->new(0,0,$imgbin{menu_closedeye_green_left}->w,$imgbin{menu_closedeye_green_left}->h), $app, $green_left);
                        SDL::Video::blit_surface ( $imgbin{menu_closedeye_green_right}, SDL::Rect->new(0,0,$imgbin{menu_closedeye_green_right}->w,$imgbin{menu_closedeye_green_right}->h), $app, $green_right);
                    SDL::Video::update_rects( $app, $green_left, $green_right);
                }
            } else {
                if (rand(200) <= 1) {
                    $blink_green = 3;
                    SDL::Video::blit_surface ( $imgbin{menu_closedeye_green_left},SDL::Rect->new(0,0,$imgbin{menu_closedeye_green_left}->w,$imgbin{menu_closedeye_green_left}->h), $app, $green_left);
                    SDL::Video::blit_surface ( $imgbin{menu_closedeye_green_right},SDL::Rect->new(0,0,$imgbin{menu_closedeye_green_right}->w,$imgbin{menu_closedeye_green_right}->h), $app, $green_right);
                    SDL::Video::update_rects( $app,$green_left, $green_right);
                }
            }
            if ($blink_purple > 0) {
                $blink_purple--;
                if (!$blink_purple) {
                    SDL::Video::blit_surface ( $back_start,$purple_left, $app, $purple_left);
                   SDL::Video::blit_surface (  $back_start,$purple_right, $app, $purple_right);
                    SDL::Video::update_rects( $app,$purple_left, $purple_right);
                    if (rand(3) <= 1) {  #- reblink
                        $blink_purple = -5;
                    }
                }
            } elsif ($blink_purple < 0) {
                $blink_purple++;
                if (!$blink_purple) {
                    $blink_purple = 3;
                    SDL::Video::blit_surface ( $imgbin{menu_closedeye_purple_left},SDL::Rect->new(0,0,$imgbin{menu_closedeye_purple_left}->w,$imgbin{menu_closedeye_purple_left}->h), $app, $purple_left);
                    SDL::Video::blit_surface ( $imgbin{menu_closedeye_purple_right},SDL::Rect->new(0,0,$imgbin{menu_closedeye_purple_right}->w,$imgbin{menu_closedeye_purple_right}->h), $app, $purple_right);
                    SDL::Video::update_rects( $app,$purple_left, $purple_right);
                }
            } else {
                if (rand(200) <= 1) {
                    $blink_purple = 3;
                    SDL::Video::blit_surface ( $imgbin{menu_closedeye_purple_left},SDL::Rect->new(0,0,$imgbin{menu_closedeye_purple_left}->w,$imgbin{menu_closedeye_purple_left}->h), $app, $purple_left);
                   SDL::Video::blit_surface (  $imgbin{menu_closedeye_purple_right},SDL::Rect->new(0,0,$imgbin{menu_closedeye_purple_right}->w,$imgbin{menu_closedeye_purple_right}->h), $app, $purple_right);
                    SDL::Video::update_rects( $app,$purple_left, $purple_right);
                }
            }

        }

        if ($graphics_level > 2 && $speed_ok) {
            $draw_logo->();
        }

        my $to_wait = $TARGET_ANIM_SPEED - (SDL::get_ticks() - $synchro_ticks);
#        print "$to_wait\n";
        if ($to_wait > 0) {
            Games::FrozenBubble::CStuff::fbdelay($to_wait);
            $speed_ok and $speed_ok = 4;
        } else {
            #- disable nice graphics artwork if computer is too slow
#            print "$to_wait\n";
            if ($speed_ok) {
                $speed_ok--;
                if (!$speed_ok) {
                    print "Eye-candy animation is too slow, disabling ($logo_candy_method).\n";
                    $draw_logo->();
                }
            }
        }

        if (++$time_counter == 1000) {  #- 20 seconds
            $pdata{demo} = 1;
            my @files = glob("$FPATH/data/demo*");
            replay($files[int(rand(@files))]);
            $pdata{demo} = 0;
          blacken:
            foreach my $step (1..35) {
                my $ticks = SDL::get_ticks();
                Games::FrozenBubble::CStuff::blacken($app, $step);
                SDL::Video::update_rect($app, 0, 0, 0, 0);
                my $to_wait = $TARGET_ANIM_SPEED - (SDL::get_ticks() - $ticks);
                $to_wait > 0 and Games::FrozenBubble::CStuff::fbdelay($to_wait);

                SDL::Events::pump_events();
                while (SDL::Events::poll_event($event) != 0) {
                    if ($event->type == SDL_QUIT) {
                        cleanup_and_exit();
                    }
                    if (extended_keypress($event)) {
                        last blacken;
                    }
                }
            }
            $display_menu->();
            $invalidate_all->();
            $menu_update->();
            SDL::Video::update_rect($app, 0, 0, 0, 0);
            $time_counter = 0;
            play_music('intro');
        }
    }

    save_config();

    iter_players {
       !is_1p_game() and $pdata{$::p}{score} = 0;
    };
}


#- ----------- editor stuff --------------------------------------------

sub choose_levelset() {
    my ($choose_level) = @_;

    my @levelsets = sort glob("$FBLEVELS/*");

    if (!@levelsets && !$choose_level) {
        # no $FBHOME/levels directory or void directory, just return and let the
        # game continue (means that the level editor has never been opened)

    } else {

        if (@levelsets <= 1 && !$choose_level) {
            load_levelset($levelsets[0]);
        } else {
            #if they are choosing the start level, we need to ensure the default
            #levelset is in $FBLEVELS or the dialog won't display properly
            if ($choose_level) {
                -d $FBLEVELS or mkdir $FBLEVELS;
                -d $FBLEVELS or die "Can't create $FBLEVELS directory.\n";
                -f "$FBLEVELS/default-levelset" or cp_af("$FPATH/data/levels", "$FBLEVELS/default-levelset");
            }

            Games::FrozenBubble::LevelEditor::init_app('embedded', $app);
            Games::FrozenBubble::LevelEditor::create_play_levelset_dialog($choose_level, $levels{current});
            SDL::Mouse::show_cursor(1);
            my @game_info = Games::FrozenBubble::LevelEditor::handle_events();
            @game_info or return;
            load_levelset("$FBLEVELS/$game_info[0]");
            $levels{current} = $game_info[1];
            SDL::Mouse::show_cursor(0);
        }
    }

    return 1;
}

sub replay {
    my ($replayfile) = @_;
    if ($replayfile =~ /^http/) {
        my $filename = $replayfile;
        $replayfile = Games::FrozenBubble::Net::http_download($replayfile);
        $replayfile or return;
        if ($filename =~ /\.bz2$/) {
            my $fh;
            do { $filename = POSIX::tmpnam() }
              until $fh = IO::File->new($filename, O_WRONLY|O_CREAT|O_EXCL);
            print $fh $replayfile;
            $fh->close;
            local *F;
            local $/ = undef;

            return unless -e $filename;

            my $bz      = Compress::Bzip2::bzopen($filename, 'r');
            $replayfile = '';
            my $line    = '';
            while($bz->bzreadline($line) > 0){ $replayfile .= $line; }
            
            $bz->bzclose();
            unlink ($filename);
         }
    } else {
        if ($replayfile =~ /\.bz2$/) {
            local *F;
            local $/ = undef;
            my $filename = $replayfile;

            return unless -e $filename;

            my $bz      = Compress::Bzip2::bzopen($filename, 'r');
            $replayfile = '';
            my $line    = '';
            while($bz->bzreadline($line) > 0){ $replayfile .= $line; }
            
            $bz->bzclose();
        } else {
            $replayfile = cat_($replayfile);
        }
    }
    my $b = before_leaving {
        $playdata = undef;
        srand SDL::get_ticks();
    };
    %recorddata = ();
    $playdata = [];
    my $linenumber = 0;
    my $current_frame_num;
    my $current_frame_action_data = {};
    my $current_frame_mp_messages_data = [];
    foreach my $line (split /\n/, $replayfile) {
        $linenumber++;
        my ($key, $value) = $line =~ /(.*?):(.*)?/ or print("Incorrect line number $linenumber in savegame.\n"), return;
        if ($key eq 'record_protocol') {
            if ($value > $RECORD_PROTOCOL_LEVEL) {
                print("Sorry, a more recent version of Frozen-Bubble is needed to play this record.\n"), return;
            } elsif ($value < $RECORD_PROTOCOL_LEVEL) {
                print("Sorry, an older version of Frozen-Bubble is needed to play this record.\n"), return;
            }
        } elsif ($key eq 'players') {
            @PLAYERS = split /,/, $value;
        } elsif ($key eq 'gametype') {
            $pdata{gametype} = $value;
        } elsif ($key eq 'current_level') {
            $levels{current} = $value;
        } elsif ($key eq 'chainreaction') {
            $chainreaction = $value;
        } elsif ($key eq 'time') {
            print 'Game recorded on ' . localtime($value) . ".\n";
        } elsif ($key eq 'comment') {
            print "Comment specified with record: $value.\n";
        } elsif ($key eq 'srand') {
            srand $value;
        } elsif ($key eq 'bubbles') {
            @{$recorddata{pdatas}{bubbles}} = split /,/, $value;
        } elsif ($key eq 'mp_result') {
            $recorddata{pdatas}{mp_result} = $value;
        } elsif ($key eq 'player_id') {
            my ($p, $id) = $value =~ /(.*?)\|(.*)/ or print("Incorrect line number $linenumber in savegame.\n"), return;
            $pdata{$p}{id} = $id;
        } elsif ($key eq 'player_nick') {
            my ($p, $nick) = $value =~ /(.*?)\|(.*)/ or print("Incorrect line number $linenumber in savegame.\n"), return;
            $pdata{$p}{nick} = $nick;
        } elsif ($key eq 'frame_action') {
            my ($framenum, $player, $action, $actionvalue) = $value =~ /(\d+)\|(\w+)\|(\w+)\|(\w+)/;
            if ($framenum != $current_frame_num && defined($current_frame_num)) {
                push @$playdata, [ $current_frame_num, { actions => $current_frame_action_data,
                                                         mp_messages => $current_frame_mp_messages_data } ];
                $current_frame_action_data = {};
                $current_frame_mp_messages_data = [];
            }
            $current_frame_num = $framenum;
            $current_frame_action_data->{$player}{$action} = $actionvalue;
        } elsif ($key eq 'frame_mpmessage') {
            my ($framenum, $id, $message) = $value =~ /(\d+)\|(.)\|(.+)/;
            if ($framenum != $current_frame_num && defined($current_frame_num)) {
                push @$playdata, [ $current_frame_num, { actions => $current_frame_action_data,
                                                         mp_messages => $current_frame_mp_messages_data } ];
                $current_frame_action_data = {};
                $current_frame_mp_messages_data = [];
            }
            $current_frame_num = $framenum;
            push @$current_frame_mp_messages_data, { id => $id, msg =>  $message };
        }
    }
    push @$playdata, [ $current_frame_num, { actions => $current_frame_action_data,
                                             mp_messages => $current_frame_mp_messages_data } ];
    $pdata{$_}{score} = 0 foreach @PLAYERS;
    if (is_mp_game()) {
        foreach my $p (@PLAYERS) {
            $pdata{id2p}{$pdata{$p}{id}} = $p;
        }
    }
    local $direct = 1;
    #- I'm wondering if the following is really more dirty than adding a $playdata test in the beginning of the three functions..
    local *Games::FrozenBubble::Net::gsend = sub {};
    local *Games::FrozenBubble::Net::grecv_get1msg_ifdata = sub { return; };
    local *check_mp_connection = sub {};
    new_game_once();
    new_game();
    while (1) {
        eval { maingame() };
        if ($@) {
            if ($@ =~ /^quit/ || $@ =~ /^new_game/) {
                last;
            } else {
                die;
            }
        }
    }
}

#- ----------- main -------------------------------------------------------

init_game();

if ($replayparam) {
    replay($replayparam);
    $replayparam = undef;
}

if (!$direct) {
    menu('first time');
}

while (!new_game_once()) { menu() }
new_game() or goto go_to_menu;

while (1) {
    eval { maingame() };
    if ($@) {
        my $died = $@;
        my $recorded = save_record_if_needed();
        if ($start_time != 0) {
            $addicted_time += SDL::get_ticks() - $start_time;
            $start_time = 0;
        }

        if ($died =~ /^new_game/) {
            new_game() or goto go_to_menu;

        } elsif ($died =~ /^quit/) {
            if (is_mp_game()) {
                if ($pdata{gametype} eq 'lan') {
                    Games::FrozenBubble::Net::disconnect();
                    show_mp_scores();
                    grab_key();
                    goto go_to_menu;
                } else {
                    if (Games::FrozenBubble::Net::reconnect() && new_game_once()) {
                        new_game() or goto go_to_menu;
                    } else {
                        goto go_to_menu;
                    }
                }
            } else {
              go_to_menu:
                do { menu() } while (!new_game_once());
                new_game();
            }

        } else {
            if (!$recorded) {
                print "\n******************************************************************************\n"
                    . "* Unexpected abort in process! Forcing record: please send the record file to FB authors so that they fix the bug if possible!\n"
                    . "******************************************************************************\n\n";
                $autorecord = 1;
                save_record_if_needed();
            } else {
                print "\n******************************************************************************\n"
                    . "* Unexpected abort in process! Please send the record file to FB authors so that they fix the bug if possible!\n"
                    . "******************************************************************************\n\n";
            }
            die $died;
        }
    }
}

__END__

=encoding UTF-8

=head1 NAME

frozen-bubble - arcade/reflex game

=head1 SYNOPSIS

    frozen-bubble [OPTION]...

=head1 DESCRIPTION

The B<Frozen-Bubble> game is a free software implementation of
a popular arcade/reflex game. The game mainly consists of firing
randomly chosen bubbles across the board. If the shoot ends up
having a clump of at least 3 bubbles of the same color, they all
pop. If some bubbles were sticked only on the popping clump, they
fall. In 1-player mode, the goal is to pop all the bubbles on the
board as quickly as possible. In 2-players or network mode, you
have to get your opponent to "die" before you.

=head1 CONTROL

The default controlling mechanism is through the keyboard, but
you can play with a joystick or a joypad if it is supported by
the system (use the commandline option B<-ji> to make sure
frozen-bubble detected your joysticks). A key (or a joystick
direction or button) is needed for moving the aim to the left,
moving the aim to the right, center, and fire.

=head1 1-PLAYER GAME

In single player mode, as a beginner the best training is to
choose B<Play Default Levelset>, which lets you run through
100 levels of an increasing difficulty. Pop all the bubbles of
each level to advance to the next level.

If you want to train for multiplayer, choose B<Multiplayer
Training> which reproduces the conditions of 2-player or
network mode; the only difference is that created malus bubbles
are counted in your score, and you must get the highest score you
can in 2 minutes.

=head1 2-PLAYERS GAME

In 2-players mode, you can play against a friend (or a foe,
actually) on the same computer. The board is populated with
random bubbles, and your goal is to make big clumps to send malus
bubbles to your opponent.

=head1 NETWORK GAME

If your computer has networking, you can choose LAN GAME to play
games against others on your local network (up to 5 players).
Frozen-Bubble will look for a game server on the local network
with a UDP broadcast, connect to it if found, or start a new game
server if not found.

If your computer is connected to Internet, you can choose NET
GAME to play against others on Earth (or beyond?). Frozen-Bubble
will retrieve the server list from the master server and propose
you to choose between available servers. The flag in front of a
server indicates the preferred language for chatting with others
before the game is started. The ping is the roundtrip when
talking with the server, choose a low ping when possible.

=head1 OPTIONS

=over

=item B<--help>

show command-line options summary

=item B<--fullscreen>

start the game in fullscreen mode

=item B<--no-fullscreen>

don't start the game in fullscreen mode

=item B<--no-sound>

disable music and sound effects

=item B<--no-music>

disable music (but not sound effects)

=item B<--no-sfx>

disable sound effects (but not music)

=item B<--playlist> I<directory>

use all files of the given directory as music files and play them

=item B<--playlist> I<file>

use all files listed in the given file as music files and play them

=item B<--slow-machine>

use this option if B<frozen-bubble>
runs too slowly on your machine (disables a few animations)

=item B<--very-slow-machine>

same as before, if it is not enough (disables all that can be disabled)

=item B<--solo>

directly start solo (1p) game, with random levels

=item B<--direct>

directly start 2p game (don't display menu)

=item B<--gameserver> I<host[:port]>

directly start NET/LAN game connecting to this game server (if
port is omitted, default port is used)

=item B<--chain-reaction>

enable chain-reaction

=item B<--level> I<number>

start directly the game, at level I<number>

=item B<--colour-blind>

use special bubbles for colourblind people

=item B<--no-time-limit>

disable time limit for shooting (e.g. kids mode)

=item B<--player-malus> I<number>

add I<number> malus to the left player (can be negative -
doesn't work in network mode)

=item B<--mp-training-difficulty> I<number>

set the average duration between receiving malus bubbles in 1
player multiplayer training (default 30 (= every 30 seconds on
average), the lower the harder)

=item B<--joysticks-info>

print information about detected joystick(s) on startup (if
Frozen-Bubble doesn't see your joysticks/joypads, try loading
the joydev module with B<modprobe joydev> as root, then
retry)

=item B<--no-echo>

when sound is enabled, disable echoing each typed character with
a typewriter sound (it may get on your nerves)

=item B<--my-nick> I<nick>

for NET/LAN games, use this nick instead of username (max 10
chars, ASCII alphanumeric plus dash and underscore only) - notice
that the /nick command is also available when connected to a
server to set your nick

=item B<--private>

after connecting to a server for a NET game, don't use
http://hostip.info/ to retrieve your geographical position to
send it to other players

=item B<--record> I<directory>

specify the recording directory (normally, records are saved in
the directory '.frozen-bubble/records' down your home directory)

=item B<--auto-record>

automatically record all applicable games (normally, a record is
triggered by hitting the Print Screen key during a game)

=item B<--comment> I<'...'>

add the comment enclosed between simple quotes to records (must
not contain anything else than ASCII), it will be shown on
console when playing back the record later

=item B<--replay> I<record_file|URL>

playback the specified record file

=item B<--save-frames> I<directory>

specify a directory where all (game) frames will be recorded; as the
game is slowed down, can only be used with --replay; warning, output
is huge as 50 frames of each 900 KB are saved per second (e.g. 43 MB
per second); a typical use case is then to build a video out of the
frames with e.g. this kind of command:

    mencoder mf:///tmp/fbframes/frame* -mf fps=50 -o /tmp/output.avi -ovc lavc -lavcopts vcodec=mpeg4

=back

=head1 AUTHOR

Written by Guillaume Cottenceau.
This manual page was originally written by Josselin Mouette <josselin.mouette at ens-lyon.org>.

Visit official homepage: L<http://www.frozen-bubble.org/>

=head1 SEE ALSO

frozen-bubble-editor

=head1 COPYRIGHT

Copyright © 2000-2012 The Frozen-Bubble Team.

This is Free Software; this software is licensed under the GPL version 2, as published by the Free Software Foundation.
There is NO warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

__END__
:endofperl
