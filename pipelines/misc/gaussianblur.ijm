
args=split(getArgument(),",");
input=args[0];
outfile=args[1];

setBatchMode(true);
open(input);
fileSt=getTitle();
dotindex=lastIndexOf(fileSt,".");
name=substring(fileSt,0,dotindex);

run("Gaussian Blur...", "sigma=5");

saveAs("PNG", outfile);

close();
run("Quit")