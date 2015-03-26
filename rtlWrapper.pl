#!/usr/bin/perl

use strict;
use Getopt::Long;

$0=~s/^.+\///;

chomp(my($rtlPowerCommand)=`which rtl_power`);
chomp(my($sysTimeNow)=`date +%s`);
chomp(my($yyyMmDd)=`date +%Y%m%d`);
chomp(my($computerInfo)=`uname -a`);

my($logDirectory)="~/log";
my($tmpDirectory)="~/tmp";
my($dataDirectory)="~/data";
my($configDirectory)="$dataDirectory/config";
my($configFile)="definedScans.cf";
my($logFile)=$logDirectory."/$0.$sysTimeNow.log";
my($Fmin,$Fmax,$numberOfBuckets,$intInterval,$exitTimer,$deviceNumber,$rawOutputFilename,$definedScan,$commandLineArguments);

open(LOG,"+>$logFile");

print LOG "[$0] $computerInfo\n";


GetOptions ("Fmin=s" => \$Fmin,
	    "Fmax=s" => \$Fmax,
	    "b=s"    => \$numberOfBuckets,
	    "i=s"    => \$intInterval,
	    "e=s"    => \$exitTimer,
	    "d=s"    => \$deviceNumber,
	    "c=s"    => \$definedScan,
	    "o=s"    => \$rawOutputFilename
    );

$rawOutputFilename=$rawOutputFilename.".".$sysTimeNow;


if(!$definedScan) {
    validateOptions();
    $commandLineArguments=assembleCommandLineOptions();
}

#getDefinedScan();
my($commandToExecute)="sudo ".$rtlPowerCommand.$commandLineArguments;
runCommand();


sub getDefinedScan {
    if($definedScan) {
	open(CF,"$configDirectory/definedScans.cf");
	while(<CF>) {
	    if($_=~/$definedScan\|(.+)/) {
		print "[getDefinedScan] found scan [$definedScan]. setting command line arguments to [$1]\n";
		$commandLineArguments=$1;
	    }
	}
    }
}

sub runCommand {
    my($exitStatus)==`$commandToExecute &`;
    print "[$exitStatus]\n";
}

sub validateOptions {
    print LOG "[validateOptions] Validating command line options.\n";
    if((!$Fmin)|(!$Fmax)|(!$numberOfBuckets)|(!$rawOutputFilename)) {
	print "[validateOptions] You must specify AT LEAST a frequency minimum [-Fmin], frequency maximum [-Fmax], number of buckets [-b], and an output file name for all your data.\n";
	exit(666);
    }
    return(0);
}

sub assembleCommandLineOptions {
    print LOG "[assembleCommandLineOptions] Building command line options for [$rtlPowerCommand].\n";
    my($tmpCommandLine)=" -f ".$Fmin.":".$Fmax.":".$numberOfBuckets;
    if($intInterval) {
	$tmpCommandLine=$tmpCommandLine." -i ".$intInterval;
	print LOG "[assembleCommandLineOptions] Using integration interval [$intInterval].\n";
    }
    if($exitTimer) {
	$tmpCommandLine=$tmpCommandLine." -e ".$exitTimer;
	print "[assembleCommandLineOptions] Using an exit timer set for [$exitTimer]. I WILL EXIT IN [$exitTimer]\n";
    }
    if($deviceNumber) {
	$tmpCommandLine=$tmpCommandLine." -d ".$deviceNumber;
	print LOG "[assembleCommandLineOptions] Using device [$deviceNumber].\n";
    }
    $tmpCommandLine=$tmpCommandLine." ".$rawOutputFilename;
    print LOG "[assembleCommandLineOptions] Using command line options [$tmpCommandLine]\n";
    return($tmpCommandLine);
}


