macro "Cell Viewer"
{
	versionFIJI = "1.53b";
	requires(versionFIJI);

	// Title Pop Up
	showMessage("Pomegranate Cell Isolator Tool", "<html>"
	+"<font size=+3><center><b>Pomegranate</b><br></center>"
	+"<font size=+1><center><b>Cell Isolator Tool</b><br></center>"
	+"<br>"
	+"<font size=-2><center><b>Virginia Tech, Blacksburg, Virginia</b></center>"
	+"<font size=-2><center><b>Department of Biological Sciences - Hauf Lab</b></center>"
	+"<ul>"
	+"<li><font size=-2>FIJI Version Required: " + versionFIJI
	+"</ul>"
	+"<font size=-2><center>Please read accompanying documentation</b></center>"
	+"<font size=-2><center>[Erod Keaton Baybay - erodb@vt.edu]</b></center>");

	showMessageWithCancel("Prerun Cleanup","This macro performs a prerun clean up\nThis will close all currently open images without saving\nClick OK to Continue");
	cleanAll();

	// Designate Input Image
	Dialog.create("Input Image");
		Dialog.addChoice("Input Method", newArray("Select Image from Directory","Manually Enter Path"));
	Dialog.show();
	if (Dialog.getChoice() == "Select Image from Directory") imagePath = File.openDialog("Choose an Input  File"); 
	else imagePath = getString("Image Path", "/Users/hauflab/Documents");

	open(imagePath);

	call("ij3d.ImageJ3DViewer.close");
	getVoxelSize(vxy, vxy, vz, unit);
	original = getTitle();
	
	close("\\Others");
	run("Select None");
	roiManager("Reset");
	print("\\Clear");
	
	setSlice(round(nSlices/2));
	run("Duplicate...", "title=TEMP duplicate");
	run("Z Project...", "projection=[Max Intensity]");
	close("TEMP");
	
	setTool("Wand");
	waitForUser("Select a cell (Wand Tool)");
	
	if (selectionType() != -1)
	{	
		roiManager("Add");
		selectImage(original);
		
		roiManager("Select", 0);
		run("Duplicate...", "title=Extracted_Cell duplicate");
		setBackgroundColor(0, 0, 0);
		run("Clear Outside", "stack");

		run("Select None");
		roiManager("Reset");
		close("MAX_TEMP");

		run("8-bit");
		setThreshold(3, 255);
		setOption("BlackBackground", true);
		run("Convert to Mask", "method=Default background=Dark black");

		roiManager("Deselect");
		run("Select None");
		run("Canvas Size...", "width=" + (getWidth() + 20) + " height=" + (getHeight() + 20) + " position=Center zero");

		// Medial Axis Transform for Size Measurement
		selectImage("Extracted_Cell");
		run("Z Project...", "projection=[Max Intensity]");
		rename("TEMP");
		run("Duplicate...", "duplicate title=Skeleton");
		run("Skeletonize", "stack");
		run("Select All");
		skeleLength = (getValue("RawIntDen")/255) * vxy;
		selectImage("TEMP");
		run("Duplicate...", "duplicate title=Distance_Map");
		run("Distance Map", "stack");
		imageCalculator("AND create stack", "Distance_Map","Skeleton");
		rename("MAT");
		close("Skeleton");
		close("Distance_Map");
		close("TEMP");

		// 0 to NaN
		run("32-bit");
		run("Reciprocal");
		run("Reciprocal");
		run("Select All");
		Rwidth = getValue("Mean") * vxy;
		Rlength = skeleLength + (2 * Rwidth);
		close("MAT");
		run("Analyze Particles...", "exclude clear add stack");

		showOverlay  = getBoolean("Show Ideal Reconstruction Comparison?");

		// Length and Width Parameter Extraction
		roiManager("Select", Array.getSequence(roiManager("Count")));
		roiManager("Combine");
			
		Elength = getValue("Major") / vxy;
		Ewidth = getValue("Minor") / vxy;
		Eangle = getValue("Angle");
			
		Flength = getValue("Feret") / vxy;
		Fwidth = getValue("MinFeret") / vxy;
		Fangle = getValue("FeretAngle");

		// Extract Volume
		volume = 0;
		n = roiManager("Count");
		for (i = 0; i < n; i++)
		{
			roiManager("Select", i);
			volume = volume + getValue("Area") * vz;
		}

		if (showOverlay)
		{	
			// Ellipsoidal Overlay
			run("Rotate...", "rotate angle="+(Eangle));
			getSelectionBounds(rx, ry, bx, by);
			shiftx = round(Elength - bx)/2;
			shifty = round(Ewidth - by)/2;
			makeRectangle(rx - shiftx, ry - shifty, Elength, Ewidth, Ewidth);
			run("Rotate...", "  angle="+(-Eangle));
			Roi.setStrokeWidth(1);
			Roi.setStrokeColor("red");
			Overlay.addSelection;
	
			run("Select None");
			roiManager("Select", Array.getSequence(roiManager("Count")));
			roiManager("Combine");
				
			// Feret Overlay
			run("Rotate...", "rotate angle="+(Fangle));
			getSelectionBounds(rx, ry, bx, by);
			shiftx = round(Flength - bx)/2;
			shifty = round(Fwidth - by)/2;
			makeRectangle(rx - shiftx, ry - shifty, Flength, Fwidth, Fwidth);
			run("Rotate...", "rotate angle="+(-Fangle));
			Roi.setStrokeWidth(1);
			Roi.setStrokeColor("yellow");
			Overlay.addSelection;
			Overlay.show;
		}
		
		print("[Size Information]");
		print("Fit Ellipse Length: " + (Flength * vxy) + " " + unit);
		print("Fit Ellipse Width: " + (Fwidth * vxy) + " " + unit);
		
		print("Feret Length: " + (Flength * vxy) + " " + unit);
		print("Feret Width: " + (Fwidth * vxy) + " " + unit);
		
		print("Reconstruction Length: " + Rlength + " " + unit);
		print("Reconstruction Width: " + 2 * Rwidth + " " + unit);

		print("Volume: " + volume + " cubic. " + unit);
				
		setSlice(round(nSlices/2));
		roiManager("Show None");
		run("Select None");
		roiManager("Deselect");

		run("3D Viewer");
		call("ij3d.ImageJ3DViewer.setCoordinateSystem", "false");
		call("ij3d.ImageJ3DViewer.add", "Extracted_Cell", "None", "Extracted_Cell", "0", "true", "true", "true", "1", "0");
		call("ij3d.ImageJ3DViewer.select", "Extracted_Cell");
		call("ij3d.ImageJ3DViewer.setColor", "255", "255", "255");

		selectWindow("Log");
		waitForUser("Cell Isolated!");
	}
}

// Clean Up Function
function cleanAll()
{
	close('*');
	run("Clear Results");
	roiManager("Reset");
	print("\\Clear");
} 