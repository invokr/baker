#!/usr/bin/perl

use Text::Markdown 'markdown';
use File::Slurp;
use File::Basename 'dirname';
use Cwd 'abs_path';
use Config::Simple;
use strict;

# Get path to script
my $path = dirname(abs_path($0))."/../";

# Load Configuration
my $cfg = new Config::Simple($path."config.ini") || die "Failed to read config.\n";

# Load header / footer / nav template
my $tpl_header = read_file($path."templates/header.tpl");
my $tpl_nav = read_file($path."templates/nav.tpl");
my $tpl_footer = read_file($path."templates/footer.tpl");
$tpl_header = tpl_replace($tpl_header, "title", $cfg->param("Title"));

# Iterate content directory
parsedir("", 0);

print "-> Website build in /dist/\n";

# Function to replace values within templates
sub tpl_replace {
    my $t = shift;
    my $s = shift;
    my $r = shift;
  
    $t =~ s/\{\$$s\}/$r/g;
    return $t;
}

# Parses a directory for markup files
sub parsedir {
    my $d = shift;
    my $i = shift;
    my $nav = "";
    my $d_prnt = $d;
    $d_prnt =~ s/$path//g;
    my %files;
    my $p = $path."content/$d";
    my $nav_tpl = $tpl_nav;

    print "-+ Entering $d_prnt\n";
    
    my $addp = 0;
    my $addpp = 0;

    my @files = ();

    opendir(my $dfh, $p) || die "Failed to read: $d\n";
    while (my $f = readdir($dfh)) {
        if ( -d $p.$f) {
            if ($f eq ".") {                
                $addp = 1;
            } elsif ($f eq "..") {
                if ($i > 0) {
                    $addpp = 1;
                }
            } else {
                push @files, ["$f/", "$f"];
                # $nav .= "<a href='$f/'>$f</a>\n";
                parsedir($d.$f."/", 1);
            }
        } else {
            if ($f =~ /\.md/) {
                my $fn = (split '.md', $f)[0];        
                print "-> Parsing $f\n";
                
                my $src = read_file($p.$f);
                $src = markdown($src);
                $files{$fn} = $src;

                if ($fn ne "index" && substr($fn, 0, 1) ne "_") {
                    push @files, ["$fn.html", $fn];
                }
            }
        }
    }
    
    if ($addpp) {
        $nav = "<a href='../'>..</a>\n".$nav;
    }
    
    if ($addp) {
        $nav = "<a href='./'>.</a>\n".$nav;
    }
    
    my @fsorted = sort { $a->[1] cmp $b->[1] || $a->[2] cmp $b->[2] } @files;
    
    for my $aref (@fsorted) {
        $nav .= "<a href='".$aref->[0]."'>".$aref->[1]."</a>";    
    }

    if ($d ne "") {
        mkdir ($path."dist/$d");
    }
    $nav_tpl = tpl_replace($nav_tpl, "nav", $nav);
    while (my ($key, $val) = each %files) {
        write_file($path."dist/$d$key.html", $tpl_header.$nav_tpl.$val.$tpl_footer);
        write_file($path."dist/$d$key\_ajax.html", $nav_tpl.$val);
    }

    closedir($dfh);
}
