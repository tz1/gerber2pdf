gerber2pdf - translate gerber language to postscript/pdf
==========

An old awk script I used to convert gerber files to PDF (or postscript) for making circuit boards.

Why awk?  This was the mid 1990's.  It would have been in C.  Perl, Python, and most of the rest were not mature.

Why postscript/pdf?

First, because it deals in inches.  If I need to make something to go on a transparency, I don't want to output something that scales, nor something with pixels even if there is a ppi in the metadata.

Second, the line types and ends (compare HTML5 canvas) make it easy to draw the equivalent of a circular apeture.  So the awk script is a translator - Gerbers are merely pens with moves, lines, arcs.  PS/PDF has the same operators, I just need to adjust the offset and scale.  The only state is the last coordinate (since if X or Y doesn't change, they are omitted in the Gerber but must be included in the PDF).

Third, PDF is just postscript with abbreviated operators (l=lineto S=Stroke), so adding a few defines allows the same output to be used for either.

X14358Y4350D02* (moveto, don't draw)
X13808D01*      (pen down, line-to, unchanged y omitted)
Y3950*
X14358*
Y4350*
X14333Y4325D02* (pen up, moveto...

becomes in pdf

 14358 4350 m  13808 4350 l  13808 3950 l  14358 3950 l  14358 4350 l  S 
 
