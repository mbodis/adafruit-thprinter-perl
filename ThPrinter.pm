#use lib "/root/perl5/lib";


# # # # # # # # # # # # # # # # # # #
# @author: Miroslav Bodis 
# 2015-05-03
# 
# Adafruit thermal printer library
# printer version: 2.68 2013-06-07
# 
# product: http://www.adafruit.com/product/597
# documentation: http://www.adafruit.com/datasheets/A2-user%20manual.pdf
# 
# 
# added custom method:
#  printing image with gradient effect
# 
# 
# dependency:
# 	libdevice-serialport-perl
#   ImageMagick-perl
#   Image::Imlib2
#   libtext-unaccent-perl
# 
# # # # # # # # # # # # # # # # # # #

use Device::SerialPort qw( :PARAM :STAT 0.07 );
use Image::Imlib2;
use Time::HiRes;
use utf8;
use Unicode::Normalize;
use Text::Unaccent;
use lib "./helper";
use Cp437Helper;
use Cp850Helper;

package ThPrinter;

my $printer;
my $Cp437Helper = new Cp437Helper();
my $Cp850Helper = new Cp850Helper();

# constructor
sub new {
	my $class = shift; # $_[0] contains the class name
	my $in_port = shift; # $_[1] contains the value of port
	my $self = {
		# hardware settings
		heatingDots => 7,		#7		<0 - 30>
		heatTime => 80, 		#80		<3 - 255>
		heatInterval => 25,		#25		<0 - 255>
		density => 31,			#31		<0 - 31>
		break_time => 7,		#7		<0 - 7>
	
		# timouts
		timeout_text => 0.01,
		timeout_bitmap => 0.001, 			# 0.000005
		timeout_bitmap_gradient => 0.002, 	# 0.001, 0.002, 0.003 slow but ok
		timeout_barcode => 1,				# 1 		
		
		# colored images thrashold
	    rgb_threshold => 48, # if average of RGB channel is less than print white
    	alpha_threshold => 127, 	# pixels with less alpha are white

		#other
		code_table => 0,
		img_pos => 0, # printed image position (if image is smaller than 384) 0=left, 1=center, 2=right

		#debug
		save_print_img => 1 # save image to disk 1/0 == true/false

	};
	bless $self, $class; # make $self an object of class $class

	#inicialize printer
	$self->initPrinter($in_port);
	$self->initSettings();
	$self->setControllParameterCommand($self->{heatingDots}, $self->{heatTime}, $self->{heatInterval});
	$self->setPrintingDensity($self->{density}, $self->{break_time});

	return $self; # a constructor always returns an blessed() object	
}

sub initPrinter(){
	my ( $self, $port ) = @_;

	if (length($port) == 0){
		$port = "/dev/ttyAMA0";
		# $port = "/dev/ttyS0";
	}
	$printer = new Device::SerialPort($port); 
	# $printer->user_msg(ON); 
	$printer->baudrate(19200); 
	$printer->parity("none"); 
	$printer->databits(8); 
	$printer->stopbits(1); 
	$printer->handshake("xoff"); 
	$printer->write_settings;

	$printer->lookclear; 
}

sub sleep(){
	my ( $self, $time) = @_;
	Time::HiRes::sleep($time);
}

#
# because of limited printer buffer
# print string by char and wait some time 
# 
# 
#
sub printText(){
	my ( $self, $msg, $empty_line ) = @_;

	my ($chr, $chrI);
	for (my $var = 0; $var < length($msg); $var++) {

		$chr = substr($msg, $var, 1);

		# get char by PC437 table		
		if ($self->{code_table} == 0){		
			$chrI = $Cp437Helper->charToInt($chr);

		# get char by PC850 table		
		}elsif ($self->{code_table} == 2){
			$chrI = $Cp850Helper->charToInt($chr);

		# else	
		}else{
			$chr = Text::Unaccent::unac_string("UTF-8", $chr);
		}


		if ($chrI){
			$printer->write(chr($chrI));	
		}else{
			$chr = Text::Unaccent::unac_string("UTF-8", $chr);
			$printer->write($chr);	
		}
		$self->sleep($self->{timeout_text});
				
	}

	if (length($empty_line) == 0){
		$self->printAndLinefeed();
	}
}

# # # # # # # # # # # # # # # # # # #
# 			PRINT COMMANDS 			#
# # # # # # # # # # # # # # # # # # #

# prints the data in printer buffer and feeds one line.
# When the print buffer is empty, LF feeds one line.
sub printAndLinefeed(){
	my ( $self) = @_;
	$printer->write(chr(10));
}

# TAB position is 4 chars position
sub jumpToTabPosition(){
	my ( $self) = @_;
	
	# $printer->write(chr(9)); #not works ?
	for (my $i=0; $i<4; $i++){
		$printer->write(chr(32));
		
	}	
}

#
# print data from buffer
# 
sub printDataFromBuffer(){
	my ( $self) = @_;

	$printer->write(chr(12));
}

#
# turn printer on
# 
sub setPrintOnline(){
	my ( $self) = @_;

	$printer->write(chr(27));
	$printer->write(chr(61));
	$printer->write(chr(10));
}

#
# turn printer off
# need to run init printer again
# 
sub setPrintOffline(){
	my ( $self) = @_;

	$printer->write(chr(27));
	$printer->write(chr(61));
	$printer->write(chr(0));
}

# # # # # # # # # # # # # # # # # #
# 			LINE SPACING  		  #
# # # # # # # # # # # # # # # # # #

#
# select default line spacing
# 
sub defaultSpacing(){
	my ( $self) = @_;
	$printer->write(chr(27));
    $printer->write(chr(50));
}

#
# n pixels spacing
# 
sub setSpacing(){
	my ( $self, $n) = @_;

	# 32 points is default	
	if (length($n) > 0 && $n >= 0 && $n <= 255){

		$printer->write(chr(27));
	    $printer->write(chr(51));
	    $printer->write(chr($n));
	}else{
		$self->invalidInput("setSpacing");
	}
}

#    
# L, C, R - set text alignment   
# 
sub setTextAlign(){
	my ( $self, $align) = @_;

	$res_align = 0;		

	if ($align eq 'L'){
		$res_align = 0;		
	}elsif ($align eq 'C'){
		$res_align = 1;		
	}elsif ($align eq 'R'){
		$res_align = 2;		
	}

	$printer->write(chr(27));
    $printer->write(chr(97));
    $printer->write(chr($res_align));
}

#
# set left space
#  Set the left space with dots
# Left space is nL+nH*256,unit:0.125mm
# 
# $nL 0-255 left margin
# $nH 0-255 top margin
# 
sub setLeftSpace(){
	my ( $self, $nL, $nH) = @_;	

	if (length($nL) > 0 && $nL>=0 && $nL <= 255
		&& $nH>=0 && $nH <= 255){
	    $printer->write(chr(27));
	    $printer->write(chr(36));

	    $printer->write(chr($nL));
	    $printer->write(chr($nH));
    }else{    	
		$self->invalidInput("setLeftSpace");
    }
}

#
# set left blank char nums
# Default is 0
# 0 ≤ m ≤ 47
# 
sub setLeftSpaceChars(){
	my ( $self, $n) = @_;

	if (length($n) > 0 && $n>=0 && $n <= 47){
		$printer->write(chr(27));
	    $printer->write(chr(66));
	    $printer->write(chr($n));
	}else{		
		$self->invalidInput("setLeftSpaceChars");
	}
}



# # # # # # # # # # # # # # # # # # # # # #
# 			CHARACTER COMMAND 			  #
# # # # # # # # # # # # # # # # # # # # # #

sub setFontEnlargeOn(){
	my ( $self) = @_;

	$printer->write(chr(29));
    $printer->write(chr(33));
    $printer->write(chr(1));
}

sub setFontEnlargeOff(){
	my ( $self) = @_;

	$printer->write(chr(29));
    $printer->write(chr(33));
	$printer->write(chr(0));
}

sub setBoldOn(){
	my ( $self ) = @_;

	$printer->write(chr(27));
    $printer->write(chr(69));
    $printer->write(chr(1));
}

sub setBoldOff(){
	my ( $self) = @_;

	$printer->write(chr(27));
    $printer->write(chr(69));
	$printer->write(chr(0));
}

sub setBoldOn_2(){
	my ( $self ) = @_;

	$printer->write(chr(27));
    $printer->write(chr(32));
    $printer->write(chr(1));
}

sub setBoldOff_2(){
	my ( $self) = @_;

	$printer->write(chr(27));
    $printer->write(chr(32));
	$printer->write(chr(0));
}

sub setDoubleWidthOn(){
	my ( $self) = @_;

	$printer->write(chr(27));
    $printer->write(chr(14));
}

sub setDoubleWidthOff(){
	my ( $self) = @_;

	$printer->write(chr(27));
    $printer->write(chr(20));
}

sub setUpsidedownOn(){
	my ( $self) = @_;

	$printer->write(chr(27));
    $printer->write(chr(123));
	$printer->write(chr(1));
}

sub setUpsidedownOff(){
	my ( $self) = @_;

	$printer->write(chr(27));
    $printer->write(chr(123));
	$printer->write(chr(0));
}

sub setInverseOn(){
	my ( $self) = @_;

	$printer->write(chr(29));
    $printer->write(chr(66));
	$printer->write(chr(1));
}

sub setInverseOff(){
	my ( $self) = @_;

	$printer->write(chr(29));
    $printer->write(chr(66));
	$printer->write(chr(0));
}

#
# set underline height 1, 2 pixel height
#
sub setUnderlineOn(){
	my ( $self, $n) = @_;
	
	if (!(length($n) > 0 && $n >= 1 && $n <= 2)){
		$n = 1;
	}

	$printer->write(chr(27));
    $printer->write(chr(45));
	$printer->write(chr($n));
}

sub setUnderlineOff(){
	my ( $self) = @_;

	$printer->write(chr(27));
    $printer->write(chr(45));
	$printer->write(chr(0));
}

sub setUserDefinedCharsOn(){
	my ( $self) = @_;

	$printer->write(chr(27));
    $printer->write(chr(37));
	$printer->write(chr(1));
}

sub setUserDefinedCharsOff(){
	my ( $self) = @_;

	$printer->write(chr(27));
    $printer->write(chr(37));
	$printer->write(chr(0));
} 

#
# test of custom char - char is fully black
# 
sub defineUserDefinedCharactersTest(){
	my ( $self, $chr) = @_;

	if ($chr >=32 && $chr<=126){
		# s= 3,32≤ n ≤ m < 127
		my $s = 3; #character height bytes 3==(24dots)
		my $w = 12; #character width 0~12(s==3)
		my $n = $chr; # user-defined character starting code <32 - 126>
		my $m = $chr; # user-defined character ending code <n - 126>
		$printer->write(chr(27));
		$printer->write(chr(38));
		$printer->write(chr($s));
		$printer->write(chr($n));
		$printer->write(chr($m));
		$printer->write(chr($w));
		
		#dx: data x = s*w	
		for (my $x = 0; $x < $s*$w; $x++) {
			$printer->write(chr(255));
		}	
	}else{
		$self->invalidInput("defineUserDefinedCharactersTest");	
	}
	
}

#
# define custom character
# $chr - define a char to replace
# $filename - bitmap of new char 12x24px (binary image)
# 
sub defineUserDefinedCharactersByBitmap(){
	my ( $self, $chr, $filename) = @_;

	if ($chr >=32 && $chr<=126){
		# s= 3,32≤ n ≤ m < 127
		my $s = 3; #character height bytes 3==(24dots)
		my $w = 12; #character width 0~12(s==3)
		my $n = $chr; # user-defined character starting code <32 - 126>
		my $m = $chr; # user-defined character ending code <n - 126>

		$printer->write(chr(27));
		$printer->write(chr(38));
		$printer->write(chr($s));
		$printer->write(chr($n));
		$printer->write(chr($m));
		$printer->write(chr($w));

		my $image = Image::Imlib2->load($filename);
	
		my $width = $image->get_width;
		my $height = $image->get_height;	

		if ($width != 12 || $height !=24 ){
			$self->invalidInput("defineUserDefinedCharactersByBitmap img should be 12x24 px");
			return;
		}

		my $rr, $gg, $bb, $aa, $byte;
		for (my $wi = 0; $wi < $width; $wi++) {
			for (my $h = 0; $h < 3; $h++) {

				$byte = '';
				for (my $b = 0; $b < 8; $b++) {
					($rr, $gg, $bb, $aa) = $image->query_pixel(($wi), ($h*8 + $b));					
					
					$byte .= $self->getBitByColorVaues($rr, $gg, $bb, $aa);
				}
				$printer->write(chr(bin2dec($byte)));
				$self->sleep($self->{timeout_bitmap});
			}
			
		}		
	}else{
		$self->invalidInput("defineUserDefinedCharactersByBitmap char should be between 32 and 127");	
	}
	
}

# 
# 0: USA
# 1: France
# 2: Germany
# 3: U.K.
# 4: Denmark 1
# 5: Sweden
# 6: Italy
# 7: Spain 1
# 8: Japan
# 9: Norway
# 10: Denmark 2
# 11: Spain 2
# 12: Latin America
# 13: Korea
# 
sub setInternalCharacterSet(){
	my ( $self, $n) = @_;

	if ($n>=0 && $n <=13){
		$printer->write(chr(27));
	    $printer->write(chr(82));
		$printer->write(chr($n));
	}else{
		$self->invalidInput("setInternalCharacterSet");
	}
}

sub setFontBOn(){
	my ( $self) = @_;

	$printer->write(chr(27));
    $printer->write(chr(33));
	$printer->write(chr(1));
}

sub setFontBOff(){
	my ( $self) = @_;

	$printer->write(chr(27));
    $printer->write(chr(33));
	$printer->write(chr(0));
} 

#
# 0: CP437
# 1: CPKatakana
# 2: CP850 
# 3: CP860 
# 4: CP863 
# 5: CP865 
# 6: CP1251
# 7: CP866 Cyrilliec #2
# 8: MIK [Cyrillic /Bulgarian]
# 9: CP755
# 10: Iran
# 11: reserve
#
sub selectCharacterCodeTable(){
	my ( $self, $n) = @_;

	if ($n >= 0 && $n <= 12){
		$self->{code_table} = $n;

		$printer->write(chr(27));
		$printer->write(chr(116));
		$printer->write(chr($n));
	}else{
		$self->invalidInput("selectCharacterCodeTable");
	}
}


# # # # # # # # # # # # # # # # # # # # #
# 			BIT IMAGE COMMAND 			#
# # # # # # # # # # # # # # # # # # # # #


# 
# Printing bitmap with width & height
# r: Bitmap height
# n: Bitmap width
# Bitmap format: d1-dn 
#
sub printBitmap(){
	my ( $self, $filename) = @_;

	my $image = $self->repairImgSize($filename);		
	my $width = $image->get_width;
	my $height = $image->get_height;

	my $rr, $gg, $bb, $aa, $byte;

	for (my $h_limit = 0; $h_limit < ($height/255); $h_limit++) {

		my $from = $h_limit * 255;		
		my $to = ($h_limit+1) * 255;		
		if ($to > $height){
			$to = $height;
		}

		$printer->write(chr(18));
		$printer->write(chr(42));
		$printer->write(chr($to-$from));
		$printer->write(chr($width/8));

		if ($to > $height){
			$to = $height;
		}

		for (my $h = $from; $h < $to; $h++) {

			for (my $w = 0; $w < $width/8; $w++) {

				$byte = '';
				for (my $b = 0; $b < 8; $b++) {
					($rr, $gg, $bb, $aa) = $image->query_pixel(($w*8 + $b), ($h));					
					
					$byte .= $self->getBitByColorVaues($rr, $gg, $bb, $aa);
				}
				$printer->write(chr(bin2dec($byte)));

			}
			$self->sleep($self->{timeout_bitmap});
			
		}
	}
}

# 
# Printing bitmap with width & height
# r: Bitmap height
# n: Bitmap width
# Bitmap format: d1-dn
#
# this is custom method: print image widh gradient form 0% to 100% image visibility
# changing the heat-time of printer we are able to set the right density for gradient
#
# $limit - if unset gradient will be applied to whole height
# $limit - if set, gradient will be applied to first $limit rows
# 
sub printBitmapGradient(){
	my ( $self, $filename, $limit) = @_;
	
	my $image = $self->repairImgSize($filename);		
	my $width = $image->get_width;
	my $height = $image->get_height;

	if (length($limit) == 0 || $limit > $height){
		$limit = $height;
	}

	my $rr, $gg, $bb, $aa, $pxl, $byte;

	for (my $h = 0; $h < $height; $h++) {

		# set visibility
		my $grad = 3; 
		if ($h > 0){
			$grad = int($h*100/$limit);
			if ($grad < 3){
				$grad = 3;
			}
		}
		$grad = 100 if ($grad > 100);
		$self->setControllParameterCommand($self->{heatingDots}, $grad, $self->{heatInterval});

		$printer->write(chr(18));
		$printer->write(chr(42));
		$printer->write(chr(1));
		$printer->write(chr($width/8));
         
		for (my $w = 0; $w < $width/8; $w++) {

			$byte = '';
			for (my $b = 0; $b < 8; $b++) {
				($rr, $gg, $bb, $aa) = $image->query_pixel(($w*8 + $b), $h );
					
				$byte .= $self->getBitByColorVaues($rr, $gg, $bb, $aa);
			}	

			# print bin2dec($byte);
			$printer->write(chr(bin2dec($byte)));
			$self->sleep($self->{timeout_bitmap_gradient});
			

		}

	}

}

sub getBitByColorVaues(){
	my ( $self, $r, $g, $b, $a) = @_;

	#white
	if ($r == 255 && $g == 255 && $b == 255){
		return '0'; 

	#black	
	}elsif ($r == 0 && $g == 0 && $b == 0){
		return '1';					

	#black	
	}elsif ( (($r + $g + $b)/3 < $self->{rgb_threshold}) 
		|| ($a < $self->{alpha_threshold}) ){
		return '1'; 

	#white
	}else{
		return '0';
	}

}

#
# this setting is applied only if printing image is smaller than width (384px)
#
sub setImagePosition(){
	my ( $self, $pos) = @_;
	
	if ($pos >= 0 && $pos <= 2){
		$self->{img_pos} = $pos;
		
	}else{
		$self->invalidInput("setImagePosition");
	}
}

#
# if printing image is too small (align by setting) or too big (resize)
#
sub repairImgSize(){
	my ( $self, $filename) = @_;

	my $image = Image::Imlib2->load($filename);
	my $width = $image->get_width;
	my $height = $image->get_height;

	# if image too big -> resize and keep ratio
	if ($width > 384){
		$image = $image->create_scaled_image(384, $height* (384/$width) );

	# if image too small -> create image with 384 width and align by setting	
	}elsif($width < 384){
		my $new_image = Image::Imlib2->new(384, $height);

		for (my $x = 0; $x < $new_image->get_width; $x++) {
		    for (my $y = 0; $y < $new_image->get_height; $y++) {    	        	
		        $new_image->set_color(255, 255, 255, 255);
		        $new_image->draw_point($x, $y);
	    	}
		}

		# This will blend the source rectangle x, y, width, height from the source_image onto the current image 
		# at the destination x, y location scaled to the width and height specified. If merge_alpha is set to 1 it will
		# also modify the destination image alpha channel, otherwise the destination alpha channel is left untouched.

		# LEFT
		if ($self->{img_pos} == 0){
			$new_image->blend($image, 0, 0, 0, $width, $height, 0, 0, $width, $height);

		# CENTER
		}elsif ($self->{img_pos} == 1){
			$new_image->blend($image, 0, 0, 0, $width, $height, (384-$width)/2, 0, $width, $height);

		# RIGHT
		}elsif ($self->{img_pos} == 2){
			$new_image->blend($image, 0, 0, 0, $width, $height, 384-$width, 0, $width, $height);
		}

		$image = $new_image;
	}

	if ($self->{save_print_img}){
		$image->image_set_format('png');
		$image->save('print.png');	
	}

	return $image;
}

# # # # # # # # # # # # # # # # # # # # # # #
#			KEY CONTROLL COMMAND 			#
# # # # # # # # # # # # # # # # # # # # # # #

sub setPanelKeyOn(){
	my ( $self) = @_;

	# This command has no effection
	# $printer->write(chr(27));
	# $printer->write(chr(99));
	# $printer->write(chr(53));
	# $printer->write(chr(0));
} 

sub setPanelKeyOff(){
	my ( $self) = @_;

	# This command has no effection
	# $printer->write(chr(27));
    # $printer->write(chr(99));
	# $printer->write(chr(53));
	# $printer->write(chr(1));
} 


# # # # # # # # # # # # # # # # # # #
# 			INIT COMMAND 			#
# # # # # # # # # # # # # # # # # # #

# 
# Initializes the printer
# - the print buffer is cleared
# - reset the param to default value
# - return to standard mode
# - delete user-defined characters
sub initSettings(){
	my ( $self) = @_;
	$printer->write(chr(27));
	$printer->write(chr(64));
}

# # # # # # # # # # # # # # # # # # #
#			STATUS COMMAND 			#
# # # # # # # # # # # # # # # # # # #

# transmit paper sensor status
# P<Paper>V<Voltage>T<Degree>
# $n ??
sub transmitPaperSensorStatus(){
	my ( $self) = @_;
	$printer->write(chr(27));
	$printer->write(chr(118));
	$printer->write(chr($n));
	#TODO
}

# enable/disable automatic status back
sub automaticStatusBack(){
	#TODO 
}

# transmit peripheral device status
sub automaticStatusBack(){
	my ( $self) = @_;
	#this command is not supported	
}

# # # # # # # # # # # # # # # # # # # # #
#			BAR CODE COMMAND 			#
# # # # # # # # # # # # # # # # # # # # #

#
# This command selects the printing position for human readable
# characters when printing a barcode. The default is n=0. Human readable
# characters are printed using the font specified by GS fn. Select the
# printing position as follows:
# 
# Printing Positioin
# 
# 0: Not printed
# 1: Above the barcode
# 2: Below the barcode
# 3: Both above and below the barcode
#
sub setPrintingPositionOfCharacters(){
	my ( $self, $pos) = @_;

	if ($pos >= 0 && $pos <= 3){
		$printer->write(chr(29));
		$printer->write(chr(72));
		$printer->write(chr($pos));
	}else{
		$self->invalidInput("setPrintingPositionOfCharacters");
	}
}

#
# This command selects the height of a barcode. n specifies the number
# of dots in the vertical direction. The default value is 50
# 
sub setBarcodeHeight(){
	my ( $self, $h) = @_;

	if ($h >= 1 && $h <= 255){
		$printer->write(chr(29));
		$printer->write(chr(104));
		$printer->write(chr($h));
	}else{
		$self->invalidInput("setBarcodeHeight");
	}
}

# 
# Set the barcode printing left space
# 
sub setBarcodePrintLeftSpace(){
	my ( $self, $n) = @_;

	$printer->write(chr(29));
	$printer->write(chr(120));
	$printer->write(chr($n));	
}

#
#  This command selects the horizontal size of a barcode.
#  n = 2,3
#  The default value is 3
#  
sub setBarcodeWidth(){
	my ( $self, $n) = @_;

	if ($n == 2 || $n ==3){
		$printer->write(chr(29));
		$printer->write(chr(119));
		$printer->write(chr($n));	
	}else{
		$self->invalidInput("setBarcodeWidth");
	}
}

#
# CODE SYSTEM, NUMBER OF CHARACTERS, VALID CHARS
# 65 = UPC-A    	11,12				48-57
# 66 = UPC-E    	11,12				48-57		
# 67 = EAN13    	12,13				48-57
# 68 = EAN8    		7,8   				48-57
# 69 = CODE39    	>1  				32, 36, 37, 43, 48-57, 65-90
# 70 = I25        	>1, even number 	48-57
# 71 = CODEBAR		>1					36, 43, 45-58, 65-68
# 72 = CODE93		>1					0-127
# 73 = CODE128		>1					0-127
# 74 = CODE11		>1					48-57
# 75 = MSI			>1					48-57
# 
# 
sub printBarcode(){
	my ( $self, $format, $barcode) = @_;

	if (length($format) ==0 || length($barcode) ==0){
		$self->invalidInput("printBarcode");	
		return;
	}

	if (!($format >= 65 && $format<= 75)){
		$self->invalidInput("printBarcode format - ");	
		return;	
	}

	my $length = length($barcode);
	my $err_msg = '';

	# 65 = UPC-A    	11,12				48-57
	if ($format == 65){
		$err_msg .= $self->validateLength($barcode, 11, 12);
		$err_msg .= $self->validateChars($barcode, 48, 57);

	# 66 = UPC-E    	11,12				48-57
	}elsif ($format == 66){
		#not works - not supported?
		$err_msg .= $self->validateLength($barcode, 11, 12);
		$err_msg .= $self->validateChars($barcode, 48, 57);

	# 67 = EAN13    	12,13				48-57
	}elsif ($format == 67){
		$err_msg .= $self->validateLength($barcode, 12, 13);
		$err_msg .= $self->validateChars($barcode, 48, 57);

	# 68 = EAN8    		7,8   				48-57
	}elsif ($format == 68){
		$err_msg .= $self->validateLength($barcode, 7, 8);
		$err_msg .= $self->validateChars($barcode, 48, 57);

	# 69 = CODE39    	>1  				32, 36, 37, 43, 48-57, 65-90
	}elsif ($format == 69){
		if ($self->validateLength($barcode, 1)
			&& $self->validateChars($barcode, 32)
			&& $self->validateChars($barcode, 36)
			&& $self->validateChars($barcode, 37)
			&& $self->validateChars($barcode, 43)
			&& $self->validateChars($barcode, 48, 57)
			&& $self->validateChars($barcode, 65, 90) ){

			$err_msg = 	"printBarcode invalid barcode";
		}

	# 70 = I25        	>1, even number 	48-57
	}elsif ($format == 70){
		$err_msg .= $self->isLengthEven($barcode);
		$err_msg .= $self->validateLength($barcode, 1);
		$err_msg .= $self->validateChars($barcode, 48, 57);

	# 71 = CODEBAR		>1					36, 43, 45-58, 65-68
	}elsif ($format == 71){
		$err_msg .= $self->validateLength($barcode, 1);
		if ( $self->validateChars($barcode, 36)
			&& $self->validateChars($barcode, 43)
			&& $self->validateChars($barcode, 45, 58)
			&& $self->validateChars($barcode, 65, 68) ){
			
			$err_msg = 	"printBarcode invalid barcode";
		}

	# 72 = CODE93		>1					0-127
	}elsif ($format == 72){
		$err_msg .= $self->validateLength($barcode, 1);
		$err_msg .= $self->validateChars($barcode, 0, 127);

	# 73 = CODE128		>1					0-127
	}elsif ($format == 73){
		$err_msg .= $self->validateLength($barcode, 1);
		$err_msg .= $self->validateChars($barcode, 0, 127);

	# 74 = CODE11		>1					48-57
	}elsif ($format == 74){
		$err_msg .= $self->validateLength($barcode, 1);
		$err_msg .= $self->validateChars($barcode, 48, 57);

	# 75 = MSI			>1					48-57
	}elsif ($format == 75){
		$err_msg .= $self->validateLength($barcode, 1);
		$err_msg .= $self->validateChars($barcode, 48, 57);

	}

	if (length($err_msg)){
		$self->invalidInput("printBarcode " . $err_msg);
		return;
	}

	$printer->write(chr(29));
	$printer->write(chr(107));
	$printer->write(chr($format));
	$printer->write(chr($length));
	$printer->write($barcode);
	$self->sleep($self->{timeout_barcode});

}

sub validateLength(){
	my ( $self, $barcode, $from, $to) = @_;

	if (length($barcode) < $from){
		return "invalid length: too short";
	}

	if (length($to) > 0){
		if (length($barcode) > $to){
			return "invalid length: too long";
		}
	}

	return '';
}

sub validateChars(){
	my ( $self, $barcode, $from, $to) = @_;
	
	$to = $form if (length($to) == 0);

	foreach (split("", $barcode)){
		for (my $m = $from; $m <= $to; $m++) {
			if (chr($m) eq $_){
				return '';
			}
		}
		return "invalid char value " . $_;
	}

	return '';
}

sub isLengthEven(){
	my ( $self, $barcode) = @_;

	if ((length($barcode)%2) == 1){

		return "invalid length: odd";
	}

	return '';
}


# # # # # # # # # # # # # # # # # # # # # # # # #
#			CONTROLL PARAMETER COMMAND 			#
# # # # # # # # # # # # # # # # # # # # # # # # #


#
# Set "max heating dots", "heating time", "heating interval"
# n1 = 0-255 Max printing dots, Unit (8 dots), Default:7(64dots)
# n2 = 3-255 Heating time, Unit(10us), Default 80(800us)
# n3 = 0-255 Heating interval, Unit(10us), Default: 2(20us)
# The more max height dots, the more peak current will cost
#  when printing, the faster printing speed. The max heating dots is
#  8*(n1+1)
# The more heating time, the more density, but the slower printing
# speed. If heating time is too short, blank page may occur.
# The more heating interva, the more clear, but slower 
#  printing speed
#  
#  n1 = $heatingDots
#  n2 = $heatTime
#  n3 = $heatInterval
sub setControllParameterCommand(){
	my ( $self, $heatingDots, $heatTime, $heatInterval) = @_;

	if ( ($heatingDots >= 0 && $heatingDots <= 30) 
		&& ($heatTime >= 3 && $heatTime <= 255) 
		&& ($heatInterval >= 0 && $heatInterval <= 255) ){

		$printer->write(chr(27));
		$printer->write(chr(55));
		$printer->write(chr($heatingDots)); 	# <0 - 30>
		$printer->write(chr($heatTime));		# <3 - 255>
		$printer->write(chr($heatInterval));	# <0 - 255>
	}else{
		$self->invalidInput("setControllParameterCommand");
	}
}

#
# Setting the time for control board to enter sleep mode.
# n1 = 0-255 The time waiting for sleep after printing finished,
# Unit(Second), Default:0(don't sleep)
# When control board is in sleep mode, host must send one byte(0xff)
# to wake up control board. And waiting 50ms, then send printing command and data.
# NOTE: The command is useful when the system is powered by battery
# 
sub setSleep(){
	my ( $self, $n1) = @_;
	
	if ($n1 >= 0 && $n1 <=255){		
		$printer->write(chr(27));
		$printer->write(chr(56));
		$printer->write(chr($n1));
	}else{
		$self->invalidInput("setSleep");
	}
}

#
# D4..D0 of n is used to set the printing density
# 	Density is 50% + 5% * n(D4-D0) printing density
# D7..D5 of n is used to set the printing break time
# 	Break time is n(D7-D5)*250us
#
# $n1 = <0-31> density (integer)
# $n2 = <0-7> break time (integer)
sub setPrintingDensity(){
	my ( $self, $n1, $n2) = @_;

	if ( ($n1 >= 0 && $n1 <= 31) 
		&& ($n2 >= 0 && $n2 <= 7) ){

		my $nb = dec2bin($n1) . dec2bin($n2); 
		my $n = bin2dec($nb);

		$printer->write(chr(18));
		$printer->write(chr(35));

		$printer->write(chr($n));
	}else{
		$self->invalidInput("setPrintingDensity");
	}

}

#
# print the test page
#
sub printTestPage(){
	my ( $self) = @_;

	$printer->write(chr(18));
	$printer->write(chr(84));
}


sub printTestChars(){
	my ( $self) = @_;

	for (my $m = 32; $m < 255; $m++) {
		# print $m;
		$printer->write(chr($m));
		$self->sleep($self->{timeout_text});
	}

}

# # # # # # # # # # # # # # #
#			HELPER 			#
# # # # # # # # # # # # # # #

sub invalidInput(){
	my ( $self, $msg) = @_;
	print $msg . " invalid input";

}

sub dec2bin {
    my $str = unpack("B32", pack("N", shift));
    $str =~ s/^0+(?=\d)//;   # otherwise you'll get leading zeros
    return $str;
}

sub bin2dec {
    return unpack("N", pack("B32", substr("0" x 32 . shift, -32)));
}


1
__END__
       
        




