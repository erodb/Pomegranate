/*  Pomegranate
 *  
 *  Virginia Polytechnic Institute and State University
 *  Blacksburg, Virginia
 *  Hauf Lab
 *  
 *  Erod Keaton D. Baybay (2019) - erodb@vt.edu
 *  Last Updated: June 26, 2019
 */

macro "Pomegranate"
{ 		 
	versionFIJI = "1.52o";
	versionPIPELINE = "1.0";

	requires(versionFIJI);

	// Title Pop Up
	showMessageWithCancel("Pomegranate " + versionPIPELINE, "<html>"
	  		+"<font size=+3><center><b>Pomegranate</b><br></center>"
	  		+"<font size=-2><center><b>Virginia Polytechnic Institute and State University</b></center>"
	  		+"<font size=-2><center><b>Department of Biological Sciences - Hauf Lab</b></center>"
	  		+"<ul>"
	  		+"<li><font size=-2>Pipeline Version: " + versionPIPELINE
	  		+"<li><font size=-2>FIJI Version Required: " + versionFIJI
	  		+"</ul>"
	  		+"<font size=-2><center>Please read accompanying documentation</b></center>"
	  		+"<font size=-2><center>[Erod Keaton Baybay - erodb@vt.edu]</b></center>");

	// Runtime
	sTime = getTime(); 

	waitForUser("This macro performs a prerun clean up\nThis will close all currently open images without saving\nClick OK to Continue");
	cleanAll();
	
	step = 0; // Progress Ticker
	print("[Pomegranate " + versionPIPELINE + "]");
	print("Required FIJI Version: " + versionFIJI);
	print("Currently Running FIJI Version: " + getVersion);
	print("Pre-Run FIJI Memory Usage: " + IJ.freeMemory());
	
	roiManager("Associate", "true");
	roiManager("UseNames", "true");
	
	run("Set Measurements...", "area mean standard modal min centroid center perimeter median stack limit display redirect=None decimal=3");

	// Designate Run Mode
	print("\n[Run Mode]");

	regionscale = -1;
	while (regionscale <= 0)
	{
		runModeList = newArray("Both Nuclear and Whole Cell Segmentation", "Nuclear Segmentation Only", "Whole Cell Segmentation Only");
		regionscale = 1.690;
		transpMode = false;
		Dialog.create("Pomegranate Run Parameters");
			Dialog.addChoice("Analysis Type", runModeList);
			Dialog.addNumber("Z Distance Calibration Factor", regionscale);
			Dialog.addCheckbox("Transparent Mode", transpMode);
		Dialog.show()
		runMode = Dialog.getChoice();
		regionscale = Dialog.getNumber();
		transpMode = Dialog.getCheckbox();
	}
	
	print("Analysis Type: " + runMode);
	print("Z Scaling Factor: " + regionscale);
	if (transpMode) print("Transparent Mode: Enabled");
	else print("Transparent Mode: Disabled");
	
	if (runMode == runModeList[0]) runMode = "BOTH";
	else if (runMode == runModeList[1]) runMode = "NUCL";
	else if (runMode == runModeList[2]) runMode = "WLCL";

	// Set Experiment Name
	expName = getString("Experiment Name", "Experiment_01");

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

		print("\n[User Input]");
		print("Image Name: " + imageName);
		print("Image Path: " + imagePath);

		// Designate Output Directory
		Dialog.create("Output Directory");
			Dialog.addChoice("Output Method", newArray("Select Output Directory","Manually Enter Path"));
		Dialog.show();
		if (Dialog.getChoice() == "Select Output Directory") outputPath = getDirectory("Select Output Directory"); 
		else outputPath = getString("Output Path", "/Users/hauflab/Documents");	

		// Save IDs
		getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
		saveID = "" + year + "" + month + "" + dayOfMonth + "_" + hour + "" + minute + "_" + imageName;
		runID = "OID" + (year - 2000) + "" + month + "" + dayOfMonth + "" + hour + "" + minute;

		print("\n[Experiment Information]");
		print("Experiment Name: " + expName);
		print("Save ID: " + runID);
		print("Generic Run ID: " + runID);
		
		// Output Directory
		directoryMain = outputPath+saveID+"/";
		if (!File.exists(directoryMain)) File.makeDirectory(directoryMain);

			// ROI Directory
			directoryROI = directoryMain + "ROIs/";
			if (!File.exists(directoryROI)) File.makeDirectory(directoryROI);

			// Results Directory
			directoryResults = directoryMain + "Results/";
			if (!File.exists(directoryResults)) File.makeDirectory(directoryResults);
		
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
			if (runMode != "WLCL") Dialog.addChoice("Nuclear Marker Channel", channelList, channelList[1]);
			if (runMode != "NUCL") Dialog.addChoice("Bright-Field Channel", channelList, channelList[2]);
		Dialog.show();	
		msChannel = parseInt(Dialog.getChoice()); // Measurement Channel
		if (runMode != "WLCL") nmChannel = parseInt(Dialog.getChoice()); // Nuclear Marker Channel
		if (runMode != "NUCL") bfChannel = parseInt(Dialog.getChoice()); // Bright-Field Channel

		print("\n[Run Parameters]");
		print("Measurement Channel: " + msChannel);
		if (runMode != "WLCL") print("Nuclear Marker Channel: " + nmChannel);
		if (runMode != "NUCL") print("Bright-Field Channel: " + bfChannel);

		// Defaulting Omitted Variables
		if (runMode == "WLCL") nmChannel = -2;
		if (runMode == "NUCL") bfChannel = -3;
		
		if ((nmChannel != bfChannel) && (msChannel != bfChannel) && (nmChannel != msChannel)) step++; // * * *
		else showMessageWithCancel("Pomegranate Error", "Error: Invalid Channels");
	}

// [ 2 ] -----------------------------------------------------------------------------------------------------------------------------------------------
	showStatus("Pomegranate - Nuclear Segmentation [Otsu]");
	print("\n[Bit-Depth Checkpoint A]");
	print("Current Bit-Depth: " + bitDepth() + "-bit");
	
	run("Split Channels");	
	msChannel = "C"+msChannel+"-"+imageName;
	if (runMode != "WLCL") nmChannel = "C"+nmChannel+"-"+imageName;
	if (runMode != "NUCL") bfChannel = "C"+bfChannel+"-"+imageName;

	selectImage(msChannel);
	print("\n[Bit-Depth Checkpoint B]");
	print("Current Bit-Depth: " + bitDepth() + "-bit");

	if (runMode != "WLCL")
	{
		selectImage(nmChannel);
		if (!transpMode) setBatchMode(true); 
	
			run("Duplicate...", "title=DUP duplicate");
			setSlice(round(nSlices/2));
			
			// Unsharp mask to improve Acutance
			run("Unsharp Mask...", "radius=10 mask=0.5 stack");
			if (transpMode) waitForUser("[Transparent Mode] Nuclear Unsharp Mask");
		
			// Binary Generation - Otsu Thresholding
			setAutoThreshold("Otsu dark stack");
			run("Convert to Mask", "method=Otsu background=Dark black");
			if (transpMode) waitForUser("[Transparent Mode] First Otsu Threshold");

			// Smoothing - 0.3 Micron Gaussian Blur
			run("Gaussian Blur...", "sigma=0.3 scaled stack");
			if (transpMode) waitForUser("[Transparent Mode] Gaussian Blur");
			
			run("Make Binary", "method=Otsu background=Dark black");
			if (transpMode) waitForUser("[Transparent Mode] Second Otsu Threshold");
		
			// Detection
			run("Analyze Particles...", "  circularity=0.6-1.00 exclude clear add stack"); // run("Analyze Particles...", "clear add stack");
			selectImage(nmChannel); 
			close("DUP");
			roiManager("Show All Without Labels");
			if (transpMode) waitForUser("[Transparent Mode] Nuclear ROIs (Uncleaned)");
	
		if (!transpMode) setBatchMode(false);
	}

	step++; // * * *

// [ 3 ] -----------------------------------------------------------------------------------------------------------------------------------------------
	showStatus("Pomegranate - Nuclei Building Parameter");
	
	/* 
	 *  [ Notes ]
	 *  Radius used as tolerence for XY shifts of the centroid
	 *  Higher Tolerence = Releaxed - More leniant on oddly-shaped / near-telophase nuclei
	 *  Lower Toleence = Strict - Less likely to group two nuclei as one nuclei if cells are 'stacked'
	 */

	if (runMode != "WLCL")
	{
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

			print("\n[Nuclei Building Parameters]");
			print("Tolerance Radius (microns): " + rn);
			print("Enlarge Parameter (microns): " + en);
			print("Minimum ROIs per Nuclei: " + mroi);
			print("Stability Score Threshold: " + stabThresh);
	
			if ((!isNaN(rn)) && (rn > 0)) step++; // * * *
			else showMessageWithCancel("Pomegranate Error", "Error: Invalid Radius");
		}
	}
	else step++; // * * *
	
// [ 4 ] -----------------------------------------------------------------------------------------------------------------------------------------------

	if (runMode != "WLCL")
	{
		roiManager("Deselect");
		roiManager("Set Color", "Black");
	
		nuclearIndex = 0;
		badCount = 0;
		n = roiManager("Count");
		
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
				ID = runID + "" + nuclearIndex;
				
				// Indices of ROIs creating current Nuclei
				currentMembers = newArray(); 
				currentMembers = Array.concat(currentMembers, i);
	
				// Slice Containing ROIs of the Current Nuclei
				sliceList = newArray();
				sliceList = Array.concat(sliceList, getSliceNumber());
				
				nuclearName = "N_" + ID + "_" + getSliceNumber();
				roiManager("Rename", nuclearName);
				roiManager("Set Color", currentColor);
				run("Enlarge...", "enlarge=" + en);
				run("Fit Ellipse");
	
				// Set Properties
				Roi.setProperty("Object_ID", ID);
				Roi.setProperty("Data_Type", "Nucleus");
				Roi.setProperty("ROI_Color", currentColor);
				Roi.setProperty("Nucleus_ID", nuclearIndex);
				Roi.setProperty("Mid_Slice", false);
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
				currentMaxArea = area;
				currentMaxAreaIndex = i;
				currentMaxAreaSlice = getSliceNumber();

				areaList = newArray();
				areaList = Array.concat(areaList, area);
	
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
	
						// Radius Tolerance
						if (sqrt(pow((ix - jx),2) + pow((iy - jy),2)) <= rn)
						{
							displacement = sqrt(pow((dx - jx),2) + pow((dy - jy),2));
							transit = transit + sqrt(pow((ix - jx),2) + pow((iy - jy),2));
							currentMembers = Array.concat(currentMembers, j);
							sliceList = Array.concat(sliceList, getSliceNumber());
							
							nuclearName = "N_" + ID + "_" + getSliceNumber();
							roiManager("Rename", nuclearName);
							roiManager("Set Color", currentColor);
							run("Enlarge...", "enlarge=" + en);
							run("Fit Ellipse");
	
							// Set Properties
							Roi.setProperty("Object_ID", ID);
							Roi.setProperty("Data_Type", "Nucleus");
							Roi.setProperty("ROI_Color", currentColor);
							Roi.setProperty("Nucleus_ID", nuclearIndex);
							Roi.setProperty("Mid_Slice", false);
							roiManager("Update");
							
							// Update Reference Point
							ix = jx;
							iy = jy;
	
							// Area Screening
							getStatistics(area);
							areaList = Array.concat(areaList, area);
							if (area > currentMaxArea)
							{
								currentMaxArea = area;
								currentMaxAreaIndex = j;
								currentMaxAreaSlice = getSliceNumber();
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
					print("[" + ID + "] Nuclear Index: " + nuclearIndex + "   | <X> Removing Nuclei: Insufficient number of ROIs - " + currentMembers.length);
					badCount++;
				}
				else if (getMaxIndex(areaList) == 0) // Point Spread Noise Check
				{
					print("[" + ID + "] Nuclear Index: " + nuclearIndex + "   | <X> Removing Nuclei: Inappropriate Acquisition - Largest ROI is in the first slice");
					badNuclei = Array.concat(badNuclei, currentMembers);
					badCount++;
				}
				else if (!checkSeq(sliceList)) // Continuous ROI Stack Check
				{
					print("[" + ID + "] Nuclear Index: " + nuclearIndex + "   | <!!!> Attempting Rescue: Inappropriate Acquisition - Non-continous ROI stack");
					rescue = ncroiResc(sliceList, currentMembers);
					badNuclei = Array.concat(badNuclei, rescue);
				}
				else if (stabScore < stabThresh) // Stability Score Check
				{
					print("[" + ID + "] Nuclear Index: " + nuclearIndex + "   | <X> Removing Nuclei: Low Stability Score - " + stabScore);
					badNuclei = Array.concat(badNuclei, currentMembers);
					badCount++;
				}
				else
				{
					// Annotate Mid
					roiManager("Select", currentMaxAreaIndex);
					Roi.setProperty("Mid_Slice", true);
					roiManager("Update");
					getStatistics(area);
					
					print("[" + ID + "] Nuclear Index: " + nuclearIndex + "   | Mid-Slice Index: " + currentMaxAreaIndex + "   | Number of Slices: " + currentMembers.length + "   | Mid-Slice Area (sq. micron): " + area + "   | Total Displacement (px): " + displacement + "   | Total Transit (px): " + transit + "   | Stability Score: " + stabScore);
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
		nucFile = directoryROI + replace(File.getName(imagePath),'.','_') + "_Nuclear_ROIs.zip";
		if (!File.exists(nucFile)) roiManager("Save", nucFile);
		print("File Created: " + nucFile);

		if (transpMode) waitForUser("[Transparent Mode] Nuclear ROIs (Cleaned)");
	}
	
	step++; // * * *

// [ 6 ] -----------------------------------------------------------------------------------------------------------------------------------------------

	if (runMode != "WLCL")
	{
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
			if (Roi.getProperty("Mid_Slice"))
			{
				getSelectionBounds(px, py, pw, ph);
				ps = getSliceNumber();
				
				ID = Roi.getProperty("Object_ID");
				currentColor = Roi.getProperty("ROI_Color");
				
				makePoint(px + (pw/2), py + (ph/2));
				Roi.setProperty("Object_ID", ID);
				Roi.setProperty("Data_Type", "Centroid");
				Roi.setProperty("ROI_Color", currentColor);
				Roi.setName("Z_" + ID + "_Centroid");
				roiManager("Add");
	
				print("[" + ID + "] Centroid ROI: " + i + "   | X: " + px + (pw/2) + " - Y: " + py + (ph/2) + " | Slice: " + ps);
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
		midFile = directoryROI + replace(File.getName(imagePath),'.','_') + "_Centroid_ROIs.zip";
		if (!File.exists(midFile)) roiManager("Save", midFile);
		print("File Created: " + midFile);

		if (transpMode) waitForUser("[Transparent Mode] Centroids");
	}
	
	step++; // * * *

// [ 7 ] -----------------------------------------------------------------------------------------------------------------------------------------------
	
	if (runMode != "NUCL")
	{
		showStatus("Pomegranate - Generating Whole Cell Binary");
		selectImage(bfChannel);
	
		// Select Slice
		original = getTitle();
		roiManager("Deselect");
		run("Select None");
		run("Duplicate...", "title=HOLD duplicate");
		
		midslice = 1;
		while(midslice == 1)
		{
			waitForUser("Please Select a Mid Slice");
			midslice = getSliceNumber();
		}

		if (!transpMode) setBatchMode(true);
		for (i = 1; i < midslice; i++)
		{
			selectWindow("HOLD");
			setSlice(i);
			run("Duplicate...", "title=HOLD_"+i);
			run("Remove Overlay");

			// Gaussian Blur
			run("Gaussian Blur...", "sigma=0.3 scaled");
			if ((transpMode) && (i == 1))  waitForUser("[Transparent Mode] Gaussian Blur");

			// Unsharp Mask
			run("Unsharp Mask...", "radius=" + getWidth() + " mask=0.90");
			if ((transpMode) && (i == 1)) waitForUser("[Transparent Mode] Unsharp Mask");
		
			// Thresholding
			run("8-bit");
			setAutoThreshold("Otsu dark");
			setThreshold(1, 10e6);
			run("Convert to Mask");
			//run("Open");
		}
		close("HOLD");
		if (transpMode) setBatchMode(false);
	
		// Projection
		run("Images to Stack", "name=HOLD_STACK title=HOLD use");
		run("Z Project...", "projection=[Average Intensity]");
		if (transpMode) waitForUser("[Transparent Mode] Z Projection");

		// Variance Map
		run("Variance...", "radius=1");
		setThreshold(255, 255);
		run("Convert to Mask");
		close("HOLD_STACK");
		run("Skeletonize");
		run("Invert");
		run("Erode");
		if (transpMode) waitForUser("[Transparent Mode] Variance Map");
		if (!transpMode) setBatchMode(false);

		// Size-Based Hole Filling
		binary = getTitle();
		run("Duplicate...", "title=Fill_Holes");
		run("Invert");
		run("Analyze Particles...", "size=0-500 pixel clear add");
		selectImage(binary);
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
		if (transpMode) waitForUser("[Transparent Mode] Size Based Hole Exclusion");

		// Binary Smoothing
		run("Gaussian Blur...", "sigma=2 stack");
		run("Make Binary", "method=Otsu background=Dark black");
		run("Invert");
		if (transpMode) waitForUser("[Transparent Mode] Gaussian Smoothing");
		
		rename("Binary");

		/*  [ Notes ]
		 *  For whatever reason, after the ROI Manager is reset, a selection
		 *  needs to be made in order to use Analyze Particles - otherwise
		 *  no ROIs will be added to the ROI Manager
		 */
		
		// BioVoxxel Watershed
		bvMode = getBoolean("Use Watershed Irregular Features? (BioVoxxel Required)");
		if (bvMode)
		{
			bvErosion = 1;
			bvConvThresh = 0.75;
			bvSepSize = "0-20";
			Dialog.create("BioVoxxel Watershed Irregular Features");
				Dialog.addNumber("Erosion", bvErosion);
				Dialog.addNumber("Convexity Threshold", bvConvThresh);
				Dialog.addString("Separator Size", bvSepSize);
			Dialog.show();
			bvErosion = Dialog.getNumber();
			bvConvThresh = Dialog.getNumber();
			bvSepSize = Dialog.getString();
			run("Watershed Irregular Features", "erosion=" + bvErosion + " convexity_threshold=" + bvConvThresh + " separator_size=" + bvSepSize);
			if (transpMode) waitForUser("[Transparent Mode] Watershedding");
		}
		
		run("Erode"); // See Notes
		run("Analyze Particles...", "size=250-Infinity pixel exclude clear add");
		
		/*  [ Notes ]
		 *  Erode step above is necessary for Analyze Particles to perform well
		 *  The Erode step is compensated for later in the smoothing step with
		 *  an Enlarge step (Enlarge being similar to the Dilate Morphological Operator)
		 *  
		 *  The enlarge step is annotated with a <+>
		 */
		
		// Smoothing Parameters
		gap = 10;
		interpn = 5;
		Dialog.create("Clean Up Parameters");
			Dialog.addNumber("Gap Closure Size (pixels)", gap);
			Dialog.addNumber("Interpolation Smoothing (pixels)", interpn);
		Dialog.show();
		gap = Dialog.getNumber();
		interpn = Dialog.getNumber();

		print("\n[ROI Smoothing]");
		print("Gap Closure Size (pixels): ", gap);
		print("Interpolation Smoothing (pixels): ", interpn);

		// Band Size Measurement
		selectImage("Binary");
		run("Duplicate...", "title=INTERCELL duplicate");
		run("Invert");
		run("Distance Map");
		setThreshold(1, 255);
		run("Measure");
		bandSize = 2*round(getResult("Mean", 0));
		print("Band Size (pixels): ", bandSize);
		
		if (transpMode) waitForUser("[Transparent Mode] Gap Size Measurement");
		run("Clear Results");
		
		// Smoothing
		selectImage(bfChannel);
		n = roiManager("Count");
		badMask = newArray();
		for (i = 0; i < n; i ++)
		{
			roiManager("Select",i);
			getSelectionBounds(px, py, pw, ph);
			if (pw * ph < 0.4 * (getWidth() * getHeight()))
			{
				// Gap Closure
				run("Enlarge...", "enlarge=" + gap + " pixel");
				run("Enlarge...", "enlarge=-" + gap + " pixel");

				// Band Coverage
				run("Enlarge...", "enlarge=" + bandSize + " pixel");

				// Interpolation Smoothing
				run("Interpolate", "interval=" + interpn + " smooth adjust");
				
				if (selectionType() != -1) roiManager("Update");
			}
			else 
			{
				print("Smoothing Failed (ROI too large): Temporary ROI " + call("ij.plugin.frame.RoiManager.getName", i));
				badMask = Array.concat(i, badMask);
			}
		}
		if (!transpMode) setBatchMode(true);
		if (transpMode) waitForUser("[Transparent Mode] Smoothing");

		// Solidity Filtering
		print("\n[Solidity Filtering]");
		solidThresh = 0.9;
		solidThresh = getNumber("Solidity Threshold", solidThresh);
		n = roiManager("Count");
		for (i = 0; i < n; i++)
		{
			roiManager("Select", i);
			solidScore = solidity();
			if (solidScore < solidThresh)
			{
				badMask = Array.concat(i, badMask);
				print("Poor Solidity (" + solidScore + "): Temporary ROI " + call("ij.plugin.frame.RoiManager.getName", i)); 
			}
			else print("Good Solidity (" + solidScore + "): Temporary ROI " + call("ij.plugin.frame.RoiManager.getName", i)); 
		}
		
		// Clean Up Bad ROIs
		if (badMask.length > 0)
		{
			roiManager("Select", badMask);
			roiManager("Delete");
		}
		roiManager("Deselect");
		if (transpMode) waitForUser("[Transparent Mode] ROI Cleanup");

		// Cell Radius Extraction
		print("\n[Cell Radius]");
		n = roiManager("Count");
		setBatchMode(true);
		for (i = 0; i < n; i++)
		{
			roiManager("Select", i);
			run("Create Mask");
			rename(call("ij.plugin.frame.RoiManager.getName", i));
		
			run("Select None");
			run("Distance Map");
			getStatistics(dmArea, dmMean, dmMin, dmMax);
			
			roiManager("Select", i);
			Roi.setProperty("Cell_Radius", dmMax * vx);
			roiManager("Update");
			
			print(call("ij.plugin.frame.RoiManager.getName", i) + " Cell Radius (Distance Map Maxima): " + (dmMax * vx) + " microns");
			close(call("ij.plugin.frame.RoiManager.getName", i));
		}
	
		// Create Canvas
		selectImage(original);
		run("Select None");
		roiManager("Deselect");
		
		run("Duplicate...", "duplicate");
		run("Multiply...", "value=0 stack");
		run("8-bit");
		rename("Canvas");
		
		// Load Nuclei MidPoints
		if (runMode != "WLCL")
		{
			roiManager("Open", midFile);
			print("\nLoading Midpoint ROIs - " + midFile);
			ncAlign = getBoolean("Align Wholecell ROIs with Nuclear Centroids?");
		}
		
		selectWindow("Log");
		print("\n[Whole Cell Z Alignment]");
		selectImage("Canvas");
		deleteList = newArray();
		n = roiManager("Count");
		for (i = 0; i < n; i++)
		{
			if (!startsWith(call("ij.plugin.frame.RoiManager.getName", i), 'Z'))
			{	
				nucleiContained = 0;
				roiManager("Select", i);
				Roi.getCoordinates(rx, ry);
				if (runMode != "WLCL")
				{
					for (k = i; k < n; k ++)
					{
						if (startsWith(call("ij.plugin.frame.RoiManager.getName", k), 'Z'))
						{
							deleteList = Array.concat(deleteList, k);
							roiManager("Select", newArray(i, k));
							roiManager("AND");
							if (selectionType() != -1) 
							{
								roiManager("Select", k);
								nucleiContained++;
								ID = Roi.getProperty("Object_ID");
								currentColor = Roi.getProperty("ROI_Color");
									
								if (!ncAlign) setSlice(midslice);
										
								roiManager("Select", i);
								Roi.setProperty("Paired_Nuclei", k);
								Roi.setProperty("Object_ID", ID);
								Roi.setProperty("Data_Type", "Whole_Cell");
								Roi.setProperty("ROI_Color", currentColor);
								Roi.setStrokeColor(currentColor);
								roiManager("Update");
							}
						}
					}

					// Delete Septating Cells
					if (nucleiContained != 1) deleteList = Array.concat(deleteList, i);
					else 
					{
						roiManager("Select",i);
						Roi.setProperty("nucleiContained", nucleiContained);
						roiManager("Update");
					}
					print("[" + ID + "]" + call("ij.plugin.frame.RoiManager.getName", i) + " Nuclei Contained: " + nucleiContained);
				}
				else 
				{
					setSlice(midslice);
					
					ID = runID + "" + i;
					currentColor = randomHexColor();
					
					Roi.setProperty("Object_ID", ID);
					Roi.setProperty("Data_Type", "Whole_Cell");
					Roi.setProperty("ROI_Color", currentColor);
					Roi.setStrokeColor(currentColor);
					roiManager("Update");

					print("[" + ID + "]" + call("ij.plugin.frame.RoiManager.getName", i) + " Transfering to Midslice");
				}
			}
		}
		
		// Clear Bad ROIs
		if (deleteList.length > 0)
		{
			roiManager("Select", deleteList);
			roiManager("Delete");
		}
		roiManager("Deselect");
		run("Select None");
	}
	step++; // * * *

// [ 8 ] -----------------------------------------------------------------------------------------------------------------------------------------------

	if (runMode != "NUCL")
	{
		showStatus("Pomegranate - Constructing Whole Cell Fits");
		print("\n[Whole Cell Fit Construction]");
	
		selectImage("Canvas");
		
		// Project into 3D
		n = roiManager("Count");
		for (i = 0; i < n; i++)
		{
			roiManager("Select", i);
			Roi.setProperty("Mid_Slice", true);
			roiManager("Update");
			
			ID = Roi.getProperty("Object_ID");
			currentColor = Roi.getProperty("ROI_Color");
			crad = parseFloat(Roi.getProperty("Cell_Radius"));
			
			roiManager("Rename", "A_Cell_" + (i + 1) + "_MID");
			Roi.getCoordinates(rx, ry);
	
			// ROI Volume Measurements
			midn = getSliceNumber();
			wcSlices = 1;
			r = crad;
			
			for (k = 1; k <= nSlices; k++)
			{
				dz = (midn - k) * vz;
				dr = r*(1 - sqrt(1 - pow(dz/r,2)));
				if (isNaN(dr)) dr = -1;
				
				if ((dr >= 0) && (dz != 0))
				{
					setSlice(k);
					makeSelection("freehand", rx, ry);
					if (selectionType != -1)
					{
						print("[" + ID + "] DZ: " + dz + "   R: " + r + "   DR: " + dr);
						run("Enlarge...", "enlarge=" + -dr + "");
						
						Roi.setName("B_Cell_" + (i + 1) + "_Slice_" + k);
					
						Roi.setProperty("Object_ID", ID);
						Roi.setProperty("Data_Type", "Whole_Cell");
						Roi.setProperty("Mid_Slice", false);
						Roi.setProperty("ROI_Color", currentColor);
						Roi.setStrokeColor(currentColor);
						roiManager("Add");
		
						// Paint Canvas
						setColor(255,255,255);
						fill();
							
						wcSlices++;
					}
				}
			}
			print("[" + ID + "] Cell Index: " + (i + 1) + "   | Radius (microns): " + r + " | Slices: " + wcSlices);
			print("");
		}
		run("Select None");

		for (i = 0; i < roiManager("Count"); i++)
		{
			roiManager("Select", i);
			roiManager("Set Color", Roi.getProperty("ROI_Color"));
			roiManager("Rename", "WC_" + Roi.getProperty("Object_ID") + "_" + getSliceNumber());
		}
	
		// Whole Cell ROI Export
		showStatus("Pomegranate - Exporting Whole Cell ROis");
		print("\n[Exporting Whole Cell ROIs]");
		wcFile = directoryROI + replace(File.getName(imagePath),'.','_') + "_Whole_Cell_ROIs.zip";
		if (!File.exists(wcFile)) roiManager("Save", wcFile);
		print("File Created: " + wcFile);

		if (transpMode) waitForUser("[Transparent Mode] Reconstruction");
		if (!transpMode) setBatchMode(false);
		
	} 

	step++; // * * *

// [ 9 ] -----------------------------------------------------------------------------------------------------------------------------------------------

	// Reload and Inspect
	selectImage(msChannel);
	roiManager("Reset");
	if (runMode != "NUCL") roiManager("Open", wcFile);
	if (runMode != "WLCL")roiManager("Open", nucFile);

	roiManager("Show All Without Labels");
	waitForUser("Please Inspect ROIs.\nWhen deleting whole objects, ensure that all ROIs with the same OID are deleted.");
	if (transpMode) waitForUser("[Transparent Mode] Manual Filter");

// [ 9 ] -----------------------------------------------------------------------------------------------------------------------------------------------

	// Measure Intensity
	showStatus("Pomegranate - Measuring Whole Cell ROIs");
	
	selectImage(msChannel);
	print("\n[Bit-Depth Checkpoint C]");
	print("Current Bit-Depth: " + bitDepth() + "-bit");
	
	roiManager("Deselect");
	roiManager("Show All Without Labels");
	roiManager("Measure");
	
	// Append Additional Info to Output
	n = roiManager("Count");
	for (i = 0; i < n; i++)
	{
		roiManager("Select", i);
		ID = Roi.getProperty("Object_ID");
		dType = Roi.getProperty("Data_Type");
		mid = Roi.getProperty("Mid_Slice");
			
		setResult("Object_ID", i, ID);
		if (mid) setResult("ROI_Type", i, "MID");
		else setResult("ROI_Type", i, "NONMID");
			
		setResult("Data_Type", i, dType);
		setResult("Image", i, imageName);
		setResult("Experiment", i, expName);
	}
	
	// Results Export
	showStatus("Pomegranate - Exporting Whole Cell Measurements");
	print("\n[Exporting Results]");
	wcResultFile = directoryResults + replace(File.getName(imagePath),'.','_') + "_Results_Full.csv";
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

	// End Run Cleanup
	cleanAll();
	close("Log");
	close("Results");
	run("Collect Garbage"); 
	waitForUser("Done", "Analysis is complete\nPlease review files in your output directory");
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

// Solidity Check
function solidity()
{
	if (selectionType() != -1)
	{
		getStatistics(AR1); // Area
		
		Roi.getCoordinates(rx, ry);
		run("Convex Hull");
		getStatistics(AR2); // Convex Area
		
		makeSelection("freehand",rx,ry); // Restore
		return(AR1/AR2);
	}
	else return(NaN);
}

// Return Index of Max in Array
function getMaxIndex(arr)
{
	Array.getStatistics(arr, min, max);
	for (i = 0; i < arr.length; i++) if (arr[i] == max) return i
}

// Non-Continuous ROI Rescue
function ncroiResc(sliceArr, memberArr)
{
	if ((memberArr.length > 1) && (memberArr.length == sliceArr.length))
	{
		seqL = 0;
		seqLcache = newArray();
		lastIndcache = newArray();
		sliceArr = Array.sort(sliceArr);
		for (i = 1; i < sliceArr.length; i++)
		{
			if (sliceArr[i] == sliceArr[i - 1] + 1) seqL++;
			else
			{
				seqLcache = Array.concat(seqLcache, seqL + 1);
				lastIndcache = Array.concat(lastIndcache, i);
				seqL = 0;
			}
		}
		seqLcache = Array.concat(seqLcache, seqL + 1);
		lastIndcache = Array.concat(lastIndcache, i);
		
		Array.getStatistics(seqLcache, seqLmin, seqLmax);
		
		for (i = 1; i < seqLcache.length; i++) 
		{
			if (seqLcache[i] == seqLmax)
			{
				for (j = 1; j < memberArr.length; j++)
				{
					if ((j > lastIndcache[i] - seqLmax - 1) && (j < lastIndcache[i])) memberArr[j] = NaN; 
				}
			}
		}
		print(" ---- <!!!> ROI Rescue Successful - Non-continuous ROIs for this OID will be deleted.");
		return memberArr;
	}
	print(" ---- <!!!> ROI Rescue Failed - All ROIs for this OID will be deleted.");
	return memberArr;
}