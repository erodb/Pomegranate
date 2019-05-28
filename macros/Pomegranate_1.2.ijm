/*  Pomegranate
 *  
 *  Virginia Polytechnic Institute and State University
 *  Blacksburg, Virginia
 *  Hauf Lab
 *  
 *  Erod Keaton D. Baybay (2019) - erodb@vt.edu
 */

macro "Pomegranate"
{
	versionFIJI = "1.52n";
	versionPIPELINE = "1.2";
	r = 18;

	// Runtime
	sTime = getTime(); 

	waitForUser("This macro performs a prerun clean up\nThis will close all currently open images without saving\nClick OK to Continue");
	cleanAll();
	
	step = 0; // Progress Ticker
	requires(versionFIJI);
	print("[Pomegranate " + versionPIPELINE + "]");
	print("Required FIJI Version: " + versionFIJI);
	print("Currently Running FIJI Version: " + getVersion);
	print("Pre-Run FIJI Memory Usage: " + IJ.freeMemory());
	
	run("Set Measurements...", "area mean standard modal min centroid center perimeter median stack display redirect=None decimal=3");

	// Z Axis Scaling Correction
	print("\n[Z-axis Scaling Correction]");
	regionscale = 1.0;
	if (getBoolean("Images may be subject to z-axis scaling due to differences in axial resolutions.\nWould you like to correct this scaling?"))
	{
		if (getBoolean("Would you like to automatically calculate this scaling?"))
		{
			Dialog.create("Z-axis Correction");
				Dialog.addNumber("Immersion Oil Refractive Index: ", 1.516);
				Dialog.addNumber("Microscope Numerical Aperture: ", 1.4);
			Dialog.show();
			znoil = Dialog.getNumber();
			zNA = Dialog.getNumber();
			if ((zNA * znoil) != 0) regionscale = znoil / (zNA * 0.61);
			print("Immersion Oil Refractive Index: " + znoil);
			print("Microscope Numerical Aperture: " + zNA);
			waitForUser("Z-axis is scaled by " + regionscale + "\nThis value will be corrected for this analysis.");
		}
		else
		{
			regionscale = getNumber("Correction Factor: ", defaultValue);
			print("Immersion Oil Refractive Index: NA (Manual Input)");
			print("Microscope Numerical Aperture: NA (Manual Input)");
			waitForUser("Z-axis is scaled by " + regionscale + "\nThis value will be corrected for this analysis.");
		}
	}
	else 
	{
		print("Immersion Oil Refractive Index: NA (No Correction)");
		print("Microscope Numerical Aperture: NA (No Correction)");
		waitForUser("Z-axis is scaled by " + regionscale + "\nThis value will NOT be corrected for this analysis.");
	}
	print("Correction Factor: " + regionscale);

// [ 0 ] -----------------------------------------------------------------------------------------------------------------------------------------------
	showStatus("Pomegranate - Opening Images");

	while (step == 0)
	{
		// Designate Input Image
		Dialog.create("Input Image");
			Dialog.addChoice("Input Method", newArray("Select Image from Directory","Manually Enter Path"));
		Dialog.show();
		if (Dialog.getChoice() == "Select Image from Directory") imagePath = File.openDialog("Choose an Input  File"); 
		else imagePath = getString("Image Path", "/Users/hauflab/Documents");

		// Designate Output Directory
		Dialog.create("Output Directory");
			Dialog.addChoice("Output Method", newArray("Select Output Directory","Manually Enter Path"));
		Dialog.show();
		if (Dialog.getChoice() == "Select Output Directory") outputPath = getDirectory("Select Output Directory"); 
		else outputPath = getString("Output Path", "/Users/hauflab/Documents");	

		// Save IDs
		getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
		saveID = "" + year + "" + month + "" + dayOfMonth + "_" + hour + "" + minute + "_" + replace(File.getName(imagePath),'.','_');
		
		// Output Directory
		directoryMain = outputPath+saveID+"/";
		if (!File.exists(directoryMain)) File.makeDirectory(directoryMain);
		
		imageName = File.getName(imagePath);
		
		run("Bio-Formats Importer", "open=" + imagePath + " autoscale color_mode=Composite view=Hyperstack stack_order=XYCZT");
		
		if (isOpen(imageName)) step++; // * * *
		else showMessageWithCancel("Pomegranate Error", "Error: Unable to Open Image");
	}

// [ 1 ] -----------------------------------------------------------------------------------------------------------------------------------------------
	showStatus("Pomegranate - Assigning Channels");

	// Get Image Dimensions
	getDimensions(width, height, channels, slices, frames);
	getVoxelSize(vx, vy, vz, unit);
	print("Original Voxel Size: " + vx + " " + unit + " ," + vy + " " + unit + " ," + vz + " " + unit);

	// Implement Scaling (if applicable)
	run("Properties...", "channels=" + channels +" slices=" + slices +" frames=" + frames + " unit=" + unit + " pixel_width=" + vx + " pixel_height=" + vy + " voxel_depth=" + vz / regionscale);	
	getVoxelSize(vx, vy, vz, unit);
	print("Corrected Voxel Size: " + vx + " " + unit + ", " + vy + " " + unit + ", " + vz + " " + unit);

	
	channelList = newArray(channels);
	for (i = 1; i <= channels; i++) channelList[i-1] = "" + i;

	// Assign Channels
	while (step == 1)
	{
		Dialog.create("Channel Selection");
			Dialog.addChoice("Measurement Channel", channelList, channelList[0]);
			Dialog.addChoice("Nuclear Marker Channel", channelList, channelList[1]);
			Dialog.addChoice("Bright-Field Channel", channelList, channelList[2]);
		Dialog.show();	
		msChannel = parseInt(Dialog.getChoice()); // Measurement Channel
		nmChannel = parseInt(Dialog.getChoice()); // Nuclear Marker Channel
		bfChannel = parseInt(Dialog.getChoice()); // Bright-Field Channel

		print("\n[Run Parameters]");
		print("Measurement Channel: " + msChannel);
		print("Nuclear Marker Channel: " + nmChannel);
		print("Bright-Field Channel: " + bfChannel);
		
		if ((nmChannel != bfChannel) && (msChannel != bfChannel) && (nmChannel != msChannel)) step++; // * * *
		else showMessageWithCancel("Pomegranate Error", "Error: Invalid Channels");
	}

// [ 2 ] -----------------------------------------------------------------------------------------------------------------------------------------------
	showStatus("Pomegranate - Nuclear Segmentation [Otsu]");

	run("Split Channels");	
	msChannel = "C"+msChannel+"-"+imageName;
	nmChannel = "C"+nmChannel+"-"+imageName;
	bfChannel = "C"+bfChannel+"-"+imageName;
	
	selectImage(nmChannel);
	setBatchMode(true); 

		run("Duplicate...", "title=DUP duplicate");
		setSlice(round(nSlices/2));
	
		// Binary Generation - Otsu Thresholding
		setAutoThreshold("Otsu dark stack");
		run("Convert to Mask", "method=Otsu background=Dark black");
	
		// Smoothing - 0.3 Micron Gaussian Blur
		run("Gaussian Blur...", "sigma=0.3 scaled stack");
		run("Make Binary", "method=Otsu background=Dark black");
	
		// Detection
		run("Analyze Particles...", "  circularity=0.6-1.00 exclude clear add stack"); // run("Analyze Particles...", "clear add stack");
		selectImage(nmChannel); 
		close("DUP");
		roiManager("Show All Without Labels");

	setBatchMode(false);

	step++; // * * *

// [ 3 ] -----------------------------------------------------------------------------------------------------------------------------------------------
	showStatus("Pomegranate - Nuclei Building Parameter");
	
	/* 
	 *  [ Notes ]
	 *  Radius used as tolerence for XY shifts of the centroid
	 *  Higher Tolerence = Releaxed - More leniant on oddly-shaped / near-telophase nuclei
	 *  Lower Toleence = Strict - Less likely to group two nuclei as one nuclei if cells are 'stacked'
	 */
	 
	while (step == 3)
	{
		rn = 15 * vx;
		en = 0.2;
		Dialog.create("Nuclei Building Parameters");
			Dialog.addNumber("Tolerance Radius (microns)", rn);
			Dialog.addNumber("Enlarge Parameter (microns)", en);
		Dialog.show();
		rn = Dialog.getNumber / vx;
		en = Dialog.getNumber;

		print("Tolerance Radius (microns): " + rn);
		print("Enlarge Parameter (microns): " + en);

		if ((!isNaN(rn)) && (rn > 0)) step++; // * * *
		else showMessageWithCancel("Pomegranate Error", "Error: Invalid Radius");
	}
	
// [ 4 ] -----------------------------------------------------------------------------------------------------------------------------------------------
	
	// Sluggish algorithm to group ROIs that make up one nuclei - using ROI names with predictable delimiters
	
	roiManager("Deselect");
	roiManager("Set Color", "Black");

	nuclearIndex = 0;
	midList = newArray();
	n = roiManager("Count");
	setBatchMode(true); 
	
	print("\n[Nuclear Fit Construction]");
	for (i = 0; i < n; i++)
	{
		showStatus("Pomegranate - Building Nuclei #" + nuclearIndex);
		if (!startsWith(call("ij.plugin.frame.RoiManager.getName", i), 'N'))
		{
			nuclearIndex++;
			transit = 0;
			displacement = 0;
			sliceCount = 1;
			currentColor = randomHexColor();
			
			roiManager("Select",i);
			nuclearName = "N" + nuclearIndex + "-" + i + "-" + getSliceNumber();
			roiManager("Rename", nuclearName);
			roiManager("Set Color", currentColor);
			run("Enlarge...", "enlarge=" + en);
			run("Fit Ellipse");

			// Set Properties
			Roi.setProperty("Nucleus_ID", nuclearIndex);
			Roi.setProperty("Status","START");
			roiManager("Update");

			// Establish First Reference Point
			getSelectionBounds(px, py, pw, ph);
			ix = px + round(pw/2);
			iy = py + round(ph/2);

			// Displacement
			dx = ix;
			dy = iy;

			// Area Screening Defaults
			getStatistics(area);
			Av = area;
			Ai = i;

			/* 
	 		 *  [ Notes ]
	 		 *  Displacement describes the shift between the bottom slice and top slice of the Nuclei
	 		 *  Transit describes the sum of all XY shifts between slices and their neighbor slice
	 		 *  Stability Score is the ratio of Displacement and Transit
	 		 */

			for (j = i + 1; j < n; j++)
			{
				showProgress(j,n);

				// Sweep ROIs within Reference Point Radius
				if ((i != j) && (!startsWith(call("ij.plugin.frame.RoiManager.getName", j), 'N')))
				{
					roiManager("Select", j);
					getSelectionBounds(px, py, pw, ph);
					jx = px + round(pw/2);
					jy = py + round(ph/2);
					getStatistics(area);

					// Radius Tolerance
					if (sqrt(pow((ix - jx),2) + pow((iy - jy),2)) <= rn)
					{
						displacement = sqrt(pow((dx - jx),2) + pow((dy - jy),2));
						transit = transit + sqrt(pow((ix - jx),2) + pow((iy - jy),2));
						sliceCount++;
						
						nuclearName = "N" + nuclearIndex + "-" + j + "-" + getSliceNumber();
						roiManager("Rename", nuclearName);
						roiManager("Set Color", currentColor);
						run("Enlarge...", "enlarge=" + en);
						run("Fit Ellipse");

						// Set Properties
						Roi.setProperty("Nucleus_ID", nuclearIndex);
						Roi.setProperty("Status","NIL");
						roiManager("Update");
						
						// Update Reference Point
						ix = jx;
						iy = jy;

						// Area Screening
						if (area > Av)
						{
							Av = area;
							Ai = j;
						}
					}
				}
			}

			// Annotate Mid
			roiManager("Select", Ai);
			Roi.setProperty("Status","MID");
			roiManager("Update");

			getStatistics(area);
			print("Nuclear Index: " + Roi.getProperty("Nucleus_ID") + "   | Mid-Slice Index: " + Ai + "   | Number of Slices: " + sliceCount + "   | Mid-Slice Area (sq. micron): " + area + "   | Total Displacement (px): " + displacement + "   | Total Transit (px): " + transit + "   | Stability Score: " + (1 - (displacement/transit)));
			midList = Array.concat(midList, Ai);
		}
	} 
	
	print("\n[Detection Summary]");
	print("Total Detected ROIs: " + roiManager("Count"));
	print("Total Generated Nuclei: " + nuclearIndex);

	//ROI Export
	print("\n[Exporting Nuclear ROI Files]");
	roiFile = directoryMain + replace(File.getName(imagePath),'.','_') + "_Nuclear_ROIs.zip";
	if (!File.exists(roiFile)) roiManager("Save", roiFile);
	print("File Created: " + roiFile);

	step++; // * * *
	
// [ 5 ] -----------------------------------------------------------------------------------------------------------------------------------------------

	// Measure Intensity
	showStatus("Pomegranate - Measuring Nuclear ROIs");

	selectImage(msChannel);
	roiManager("Deselect");
	roiManager("Show All Without Labels");
	roiManager("Measure");
	
	step++; // * * *

// [ 6 ] -----------------------------------------------------------------------------------------------------------------------------------------------

	showStatus("Pomegranate - Producing Midplane Point ROIs");
	oldList = Array.getSequence(roiManager("Count"));
	for (i = 0; i < midList.length; i++) 
	{
		showProgress(i,midList.length);
		
		roiManager("Select", midList[i]);
		getSelectionBounds(px, py, pw, ph);
		
		name = Roi.getProperty("Nucleus_ID");
		makePoint(px + (pw/2), py + (ph/2));
		Roi.setName("N" + name + "_Centroid");
		
		roiManager("Add");
	}

	roiManager("Select", oldList);
	roiManager("Delete");
	roiManager("Deselect");

	// Midpoint Export
	midFile = directoryMain + replace(File.getName(imagePath),'.','_') + "_Midpoint_ROIs.zip";
	if (!File.exists(midFile)) roiManager("Save", midFile);
	print("File Created: " + midFile);

	step++; // * * *

// [ 7 ] -----------------------------------------------------------------------------------------------------------------------------------------------

	showStatus("Pomegranate - Generating Wholecell Binary");
	setBatchMode(false);
	selectImage(bfChannel);
	
	// Select Slice
	original = getTitle();
	roiManager("Deselect");
	run("Select None");
	run("Duplicate...", "title=HOLD duplicate");
	// run("Orthogonal Views");
	waitForUser("Please Select a Slice");
	selectWindow("HOLD");
	slice = getSliceNumber();

	setBatchMode(true);

	// Unsharp Mask
	run("Duplicate...", "title=HOLD_2");
	close("HOLD");
	run("Remove Overlay");
	run("Unsharp Mask...", "radius=" + getWidth() + " mask=0.90");

	// Thresholding
	run("16-bit");
	setAutoThreshold("Otsu dark");
	setThreshold(1, 10e6);
	run("Convert to Mask");
	run("Fill Holes");
	run("Open");

	// Watersheding (Distance Transform)
	run("Distance Transform Watershed", "distances=[Chessknight (5,7,11)] output=[16 bits] normalize dynamic=6 connectivity=8");
	setThreshold(1, 10e6);
	run("Convert to Mask");

	// Binary to ROI
	rename("Binary");
	run("Analyze Particles...", "size=10-Infinity exclude clear include add");
	close("HOLD_2");

	// Cleaning
	Dialog.create("Clean Up Parameters");
		Dialog.addNumber("Gap Closure Size (pixels)", 10);
		Dialog.addNumber("Interpolation Smoothing (pixels)", 5);
	Dialog.show();
	gap = Dialog.getNumber();
	interpn = Dialog.getNumber();
	n = roiManager("Count");
	for (i = 0; i < n; i ++)
	{
		roiManager("Select",i);
		run("Enlarge...", "enlarge=" + gap + " pixel");
		run("Enlarge...", "enlarge=-" + gap + " pixel");
		run("Interpolate", "interval=" + interpn + " smooth");
		roiManager("Update");
	}

	// Manual Inspection
	setBatchMode(false);
	selectWindow("ROI Manager");
	waitForUser("Please filter ROIs manually\nOnce ROIs are filtered, click OK to continue.");
	setBatchMode(true);

	// ROI to Clean Binary
	roiManager("Deselect");
	roiManager("Combine");
	run("Create Mask");

	// Load Nuclei MidPoints
	roiManager("Reset");
	roiManager("Open", midFile);

	// Canvas
	selectImage(original);
	run("Duplicate...", "duplicate");
	run("Multiply...", "value=0 stack");
	run("8-bit");
	rename("Canvas");

	// Z Alignment
	n = roiManager("Count");
	slice = 1;	
	for (i = 0; i < n; i++)
	{
		// Grab
		selectImage("Mask");
		roiManager("Select", i);
		getSelectionBounds(px, py, pw, ph);
		doWand(px - 10, py - 10);
		Roi.getCoordinates(rx, ry);
		getSelectionBounds(px, py, pw, ph);
	
		// Release
		if (pw * ph < 0.4 * (getWidth() * getHeight()))
		{
			setColor(0, 0, 0);
			fill();
			
			selectImage("Canvas");
			roiManager("Select", i);
			makeSelection("freehand",rx,ry);
			
			setColor(255,255,255);
			fill();
		}
	}

	// Clean, Z Aligned Binary to ROI
	selectImage("Canvas");
	run("Select None");
	run("Analyze Particles...", "size=20-Infinity pixel exclude clear add stack");
	
	step++; // * * *

// [ 8 ] -----------------------------------------------------------------------------------------------------------------------------------------------

	showStatus("Pomegranate - Constructing Whole Cell Fits");
	print("\n[Whole Cell Fit Construction]");
	r = getNumber("Cell Radius (microns): ", r * vx);
	print("Cell Radius: " + r + " microns");
	r = r / vx;
	
	// Project into 3D
	n = roiManager("Count");
	for (i = 0; i < n; i++)
	{
		roiManager("Select", i);
		roiManager("Rename", "A_Cell_" + (i + 1) + "_MID");
		Roi.getCoordinates(rx, ry);
		
		getStatistics(A1);
		wcVol = A1;
		midn = getSliceNumber();
		wcSlices = 0;
		
		for (k = 1; k <= nSlices; k++)
		{
			dz = 1/regionscale * (midn - k);
			kr = floor(sqrt(pow(r,2) - pow(dz,2)));
			if ((r - kr) > 0)
			{
				setSlice(k);
				makeSelection("freehand",rx,ry);
				run("Enlarge...", "enlarge=" + -(r - kr) + " pixel");
				Roi.setName("B_Cell_" + (i + 1) + "_Slice_" + k);
				
				// Only Accept ROI if smaller than midslice
				getStatistics(A2);
				if (A1 > A2) 
				{
					roiManager("Add");
					wcVol = wcVol + A2;
					wcSlices++;
				}
			}
		}
		print("Cell Index: " + (i + 1) + " | Volume (cubic microns): " + wcVol + " | Slices: " + wcSlices);
	}

	run("Select None");

	// Wholecell Export
	wcFile = directoryMain + replace(File.getName(imagePath),'.','_') + "_Wholecell_ROIs.zip";
	if (!File.exists(wcFile)) roiManager("Save", wcFile);
	print("File Created: " + wcFile);

	setBatchMode(false); 

	step++; // * * *

// [ 9 ] -----------------------------------------------------------------------------------------------------------------------------------------------

	showStatus("Pomegranate - Exporting Results");
	print("\n[Exporting Results]");
			
	// Results Export
	resultFile = directoryMain + replace(File.getName(imagePath),'.','_') + "_Results.csv";
	if (!File.exists(resultFile)) saveAs("Results", resultFile);
	print("File Created: " + resultFile);

	// Runtime Check
	print("\n[Run Performance]");
	print("Total Runtime: " + ((getTime() - sTime)/1000) + " seconds");   
	print("Post-Run FIJI Memory Usage: " + IJ.freeMemory());

	// Log File Export
	logFile = directoryMain + replace(File.getName(imagePath),'.','_') + "_LOG.txt";
	if (!File.exists(logFile))
	{
		selectWindow("Log");
		saveAs("Text", logFile);
	}

	run("Collect Garbage"); 
	waitForUser("Done", "Macro is complete.");
}


// [ Functions ] -----------------------------------------------------------------------------------------------------------------------------------------------

// Clean Up Function
function cleanAll()
{
	close('*');
	run("Clear Results");
	roiManager("Reset");
	print("\\Clear");
} 

// Return a Random Color in Hex Function
function randomHexColor()
{
	hex = newArray();
	char = newArray('1','2','3','4','5','6','7','8','9','0','A','B','C','D','E','F');
	output = '#' + char[round((char.length - 1) * random)] + char[round((char.length - 1) * random)] + char[round((char.length - 1) * random)] + char[round((char.length - 1) * random)] + char[round((char.length - 1) * random)] + char[round((char.length - 1) * random)];
	return output;
}
