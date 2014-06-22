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

use strict;
use warnings;

use lib 'lib';
use Games::PangZero;


eval {
  Games::PangZero::Initialize();
  #Games::PangZero::DoDemo() while 1;
  #while (1) { Games::PangZero::DoRecordDemo(); $Games::PangZero::App->delay(2000); }
  while (1) {
    Games::PangZero::MainLoop();
  }
};
if ($@) {
  my $errorMessage = $@;
  Games::PangZero::ShowErrorMessage($errorMessage);
  die $errorMessage;
}

__END__
:endofperl
