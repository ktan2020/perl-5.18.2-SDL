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
# ****************************************************************************
#
#                          Frozen-Bubble Level Editor
#
# Copyright (c) 2002 - 2004 Kim Joham and David Joham <[k|d]joham@yahoo.com>
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
#
# *****************************************************************************
#
# Design & Programming by Kim Joham and David Joham, October 2002 to January 2003
# Email - [k|d]joham at yahoo.com
#
# *****************************************************************************

use SDLx::App;
use Games::FrozenBubble::Config;
use Games::FrozenBubble::Stuff;
use Games::FrozenBubble::LevelEditor;

$FPATH = $Games::FrozenBubble::Config::FPATH;
$FLPATH = $Games::FrozenBubble::Config::FLPATH;

# command line options modified from frozen-bubble code
local $_ = "@ARGV";

/-h/ and die 'Usage:  [OPTION]...
-h, --help                      display this help screen
-cb, --colourblind              use bubbles for colourblind people
-ls<filename>,
        --levelset<filename>    directly start with the specified levelset name
-l<#n>, --level<#n>             directly start the n-th level
-fs, --fullscreen               start in fullscreen mode
';

/-cb/ || /-co/ and $colourblind = 1;
$FBLE::levelset_name = /-ls\s*(\S+)/ || /-levelset\s*(\S+)/ ? $1 : 'default-levelset';
$FBLE::curr_level = /-l\s*(\d+)/ || /-level\s*(\d+)/ ? $1 : 1;
$FBLE::command_line_fullscreen = to_bool(/-fs/ || /-fullscreen/);

my $app = SDLx::App->new(icon => "$FPATH/gfx/pinguins/window_icon_penguin.png",
                        title => 'frozen-bubble level editor',
                        width => 640, height => 480);

Games::FrozenBubble::LevelEditor::init_setup('stand-alone', $app->surface());
Games::FrozenBubble::LevelEditor::handle_events();

__END__

=encoding UTF-8

=head1 NAME

frozen-bubble-editor - a level editor for Frozen Bubble

=head1 SYNOPSIS

    frozen-bubble-editor [OPTION]...

=head1 DESCRIPTION

This editor lets you manipulate level-sets, in which you can add, remove
and modify levels thanks to a mouse-oriented interface (there are also
many interesting keyboard shortcuts). The interface is very
straightforward: click on the written planches on the left an right parts
of the screen to perform the relevant actions, and on the level area to
change the bubble color; use the "void" bubble (or right-click) to
remove a bubble.

=head1 OPTIONS

=over

=item B<-h>, B<--help>

show command-line options summary

=item B<-fs>, B<--fullscreen>

start in fullscreen mode

=item B<-ls> I<FILENAME>, B<--levelset> I<FILENAME>

directly start with the specified levelset name

=item B<-l> I<NUMB>, B<--level> I<NUMB>

directly start the level number I<NUMB>

=item B<-cb>, B<--colourblind>

use special bubbles for colourblind people

=back

=head1 KEY SHORTCUTS

The following key shortcuts are available during level edition:

=over

=item B<F1>

displays the help dialog

=item B<p>, B<h>, B<left>

previous level

=item B<n>, B<l> , B<right>

next level

=item B<up>

first level

=item B<down>

last level

=item B<a>

append level

=item B<i>

insert level

=item B<d>

delete level

=item B<]>

move level right

=item B<[>

move level left

=item B<j>

jump to level (after B<j>, enter level number, then B<Return>)

=item B<o>

open levelset

=item B<s>

save levelset

=item B<f>

toggle fullscreen

=item B<q>, B<Escape>

quit

=back

During dialogs, you may use B<Return> to accept and B<Escape> to cancel.

=head1 AUTHOR

Written by Kim Joham and David Joham <[k|d]joham at yahoo.com>.
Integration work by Guillaume Cottenceau <guillaume.cottenceau at free.fr>.
This manual page was written by Guillaume Cottenceau.

Visit official homepage: L<http://www.frozen-bubble.org/>

=head1 SEE ALSO

frozen-bubble

=head1 COPYRIGHT

Copyright © 2002, 2003 Kim Joham and David Joham <[k|d]joham at yahoo.com>.

This is Free Software; this software is licensed under the GPL version 2, as published by the Free Software Foundation.
There is NO warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

__END__
:endofperl
