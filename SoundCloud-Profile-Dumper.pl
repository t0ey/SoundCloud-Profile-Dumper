#!/usr/bin/perl -w
#--------------------------------------------------------------------------#
#
#     Author:  Toey Jammer
#    Contact:  toey@toey.org
# 
# !!!PLEASE READ README FILE!!!
#--------------------------------------------------------------------------#


use strict;
use File::stat;
# sound cloud profile name
my $profile = 'sizzlebird';
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
$hash{rawDataAge} = 42;

fetchRAWdata();
downloadTrackData();

sub downloadTrackData {
 delete $hash{csv};
 
 csvHeadings();
 hashIDs();
 
 foreach my $key (grep { /page/ } returnPageKeys()) {
  hashLinks($key);
  initTrackHash();
  foreach my $line (`awk '/^\\[\/,\/\\.[0-9]+\$/' $hash{rawDataDir}/$key`) {
   # match trackname, track link and track artwork
   if ($line =~ /^\[(\d+)\](.*?)$/) {
    my $i = $1;
    $hash{track}{'08link'} = $hash{links}{$i};
    $hash{track}{'01name'} = $2;
    $i--;
    #print $hash{links}{$i}."\n";
    $hash{track}{'09artwork'} = $hash{links}{$i} if ($hash{links}{$i} =~ /artworks\-/);
    $hash{track}{'09artwork'} =~ s/(\?.*?)$//;
    $hash{track}{'02sname'} = $1 if ($hash{track}{'08link'} =~ /\/([^\/]+)$/);
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
    #if we're upto here the full track name has been caputured and we can set the ID
    $hash{track}{'03id'} = $hash{names}{$hash{track}{'01name'}} if ($hash{names}{$hash{track}{'01name'}});
    setID() if (!$hash{track}{'03id'});
    next;
   }
   # match amount of plays and favoritings
   if ($line =~ /(\d+) Plays?/) {
    $hash{track}{'05plays'} = $1;
    $hash{track}{'06favorites'} = $1 if ($line =~ /(\d+) Favoritings?/);
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

sub csvHeadings {
 initTrackHash();
 $hash{track}{'01name'}      = 'Name';
 $hash{track}{'02sname'}     = 'Shortname';
 $hash{track}{'03id'}        = 'SoundCloud ID';
 $hash{track}{'04date'}      = 'Release Date';
 $hash{track}{'05plays'}     = 'Plays';
 $hash{track}{'06favorites'} = 'Favoritings';
 $hash{track}{'07length'}    = 'Length';
 $hash{track}{'08link'}      = 'SoundCloud URL';
 $hash{track}{'09artwork'}   = 'Artwork';
 $hash{track}{'10download'}  = 'Track';
 $hash{track}{'11purchase'}  = 'Purchase URL';
 csvTrackHash();
 return 0;
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

sub hashIDs {
 foreach (`cat $hash{rawDataDir}/source*`) {
  next if (! /track=\"(\d+)\".*?\>([^\<\>]+)\<\/a\>(<\/h3\>)?$/ );
  my $id = $1; my $name = $2;
  $name =~ s/\s+Artwork$//;
  $hash{ids}{$id} = $name;
  $hash{names}{$name} = $id;
 }
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

sub downloadArt {
 # return if there is no file to download
 return 0 if (!$hash{track}{'09artwork'});
 # create target directory if it does not exist
 mkdir "$hash{artDir}" if (!-d $hash{artDir});
 # create temporary variables containing the download URL
 my $url = $hash{track}{'09artwork'};
 my $filename = $hash{track}{'09artwork'};
 # extract filename from URL and convert
 $filename =~ s/^.*?\/([^\/]+)$/$1/;
 # point the csv value to its local location
 $hash{track}{'09artwork'} = $filename;
 # return if the file already exists
 return 0 if (-e "$hash{artDir}/$filename");
 # download the file
 wgetFile($url, "\"$hash{artDir}/$filename\"");
 # exit
 return 0;
}

sub setID {

 my @array1 = split //, $hash{track}{'01name'};
 my $last = 100000;
 
 print "setID(WARNING) using heuristics to find track ID:\n" if ($hash{debug});
 
 foreach my $key (sort keys %{$hash{ids}}) {
  my @array2 = split //, $hash{ids}{$key};
  my @diff = returnDiff(@array1, @array2);
  if ($#diff < $last) {
   $hash{track}{'03id'} = $key;
   $last = $#diff;
   if ($hash{debug}) {
    print "\tThe Symmetric Difference\n";
    print "\tOf: '$hash{track}{'01name'}'\n";
    print "\tAnd: '$hash{ids}{$key}'\n\tEquals: $#diff\n";
   }
   next;
  }
  print "Diff of: '$hash{track}{'01name'}' & '$hash{ids}{$key}' = $#diff\n" if ($hash{debug} >= 3);
 }
 
 print "================\n";
}

sub returnDiff {
 my @union = (); my @intersection = (); my @difference = (); my %count = ();
 
 foreach my $element (@_) { $count{$element}++ }
 
 foreach my $element (keys %count) {
  push @union, $element;
  push @{ $count{$element} > 1 ? \@intersection : \@difference }, $element;
 }
 
 return @difference;
}

sub downloadMusic {
 # return if there is no file to download
 return 0 if (!$hash{track}{'10download'});
 # create target directory if it does not exist
 mkdir "$hash{musicDir}" if (!-d $hash{musicDir});
 # create temporary variables containing the download URL and filename
 my $url = $hash{track}{'10download'};
 my $filename = $hash{track}{'01name'};
 # remove unessesary text from file name
 # this removes reference to free tracks i.e. [Free Download], (Free) ( Now Free!), etc...
 $filename =~ s/\s?\W\s?([^\W\s]+)?\s?free(\s?[^\s]+)?\W\s?//i;
 # point the csv value to its local location
 $hash{track}{'10download'} = "$filename.mp3";
 # return if the file already exists
 return 0 if (-e "$hash{musicDir}/$filename.mp3");
 # download the file
 wgetFile($url, "\"$hash{musicDir}/$filename.mp3\"");
 # exit
 return 0;
}

sub wgetFile {
 my ($url, $destination) = (shift, shift);
 print "wgetFile(INFO) downloading $url to $destination" if ($hash{debug} >= 2);
 if ($destination =~ /rawData/) {
  `wget -T 10 -t 5 -w 3 -O $destination $url`;
  return 0;
 }
 `wget -T 10 -t 5 -w 3 -c -O $destination $url`;
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
 print "writeCSV(INFO) writing '$hash{csvFile}'\n" if ($hash{debug} >= 2);
 open FILE, ">$hash{csvFile}";
 print FILE $_."\n" foreach (@{$hash{csv}});
 close FILE;
}
################################################################################################################
sub fetchRAWdata {
 
 initRawDataDir();
 
 # confirm we haven't done this within the defined raw data cache maxium age
 # also creates directory structures
 return 0 if (!testRAWdataAge());
 
 # grab first page raw data
 wgetFile($hash{url}, "$hash{rawDataDir}/source0.html");
 setTotalPages("$hash{rawDataDir}/source0.html");
 
 #formats the first pages index number correctly, and destorys page0
 rename "$hash{rawDataDir}/source0.html", "$hash{rawDataDir}/source".formatPageNum(1).".html";

 #exit if there is no more pages
 if (!$hash{totalPages}) { lynxDumpSource(); return 0; }
 
 #prints the number of pages to fetch if debuging is high
 print "fetchRAWdata(INFO) Found $hash{totalPages} pages to slurp...\n" if ($hash{debug} >= 2);
 
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
 $hash{totalPages} = '';
 foreach (reverse split '</a>', `grep "Prev.*Next" $file`) {
  if ( /(\d+)$/ ) {
   $hash{totalPages} = $1;
   last;
  }
 }
 return 0;
}

sub testRAWdataAge {
 
 my $file = extractRAWfn();

 if (!$file) {
  print "testRAWdataAge(INFO) no raw data found in '$hash{rawDataDir}... slurping pages\n" if ($hash{debug} >= 2);
  return 1;
 }

 if (checkFileMtime("$hash{rawDataDir}/$file")) {
  print "testRAWdataAge(INFO) '$hash{rawDataDir}/$file is older than $hash{rawDataAge} seconds... slurping pages\n" if ($hash{debug} >= 2);
  return 1;
 }

 if (!setTotalPages("$hash{rawDataDir}/$file")) {
  print "testRAWdataAge(INFO) found $hash{rawDataDir}/$file... raw data cache is valid, no need to download source :)\n" if ($hash{debug} >= 2);
  slurpRAWdata();
  return 0;
 }

 if ($file =~ /$hash{totalPages}$/) {
  print "testRAWdataAge(INFO) '$hash{rawDataDir}/$file' is not the last file of $hash{totalPages}... slurping pages\n" if ($hash{debug} >= 2);
  return 1;
 }

 print "testRAWdataAge(INFO) found $hash{rawDataDir}/$file... raw data cache is valid, no need to download source :)\n" if ($hash{debug} >= 2);
 slurpRAWdata();
 return 0;
}

sub executeCmd {
 my ($command, $arrayRef) = (shift, shift);
 if (!$arrayRef || $arrayRef !~ /^ARRAY/) {
  print "executeCmd(ERROR) Not passed an Array Reference\n" if ($hash{debug});
  return 0;
 }
 print "executeCmd(INFO) Executing: \'$command\'\n" if ($hash{debug} >= 3);
 @$arrayRef = `$command`;
 return 0;
}

sub formatPageNum {
 my ($i) = (shift);
 my $format = "%0".length ($hash{totalPages})."d";
 return sprintf ("$format", $i);
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

sub returnPageKeys {
 return grep { /^page|source/ } sort keys %hash;
}

sub initRawDataDir {
 mkdir "$profile" if (!-d "$profile");
 mkdir "$hash{rawDataDir}" if (!-d "$hash{rawDataDir}");
}

sub saveRAWdata {
 print "saveRAWdata(INFO) clearing raw directory data before saving\n" if ($hash{debug} >= 2);
 rmdir $hash{rawDataDir};
 initRawDataDir();
  
 foreach my $key (returnPageKeys()) {
  print "saveRAWdata(INFO) writing cache '$hash{rawDataDir}/$key'\n" if ($hash{debug} >= 2);
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

