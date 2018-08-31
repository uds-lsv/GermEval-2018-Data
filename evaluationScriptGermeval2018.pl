#! /usr/bin/perl -w

use strict;
use Getopt::Long qw(GetOptions);

my $noOfColumnsPred = 3;
my $noOfColumnsGold = 3;

my $columnForTask1 = 2;
my $columnForTask2 = 3;

my %fineGrainedLabels = ();
$fineGrainedLabels{"OTHER"}++;
$fineGrainedLabels{"ABUSE"}++;
$fineGrainedLabels{"INSULT"}++;
$fineGrainedLabels{"PROFANITY"}++;

my %coarseGrainedLabels = ();
$coarseGrainedLabels{"OTHER"}++;
$coarseGrainedLabels{"OFFENSE"}++;

my $help;
my $whichTask;
my $task1;
my $task2; 

my $predFile;
my $goldFile;

################# ACTUAL MAIN PART ##################


GetOptions(
    'help|h' => \$help,
    'pred=s' => \$predFile,
    'gold=s' => \$goldFile,
    'task=s' => \$whichTask,
);

my $usage = <<"END_MESSAGE";
Usage:
perl evaluationScriptGermeval2018.pl --pred <file> --gold <file> --task <task-number>

Options:
    --pred <file>
        <file> represents the prediction file;
        this is an obligatory parameter
    --gold <file>
        <file> represents the gold standard file
        this is an obligatory parameter
    --task <task-number>
        for <task-number> choose between 1 for TASK1 and 2 for TASK2;
        if you do not specify this parameter, the evaluation tool will evaluate for all tasks
END_MESSAGE


if(defined($help)){
    die "EVALUATION TOOL FOR GERMEVAL SHARED TASK (version 1.0)\n\n$usage";
} else {
    if(defined($whichTask)){
	if($whichTask == 1){
	    $task1 = 1;
	    print "Evaluate on TASK1!\n\n";
	} elsif($whichTask == 2){
	    $task2 = 1;
	    print "Evaluate on TASK2!\n\n";
	} else {
	    die "ERROR: you specified \"$whichTask\" as a task parameter; this parameter is not defined!\n\n$usage";
	}
	
    } else {
	print "Found no valid task flag; therefore evaluating for all tasks.\n\n";
    }

    if((!(defined($predFile))) && (!(defined($goldFile)))){
	die "ERROR: neither prediction file nor gold standard file were specified!\n\n$usage";
    }


    if(!(defined($predFile))){
	die "ERROR: no prediction file was specified!\n\n$usage";
    } else {
	if(!(-e $predFile)){
	    die "ERROR: the prediction file $predFile does not exist!\n";
	}
    }

    if(!(defined($goldFile))){
	die "ERROR: no gold standard file was specified!\n\n$usage";
    } else {
	if(!(-e $goldFile)){
	    die "ERROR: the gold standard file $goldFile does not exist\n";
	}
    }


}

checkWellFormednessOfFiles($predFile,$goldFile);

if(($task1)||
   ((!($task1)) && (!($task2)))){
    #evaluate task 1
    print "****************************TASK 1: COARSE ************************\n";
    evaluateTask($predFile,$goldFile,\%coarseGrainedLabels,$columnForTask1);
    print "*******************************************************************\n\n";
}

if(($task2)||
   ((!($task2)) && (!($task1)))){
    # evaluate task 2
    print "****************************TASK 2: FINE **************************\n";
    evaluateTask($predFile,$goldFile,\%fineGrainedLabels,$columnForTask2);
    print "*******************************************************************\n\n";
}




############### SUBROUTINES ###################

sub roundNumber{
    my $value = shift;
    my $rounded = int(100 * $value + 0.5) / 100;
    return $rounded;
}

sub evaluateTask{
    my $predFile = shift;
    my $goldFile = shift;
    my %labels = %{shift(@_)};
    my $columnToEval = shift;

    my @labelsList = sort {$a cmp $b}(keys(%labels));

    my ($correct,$total,$acc) = evalAccuracy($predFile,$goldFile,$columnToEval);
    printf ("ACCURACY: %.2f (correct\=%d; total instances\=%d)\n", $acc,$correct,$total);
    
    my $sumPrec = 0;
    my $sumRec = 0;
    foreach my $label(@labelsList){

	my ($prec,$rec,$f) = evalPrecRecFForLabel($predFile,$goldFile,$columnToEval,$label);
	$sumPrec = $prec + $sumPrec;
	$sumRec = $rec + $sumRec;

	$prec = roundNumber($prec*100);
	$rec = roundNumber($rec*100);
	$f = roundNumber($f*100);
	printf("CATEGORY \"${label}\": precision\=%.2f recall\=%.2f fscore\=%.2f\n",$prec,$rec,$f);
	
    }
    
    # compute average precision, recall, f
    my $avgPrec = 0;
    my $avgRec = 0;
    my $avgF = 0;

    if(@labelsList > 0){
	$avgPrec = $sumPrec / @labelsList;
	$avgRec = $sumRec / @labelsList;
    }
    
    my $avgFDenom = $avgPrec + $avgRec;
    if($avgFDenom > 0){
	$avgF = (2 * $avgPrec * $avgRec) / $avgFDenom;
    }

    $avgPrec = roundNumber($avgPrec*100);
    $avgRec = roundNumber($avgRec*100);
    $avgF = roundNumber($avgF*100);

    printf("AVERAGE: precision\=%.2f recall\=%.2f fscore\=%.2f\n",$avgPrec,$avgRec,$avgF);
}


sub evalPrecRecFForLabel{
    my $predFile = shift;
    my $goldFile = shift;
    my $columnToEval = shift;
    my $label = shift;

	
    my $tp = 0;
    my $fp = 0;
    my $fn = 0;
    
    open(INFP,$predFile);
    open(INFG,$goldFile);
    while(my $linePred = <INFP>){
	chomp($linePred);
    $linePred =~ s/^\s+|\s+$//g;
	my $lineGold = <INFG>;
	chomp($lineGold);
    $lineGold =~ s/^\s+|\s+$//g;
	
	my @predColumns = split(/\t/,$linePred);
	my @goldColumns = split(/\t/,$lineGold);
	
	my $predLabel = $predColumns[$columnToEval -1];
	my $goldLabel = $goldColumns[$columnToEval -1];
	
	if($goldLabel eq $label){
	    if($predLabel eq $label){
		$tp++;
	    } else {
		$fn++;
	    }
	} elsif($predLabel eq $label){
	    $fp++;
	}
	
    }
    close(INFG);
    close(INFP);
    
    my $prec = 0;
    my $precDenom = $fp + $tp;
    if($precDenom > 0){
	$prec = $tp / $precDenom;
    }
    
    
    my $recall = 0;
    my $recallDenom = $fn + $tp;
    if($recallDenom > 0){
	$recall = $tp / $recallDenom;
    }
    
    
    my $f = 0;
    my $fDenom = $prec + $recall;
    if($fDenom > 0){
	$f = (2 * $prec * $recall) / $fDenom;
    }
    
  
    return ($prec,$recall,$f);
}

sub evalAccuracy{
    my $predFile = shift;
    my $goldFile = shift;
    my $columnToEval = shift;

    my $total = 0;
    my $correct = 0;

    open(INFP,$predFile);
    open(INFG,$goldFile);
    while(my $linePred = <INFP>){
	chomp($linePred);
    $linePred =~ s/^\s+|\s+$//g;

	my $lineGold = <INFG>;
	chomp($lineGold);
    $lineGold =~ s/^\s+|\s+$//g;
	
	my @predColumns = split(/\t/,$linePred);
	my @goldColumns = split(/\t/,$lineGold);

	my $predLabel = $predColumns[$columnToEval -1];
	my $goldLabel = $goldColumns[$columnToEval -1];

	if($predLabel eq $goldLabel){
	    $correct++;
	}
	$total++;
    }
    close(INFG);
    close(INFP);

    my $acc = 0;
    if($total > 0){
	$acc = $correct / $total;
    }

    return ($correct,$total,$acc*100);
}

sub checkWellFormednessOfFiles{
    my $noOfLinesCheck = checkNoOfLinesOfFiles($predFile,$goldFile);
    
    if($noOfLinesCheck == 1){

	# irrespective of what task is evaluated
	# both prediction and gold file always have to comprise
	# exactly 3 columns
	checkNoOfColumns($predFile,$noOfColumnsPred);
	checkNoOfColumns($goldFile,$noOfColumnsGold);

	if((defined($task1))||
	   ((!(defined($task1)))&&(!(defined($task2))))){
	    checkLabelsOfColumn($predFile,$columnForTask1,\%coarseGrainedLabels);
	    checkLabelsOfColumn($goldFile,$columnForTask1,\%coarseGrainedLabels);
	}

	if((defined($task2))||
	   ((!(defined($task2)))&&(!(defined($task1))))){
	   checkLabelsOfColumn($predFile,$columnForTask2,\%fineGrainedLabels);
	   checkLabelsOfColumn($goldFile,$columnForTask2,\%fineGrainedLabels);
	}

	if((!($task1)) && (!($task2))){
	    checkLabelsOfColumn($goldFile,$columnForTask1,\%coarseGrainedLabels);
	    checkLabelsOfColumn($predFile,$columnForTask1,\%coarseGrainedLabels);
	    checkLabelsOfColumn($goldFile,$columnForTask2,\%fineGrainedLabels);
	    checkLabelsOfColumn($goldFile,$columnForTask2,\%fineGrainedLabels);
	}

    } elsif($noOfLinesCheck == 0) {
	die "ERROR: files are incompatable (different number of lines)!\nHint: maybe you have some empty lines in one of the files -- please remove them!";
    } elsif($noOfLinesCheck == -1){
	die "ERROR: two empty files\n";
    }
}

sub checkLabelsOfColumn{
    my $file = shift;
    my $columnIndex = (shift)-1;
    my $labelsRef = shift;

    open(INF,$file);
    while(my $line = <INF>){
	chomp($line);
    $line =~ s/^\s+|\s+$//g;
	my @columns = split(/\t/,$line);
	my $cell = $columns[$columnIndex];
	if(!(defined($labelsRef->{$cell}))){
	    die "ERROR: line \"${line}\" of file $file contains unknown label $cell!\n"; 
	}
    }
    close(INF);
}

sub checkNoOfColumns{
    my $file = shift;
    my $columnsToHave = shift;

    open(INF,$file);
    while(my $line = <INF>){
	chomp($line);
    $line =~ s/^\s+|\s+$//g;
	my @columns = split(/\t/,$line);
	my $noOfColumnsInLine = @columns;
	if($columnsToHave != $noOfColumnsInLine){
	    die "ERROR: line \"${line}\" of file $file contains $noOfColumnsInLine columns; however it should have $columnsToHave columns!\n";
	}
    }
    close(INF);
}

sub checkNoOfLinesOfFiles{
    my $file1 = shift;
    my $file2 = shift;

    my @linesOfFile1 = readLinesFromFile($file1);
    my @linesOfFile2 = readLinesFromFile($file2);

    my $sizeOfFile1 = @linesOfFile1;
    my $sizeOfFile2 = @linesOfFile2;

    if($sizeOfFile1 != $sizeOfFile2){
	return 0;
    } elsif($sizeOfFile1 == 0){
	return -1;
    } else {
	return 1;
    }
}

sub readLinesFromFile{
    my $file = shift;
    my @lines = ();
    open(INF,$file);
    while(my $line = <INF>){
	chomp($line);
    $line =~ s/^\s+|\s+$//g;
	push(@lines,$line);
    }
    close(INF);
    return @lines;
}
