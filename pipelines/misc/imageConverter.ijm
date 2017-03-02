//$FIJI -macro $PREPROCIMG "$inputpath,outputdir”


args = split(getArgument(),",");
input = args[0];// save dir
outputdir = args[1];//file name
setBatchMode("hide");
open(input);

fileSt=getTitle();
dotindex=lastIndexOf(fileSt,".");
truname=substring(fileSt,0,dotindex);

run("NIfTI-1", "save="+outputdir+truname+".nii");
close();
run("Quit");