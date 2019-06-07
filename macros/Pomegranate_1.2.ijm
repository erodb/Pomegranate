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
			// Calculate Z Axis Scaling
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
			// Manual Input Z Axis Scaling
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

		imageName = File.getName(imagePath);

		// Designate Output Directory
		Dialog.create("Output Directory");
			Dialog.addChoice("Output Method", newArray("Select Output Directory","Manually Enter Path"));
		Dialog.show();
		if (Dialog.getChoice() == "Select Output Directory") outputPath = getDirectory("Select Output Directory"); 
		else outputPath = getString("Output Path", "/Users/hauflab/Documents");	

		// Save IDs
		getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
		saveID = "" + year + "" + month + "" + dayOfMonth + "_" + hour + "" + minute + "_" + imageName;
		runID = "" + year + "" + month + "" + dayOfMonth + "" + hour + "" + minute;
		
		// Output Directory
		directoryMain = outputPath+saveID+"/";
		if (!File.exists(directoryMain)) File.makeDirectory(directoryMain);
		
		run("Bio-Formats Importer", "open=" + imagePath + " autoscale color_mode=Composite view=Hyperstack stack_order=XYCZT");
		
		if (isOpen(imageName)) step++; // * * *
		else showMessageWithCancel("Pomegranate Error", "Error: Unable to Open Image");
	}

// [ 1 ] -----------------------------------------------------------------------------------------------------------------------------------------------
	showStatus("Pomegranate - Assigning Channels");

	// Get Image Dimensions
	getDimensions(width, height, channels, slices, frames);
	getVoxelSize(vx, vy, vz, unit);
	print("Original Voxel Size: " + vx + " " + unit + ", " + vy + " " + unit + ", " + vz + " " + unit);

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
		// Nuclear ROI Run Parameters
		rn = 15 * vx;
		en = 0.2;
		mroi = 5;
		stabThresh = 0.7;
		Dialog.create("Nuclei Building Parameters");
			Dialog.addNumber("Tolerance Radius (microns)", rn);
			Dialog.addNumber("Enlarge Parameter (microns)", en);
			Dialog.addNumber("Minimum ROIs per Nuclei", mroi);
			Dialog.addNumber("Stability Score Threshold", stabThresh);
		Dialog.show();
		rn = Dialog.getNumber / vx;
		en = Dialog.getNumber;
		mroi = Dialog.getNumber;
		stabThresh = Dialog.getNumber();

		// Disqualified ROIs
		badNuclei = newArray();

		print("Tolerance Radius (microns): " + rn);
		print("Enlarge Parameter (microns): " + en);
		print("Minimum ROIs per Nuclei: " + mroi);
		print("Stability Score Threshold: " + stabThresh);

		if ((!isNaN(rn)) && (rn > 0)) step++; // * * *
		else showMessageWithCancel("Pomegranate Error", "Error: Invalid Radius");
	}
	
// [ 4 ] -----------------------------------------------------------------------------------------------------------------------------------------------
	
	// Sluggish algorithm to group ROIs that make up one nuclei - using ROI names with predictable delimiters
	
	roiManager("Deselect");
	roiManager("Set Color", "Black");

	nuclearIndex = 0;
	badCount = 0;
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
			currentColor = randomHexColor();
			
			roiManager("Select",i);
			
			// Indices of ROIs creating current Nuclei
			currentMembers = newArray(); 
			currentMembers = Array.concat(currentMembers, i);

			// Slice Containing ROIs of the Current Nuclei
			sliceList = newArray();
			sliceList = Array.concat(sliceList, getSliceNumber());
			
			nuclearName = "N" + nuclearIndex + "-" + i + "-" + getSliceNumber();
			roiManager("Rename", nuclearName);
			roiManager("Set Color", currentColor);
			run("Enlarge...", "enlarge=" + en);
			run("Fit Ellipse");

			// Set Properties
			ID = runID + "" + nuclearIndex;
			Roi.setProperty("Object_ID", ID);
			Roi.setProperty("Nucleus_ID", nuclearIndex);
			Roi.setProperty("Mid-Slice", false);
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
			As = getSliceNumber();

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
						currentMembers = Array.concat(currentMembers, j);
						sliceList = Array.concat(sliceList, getSliceNumber());
						
						nuclearName = "N" + nuclearIndex + "-" + j + "-" + getSliceNumber();
						roiManager("Rename", nuclearName);
						roiManager("Set Color", currentColor);
						run("Enlarge...", "enlarge=" + en);
						run("Fit Ellipse");

						// Set Properties
						ID = runID + "" + nuclearIndex;
						Roi.setProperty("Object_ID", ID);
						Roi.setProperty("Nucleus_ID", nuclearIndex);
						Roi.setProperty("Mid-Slice", false);
						roiManager("Update");
						
						// Update Reference Point
						ix = jx;
						iy = jy;

						// Area Screening
						if (area > Av)
						{
							Av = area;
							Ai = j;
							As = getSliceNumber();
						}
					}
				}
			}

			/* 
	 		 *  [ Notes ]
	 		 *  Displacement describes the shift between the bottom slice and top slice of the Nuclei
	 		 *  Transit describes the sum of all XY shifts between slices and their neighbor slice
	 		 *  Stability Score is the ratio of Displacement and Transit
	 		 */

			// Stability Score
			stabScore = 1 - (displacement/transit);
			if (isNaN(stabScore)) stabScore = 0;

			// Nuclear Quality Control
			if (currentMembers.length < mroi) // Minimum ROI per Nuclei Check
			{
				badNuclei = Array.concat(badNuclei, currentMembers);
				print("[" + ID + "] Nuclear Index: " + nuclearIndex + "   | <!> Removing Nuclei: Insufficient number of ROIs - " + currentMembers.length);
				badCount++;
			}
			else if (!checkSeq(sliceList)) // Continuous ROI Stack Check
			{
				badNuclei = Array.concat(badNuclei, currentMembers);
				print("[" + ID + "] Nuclear Index: " + nuclearIndex + "   | <!> Removing Nuclei: Inappropriate Acquisition - Non-continous ROI stack");
				badCount++;
			}
			else if (stabScore < stabThresh) // Stability Score Check
			{
				badNuclei = Array.concat(badNuclei, currentMembers);
				print("[" + ID + "] Nuclear Index: " + nuclearIndex + "   | <!> Removing Nuclei: Low Stability Score - " + stabScore);
				badCount++;
			}
			else if (As == 1) // Noisy / Bleed-Through Acquisition Check
			{
				badNuclei = Array.concat(badNuclei, currentMembers);
				print("[" + ID + "] Nuclear Index: " + nuclearIndex + "   | <!> Removing Nuclei: Inappropriate Acquisition - Largest ROI is in the first slice");
				badCount++;
			}
			else
			{
				// Annotate Mid
				roiManager("Select", Ai);
				Roi.setProperty("Mid-Slice", true);
				roiManager("Update");
				getStatistics(area);
				
				print("[" + ID + "] Nuclear Index: " + nuclearIndex + "   | Mid-Slice Index: " + Ai + "   | Number of Slices: " + currentMembers.length + "   | Mid-Slice Area (sq. micron): " + area + "   | Total Displacement (px): " + displacement + "   | Total Transit (px): " + transit + "   | Stability Score: " + stabScore);
				midList = Array.concat(midList, Ai);
			}
		}
	} 

	// Delete Disqualified ROIs
	if (badNuclei.length > 0)
	{
		roiManager("Select", badNuclei);
		roiManager("Delete");
	}
	roiManager("Deselect");
	
	print("\n[Detection Summary]");
	print("Total Detected ROIs: " + roiManager("Count"));
	print("Total Generated Nuclei: " + nuclearIndex);
	print("Total Removed Nuclei: " + badCount);

	// Nuclear ROI Export
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

	// Record Object IDs and Data Type
	n = roiManager("Count");
	for (i = 0; i < n; i++)
	{
		roiManager("Select", i);
		ID = Roi.getProperty("Object_ID");
		setResult("Object_ID", i, ID);
		setResult("Data_Type", i, "Nucleus");
	}

	// Results Export
	showStatus("Pomegranate - Exporting Nuclear Measurements");
	print("\n[Exporting Results]");
	nResultFile = directoryMain + replace(File.getName(imagePath),'.','_') + "_Results_Nuclear.csv";
	if (!File.exists(nResultFile)) saveAs("Results", nResultFile);
	print("File Created: " + nResultFile);
	
	step++; // * * *

// [ 6 ] -----------------------------------------------------------------------------------------------------------------------------------------------

	/*  [ Notes ]
	 *  The following is good for aligning whole cell ROIs with
	 *  nuclear ROIs. This acts on the assumption that Nuclei are
	 *  perfectly centered in Z within the cell. 
	 */
	 
	showStatus("Pomegranate - Producing Centroid ROIs");
	print("\n[Centroid Construction]");
	n = roiManager("Count");
	oldList = Array.getSequence(n);
	for (i = 0; i < n; i++) 
	{
		showProgress(i, n);
		roiManager("Select", i);
		if (Roi.getProperty("Mid-Slice"))
		{
			getSelectionBounds(px, py, pw, ph);
			ps = getSliceNumber();
			
			name = Roi.getProperty("Nucleus_ID");
			ID = Roi.getProperty("Object_ID");
			makePoint(px + (pw/2), py + (ph/2));
			Roi.setName("N" + name + "_Centroid");
			Roi.setProperty("Object_ID", ID);

			print("[" + ID + "] Centroid ROI: " + i + "   | X: " + px + (pw/2) + " - Y: " + py + (ph/2) + " | Slice: " + ps);
			roiManager("Add");
		}
	}
	
	// Clear Original ROIs
	if (oldList.length > 0)
	{
		roiManager("Select", oldList);
		roiManager("Delete");
	}
	roiManager("Deselect");

	// Centroid Export
	showStatus("Pomegranate - Exporting Centroid ROis");
	print("\n[Exporting Centroid ROIs]");
	midFile = directoryMain + replace(File.getName(imagePath),'.','_') + "_Centroid_ROIs.zip";
	if (!File.exists(midFile)) roiManager("Save", midFile);
	print("File Created: " + midFile);

	step++; // * * *

// [ 7 ] -----------------------------------------------------------------------------------------------------------------------------------------------
	
	showStatus("Pomegranate - Generating Whole Cell Binary");
	setBatchMode(false);
	selectImage(bfChannel);

	// Select Slice
	original = getTitle();
	roiManager("Deselect");
	run("Select None");
	run("Duplicate...", "title=HOLD duplicate");
	waitForUser("Please Select a Mid Slice");
	midslice = getSliceNumber();

	setBatchMode(true);
	for (i = 1; i < midslice; i++)
	{
		// Unsharp Mask
		selectWindow("HOLD");
		setSlice(i);
		run("Duplicate...", "title=HOLD_"+i);
		run("Remove Overlay");
		run("Unsharp Mask...", "radius=" + getWidth() + " mask=0.90");
	
		// Thresholding
		run("16-bit");
		setAutoThreshold("Otsu dark");
		setThreshold(1, 10e6);
		run("Convert to Mask");
		run("Open");
	}
	close("HOLD");

	// Projection
	run("Images to Stack", "name=HOLD_STACK title=HOLD use");
	run("Z Project...", "projection=[Average Intensity]");
	close("HOLD_STACK");

	// "Skeleton Floss"
	run("Invert");
	setOption("BlackBackground", true);
	run("Make Binary");
	run("Skeletonize");
	run("Invert");
	run("Erode"); // Erode Step [ See Notes ]
	rename("Binary");
	
	// Size-Based Hole Filling
	run("Duplicate...", "title=Fill_Holes");
	run("Invert");
	run("Analyze Particles...", "size=0-500 pixel clear add");
	selectImage("Binary");
	for (i = 0; i < roiManager("Count"); i++)
	{
		roiManager("Select", i);
		setColor(255, 255, 255);
		fill();
	}
	close("Fill_Holes");
	roiManager("Reset");
	makeRectangle(1, 1, 1, 1);
	run("Select None");

	/*  [ Notes ]
	 *  For whatever reason, after the ROI Manager is reset, a selection
	 *  needs to be made in order to use Analyze Particles - otherwise
	 *  no ROIs will be added to the ROI Manager
	 */

	run("Analyze Particles...", "size=10-Infinity exclude clear add");
	setBatchMode(false);
	
	/*  [ Notes ]
	 *  Erode step above is necessary for Analyze Particles to perform well
	 *  The Erode step is compensated for later in the smoothing step with
	 *  an Enlarge step (Enlarge being similar to the Dilate Morphological Operator)
	 *  
	 *  The enlarge step is annotated with a <+>
	 */
	
	// Smoothing Parameters
	gap = 10;
	interpn = 10;
	Dialog.create("Clean Up Parameters");
		Dialog.addNumber("Gap Closure Size (pixels)", gap);
		Dialog.addNumber("Interpolation Smoothing (pixels)", interpn);
	Dialog.show();
	gap = Dialog.getNumber();
	interpn = Dialog.getNumber();
	
	// Smoothing
	n = roiManager("Count");
	badMask = newArray();
	for (i = 0; i < n; i ++)
	{
		roiManager("Select",i);
		getSelectionBounds(px, py, pw, ph);
		if (pw * ph < 0.4 * (getWidth() * getHeight()))
		{
			run("Enlarge...", "enlarge=" + gap + " pixel");
			run("Enlarge...", "enlarge=-" + gap + " pixel");
			run("Interpolate", "interval=" + interpn + " smooth adjust");
			roiManager("Update");
		}
		else badMask = Array.concat(i, badMask);
	}
	
	// Clean Up Bad ROIs
	if (badMask.length > 0)
	{
		roiManager("Select", badMask);
		roiManager("Delete");
	}
	roiManager("Deselect");


	// ROI to Clean Binary
	roiManager("Deselect");
	roiManager("Combine");
	run("Create Mask");

	// Manual Inspection
	/*
	setBatchMode(false);
	selectImage("Mask");
	selectWindow("ROI Manager");
	waitForUser("Please filter ROIs manually\nOnce ROIs are filtered, click OK to continue.");
	setBatchMode(true);*/
	
	// Load Nuclei MidPoints
	roiManager("Reset");
	roiManager("Open", midFile);

	// Canvas
	selectImage(original);
	run("Duplicate...", "duplicate");
	run("Multiply...", "value=0 stack");
	run("8-bit");
	rename("Canvas");

	/*  [ Notes ]
	 *  The Grab-Release system is a way to take information from the 2D binary
	 *  and place them into a 3D canvas for whole cell reconstruction. 
	 *  It's not an ideal algorithm - but it works.
	 *  
	 *  Convexity is the ratio of areas between an ROI and its Convex Hull
	 */

	convThresh = 0.9;
	convThresh = getNumber("Convexity Threshold", convThresh);

	// Z Alignment
	n = roiManager("Count");
	oldList = Array.getSequence(n);
	print("\n[Transferring Mask to Canvas]");
	selectImage("Canvas");
	slice = 1;	
	for (i = 0; i < n; i++)
	{
		// Target
		selectImage("Mask");
		roiManager("Select", i);
		ID = Roi.getProperty("Object_ID");
		getSelectionBounds(px, py, pw, ph);

		// Grab
		doWand(px - 10, py - 10);
		Roi.getCoordinates(rx, ry);
		getSelectionBounds(px, py, pw, ph);
		convScore = convexity();
	
		// Conditional Release
		if (pw * ph < 0.4 * (getWidth() * getHeight()))
		{
			if (convScore > convThresh)
			{
				setColor(0, 0, 0);
				fill();
				
				selectImage("Canvas");
				roiManager("Select", i);
				
				makeSelection("freehand",rx,ry);
				run("Enlarge...", "enlarge=1 pixel"); // <+>
				
				// Temporary ROIs - Keeps centroids up front
				Roi.setProperty("Object_ID", ID);
				Roi.setName("Z_"+ID); 
				roiManager("Add");
	
				// Paint Canvas
				setColor(255,255,255);
				fill();
	
				print("[" + ID + "] Cell Index: " + (i + 1) + "   | Transferred to Canvas");
			}
			else print("[" + ID + "] Cell Index: " + (i + 1) + "   | <!> ROI is below convexity threshold: " + convScore);
		}
		else print("[" + ID + "] Cell Index: " + (i + 1) + "   | <!> ROI is too large: " + (pw * ph) + " pixels");
	}

	// Clear Original ROIs
	if (oldList.length > 0)
	{
		roiManager("Select", oldList);
		roiManager("Delete");
	}
	roiManager("Deselect");

	
	step++; // * * *

// [ 8 ] -----------------------------------------------------------------------------------------------------------------------------------------------

	showStatus("Pomegranate - Constructing Whole Cell Fits");
	print("\n[Whole Cell Fit Construction]");

	selectImage("Canvas");
	r = getNumber("Cell Radius (microns): ", r * vx);
	print("Cell Radius: " + r + " microns");
	r = r / vx;
	
	// Project into 3D
	n = roiManager("Count");
	for (i = 0; i < n; i++)
	{
		roiManager("Select", i);
		ID = Roi.getProperty("Object_ID");
		roiManager("Rename", "A_Cell_" + (i + 1) + "_MID");
		Roi.getCoordinates(rx, ry);

		// ROI Volume Measurements
		getStatistics(A1);
		midn = getSliceNumber();
		wcVol = A1;
		wcSlices = 0;
		
		for (k = 1; k <= nSlices; k++)
		{
			dz = 1/regionscale * (midn - k);
			kr = round(sqrt(pow(r,2) - pow(dz,2)));
			if ((r - kr) >= 0)
			{
				setSlice(k);
				makeSelection("freehand",rx,ry);
				run("Enlarge...", "enlarge=" + -(r - kr) + " pixel");
				Roi.setName("B_Cell_" + (i + 1) + "_Slice_" + k);
				
				// Check for successful erosion
				getStatistics(A2);
				if ((A1 > A2) || ((r - kr) == 0))
				{
					Roi.setProperty("Object_ID", ID);
					roiManager("Add");

					// Paint Canvas
					setColor(255,255,255);
					fill();
					
					wcVol = wcVol + A2;
					wcSlices++;
				}
			}
		}
		print("[" + ID + "] Cell Index: " + (i + 1) + "   | Volume (cubic microns): " + wcVol + " | Slices: " + wcSlices);
	}

	run("Select None");

	// Whole Cell ROI Export
	showStatus("Pomegranate - Exporting Whole Cell ROis");
	print("\n[Exporting Whole Cell ROIs]");
	wcFile = directoryMain + replace(File.getName(imagePath),'.','_') + "_Whole_Cell_ROIs.zip";
	if (!File.exists(wcFile)) roiManager("Save", wcFile);
	print("File Created: " + wcFile);

	setBatchMode(false); 

	step++; // * * *

// [ 9 ] -----------------------------------------------------------------------------------------------------------------------------------------------

	// Measure Intensity
	showStatus("Pomegranate - Measuring Whole Cell ROIs");

	selectImage(msChannel);
	roiManager("Deselect");
	roiManager("Show All Without Labels");
	roiManager("Measure");

	// Record Object IDs and Data Type
	n = roiManager("Count");
	for (i = 0; i < n; i++)
	{
		roiManager("Select", i);
		ID = Roi.getProperty("Object_ID");
		setResult("Object_ID", i, ID);
		setResult("Data_Type", i, "Whole_Cell");
	}

	// Results Export
	showStatus("Pomegranate - Exporting Whole Cell Measurements");
	print("\n[Exporting Results]");
	wcResultFile = directoryMain + replace(File.getName(imagePath),'.','_') + "_Results_Whole_Cell.csv";
	if (!File.exists(wcResultFile)) saveAs("Results", wcResultFile);
	print("File Created: " + wcResultFile);
	
	step++; // * * *

// [ 10 ] -----------------------------------------------------------------------------------------------------------------------------------------------

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

// Check if Array is a 1-Interval Sequence
function checkSeq(arr)
{
	output = true;
	arr = Array.sort(arr);
	min = arr[0];
	for (i = 0; i < arr.length; i++) arr[i] = arr[i] - min;
	refSeq = Array.getSequence(arr.length);
	for (i = 0; i < arr.length; i++) if (arr[i] != refSeq[i]) output = false;
	return output;
}

// Convexity Check
function convexity()
{
	if (selectionType() != -1)
	{
		getStatistics(AR1);
		Roi.getCoordinates(rx, ry);
		run("Convex Hull");
		getStatistics(AR2);
		makeSelection("freehand",rx,ry);
		
		return(AR1/AR2);
	}
	else return(NaN);
}