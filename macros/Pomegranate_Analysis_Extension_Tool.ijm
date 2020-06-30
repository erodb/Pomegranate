macro "Pomegranate Width Analysis Tool" {
	
	versionFIJI = "1.53b";
	requires(versionFIJI);

	// Title Pop Up
	showMessage("Pomegranate Analysis Extension Tool", "<html>"
			+"<font size=+3><center><b>Pomegranate</b><br></center>"
			+"<font size=+1><center><b>Analysis Extension Tool</b><br></center>"
			+"<br>"
			+"<font size=-2><center><b>Virginia Tech, Blacksburg, Virginia</b></center>"
			+"<font size=-2><center><b>Department of Biological Sciences - Hauf Lab</b></center>"
			+"<br>"
			+"<font size=-2><center>Please read accompanying documentation</b></center>"
			+"<font size=-2><center>[Erod Keaton Baybay - erodb@vt.edu]</b></center>");

	showMessageWithCancel("Prerun Cleanup","This macro performs a prerun clean up\nThis will close all currently open images without saving\nClick OK to Continue");
	cleanAll();

	roiManager("Associate", "true");
	roiManager("UseNames", "true");
	run("Options...", "iterations=1 count=1 black do=Nothing");
	
	run("Set Measurements...", "area mean standard modal min centroid center perimeter fit shape feret's median stack limit display redirect=None decimal=3");

	transpMode = false;
	confirmWindow = false;
	Atype = -1;
	Dialog.create("Input Type");
		Dialog.addChoice("Analysis Type", newArray("Batch Mode (Multiple Pomegranate Analyses)","Single Mode (One Pomegranate Analysis)"));
		Dialog.addCheckbox("Transparent Mode", transpMode);
	Dialog.show();
	Atype = Dialog.getChoice();
	transpMode = Dialog.getCheckbox();
	if (Atype == "Batch Mode (Multiple Pomegranate Analyses)") runMode = true; 
	else runMode = false;

	if(runMode) confirmWindow = getBoolean("Batch mode (Multiple Pomegranate Analyses)\nShow confirmation window with each analysis?");
// -----------------------------------------------------------------------------------------------------------------------------------------------

	// Designate Input Directory
	Dialog.create("Input Directory");
		Dialog.addMessage("Analysis Type: " + Atype);
		Dialog.addChoice("Input Method", newArray("Select Input Directory","Manually Enter Path"));
	Dialog.show();
	if (Dialog.getChoice() == "Select Input Directory") directoryHolder = getDirectory("Choose an Input Directory"); 
	else directoryHolder = getString("Image Path", "/Users/hauflab/Documents");

	if (runMode) inputList  = getFileList(directoryHolder);
	else inputList = Array.concat(newArray(), directoryHolder);

	if (!transpMode) setBatchMode(true);

	
	for (m = 0; m < inputList.length; m++)
	{
		if(runMode) directoryMain = directoryHolder + inputList[m];
		else directoryMain = inputList[m];
		
		directoryResults = directoryMain + "Results";
		directoryROIs = directoryMain + "ROIs";

		nameLabel = replace(replace(File.getName(directoryMain), "/", ""),".","_"); 
		if (File.exists(directoryMain + "/Binaries/Whole_Cell_RGB.tif"))
		{
			open(directoryMain + "/Binaries/Whole_Cell_RGB.tif");
		
			run("8-bit");
			setThreshold(1, 255);
			setOption("BlackBackground", true);
			run("Convert to Mask", "method=Default background=Dark black");
			run("Z Project...", "projection=[Max Intensity]");
			binary = getTitle();
		
		// -----------------------------------------------------------------------------------------------------------------------------------------------
		
			roiList = getFileList(directoryROIs);
			for (i = 0; i < roiList.length; i++) if (endsWith(roiList[i],"_Filtered_Reconstruction_Output_Whole_Cell_ROIs.zip")) 
			{
				roiPath = directoryROIs + "/" + roiList[i];
				imageName = replace(roiList[i],"_Filtered_Reconstruction_Output_Whole_Cell_ROIs.zip",".tif");
			}
			roiManager("Open", roiPath);
		
			n = roiManager("Count");
			if (n > 0)
			{
				// Table Headers
				print("\\Clear");
				print("Image,Object_ID,Type,Radius");

				// Quantify Widths
				selectImage(binary);
				for (i = 0; i < n; i++)
				{
					roiManager("Select", i);
					if ((startsWith(call("ij.plugin.frame.RoiManager.getName", i), "WC")) & (Roi.getProperty("Mid_Slice") == 1)) 
					{
						run("Duplicate...", "title=Extract");
						setBackgroundColor(0, 0, 0);
						run("Clear Outside");
	
						// Distance Map
						selectImage("Extract");
						run("Duplicate...", "duplicate title=Distance_Map");
						run("Distance Map", "stack");
							
						// Skeleton Image
						selectImage("Extract");
						run("Duplicate...", "duplicate title=Skeleton");
						run("Skeletonize", "stack");
						run("Analyze Skeleton (2D/3D)", "prune=none");
					
						// Isolate Cell Tips 
						selectWindow("Tagged skeleton");
						run("Duplicate...", "duplicate title=Cell_Tip_Binary");
						setThreshold(1, 35);
						setOption("BlackBackground", true);
						run("Convert to Mask", "method=Default background=Dark black");
					
						// Isolate Cell Body 		
						selectWindow("Tagged skeleton");
						run("Duplicate...", "duplicate title=Cell_Body_Binary");
						setThreshold(35, 255);
						setOption("BlackBackground", true);
						run("Convert to Mask", "method=Default background=Dark black");
					
						// Skeleton Image AND Distance Map
						imageCalculator("AND create stack", "Distance_Map","Cell_Body_Binary");
						rename("Merge_Body");
					
						// Cell Tips Image AND Distance Map
						imageCalculator("AND create stack", "Distance_Map","Cell_Tip_Binary");
						rename("Merge_Tips");
	
						selectImage("Merge_Body");
						roiManager("Select", i);
						Roi.getContainedPoints(rxp, ryp);
						for (j = 0; j < rxp.length; j++) 
						{
							I = getPixel(rxp[j], ryp[j]);
							if (I != 0) print(imageName + "," + Roi.getProperty("Object_ID") + ",Body," + I);
						}
	
						selectImage("Merge_Tips");
						roiManager("Select", i);
						Roi.getContainedPoints(rxp, ryp);
						for (j = 0; j < rxp.length; j++) 
						{
							I = getPixel(rxp[j], ryp[j]);
							if (I != 0) print(imageName + "," + Roi.getProperty("Object_ID") + ",Tip," + I);
						}
	
						// Cleanup
						selectImage(binary);
						close("\\Others");
					}
				}

				
				// Result File Export [OVERWRITE]
				logFile = directoryResults + "/" + nameLabel + "_Width_Profile.csv";
				selectWindow("Log");
				if (File.exists(logFile))
				{
					showMessageWithCancel("Prerun Cleanup","There is an existing Width Profile file for this Pomegranate Analysis. Overwrite?");
					saveAs("Text", logFile);
				}
				else saveAs("Text", logFile);
				
				close("Results");
				if (confirmWindow) showMessageWithCancel("[" + nameLabel + "]\nCompleted " + (m + 1) + " out of " + inputList.length + " analyses\nContinuing to next analysis.");
				cleanAll();
			}
			else
			{
				showMessageWithCancel("Pomegranate Error", "Error: No ROIs in ROI Manager\nResponse: Ending Analysis");
				cleanAll();
				exit();
			}
		}
		else
		{
			showMessageWithCancel("Pomegranate Error", "Error: Unable to find Whole Cell RGB Image\nResponse: Ending Analysis");
			cleanAll();
			exit();
		}
	}
	showMessageWithCancel("Analysis is complete\nPlease review files in your output directory");
}

// -----------------------------------------------------------------------------------------------------------------------------------------------

// Clean Up Function
function cleanAll()
{
	close('*');
	run("Clear Results");
	roiManager("Reset");
	print("\\Clear");
} 