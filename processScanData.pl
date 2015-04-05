#!/usr/bin/perl 

use strict;
use Getopt::Long;
use List::Util qw(max min);

$0=~s/^.+\///;

chomp(my($hostInfo)=`uname -a`);
chomp(my($gnuPlotExecutable)=`which gnuplot`);
my($fileToProcess,$outPutImageName,$processedScan,$execGnuPlot,$up)=();
my($dbHigh,$dbLow,$rangeHigh,$rangeLow)=();
my(%dataHash)=();
my(@formattedOutput,@gains,@range)=();
chomp(my($systimeNow)=`date +%s`);

my($sleepTime)=10;
my($upConverterOffset)="125000000";
my($dataDirectory)="$ENV{DATA}";
my($configDirectory)="$ENV{CONFIG}";
my($rawScanDirectory)="$ENV{RAW_SCANS}";
my($imagesDirectory)="$ENV{SCAN_IMAGES}";
my($gnuplotScriptBase)="$ENV{GNUPLOT_SCRIPTS}";
my($processedScanData)="$ENV{PROC_SCANS}";
my($gpScriptName)="$gnuplotScriptBase/gnuplot.".$systimeNow.".gp";


GetOptions (
    "f=s" => \$fileToProcess,
    "o=s" => \$outPutImageName,
    "u"   => \$up,
    "x"   => \$execGnuPlot
    );

print dateTimeNow()."[$0] [$hostInfo]\n";
loadRawScanData($fileToProcess);
print dateTimeNow()."[$0] Calculating range.\n";
my(@rangeHighLow)=getHighLow(@range);
addBlanks();

$dbHigh=max(@gains);
$dbLow=min(@gains);
$rangeHigh=@rangeHighLow[0];
$rangeLow=@rangeHighLow[1];

print dateTimeNow()."\t=========================================================================\n";
if($up) {
print dateTimeNow()."\tUsing offset of [$upConverterOffset] for upconverter\n";
}
print dateTimeNow()."\tdbMax                : $dbHigh\n";
print dateTimeNow()."\tdbMin                : $dbLow\n";
print dateTimeNow()."\tXmax                 : $rangeHigh\n";
print dateTimeNow()."\tXmin                 : $rangeLow\n";
print dateTimeNow()."\tData points          : ".scalar(@formattedOutput)."\n";
print dateTimeNow()."\tData out             : $processedScan\n";
print dateTimeNow()."\tGnuplot script       : $gpScriptName\n";
print dateTimeNow()."\t=========================================================================\n";

writeGnuplotScript();

if($execGnuPlot) {
    print dateTimeNow()."\tImage out            : $imagesDirectory/$outPutImageName\n";
    print dateTimeNow()."[execGnuPlot] sleeping for $sleepTime seconds (waiting for text file)\n";
    sleep($sleepTime);
    print dateTimeNow()."[execGnuPlot] Executing gnuplot script [$gpScriptName]\n";
    exec($gpScriptName) or die "Can't execute Gnuplot script: $!\n";
}

print dateTimeNow()."Done.\n";

sub addBlanks {
    print dateTimeNow()."[addBlanks] Separating iso lines with blanks.\n";
    foreach my $dataLine (@formattedOutput) {
	chomp(my($dateTime,$frequency,$gain)=split(/,/,$dataLine));
	my($trimmedDataLine)="$dateTime,$frequency,$gain";
	push(@{$dataHash{$dateTime}},"$trimmedDataLine\n");
    }
    my(@sortedDateTime)=sort(keys(%dataHash));
    $fileToProcess=~s/^.+\///;
    $processedScan="$processedScanData/$fileToProcess.processed";
    print dateTimeNow()."[addBlanks] Printing processed scan data to [$processedScan].\n";
    open(FOUT,"+>$processedScan");
    foreach my $xValue (@sortedDateTime) {
	print FOUT @{$dataHash{$xValue}};
	print FOUT "\n";
    }
    undef(%dataHash);
    close(FOUT);
}

sub loadRawScanData {
    my($rawData)=shift;
    my($hGain,$lGain)=();
    print dateTimeNow()."[loadRawScanData] Loading scan data [$rawData].\n";
    open(DATA,"$rawData");
    while(<DATA>) {
	chomp(my($date,$time,$freqLow,$freqHigh,$freqStep,$numSamples,$gain,undef)=split(/,/,$_));
	next if ($_=~/^#|$\s/);
	next if ($gain=~/nan/);
	my($dateTime)=$date." ".$time;
	my($truFreq)=$freqLow + ($numSamples * $freqStep);
	if($up) {
		$truFreq=$truFreq-$upConverterOffset;
	}
	my($dataLine)="$dateTime,$truFreq,$gain";
	push(@formattedOutput,"$dataLine\n");
	push(@gains,$gain);
	push(@range,$dateTime);
    }
    close(DATA);
    print dateTimeNow()."[loadRawScanData] Found [".scalar(@formattedOutput)."] data entries.\n";
    print "$lGain,$hGain\n";
    close(DATA);
}

sub getHighLow {
    print dateTimeNow()."[getHighLow] Calculating hi/low falues.\n";
    my(@results)=();
    my(@data)=@_;
    my(@sortedData)=sort {$a <=> $b}@data;
    $results[0]=$data[scalar(@data)-1];
    $results[1]=$sortedData[0];
    print dateTimeNow()."[getHighLow] Done with hi/low.\n";
    return(@results);
    undef(@sortedData);
}

sub dateTimeNow {
    chomp(my($dateAndTimeNow)=`date +%H:%M:%S.%N`);
    print "[$dateAndTimeNow]";
}

sub writeGnuplotScript {   
    print dateTimeNow()."[writeGnuplotScript] Generating Gnuplot script.\n";
    open(GNUPLOT,"+>$gpScriptName");
    print GNUPLOT <<EOF;
#!$gnuPlotExecutable
set xlabel "Time" font "arial,8"
set ylabel "Frequency (Hz)" font "arial,8"
set zlabel "Gain (dBm)" font "arial,8"
set grid lc rgbcolor "#BBBBBB"
set timefmt '%Y-%m-%d %H:%M:%S'
set format y "%1.3f"
set format x "%Y-%m-%d %H:%M"
set xdata time
set xrange ["$rangeLow":"$rangeHigh"]
set zrange[$dbLow:$dbHigh]
unset key
set datafile separator ","
set pm3d interpolate 5,5
set view 0,180,0.98
set pm3d map
set terminal pngcairo crop
set term png enhanced size 2000,1000 enhanced font 'Verdana,10'
reportdatetime = "`date +'%Y-%m-%d'`"
reportpng = '$imagesDirectory/$outPutImageName'
set output '$imagesDirectory/$outPutImageName'
print reportpng
splot '$processedScan' u 1:2:3 with pm3d
EOF
close(GNUPLOT);
system("chmod a+x $gpScriptName")
}
