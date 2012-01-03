#!/usr/bin/perl -w
#--------------------------------------------------------------------------#
#
#  Component:  $Id: SoundCloud-Profile-Dumper.pl,v 1.0 2011/12/29 00:00:00 t0ey Exp $
#     Author:  Toey Jammer
#    Contact:  toey@toey.org
# 
# !!!PLEASE READ README file!!!
#--------------------------------------------------------------------------#


use strict;
use File::stat;
# sound cloud profile
my $profile = 'blumarten';
# create main data structure with pointer
my %hash;
my $hash = \%hash;
# set debug level
$hash{debug} = 2;
# set tracks url
$hash{url} = "http://soundcloud.com/$profile/tracks";
# set raw data cache directory
$hash{rawDataDir} = "$profile/rawData";
# set csv file
$hash{csvFile} = "$profile/tracklist.csv";
# set art directory
$hash{artDir} = "$profile/art";
# set music directory
$hash{musicDir} = "$profile/music";
# set raw data cache maxium age
$hash{rawDataAge} = 42000;

fetchRAWdata();
downloadTrackData();

sub downloadTrackData {
 delete $hash{csv};
 foreach my $key (returnPageKeys()) {
  hashLinks($key);
  initTrackHash();
  foreach my $line (`awk '/^\\[\/,\/\\.[0-9]+\$/' $hash{rawDataDir}/$key`) {
   # match trackname, track link and track artwork
   if ($line =~ /^\[(\d+)\](.*?)$/) {
    my $i = $1;
    $hash{track}{'08link'} = $hash{links}{$i};
    $hash{track}{'01name'} = $2;
    $i--;
    $hash{track}{'09artwork'} = $hash{links}{$i} if ($hash{links}{$i} =~ /artworks\-/);
    $hash{track}{'09artwork'} =~ s/(\?.*?)$//;
    $hash{track}{'02sname'} = $1 if ($hash{track}{'08link'} =~ /\/([^\/]+)$/);
    setID();
    downloadArt();
    next;
   }
   # add any additional strings to the track name
   if ($line =~ /^(\s?\s?[^\s].*?)$/) {
    $hash{track}{'01name'} .= $1;
    next;
   }
   # match track date
   if ($line =~ / on (.*?\:\d+)$/) {
    $hash{track}{'04date'} = $1;
    next;
   }
   # match amount of plays and favoritings
   if ($line =~ /(\d+) Plays?(.*?)?(\d+) Favoritings?/) {
    $hash{track}{'05plays'} = $1;
    $hash{track}{'06favorites'} = $3;
    next;
   }
   # match download link
   if ($line =~ /Favorites \[(\d+)\]Download/) {
    $hash{track}{'10download'} = $hash{links}{$1};
    downloadMusic();
    next;
   }
   # match purchase link
   if ($line =~ /Favorites \[(\d+)\]Buy/) {
    $hash{track}{'11purchase'} = $hash{links}{$1};
    next;
   }
   # track length
   if ($line =~ /0\.00 \/ (\d+\.\d+)/) {
    $hash{track}{'07length'} = $1;
    csvTrackHash();
    next;
   }
  }
 }
 writeCSV();
 return 0;
}

sub hashLinks {
 my $key = shift;
 delete $hash{links};
 foreach my $link (grep { /^\s+\d+\.\s[a-z]+\:\/\// } @{$hash{$key}} ) {
  if ($link =~ /^\s+(\d+)\.\s([a-z]+\:\/\/[^\s]+)/) {
   $hash{links}{$1} = $2;
   $hash{links}{$1} =~ s/file\:\/\/localhost/http\:\/\/soundcloud.com/;
  }
 }
}

sub initTrackHash {
 $hash{track}{'01name'}      = '';
 $hash{track}{'02sname'}     = '';
 $hash{track}{'03id'}        = '';
 $hash{track}{'04date'}      = '';
 $hash{track}{'05plays'}     = '';
 $hash{track}{'06favorites'} = '';
 $hash{track}{'07length'}    = '';
 $hash{track}{'08link'}      = '';
 $hash{track}{'09artwork'}   = '';
 $hash{track}{'10download'}  = '';
 $hash{track}{'11purchase'}  = '';
 return 0;
}

sub setID {
 
 print "'$hash{track}{'01name'}'\n";
 
 my $temp = $hash{track}{'01name'};
 $temp =~ s/(\W)/\\$1/g;
 $temp =~ s/\\\&/\\\&amp\\\;/g;
 
 print "'$temp'\n";
 
 foreach my $line (`cat $hash{rawDataDir}/source*`) {
  next if ($line !~ /track=\"(\d+)\".*?$temp.*?(\s+Art)?/i);
  $hash{track}{'03id'} = $1;
 }
 
 print "$hash{track}{'03id'}\n";
 print "=========================================================\n";
 return 0;
}

sub downloadArt {
 return 0 if (!$hash{track}{'09artwork'});
 mkdir "$hash{artDir}" if (!-d $hash{artDir});
 my $url = $hash{track}{'09artwork'};
 my $filename = $hash{track}{'09artwork'};
 $filename =~ s/^.*?\/([^\/]+)$/$1/;
 $hash{track}{'09artwork'} = "$hash{artDir}/$filename";
 return 0 if (-e "$hash{artDir}/$filename");
 wgetFile($url, "\"$hash{artDir}/$filename\"");
 return 0;
}

sub downloadMusic {
 return 0 if (!$hash{track}{'10download'});
 mkdir "$hash{musicDir}" if (!-d $hash{musicDir});
 my $url = $hash{track}{'10download'};
 my $filename = $hash{track}{'01name'};
 $filename =~ s/\s?\Wfree(\s?[^\s]+)?\W\s?//i;
 $hash{track}{'10download'} = "$hash{musicDir}/$filename.mp3";
 return 0 if (-e "$hash{musicDir}/$filename.mp3");
 wgetFile($url, "\"$hash{musicDir}/$filename.mp3\"");
 return 0;
}

sub wgetFile {
 my ($url, $destination) = (shift, shift);
 if ($destination) {
  `wget -T 10 -t 5 -w 3 -c -O $destination $url`;
  return 0;
 }
 `wget $url`;
 return 0;
}

sub csvTrackHash {
 my $csv = '';
 foreach my $key (sort keys %{$hash{track}}) {
  $csv .= "\"$hash{track}{$key}\",";
 }
 push @{$hash{csv}}, $csv;
 initTrackHash();
 return 0;
}

sub writeCSV {
 print "writeCSV(INFO) writing '$hash{csvFile}'\n" if ($hash{debug} == 2);
 open FILE, ">$hash{csvFile}";
 print FILE "\"Name\",\"Shortname\",\"SoundCloud ID\",\"Release\",\"Plays\",\"Favoritings\",\"Length\",\"SoudCloud URL\",\"Artwork Path\",\"Download Path\",\"Purchase URL\"\n";
 print FILE $_."\n" foreach (@{$hash{csv}});
 close FILE;
}

sub fetchRAWdata {
 # confirm we haven't done this within the defined raw data cache maxium age
 # also creates directory structures
 return 0 if (!testRAWdataAge());
 
 # grab first page raw data
 wgetFile($hash{url}, "$hash{rawDataDir}/source0.html");
 
 #extracts the total number of pages, exits if no more are required
 return 0 if (!setTotalPages("$hash{rawDataDir}/source0.html"));
 
 #formats the first pages index number correctly, and destorys page0
 rename "$hash{rawDataDir}/source0.html", "$hash{rawDataDir}/source".formatPageNum(1).".html";
 
 #prints the number of pages to fetch if debuging is high
 print "fetchRAWdata(INFO) Found $hash{totalPages} pages to slurp...\n" if ($hash{debug} == 2);
 
 #loop through the total number of pages and slurp them into the HoA's
 for (my $i = 2; $i <= $hash{totalPages}; $i++) {
  wgetFile($hash{url}."?page=$i", "$hash{rawDataDir}/source".formatPageNum($i).".html");
 }
 #dump data to files
 lynxDumpSource();
 #exit
 return 0;
}

sub lynxDumpSource {
 foreach my $source (grep { /\.html$/ } listDir($hash{rawDataDir})) {
  my $i = $1 if ($source =~ /(\d+).html$/);
  executeCmd("cat $hash{rawDataDir}/$source", \@{$hash{$source}});
  executeCmd("lynx -dump $hash{rawDataDir}/$source", \@{$hash{'page'.$i}});
 }
 saveRAWdata();
}

sub setTotalPages {
 my $file = shift;
 foreach (reverse split '</a>', `grep "Prev.*Next" $file`) {
  if ( /(\d+)$/ ) {
   $hash{totalPages} = $1;
   last;
  }
 }
 return 1 if ($hash{totalPages});
 return 0;
}

sub testRAWdataAge {

 if (!-d "$hash{rawDataDir}") {
  print "testRAWdataAge(INFO) '$hash{rawDataDir}' did not exist... slurping pages\n" if ($hash{debug} == 2);
  mkRAWdataDir();
  return 1;
 }
 my $file = extractRAWfn();

 if (!$file) {
  print "testRAWdataAge(INFO) no raw data found in '$hash{rawDataDir}... slurping pages\n" if ($hash{debug} == 2);
  return 1;
 }

 if (checkFileMtime("$hash{rawDataDir}/$file")) {
  print "testRAWdataAge(INFO) '$hash{rawDataDir}/$file is older than $hash{rawDataAge} seconds... slurping pages\n" if ($hash{debug} == 2);
  return 1;
 }

 if (!setTotalPages("$hash{rawDataDir}/$file")) {
  print "testRAWdataAge(INFO) found $hash{rawDataDir}/$file... raw data cache is valid, no need to download source :)\n" if ($hash{debug} == 2);
  slurpRAWdata();
  return 0;
 }

 if ($file =~ /$hash{totalPages}$/) {
  print "testRAWdataAge(INFO) '$hash{rawDataDir}/$file' is not the last file of $hash{totalPages}... slurping pages\n" if ($hash{debug} == 2);
  return 1;
 }

 print "testRAWdataAge(INFO) found $hash{rawDataDir}/$file... raw data cache is valid, no need to download source :)\n" if ($hash{debug} == 2);
 slurpRAWdata();
 return 0;
}

sub executeCmd {
 my ($command, $arrayRef) = (shift, shift);
 if (!$arrayRef || $arrayRef !~ /^ARRAY/) {
  print "executeCmd(ERROR) Not passed an Array Reference\n" if ($hash{debug});
  return 0;
 }
 print "executeCmd(INFO) Executing: \'$command\'\n" if ($hash{debug} == 3);
 @$arrayRef = `$command`;
 return 0;
}

sub formatPageNum {
 my ($i) = (shift);
 my $format = "%0".length ($hash{totalPages})."d";
 return sprintf ("$format", $i);
}

sub mkProfileDir {
 return 0 if (-d "$profile");
 print "mkProfileDir(INFO) making \'$profile\' Directory\n" if ($hash{debug} == 2); 
 mkdir "$profile";
 return 0;
}

sub mkRAWdataDir {
 mkProfileDir();
 return 0 if (-d "$hash{rawDataDir}");
 print "mkRAWdataDir(INFO) making \'$hash{rawDataDir}\' Directory\n" if ($hash{debug} == 2);
 mkdir "$hash{rawDataDir}";
 return 0;
}

sub extractRAWfn {
 my @files = grep { !/^\./ } listDir($hash{rawDataDir});
 return pop @files;
}

sub checkFileMtime {
 my $file = shift;
 my $mtime = @{stat($file)}[9];
 my $delta = time - $mtime;
 return 1 if ($delta > $hash{rawDataAge});
 return 0;
}

sub slurpRAWdata {
 foreach my $file (sort grep { !/\./ } listDir($hash{rawDataDir})) {
  open FILE, "$hash{rawDataDir}/$file";
  @{$hash{$file}} = <FILE>;
  close FILE;
 }
}

sub listDir {
 my $directory = shift;
 opendir(DIR, "$directory");
 my @files = sort readdir(DIR);
 close DIR;
 return @files;
}

sub deleteRAWdata {
 rmdir $hash{rawDataDir};
 mkRAWdataDir();
 return 0;
}

sub returnPageKeys {
 return grep { /^page|source/ } sort keys %hash;
}

sub saveRAWdata {
 print "saveRAWdata(INFO) clearing raw directory data before saving\n" if ($hash{debug} == 2);
 deleteRAWdata();
 
 foreach my $key (returnPageKeys()) {
  print "saveRAWdata(INFO) writing cache '$hash{rawDataDir}/$key'\n" if ($hash{debug} == 2);
  open FILE, ">$hash{rawDataDir}/$key";
  if ($key =~ /^source/ ) {
   print FILE $_ foreach (grep { /player\" data-sc-track=/ } @{$hash{$key}});
   close FILE;
   next;  
  }
  print FILE $_ foreach (@{$hash{$key}});
  close FILE;
 }
}

