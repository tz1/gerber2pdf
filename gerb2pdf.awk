#!/usr/bin/gawk -f

#version:
# 0.8 - PDF/ps tricks (Acroread 4 accepts it although some parameters like
#       displacements and stream lengths are broken).
# NOTE: GERBER ARCS WON'T WORK in PDF
# 0.7 - excellon drill data (append to gerber) will draw pilot hole markers.
# 0.6 - magnify needs to default to 1 for a bounding box and bleed default fix.
# 0.5 - another retraced line fix, magnify fix, bleed defaults
# 0.4 - refixed ghostscript retraced line endcap problem
# 0.3 - fixed bleed v.s. resolution

#Handles everything except extended dynamic (which defines rectangular
#apetures).  Best settings are 2.4 optimized, multi ap fill for bleed
#correction, or G36/G37 fill if bleed=0, extended gerber static (or
#you will need to convert the scaling and apeture table into the
#equivalent).  Gerber arcs are still beta, so if something looks wierd
#(multi ap fill) go back to approximate arcs.  Also D03 (point flash)
#is untested and may need a tiny move in the X or Y (but not both!) to
#work.

# USER SETTABLE VALUES

function preconfig() {

#this allows "neg" and "mir" to be put on the command line, note
#that it will match "neg", so negative or negate also work
#also, width=x and height=y to match those

    magnify = 1;
    negative = 0;

    while( ARGC ) {
        if( match( ARGV[ARGC] , "neg" ) )
            negative = 1;
        else if( match( ARGV[ARGC] , "pdf" ) )
            pdf = 1;
        else if( match( ARGV[ARGC] , "mir" ) )
            mirror = 1;
        else if( match( ARGV[ARGC] , "land" ) )
            landscape = 1;
        else if( match( ARGV[ARGC] , "width=" ) )
            boardwidth = 0 + substr( ARGV[ARGC], RSTART + 6 , 8 );
        else if( match( ARGV[ARGC] , "height=" ) )
            boardheight = 0 + substr( ARGV[ARGC], RSTART + 7 , 8 );
        else if( match( ARGV[ARGC] , "xoff=" ) )
            boardxoff = 0 + substr( ARGV[ARGC], RSTART + 5 , 8 );
        else if( match( ARGV[ARGC] , "yoff=" ) )
            boardyoff = 0 + substr( ARGV[ARGC], RSTART + 5 , 8 );
        else if( match( ARGV[ARGC] , "bleed=" ) )
            bleed = 0 + substr( ARGV[ARGC], RSTART + 6 , 8 );
        else if( match( ARGV[ARGC] , "mag=" ) )
            magnify = 0 + substr( ARGV[ARGC], RSTART + 4 , 8 );
        else if( length( ARGV[ARGC] ) ) {
            print "Unknown parameter: " ARGV[ARGC] >"/dev/stderr";
            print "land     - plot a landscape version " >"/dev/stderr";
            print "pdf      - do PDF instead of PS output " >"/dev/stderr";
            print "neg      - make a negative " >"/dev/stderr";
            print "mir      - mirror the image " >"/dev/stderr";
            print "width=X  - set width in inches (8)" >"/dev/stderr";
            print "height=Y - set height in inches (10)" >"/dev/stderr";
            print "xoff=X   - set left margin in inches (.25)" >"/dev/stderr";
            print "yoff=Y   - set bottom margin in inches (.5)" >"/dev/stderr";
            print "bleed=V  - set ink bleed in mils (narrow apetures by this, may be <0)" >"/dev/stderr";
            print "mag=M    - magnify the image M times" >"/dev/stderr";
            print "\nUsage:\ncat gerberfile excellonfile | gerb2ps.awk [opts] >ps.out" >"/dev/stderr";
            exit 0;
        }

        ARGC--;
    }

#Amount in mils the dots "bleed", i.e. how much narrower to make the
#lines to compensate.  This value should be negative for negative
#images since the background will bleed instead
#Also add about 2.5 mil for etching.
#For Epsons, 0 for positive (bleed about equals overetch),
#-2.5 for negative.
#-5 might be better on negatives for 10 mil traces with 10 mil clearance
#and would be the corresponding value to 0 for positive.

#Note this would also be useful for expanding things like solder masks

    if( bleed == "" ) {
        if( negative == 1 )
            bleed = -2.5;
        else
            bleed = 0;
    }

#this sets be the size of the board work area. if you don't want the
#entire sheet black for a negative or mirrored to be on the far side
#you need to specify width and/or height.  Most printers (including
#the epson) have their own idea about where the origin is, so to keep
#everything on the page, you may also want to set the offsets too.

    if( boardwidth == "" )
        boardwidth = 8;
    if( boardheight == "" )
        boardheight = 10;
    if( boardxoff == "" )
        boardxoff = 0.25;
    if( boardyoff == "" )
        boardyoff = 0.5;

    maginch = 72 * magnify;

    if( pdf != "" ) {

        print "%PDF-1.0";
        print "1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj";
        print "2 0 obj << /Type /Pages /Kids [ 3 0 R ] /Count 1 >> endobj"
            printf "3 0 obj << /Type /Page /MediaBox [ "

    } else {
        print "%!PS-Adobe-3.0 EPSF-3.0";
        printf "%%%%BoundingBox: ";
    }

    if( landscape )
        printf boardyoff * maginch / 2 " " 2 * boardxoff * maginch " "\
            (boardyoff / 2 + boardheight) * maginch " " (boardwidth + 2 * boardxoff) * maginch;
    else
        printf boardxoff * maginch " " boardyoff * maginch " "\
            ( boardxoff + boardwidth ) * maginch " " (boardyoff + boardheight) * maginch;

    if( pdf != "" ) {
        print " ] /Parent 2 0 R /Contents 4 0 R >> endobj";
        print "4 0 obj << /Length 0 >>";
        print "stream";
        cm0 = " ";
        cm1 = " cm";
    } else {
        print "";
        print "%%Title: Gerber Plot";
        print "%%Creator: Gerb2ps AWK Script";
        print "%%Pages: 1";
        print "%%EndComments";
#and after each showpage?
        print "%%Page: 1 1";
        print "%%BeginDocument: Gerber"
            print "";
        print "%%PDF equivalent definitions";
        print "/d {setdash} bind def";
        print "/f {fill} bind def";
        print "/RG {setrgbcolor} bind def";
        print "/h {closepath} bind def";
        print "/j {setlinejoin} bind def";
        print "/J {setlinecap} bind def";
        print "/l {lineto} bind def";
        print "/m {moveto} bind def";
#  print "/n {newpath} bind def";
        print "/q {gsave} bind def";
        print "/Q {grestore} bind def";
        print "/S {stroke} bind def";
        print "/w {setlinewidth} bind def";
        print "/cm {concat} bind def";
#  print "/W {clip} bind def";

        print "%%setup data";

        cm0 = "[ ";
        cm1 = " ] cm";
    }

    print cm0 "1 0 0 1 " boardxoff * maginch " " boardyoff * maginch cm1;

    print "%Tiling begins here with interval";
    print "%% 1 0 0 1 " boardwidth * maginch " " boardheight * maginch cm1;

    print "q";

#for larger check plots, so they don't go off the screen
#print "-240 -240 translate";

#if magnify is set...
    if( magnify != "" && magnify != 1 )
        print cm0 magnify " 0 0 " magnify " 0 0" cm1;

#landscape rotation (portrait lower left justified) if uncommented
#useful for larger check plots
    if( landscape != "")
        print cm0 "0 1 -1 0 " boardheight * 72 " 0" cm1;

}

function pretext() {
#negative
    if( negative == 1 ) {
#/re
        print " 0 0 m 0 " boardheight * 72 " l " boardwidth * 72 " " boardheight * 72 " l " boardwidth * 72 " 0 l h ";
        print " 0 0 0 RG f 1 1 1 RG";
    }
#mirror
    if( mirror != "" )
        print cm0 "-1 0 0 1 " boardwidth * 72 " 0" cm1;
}

function rgbtab() {

#EGA colors:
#84/255 .3294
#168/255 .6588

    rgb[0] = "0 0 0";
    rgb[1] = "0 0 .6588";
    rgb[2] = "0 .6588 0";
    rgb[3] = "0 .6588 .6588";
    rgb[4] = ".6588 0 0";
    rgb[5] = ".6588 0 .6588";
    rgb[6] = ".6588 .3294 0";
    rgb[7] = ".6588 .6588 .6588";
    rgb[8] = ".3294 .3294 .3294";
    rgb[9] = ".3294 .3294 1";
    rgb[10] = ".3294 1 .3294";
    rgb[11] = ".3294 1 1";
    rgb[12] = "1 .3294 .3294";
    rgb[13] = "1 .3294 1";
    rgb[14] = "1 1 .3294";
    rgb[15] = "1 1 1";
}


BEGIN {

    preconfig();

    pretext();

    pi = 3.14159265;

    lastx = 0;
    lasty = 0;
    lastd = 2;
    arez = 1000;
    inhead = 0;

#  rgbtab();
}

{
    orig = $0;
    gsub( "\r","",$0);
    sub( "*$","",$0);

    if( inhead ) {

#Excellon drill handling
        if(inhead == 1 && sub( "^M72$","",$0) ) {
            inhead = 2;
#need to compensate for bleed!
            print " 1 J 1 j ";
            print " 100 w";
            print " " 1 - negative " " 1 - negative " " 1 - negative " RG ";
        }
        if( length($0) ) {
            if( substr($0,1,1) == "T" ) {
                tnum=substr($0,2,1);
                tnum += 0;
                if( inhead == 1 )
                    ttab[tnum] = substr($0,4,20) / 0.00508;
                else
                    tool = ttab[tnum];

            }
            else
                if( substr($0,1,1) == "X" ) {

                    thisx = $0;
                    gsub( "Y[-0-9]+","",thisx );
                    sub( "X","",thisx );

                    thisy = $0;
                    gsub( "X[-0-9]+Y","",thisy );

                    printf " " thisx " " thisy - 50 + tool " m ";
                    print " " thisx " " thisy + 50 - tool " l S ";
                    printf " " thisx - 50 + tool " " thisy " m ";
                    print " " thisx + 50 - tool " " thisy " l S ";

                }
                else if( gsub("M30","",$0 ) ) {
                    print " " negative " " negative " " negative " RG ";
#end
                }
        }
    }
    else {

        sub( "^G01$","",$0);
#default to G90, G91 (inc) not supported
        sub( "^G90$","",$0);
#G74 should work too...
        sub( "^G75$","",$0);

        if( !inhead && sub( "^M48$","",$0) ) {
            inhead = 1;
        }

        if( $0 ~ /^%/ ) {
#Extended Gerber (apeture definitions, but macros will go here)

            if( gsub("^%ADD","",$0 ) ) {
#should also validate the number.
                alsocnt = 0;
                also[alsocnt++] = substr($0,1,2);
                while( gsub("^[0-9][0-9]%ADD","",$0 ) )
                    also[alsocnt++] = substr($0,1,2);
                apbad0 = 0;
#set line drawing by apeture type
                if( substr($0,3,1) == "C" )
                    aptxt = " 1 J 1 j ";
                else if( substr($0,3,1) == "R" ) {
                    aptxt = " 2 J 0 j ";
#check if square - a rectangular apeture has no simple postscript equivalent so warn the user
                    if( substr($0,5,7) != substr($0,13,7) ) {
                        print "warning, rectangular apeture:" substr($0,5,7) "x" substr($0,13,7) >"/dev/stderr" ;
                        apbad0 = 1;
                    }
                }
                else
#Macros, Thermals, etc. aren't handled, so give a warning
                    print "Unknown Apeture type:" $0 >"/dev/stderr" ;

                apsiz = (substr($0,5,7) - bleed / 1000) * arez;
                aptxt = aptxt apsiz " w ";

#to show each apeture as a different color, uncomment the next line
#    aptxt = aptxt rgb[++i % 15] " RG";

                while( alsocnt ) {
                    apbad[also[alsocnt - 1]] = apbad0;
                    apeture[also[--alsocnt]] = aptxt;
                }
                $0 = "";
            }
            else if( gsub("^%FS","",$0) ) {
                if( substr($0,1,1) != "L" ) {
                    print "Only Leading zero suppressed format supported" >"/dev/stderr";
#For trailing zero suppressed every number would have to have N zeros appended
#then truncated to N characters, N = # of integer digits + # fractional digits
                    exit 0;
                }
                if( substr($0,2,1) != "A" ) {
                    print "Only Absolute coordinates supported" >"/dev/stderr";
#I would need to keep a running absolute coordinate...
                    exit 0;
                }
                if( substr($0,3,1) != "X" || substr($0,6,1) != "Y" ) {
#NGDM sequence codes.  Right now fixed at 2.
                    print "Can't interpret format" >"/dev/stderr";
                    exit 0;
                }
                xrez = substr($0,5,1);
                yrez = substr($0,8,1);

                if( xrez != yrez ) {
                    print "Error: x and y resolution differ" >"/dev/stderr";
                    exit(0);
                }

                xpsr = 72;
                arez = 1;
                while( xrez-- ) {
                    xpsr /= 10;
                    arez *= 10;
                }
                print cm0 xpsr " 0 0 " xpsr " 0 0" cm1;
                $0 = "";
            }
            else if( gsub("^%MO","",$0) ) {
                if( $0 ~ /^IN/ )
#already in inches
                    ;
                else if( $0 ~ /^MM/ )
#UNTESTED!
                    print cm0 "25.4 0 0 25.4 0 0" cm1;
                else
                    print "Unrecognized Line: " orig >"/dev/stderr";
                $0 = "";
            }
            else {
#dump anything else to stderr
                print "Unrecognized Line: " orig >"/dev/stderr";
                $0 = "";
            }
        }
        else if( length($0) ) {

#Standard Gerber
#Note: arcs are beta

            if( gsub("G54D","",$0 ) ) {
#Apeture change.  Should really key off D10-D99 instead of G54

#to show each apeture on a separate page, comment out the next two lines
#print " showpage";
#pretext();

                if( length(apeture[substr($0,1,2)]))
                    print apeture[substr($0,1,2)];
                else
                    print "Undefined Apeture " $0 >"/dev/stderr";
                if( apbad[substr($0,1,2)] == 1 )
                    print "Used Rectagular Apeture " $0 >"/dev/stderr";

#also note rect. apetures will not draw the diagonal width correctly

                $0="";
            }
#Ignore data block (typically a comment)
            else if( gsub("G04","",$0 ) )
                $0 = "";
            else if( gsub("G36","",$0 ) ) {
                print "q 1 J 1 j 0.01 w";
                infill = 1;
                $0 = "";
            }
            else if( gsub("G37","",$0 ) ) {
#/B
                print " h f Q";
                infill = 0;
                $0 = "";
            }
            else if( gsub("M02","",$0 ) ) {
#end
            }

            else if ( $0 ~ /[XYD]/ ) {

                thisx = $0;
                gsub( "[GYIJD][-0-9]+","",thisx );
                sub( "X","",thisx );
                if( !length( thisx ) )
                    thisx = lastx;

                thisy = $0;
                gsub( "[GXIJD][-0-9]+","",thisy );
                sub( "Y","",thisy );
                if( !length( thisy ) )
                    thisy = lasty;

                thisd = $0;
                gsub( "[GXYIJ][-0-9]+","",thisd );
                sub( "D","",thisd );
                if( !length( thisd ) )
                    thisd = lastd;
                thisd += 0;

                if( $0 ~ /G/ ) {

                    thisi = $0;
                    gsub( "[YJXDG][-0-9]+","",thisi );
                    sub( "I","",thisi );

                    thisj = $0;
                    gsub( "[XYIGD][-0-9]+","",thisj );
                    sub( "J","",thisj );

                    radius = sqrt(thisi*thisi+thisj*thisj);
                    start = 180 / pi * atan2(-thisj,-thisi);
                    end = 180 / pi * atan2(thisy - lasty - thisj, thisx - lastx - thisi);

                    if( $0 !~ /G02/ ) {
                        type = "arc";
                        start -= .01;
                    }
                    else {
                        type = "arcn";
                        start += .01;
                    }

                    print " " lastx + thisi " " lasty + thisj " " radius " " start " " end " " type " ";
                    print " " thisx " " thisy " l ";

                    lastx = thisx;
                    lasty = thisy;
                    lastd = thisd;

                    $0 = "";
                }
                else {

                    if( thisd == 1 ) {
                        if( ( mvc != 1 || mvx != thisx || mvy != thisy ) && ( thisx != lastx || thisy != lasty ) ) {
                            printf " " thisx " " thisy " l ";
                            mvc++;
                            if( mvc % 8 == 7 )
                                print "";
                        }
                        inline = 1;
                    }
                    else if( thisd == 2 ) {
                        if( inline && !infill)
                            print " S ";
                        mvx = thisx;
                        mvy = thisy;
                        mvc = 0;
                        printf " " thisx " " thisy " m ";
                        inline = 0;
                    }
                    else if( thisd == 3 ) {
#UNTESTED!
#     print " 1 0 0 RG ";
                        print " " thisx " " thisy " m " thisx " " thisy " l S ";
#     print " " thisx " " thisy " m 0 .001 rlineto S ";
#     print " 0 0 0 RG ";
                    }

                    lastx = thisx;
                    lasty = thisy;
                    lastd = thisd;
                    $0="";
                }
            }
            else {
                print "Unrecognized Line: " orig >"/dev/stderr";
                $0 = "";
            }
        }

        if(length($0) )
            print;
    }

}

END {
#PDF trailer
    if( pdf != "" ) {
        print " Q";
        print "endstream";
        print "endobj";
        print "xref";
        print "0 5";
        print "0000000000 65535 f ";
        print "0000000000 00000 n ";
        print "0000000000 00000 n ";
        print "0000000000 00000 n ";
        print "0000000000 00000 n ";
        print "trailer";
        print "<< /Size 5 /Root 1 0 R >>";
        print "startxref";
        print "%%EOF";
    }
    else {
#for EPSF, unless it is somehow multipart
        print " Q";
        print "%%EndDocument";
        print "%%Trailer";
#not for EPSF, but won't print otherwise
        print " showpage ";

    }
}
