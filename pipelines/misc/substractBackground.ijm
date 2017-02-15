
//dir=getDirectory("choose dir");
args=split(getArgument(),",");
input=args[0];
outfile=args[1];
//outdir=args[1];
setBatchMode(true);
open(input);
fileSt=getTitle();
dotindex=lastIndexOf(fileSt,".");
name=substring(fileSt,0,dotindex);

run("Subtract Background...", "rolling=50");

//filename=""+outdir + name + ".png";
//print(filename);

//a=File.exists(dir);
//print(dir);
//print(a);

saveAs("PNG", outfile);

//run("NIfTI-1", "save="+outdir+name+".nii");

close();
run("Quit")