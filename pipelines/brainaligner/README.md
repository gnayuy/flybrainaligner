## Usage

### Example 1. aligning fly brains into JFRC2010

If you prefer running the alignment pipeline on the cluster, please use the absolute path for all the parameters. The fly brains are supported up to 4 color channels. In the following example, <b>-d "debug"</b> is an option to keep the intermediate temporary files for debugging; <b>-z "zflip"</b> is an option when your data's orientation is opposite in z-axis comparing to the template JFRC2010. For your convenience, you can create a folder, <b>"workdir"</b>, for saving the results. You can put the templates into the directory named <b>"configured_templates"</b> and the Vaa3D and ANTS into <b>"Toolkits"</b> folder. The input data listed as "<b>path</b>,<b>how_many_colors</b>,<b>reference_color_channel</b>,<b>x_voxelsize</b>x<b>y_voxelsize</b>x<b>z_voxelsize</b>".

```
sh /absolute_path/brainaligner/run_configured_aligner.sh /absolute_path/brainaligner/brainaligner_jfrc2010.sh 16 -d '"debug"' -o /absolute_path/workdir -c /absolute_path/brainaligner/systemvars.apconf -t /absolute_path/configured_templates -k /absolute_path/Toolkits -z "zflip" -i /absolute_path/yourdata.v3draw,4,4,0.5x0.5x0.5
```
### Example 2. aligning fly brains into JFRC2013
```
```

