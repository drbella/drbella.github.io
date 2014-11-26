#!/usr/bin/perl -- -w
# -------------------------------------------------------------------
#	mcounter.pl
#	
#	Page Access (Hits) Counter
#
#	CGI Magic March 1 1997
#
#	A much modified form of Matthew Wright's access counter
#	script, adding ability to specify digit fonts, number
#	of digits to display, different page identities, and in fact
#	all of the available user variables, on each separate
#	page that the counter can now appear on. This is done through an
#	added information string in the <img src> call. I have also
#	modified Matthew's Access Stats script to include page hit
#	statistics, and I have written a script called mreset.pl
#	to allow resetting of page hits stats (and the counter
#	displays).
#	The basic design is Matthew's, and I thank him for his
#	expertise. But for any errors in this script, blame me,
#	and not him! The latest version of this script can be
#	found at
#	http://www.spells.com/cgi/
#	This script is issued free of charge for any morally correct
#	use, with the proviso that by using this script the user
#	absolves all persons involved in its creation from all and any
#	liability, consequential or otherwise, arising from its use, and
#	also that the user advises us of the place it is being used by
#	email to: users@spells.com
#	so that we can have a look at any new ideas and modifications
#	and incorporate them where necessary.
#
#	Jeremy Rodwell, CGI Magic.
#
#	BH 13/11/98 added noincr option - display count with no 
#	increment.
#	BH 15/12/98 locked file from open for read till close after write 
#	- instead of two separate locks which could interfere with each other
#	BH 24/2/98 - see also the update_counter routine in CAR.m4 for calling
#	from perl routines. It probably should call this routine and remove
#	duplication.
#
# ---------------------------------------------------------------------
# ---------------------------------------------------------------------
# --- set up the variables --------------------------------------------

require "setup/mcounter.setup";
require "$cgi_lib_location";

# --- that's it for the variables you have to set up! ------------------
# ----------------------------------------------------------------------

# --- run the program:

# --- read and parse incoming form data with a routine in cgi-lib.magic 

&parse_form_data(*from_browser);

# --- give each of the short-form browser entry variables a 
# --- more understandable name

$style = 	$from_browser{'style'};
$pageref =	$from_browser{'ref'};
$digits =	$from_browser{'digits'};
$width =	$from_browser{'w'};
$height =	$from_browser{'h'};
$transparency =	$from_browser{'trans'};
$interlaced =	$from_browser{'int'};
$frame_width =	$from_browser{'fw'};
$frame_color =	$from_browser{'fc'};
$invisible =	$from_browser{'inv'};
$logo =		$from_browser{'logo'};
$uselog =	$from_browser{'log'};
$noincr = 	$from_browser{'noincr'}; # BH 13/11/98


# --- set defaults for unspecified variables

if (!$from_browser{'style'}) {$style = "mred";}	# default style
else {$style = $from_browser{'style'};} 	# is 'mred'

if (!$from_browser{'ref'}) {$pageref = "test";} # default ref
else {$pageref = $from_browser{'ref'};} 	# is 'test'

if (!$from_browser{'digits'}) {$digits = "6";} 	# default number
else {$digits = $from_browser{'digits'};} 	# of digits = 6

if (!$from_browser{'w'}) {$width = "21";} 	# default width
else {$width = $from_browser{'w'};} 		# = 21 pixels

if (!$from_browser{'h'}) {$height = "24";} 	# default height
else {$height = $from_browser{'h'};} 		# = 24 pixels

if (!$from_browser{'t'}) {$transparency = "no";} 
else {$transparency = $from_browser{'t'};} 	# default is 'no'

if (!$from_browser{'i'}) {$interlaced = "yes";} 
else {$interlaced = $from_browser{'i'};} 	# default is 'yes'

if (!$from_browser{'fw'}) {$frame_width = "0";} 
else {$frame_width = $from_browser{'fw'};} 	# default is '0'

if (!$from_browser{'fc'}) {$frame_color = "0,0,0";} 
else {$frame_color = $from_browser{'fc'};} 	# default is '0,0,0'

if (!$from_browser{'inv'}) {$invisible = "no";} 
else {$invisible = $from_browser{'inv'};} 	# default is 'no'

if (!$from_browser{'logo'}) {$logo = "X";} 
else {$logo = $from_browser{'logo'};} 		# default is 'X'

if (!$from_browser{'log'}) {$uselog = "no";} 
else {$uselog = $from_browser{'log'};} 		# default is 'yes'

if (!$from_browser{'noincr'}) {$noincr = "no";} # BH 13/11/98
else {$noincr = $from_browser{'noincr'};} 	# default is 'no'

# --- set the file lock/unlock variables

$lock = 2;
$unlock = 8;

# --- get the date for logging references

if ($uselog eq "yes") {
    &get_date;
}


# --- ensure that the script is being accessed from approved site

&check_referer;


# --- update the counter file with this new hit and page reference

&update_counter;


# --- if only a transparent dot is wanted for a secret counter, do it

&secret_counter;


# --- work out the length of the counter display

$num = $length = length($count[$count_found]);


# --- put the counter digits into array

while ($num > 0) {
    $CHAR{$num} = chop($count[$count_found]);
    $num--;
}


# --- work out the height and width of the counter image

$img_width = (($width * $length) + ($frame_width * 2));
$img_height = (($frame_width * 2) + $height);


# --- open the FLY tempfile for commands

open(FLY,">$fly_temp") || 	
    die "Can't Open In File For flock (FLY, $lock); FLY Commands: $!\n";

# --- create the new counter image as one gif image

print FLY "new\n";
print FLY "size $img_width,$img_height\n";


# --- if a frame is ordered, send those commands to FLY

&make_frame;


# --- copy the individual counter image commands to FLY

$j = 1;
while ($j <= $length) {

    print FLY "copy $insert_width,$insert_height,-1,-1,-1,-1,$digit_dir/$style/$CHAR{$j}$style\.gif\n";

    $insert_width = ($insert_width + $width); 

    $j++;

}


# --- if a transparent colour is required, make it transparent

if ($transparency ne "no" && $transparency =~ /.*,.*,.*/) {
    print FLY "transparent $transparency\n";
}

# --- if an interlaced image is required, do it

if ($interlaced eq "yes") {
    print FLY "interlace\n";
}


# --- close FLY

# BH No need to unlock as it was never locked!!! Perhaps a prior version
# had a lock - I changed the config file to make the temp FLY filename
# /tmp/fly_temp.$$.txt, instead of locking /tmp/fly_temp.txt.

#flock (FLY, $unlock);	
close(FLY);


&print_the_output;


# --- and the program ends ----------------------------------------------


# -----------------------------------------------------------------------
# --- sub routines begin
# -----------------------------------------------------------------------

sub check_referer 
{
    if (@referers && $ENV{'HTTP_REFERER'}) {
	foreach $referer (@referers) {
	    if ($ENV{'HTTP_REFERER'} =~ /$referer/) {
		
		$ref = 1;
            	last;
	    }
	}
    } else {
	$ref = 1;
    }

    if ($ref != 1) {
	print "Location: $bad_referer_img\n\n";

      	if ($uselog == 1) {
	    open(LOG,">>$error_log") || die "Can't Open User Error Log: 
		flock (LOG, $lock);		    $!\n";

	    print LOG "$error_log: $ENV{'REMOTE_HOST'} [$date] $ENV{'HTTP_REFERER'} - $ENV{'HTTP_USER_AGENT'}\n";

# BH No need to unlock as it was never locked!
#	    flock (LOG, $unlock);
	    close(LOG);
      	}

      	exit;
    }
}


# -----------------------------------------------------------------------
sub secret_counter
{

    if ($invisible eq "yes") {
	open(FLY,">$fly_temp") || die "Can't Open In File For 
		flock (FLY, $lock);		FLY Commands: $!\n";

	print FLY "new\n";
	print FLY "size 1,1\n";
	print FLY "fill 0,0,0,0,0\n";
	print FLY "transparent 0,0,0\n";

# BH No point in unlocking it as it was never locked!
#	flock (FLY, $unlock);
	close(FLY);

	&print_the_output;

    } elsif ($logo ne "X" && $logo =~ /.*tp:\/\//) {
	print "Location: $logo\n\n";

# --- log the hit

	if ($uselog eq "yes") {
	    &log_access;
	}

	exit(0);
    }
}


# -----------------------------------------------------------------------
sub make_frame 
{

    $insert_width = $insert_height = $frame_width;

    $insert_frame = 0;

    while ($insert_frame < $frame_width) {
	$current_width = ($img_width - $insert_frame);
	$current_height = ($img_height - $insert_frame);
	
	print FLY "line 0,$insert_frame,$img_width,$insert_frame, $frame_color\n";
	print FLY "line $insert_frame,0,$insert_frame,$img_height, $frame_color\n";
	print FLY "line $current_width,0,$current_width,$img_height,$frame_color\n";
	print FLY "line $current_height,0,$current_height,$img_width, $frame_color\n";

      	$insert_frame++;
    }
}


# -----------------------------------------------------------------------
sub log_access 
{

    open(LOG,">>$access_log") || die "Can't Open User Access Log: $!\n";
    flock (LOG, $lock);

    print LOG "[$date_counter] $ENV{'HTTP_REFERER'} - $ENV{'REMOTE_HOST'} - $ENV{'HTTP_USER_AGENT'}\n";

    flock (LOG, $unlock);
    close(LOG);
}


# -----------------------------------------------------------------------
sub update_counter
{

# --- check the file can be opened, if so, open it and lock it,
# --- otherwise display error message
# BH There seems to ba a race condition clobbering the counter file
# BH Possibly it's between the file being closed for the read and
# BH then opened for the write. Change to read/write access and leave
# BH locked all the time! In any case, it's an error to unlock the file
# between reading the old data and writing the new!

# BH    if (open (FILE, "<" . $count_file)) { 
    if (open (FILE, "+<" . $count_file)) { 
	flock (FILE, $lock);

# --- open file and place lines of data into arrays
	
	for ($loop=0; $loop < 3; $loop++) {

	    $line[$loop] = <FILE>;
	    $line[$loop] =~ s/\n$//;
	}

# --- extract individual entries and split at :: delimiter symbol

	@page = split("::", $line[0]);
	@count =split("::", $line[1]);

# --- unlock and close the file

# - BH No don't close until we're finished with it!
#	flock (FILE, $unlock);
#	close (FILE);

# --- find the page to be changed

	for ($loop = 0; $loop <= $#page; $loop++) {
	    if ($page[$loop] eq $pageref) {
		$count_found = $loop;

# --- $count_found now points to the $count matching the $page entry
# --- so end the search

		last;
	    }
	}

# --- increment the count (as located by $count_found) by 1
# --- for the page found at $page[$loop], if there is one

	if ($noincr ne "yes" and $page[$loop]) {
	    $count[$count_found]++;
	}

# --- if $page is not found, then $page must be new, so enter
# --- it as a new entry with 0 as the start count

	if ($page[$loop] ne $pageref) {
	    push(@page,$pageref);
	    push(@count,0);
	}

# --- if there is a call to reset the counter value, do that

	if ($reset_number != "") {
	    $count[$count_found] = $reset_number;
	}

# --- if there is a call to alter the number of digits
# --- from the default value, do it by re-formatting the entry

	if ($digits != "") {
	    if ($page[$loop]) {
		$count[$count_found] = sprintf ("%0".$digits."d", $count[$count_found]);
	    } else {
		$count[$count_found] = sprintf ("%06d", $count[$count_found]);
	    }
	}

# --- open the file, and write the new file contents

# BH No need - it's already open for read/write, just need to seek:
#	if (open (FILE, ">" . $count_file)) {
#	    flock (FILE, $lock);
	seek(FILE, 0, 0);

	print FILE join("::", @page), "\n";
	print FILE join("::", @count), "\n";

	flock (FILE, $unlock);
	close (FILE);

#	} else {
#	    &return_error (500, "Counter File Error", 
#			   "Cannot write to the Counter File $count_file.");
#	}

	
    } else {
	&return_error (500, "Counter File Error", 
		       "Cannot read/write from the Counter File $count_file.");
    }	
}

# -----------------------------------------------------------------------
sub print_the_output
{

# --- output the MIME header

    print "Content-type: image/gif\n\n";

# --- start fly and output the temp-file to it, then close fly

    if (open(RUNFLY,"$flyprog -i $fly_temp |")) {
      while(<RUNFLY>) {
	print;
      }
      close(RUNFLY);
    }

# --- scrap the old temp file

    unlink($fly_temp);

# --- log this access

    if ($uselog eq "yes") {
	&log_access;
    }

    exit(0);
}

# -----------------------------------------------------------------------
