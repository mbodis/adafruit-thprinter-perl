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
# demo for ThPrinter class
# 
# 
# 
# # # # # # # # # # # # # # # # # # #

use strict; 
use warnings;
use ThPrinter;
use utf8;
use Unicode::Normalize;

my $printer = new ThPrinter();


my $lineSpacing = 0;				# 0/1 == false/true
my $characterCommandTest = 0;		# 0/1 == false/true
my $customCharacter = 0;			# 0/1 == false/true
my $bitImageTest = 0;				# 0/1 == false/true
my $bitImageTest2 = 0;				# 0/1 == false/true
my $barcodeTest = 0; 				# 0/1 == false/true
my $controllParameterCommands = 0;	# 0/1 == false/true

$printer->printText("--- start of demo ---");

#
# LINE SPACING
#
if ($lineSpacing){

	$printer->setTextAlign('setSpacing - normal');
	$printer->setSpacing(250);
	$printer->setTextAlign('setSpacing - 250px');
	$printer->defaultSpacing();

	$printer->setTextAlign('C');
	$printer->printText("center");

	$printer->setTextAlign('R');
	$printer->printText("right");

	$printer->setTextAlign('L');
	$printer->printText("left");

	$printer->setLeftSpace(0, 0);
	$printer->printText("setLeftSpace - 0px");
	$printer->setLeftSpace(10, 0);
	$printer->printText("setLeftSpace - 10px");
	$printer->setLeftSpace(20, 0);
	$printer->printText("setLeftSpace - 20px");

	$printer->setLeftSpaceChars(0);
	$printer->printText("setLeftSpaceChars - 0");
	$printer->setLeftSpaceChars(5);
	$printer->printText("setLeftSpaceChars - 5");
	$printer->setLeftSpaceChars(15);
	$printer->printText("setLeftSpaceChars - 15");

	$printer->setLeftSpaceChars(0);
}

#
# CHARACTERS
#
if ($characterCommandTest){
	
	$printer->setFontEnlargeOn();
	$printer->printText("setFontEnlargeOn");

	$printer->setFontEnlargeOff();
	$printer->printText("setFontEnlargeOff");

	$printer->setBoldOn();
	$printer->printText("setBoldOn");

	$printer->setBoldOff();
	$printer->printText("setBoldOff");

	$printer->setBoldOn_2();
	$printer->printText("setBoldOn_2");

	$printer->setBoldOff_2();
	$printer->printText("setBoldOff_2");

	$printer->setDoubleWidthOn();
	$printer->printText("setDoubleWidthOn");

	$printer->setDoubleWidthOff();
	$printer->printText("setDoubleWidthOff");

	$printer->setUpsidedownOn();
	$printer->printText("setUpsidedownOn");

	$printer->setUpsidedownOff();
	$printer->printText("setUpsidedownOff");

	$printer->setInverseOn();
	$printer->printText("setInverseOn");

	$printer->setInverseOff();
	$printer->printText("setInverseOff");

	$printer->setUnderlineOn();
	$printer->printText("setUnderlineOn");

	$printer->setUnderlineOn(2);
	$printer->printText("setUnderlineOn2");

	$printer->setUnderlineOff();
	$printer->printText("setUnderlineOff");

	$printer->setFontBOn();
	$printer->printText("setFontBOn");

	$printer->setFontBOff();
	$printer->printText("setFontBOff");

	$printer->printText("code table 437");
	$printer->selectCharacterCodeTable(0);
	$printer->printTestChars();
	$printer->printAndLinefeed();
	
	$printer->printAndLinefeed();

	$printer->printText("code table 850");
	$printer->selectCharacterCodeTable(1);
	$printer->printTestChars();
	$printer->printAndLinefeed();
	
}


#
# CUSTOM CHAR
#
if ($customCharacter){
	$printer->printText("-------");
	$printer->printText("CUSTOM CHARS");
	$printer->printText("-------");
	$printer->printAndLinefeed();

	$printer->setUserDefinedCharsOn();
	$printer->defineUserDefinedCharactersTest(50); #50 == 2
	$printer->printText("2");
	$printer->defineUserDefinedCharactersByBitmap(51, 'demo_img/my_char.png'); #51 == 3
	$printer->printText("3");	
	$printer->printText("012345");

	$printer->setUserDefinedCharsOff();
	$printer->printText("012345");
}

#
# IMAGE TEST
#
if ($bitImageTest){
	$printer->printText("-------");
	$printer->printText("IMAGES");
	$printer->printText("-------");
	$printer->printAndLinefeed();

	$printer->printBitmap('demo_img/img.png');
	$printer->printAndLinefeed();

	$printer->printBitmapGradient('demo_img/img.png');
	$printer->printAndLinefeed();
}

#
# IMAGE TEST 2 - small/big image
#
if ($bitImageTest2){

	$printer->setImagePosition(0);
	$printer->printBitmap('demo_img/small_image.jpg');
	$printer->setImagePosition(1);
	$printer->printBitmap('demo_img/small_image.jpg');
	$printer->setImagePosition(2);
	$printer->printBitmap('demo_img/small_image.jpg');

	$printer->setImagePosition(0);

	$printer->printBitmap('demo_img/big_image.jpg');
}



#
# BAR CODE
# 
if ($barcodeTest){
	$printer->printText("-------");
	$printer->printText("BARCODES");
	$printer->printText("-------");
	$printer->printAndLinefeed();

	$printer->setPrintingPositionOfCharacters(0);
	$printer->printBarcode(69, "12345678901");
	$printer->printAndLinefeed();

	$printer->setPrintingPositionOfCharacters(1);
	$printer->printBarcode(65, "123456789012");
	$printer->printAndLinefeed();

	$printer->setPrintingPositionOfCharacters(2);
	$printer->printBarcode(65, "123456789012");
	$printer->printAndLinefeed();

	$printer->setPrintingPositionOfCharacters(3);
	$printer->printBarcode(65, "123456789012");
	$printer->printAndLinefeed();

	$printer->setPrintingPositionOfCharacters(2);

	$printer->setBarcodeHeight(10);
	$printer->printBarcode(65, "123456789012");
	$printer->setBarcodeHeight(50);
	$printer->printBarcode(65, "123456789012");
	$printer->setBarcodeHeight(250);
	$printer->printBarcode(65, "123456789012");
	$printer->setBarcodeHeight(50);


	$printer->setBarcodePrintLeftSpace(10);
	$printer->printBarcode(65, "123456789012");
	$printer->setBarcodePrintLeftSpace(50);
	$printer->printBarcode(65, "123456789012");
	
	$printer->setBarcodeWidth(2);
	$printer->printBarcode(65, "123456789012");
	$printer->setBarcodeWidth(3);
	$printer->printBarcode(65, "123456789012");

	
	$printer->printBarcode(65, "12345678901");
	$printer->printBarcode(66, "012400000016");
	$printer->printBarcode(67, "1234567890123");
	$printer->printBarcode(68, "12345678");
	$printer->printBarcode(69, "HELLO");
	$printer->printBarcode(70, "46485952222223");	
	$printer->printBarcode(71, 'A12345A');
	$printer->printBarcode(72, "ABCDE12345");
	$printer->printBarcode(73, "helloworld");
	$printer->printBarcode(74, "54654");
	$printer->printBarcode(75, "1654618465");
}

# 
# CONTROLL PARAMETER COMMANDS
# 

if ($controllParameterCommands){
	$printer->setControllParameterCommand(7, 80, 25);
	$printer->setSleep(20);
	$printer->setPrintingDensity(31, 7);
	$printer->printTestPage();
}

$printer->printAndLinefeed();
$printer->printText("--- end of demo ---");
