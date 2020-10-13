/*  Pomegranate
 *  
 *  Virginia Polytechnic Institute and State University
 *  Blacksburg, Virginia
 *  Hauf Lab
 *  
 *  Erod Keaton D. Baybay (2019) - erodb@vt.edu
 *  Last Updated: July 28, 2020
 */

macro "Pomegranate"
{ 		 
	versionFIJI = "1.53b";
	versionPIPELINE = "1.2i";

	requires(versionFIJI);
	
	// Title Pop Up
	showMessage("Pomegranate " + versionPIPELINE, "<html>"
	  		+"<font size=+3><center><b>Pomegranate</b><br></center>"
	  		+"<font size=-2><center><b>Virginia Tech, Blacksburg, Virginia</b></center>"
	  		+"<font size=-2><center><b>Department of Biological Sciences - Hauf Lab</b></center>"
	  		+"<ul>"
	  		+"<li><font size=-2>Pipeline Version: " + versionPIPELINE
	  		+"<li><font size=-2>FIJI Version Required: " + versionFIJI
	  		+"</ul>"
	  		+"<font size=-2><center>Please read accompanying documentation</b></center>"
	  		+"<font size=-2><center>[Erod Keaton Baybay - erodb@vt.edu]</b></center>");

	// Runtime
	sTime = getTime(); 

	showMessageWithCancel("Prerun Cleanup","This macro performs a prerun clean up\nThis will close all currently open images without saving\nClick OK to Continue");
	cleanAll();
	
	step = 0; // Progress Ticker
	print("[Pomegranate " + versionPIPELINE + "]");
	print("Required FIJI Version: " + versionFIJI);
	print("Currently Running FIJI Version: " + getVersion);
	print("Pre-Run FIJI Memory Usage: " + IJ.freeMemory());

	// Roi Manager Settings
	roiManager("Associate", "true");
	roiManager("UseNames", "true");
	
	run("Set Measurements...", "area mean standard modal min centroid center perimeter fit shape feret's median stack limit display redirect=None decimal=3");

	// Designate Run Mode
	print("\n[Run Mode]");	
	runModeList = newArray("Both Nuclear and Whole Cell Analysis", "Nuclear Analysis Only", "Whole Cell Analysis Only");
	importModeList = newArray("Single Multi-Channel Image", "Multiple Single-Channel Images");
	transpMode = false;
	segMode = false;
	Dialog.create("Pomegranate Run Parameters");
		Dialog.addChoice("Analysis Type", runModeList);
		Dialog.addChoice("Import Type", importModeList);
		Dialog.addCheckbox("Ignore Measurement Channel", segMode);
		Dialog.addCheckbox("Transparent Mode", transpMode);
	Dialog.show()
	runMode = Dialog.getChoice();
	importMode = Dialog.getChoice();
	segMode = Dialog.getCheckbox();
	transpMode = Dialog.getCheckbox();
	
	print("Analysis Type: " + runMode);
	print("Import Type: " + importMode);
	if (segMode) print("Segmentation Only: Enabled");
	else print("Segmentation Only: Disabled");
	if (transpMode) print("Transparent Mode: Enabled");
	else print("Transparent Mode: Disabled");
	
	if (runMode == runModeList[0]) runMode = "BOTH";
	else if (runMode == runModeList[1]) runMode = "NUCL";
	else if (runMode == runModeList[2]) runMode = "WLCL";

	if (importMode == importModeList[0]) importMode = "MERGED";
	else if (importMode == importModeList[1]) importMode = "UNMERGED";

// [ 1 ] -----------------------------------------------------------------------------------------------------------------------------------------------
	showStatus("Pomegranate - Opening Images");

	while (step == 0)
	{
		if (importMode == "MERGED")
		{
			// Designate Input Image
			Dialog.create("Input Image");
				Dialog.addChoice("Input Method", newArray("Select Image from Directory","Manually Enter Path"));
			Dialog.show();
			if (Dialog.getChoice() == "Select Image from Directory") imagePath = File.openDialog("Choose an Input  File"); 
			else imagePath = getString("Image Path", "/Users/hauflab/Documents");

			imageName = File.getName(imagePath);

			if (endsWith(imageName,".tif")) open(imagePath); 
			else run("Bio-Formats Importer", "open=" + imagePath + " autoscale color_mode=Composite view=Hyperstack stack_order=XYCZT");

			if (isOpen(imageName)) step++; // * * *
			else 
			{
				showMessageWithCancel("Pomegranate Error", "Error: Unable to Open Image\nResponse: Ending Analysis");
				cleanAll();
				exit();
			}
	
			// Get Image Dimensions
			getDimensions(width, height, channels, slices, frames);
			getVoxelSize(vx, vy, vz, unit);

			// Quick Check
			getVoxelSize(vx, vy, vz, unit);
			print("Original Voxel Size: " + vx + " " + unit + ", " + vy + " " + unit + ", " + vz + " " + unit);
			if (channels > 1)
			{
				channelList = newArray(channels);
				for (i = 1; i <= channels; i++) channelList[i-1] = "" + i;
			
				// Assign Channels
				while (step == 1)
				{
					Dialog.create("Channel Selection");
						if (!segMode) Dialog.addChoice("Measurement Channel", channelList, 1);
						if (runMode != "WLCL") Dialog.addChoice("Nuclear Marker Channel", channelList, 1);
						if (runMode != "NUCL") Dialog.addChoice("Bright-Field Channel", channelList, 1);
					Dialog.show();
					if (!segMode) chparamMS = Dialog.getChoice();
					if (runMode != "WLCL") chparamNC = Dialog.getChoice();
					if (runMode != "NUCL") chparamWC = Dialog.getChoice();
						
					if (!segMode) msChannel = parseInt(chparamMS); // Measurement Channel
					else msChannel = -1;
					
					if (runMode != "WLCL") nmChannel = parseInt(chparamNC); // Nuclear Marker Channel
					else nmChannel = -2;
					
					if (runMode != "NUCL") bfChannel = parseInt(chparamWC); // Bright-Field Channel
					else bfChannel = -3;
			
					print("\n[Run Parameters]");
					if (!segMode) print("Measurement Channel: " + msChannel);
					if (runMode != "WLCL") print("Nuclear Marker Channel: " + nmChannel);
					if (runMode != "NUCL") print("Bright-Field Channel: " + bfChannel);
					
					// Only Generate Folders for Valid Inputs
					if ((nmChannel != bfChannel) && (msChannel != bfChannel) && (nmChannel != msChannel)) step++; // * * *
					else showMessageWithCancel("Pomegranate Error", "Error: Invalid Channel Selection\nResponse: Returning to Channel Selection");
				}
			}
			else if ((channels < 2) && (runMode == "BOTH")) 
			{
				showMessageWithCancel("Pomegranate Error", "Error: Insufficient Channels for Analysis\nResponse: Ending Analysis");
				cleanAll();
				exit();
			}
			else if ((channels < 2) && (!segMode)) 
			{
				showMessageWithCancel("Pomegranate Error", "Error: Insufficient Channels for Analysis\nResponse: Ending Analysis");
				cleanAll();
				exit();
			}
			else step++; // * * *
			
			run("Split Channels");	
			if (!segMode) msChannel = "C"+msChannel+"-"+imageName;
			if (runMode != "WLCL") nmChannel = "C"+nmChannel+"-"+imageName;
			if (runMode != "NUCL") bfChannel = "C"+bfChannel+"-"+imageName;
		}

		
		else if (importMode == "UNMERGED")
		{
			// Measurement Channel Import
			if (!segMode) 
			{
				Dialog.create("Input Image");
					Dialog.addMessage("Measurement Signal Input Image (Measurement Channel)");
					Dialog.addChoice("Input Method", newArray("Select Image from Directory","Manually Enter Path"));
				Dialog.show();
				if (Dialog.getChoice() == "Select Image from Directory") imagePath = File.openDialog("Choose an Input  File"); 
				else imagePath = getString("Image Path", "/Users/hauflab/Documents");
				imageName = File.getName(imagePath);
	
				if (endsWith(imageName,".tif")) open(imagePath); 
				else run("Bio-Formats Importer", "open=" + imagePath + " autoscale color_mode=Composite view=Hyperstack stack_order=XYCZT");

				// Check if Open
				if (!isOpen(imageName))
				{
					showMessageWithCancel("Pomegranate Error", "Error: Unable to Open Image\nResponse: Ending Analysis");
					cleanAll();
					exit();
				}
				msChannel = getTitle();
			}
			// Nuclear Image Import
			if (runMode != "WLCL")
			{
				Dialog.create("Input Image");
					Dialog.addMessage("Nuclear Analysis Input Image (Nuclear Marker Channel)");
					Dialog.addChoice("Input Method", newArray("Select Image from Directory","Manually Enter Path"));
				Dialog.show();
				if (Dialog.getChoice() == "Select Image from Directory") imagePath = File.openDialog("Choose an Input  File"); 
				else imagePath = getString("Image Path", "/Users/hauflab/Documents");
				imageName = File.getName(imagePath);
	
				if (endsWith(imageName,".tif")) open(imagePath); 
				else run("Bio-Formats Importer", "open=" + imagePath + " autoscale color_mode=Composite view=Hyperstack stack_order=XYCZT");

				// Check if Open
				if (!isOpen(imageName))
				{
					showMessageWithCancel("Pomegranate Error", "Error: Unable to Open Image\nResponse: Ending Analysis");
					cleanAll();
					exit();
				}
				nmChannel = getTitle();
			}
			// Bright-Field Import
			if (runMode != "NUCL")
			{
				Dialog.create("Input Image");
					Dialog.addMessage("Whole-Cell Analysis Input Image (Bright-field Channel)");
					Dialog.addChoice("Input Method", newArray("Select Image from Directory","Manually Enter Path"));
				Dialog.show();
				if (Dialog.getChoice() == "Select Image from Directory") imagePath = File.openDialog("Choose an Input  File"); 
				else imagePath = getString("Image Path", "/Users/hauflab/Documents");
				imageName = File.getName(imagePath);
	
				if (endsWith(imageName,".tif")) open(imagePath); 
				else run("Bio-Formats Importer", "open=" + imagePath + " autoscale color_mode=Composite view=Hyperstack stack_order=XYCZT");

				// Check if Open
				if (!isOpen(imageName))
				{
					showMessageWithCancel("Pomegranate Error", "Error: Unable to Open Image\nResponse: Ending Analysis");
					cleanAll();
					exit();
				}
				bfChannel = getTitle();
			}

			step++; // * * *

			if (!segMode) selectImage(msChannel);
			else if (runMode == "NUCL") selectImage(nmChannel);
			else if (runMode == "WLCL") selectImage(bfChannel);
			else if (runMode == "BOTH") selectImage(bfChannel);
			
			// Get Image Dimensions
			getDimensions(width, height, channels, slices, frames);
			getVoxelSize(vx, vy, vz, unit);

			// Quick Check
			getVoxelSize(vx, vy, vz, unit);
			print("Original Voxel Size: " + vx + " " + unit + ", " + vy + " " + unit + ", " + vz + " " + unit);

			step++; // * * *
		}

		// Voxel Size Management
		Dialog.create("Voxel Size Management");
			Dialog.addString("Voxel Width", unit);
			Dialog.addNumber("Voxel Width", vx);
			Dialog.addNumber("Voxel Height", vy);
			Dialog.addNumber("Voxel Depth", vz);
		Dialog.show();
		nunit = Dialog.getString();
		nvx = Dialog.getNumber();
		nvy = Dialog.getNumber();
		nvz = Dialog.getNumber();

		if (!segMode) 
		{
			selectImage(msChannel);
			setVoxelSize(nvx, nvy, nvz, nunit);
		}
		if (runMode != "WLCL")
		{
			selectImage(nmChannel);
			setVoxelSize(nvx, nvy, nvz, nunit);
		}
		if (runMode != "NUCL")
		{
			selectImage(bfChannel);
			setVoxelSize(nvx, nvy, nvz, nunit);
		}

		print("User-defined Voxel Size: " + nvx + " " + nunit + ", " + nvy + " " + nunit + ", " + nvz + " " + nunit);
			
			
		// Set Experiment Name
		expName = getString("Experiment Name", imageName);

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
		saveID = "" + year + "" + month + "" + dayOfMonth + "_" + hour + "" + minute + "_" + replace(imageName,".","_");
		runID = "OID" + (year - 2000) + "" + month + "" + dayOfMonth + "" + hour + "" + minute;

		print("\n[Experiment Information]");
		print("Experiment Name: " + expName);
		print("Save ID: " + runID);
		print("Generic Run ID: " + runID);
		
		run("Options...", "iterations=1 count=1 black do=Nothing");

		// Output Directory
		directoryMain = outputPath + saveID + "/";
		if (!File.exists(directoryMain)) File.makeDirectory(directoryMain);
			
			// ROI Directory
			directoryROI = directoryMain + "ROIs/";
			if (!File.exists(directoryROI)) File.makeDirectory(directoryROI);
			
			// Results Directory
			directoryResults = directoryMain + "Results/";
			if (!File.exists(directoryResults)) File.makeDirectory(directoryResults);
			
			// Binary Directory
			directoryBinary = directoryMain + "Binaries/";
			if (!File.exists(directoryBinary)) File.makeDirectory(directoryBinary);
	}
// [ 2 ] -----------------------------------------------------------------------------------------------------------------------------------------------
	

	if (!segMode)
	{
		showStatus("Pomegranate - Nuclear Segmentation [Otsu]");
		print("\n[Bit-Depth Checkpoint A]");
		print("Current Bit-Depth: " + bitDepth() + "-bit");
	}

	if (runMode != "WLCL")
	{
		selectImage(nmChannel);
		if (!transpMode) setBatchMode(true); 
	
			run("Duplicate...", "title=DUP duplicate");
			setSlice(round(nSlices/2));
			if (transpMode) waitForUser("[Transparent Mode] Original Input");
			
			// Unsharp mask to improve Acutance
			run("Gaussian Blur...", "sigma=0.1 scaled stack");
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
			
			// Image Export
			nbinary = directoryBinary+"/Nuclear_Binary.tif";
			if (!File.exists(nbinary)) saveAs(".tiff", nbinary);
			print("\n[Image Export]\nNuclear Binary: " + nbinary);
			
			if (transpMode) waitForUser("[Transparent Mode] Second Otsu Threshold");
		
			// Detection
			run("Analyze Particles...", "  circularity=0.6-1.00 exclude clear add stack"); // run("Analyze Particles...", "clear add stack");
			selectImage(nmChannel); 
			close("DUP");
			roiManager("Show All Without Labels");
			if (transpMode) waitForUser("[Transparent Mode] Nuclear ROIs (Uncleaned)");
	
		if (!transpMode) setBatchMode(false);
		setSlice(round(nSlices/2));
	}

	step++; // * * *

// [ 3 ] -----------------------------------------------------------------------------------------------------------------------------------------------
	showStatus("Pomegranate - Nuclei Building Parameters");

	if (runMode != "WLCL")
	{
		while (step == 3)
		{
			// Nuclear ROI Run Parameters
			searchRadiusThresh = 2.0;
			cohesionRadiusThresh = 3.0;
			en = 0.2;
			mroi = 5;
			Dialog.create("Nuclei Building Parameters");
				Dialog.addNumber("Centroid Search Radius (" + nunit + ")", searchRadiusThresh);
				Dialog.addNumber("Centroid Cohesion Radius (" + nunit + ")", cohesionRadiusThresh);
				Dialog.addNumber("Enlarge Parameter (" + nunit + ")", en);
				Dialog.addNumber("Minimum ROIs per Nuclei", mroi);
			Dialog.show();
			searchRadiusThresh = Dialog.getNumber;
			cohesionRadiusThresh = Dialog.getNumber;
			en = Dialog.getNumber;
			mroi = Dialog.getNumber;
	
			// Disqualified ROIs
			deleteList = newArray();

			print("\n[Nuclei Building Parameters]");
			print("Centroid Search Radius (" + nunit + "): " + searchRadiusThresh);
			print("Centroid Cohesion Radius (" + nunit + "): " + cohesionRadiusThresh);
			print("Enlarge Parameter (" + nunit + "): " + en);
			print("Minimum ROIs per Nuclei: " + mroi);
	
			if ((!isNaN(searchRadiusThresh)) && (searchRadiusThresh > 0)) step++; // * * *
			else showMessageWithCancel("Pomegranate Error", "Error: Invalid Radius\nResponse: Returning to Parameter Menu");
		}
	}
	else step++; // * * *
	
// [ 4 ] -----------------------------------------------------------------------------------------------------------------------------------------------

	if (runMode != "WLCL")
	{
		roiManager("Deselect");
		roiManager("Set Color", "Black");

		midsliceList = newArray();
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
				cohesionRadius = 0;
				centroidsX = newArray();
				centroidsY = newArray();
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
				Roi.setProperty("Nuclear_Index", nuclearIndex);
				Roi.setProperty("Mid_Slice", false);
				roiManager("Update");
	
				// Establish First Reference Point
				getSelectionBounds(px, py, pw, ph);
				ix = px + round(pw/2);
				iy = py + round(ph/2);

	
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
	
						// Centroid Search Radius
						if (sqrt(pow((ix - jx),2) + pow((iy - jy),2)) <= searchRadiusThresh)
						{
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
							Roi.setProperty("Nuclear_Index", nuclearIndex);
							Roi.setProperty("Mid_Slice", false);
							roiManager("Update");
							
							// Update Reference Point and Centroid Coordinate List
							ix = jx;
							iy = jy;
							centroidsX = Array.concat(centroidsX, jx);
							centroidsY = Array.concat(centroidsY, jy);
	
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
	
				// Centroid Cohesion Radius
				Array.getStatistics(centroidsX, centroidsXmin, centroidsXmax, centroidsXmean);
				Array.getStatistics(centroidsY, centroidsYmin, centroidsYmax, centroidsYmean);
				for (j = 0; j < centroidsX.length; j++)
				{
					currentRadius = sqrt(pow((centroidsX[j] - centroidsXmean),2) + pow((centroidsY[j] - centroidsYmean),2));
					if (currentRadius > cohesionRadius) cohesionRadius = currentRadius;
				}
	
				// Nuclear Quality Control
				if (currentMembers.length < mroi) // Minimum ROI per Nuclei Check
				{
					deleteList = Array.concat(deleteList, currentMembers);
					print("[" + ID + "] Nuclear Index: " + nuclearIndex + "   | <X> Removing Nuclei: Insufficient number of ROIs - " + currentMembers.length);
					badCount++;
				}
				else if (getMaxIndex(areaList) == 0) // Point Spread Noise Check
				{
					print("[" + ID + "] Nuclear Index: " + nuclearIndex + "   | <X> Removing Nuclei: Inappropriate Acquisition - Largest ROI is in the first slice");
					deleteList = Array.concat(deleteList, currentMembers);
					badCount++;
				}
				else if (!checkSeq(sliceList)) // Continuous ROI Stack Check
				{
					print("[" + ID + "] Nuclear Index: " + nuclearIndex + "   | <!!!> Attempting Rescue: Inappropriate Acquisition - Non-continous ROI stack");
					rescue = ncroiResc(sliceList, currentMembers);
					deleteList = Array.concat(deleteList, rescue);
				}
				else if (cohesionRadius > cohesionRadiusThresh) // Cohesion Radius Check
				{
					print("[" + ID + "] Nuclear Index: " + nuclearIndex + "   | <X> Removing Nuclei: High Cohesion Radius - " + cohesionRadius);
					deleteList = Array.concat(deleteList, currentMembers);
					badCount++;
				}
				else
				{
					// Annotate Mid
					roiManager("Select", currentMaxAreaIndex);

					midsliceList = Array.concat(midsliceList, getSliceNumber());
					Roi.setProperty("Mid_Slice", true);
					roiManager("Update");
					getStatistics(area);
		
					print("[" + ID + "] Nuclear Index: " + nuclearIndex + "   | Mid-Slice Index: " + currentMaxAreaIndex + "   | Number of Slices: " + currentMembers.length + "   | Mid-Slice Area (sq. micron): " + area + "   | Cohesion Radius (" + nunit + "): " + cohesionRadius);
				}
			}
		} 
	
		// Delete Disqualified ROIs
		if (deleteList.length > 0)
		{
			roiManager("Select", deleteList);
			roiManager("Delete");
		}
		roiManager("Deselect");

		removednuclei = badCount;
		nnuclei = nuclearIndex;
		Array.getStatistics(midsliceList, dumpy, dumpy, meanMidslice, dumpy);
		meanMidslice = round(meanMidslice);

		print("\n[Mean Midplane]\nSlice: " + meanMidslice);
	
		// Nuclear ROI Export
		print("\n[Exporting Nuclear ROI Files]");
		nucFile = directoryROI + replace(File.getName(imagePath),'.','_') + "_Unfiltered_Nuclear_ROIs.zip";
		if (!File.exists(nucFile)) roiManager("Save", nucFile);
		print("File Created: " + nucFile);

		if (transpMode) waitForUser("[Transparent Mode] Nuclear ROIs (Cleaned)");
	}
	else 
	{	
		if (nSlices > 1)
		{
			// Auto Calculate Midslice using Standard Deviation
			selectImage(bfChannel);
			meanMidslice = autoFocus();
			print("Autofocus: " + meanMidslice);
		}
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
				Roi.setPosition(ps);
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
	
		// Centroid ROI Export
		showStatus("Pomegranate - Exporting Centroid ROIs");
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
		selectImage(bfChannel);
		bfbd = bitDepth();

		wcChoices = newArray("Bright-field (Default 2D Segmentation)","Binary (External Segmentation Input)");
		Dialog.create("Whole-Cell Only, Single Image Input");
			if (bfbd == 8) Dialog.addChoice("Input Image", wcChoices, wcChoices[1]);
			else Dialog.addChoice("Input Image", wcChoices, wcChoices[0]);
		Dialog.show();
		if (Dialog.getChoice() == wcChoices[0]) binaryMode = false;
		else binaryMode = true;
			
		if (!binaryMode)
		{
			showStatus("Pomegranate - Generating Whole Cell Binary");
			selectImage(bfChannel);
			if (transpMode) waitForUser("[Transparent Mode] Input Bright-field");
			
			run("32-bit");
			run("Reciprocal", "stack");
			run("Reciprocal", "stack"); // Double run("Reciprocal") converts 0 to NaN
		
			// Select Slice
			roiManager("Deselect");
			run("Select None");
			run("Duplicate...", "title=HOLD duplicate");
			
			midslice = 1;
			while(midslice == 1)
			{
				selectImage(bfChannel);
				setSlice(meanMidslice);
				waitForUser("Suggested Midplane: " + meanMidslice + "\nPlease Select a Midplane");
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
				run("Convert to Mask", "method=Otsu background=Dark black");
				//run("Open");
			}
			close("HOLD");
			if (transpMode) setBatchMode(false);
		
			// Projection
			run("Images to Stack", "name=HOLD_STACK title=HOLD use");
			run("Z Project...", "projection=[Average Intensity]");
			if (transpMode) waitForUser("[Transparent Mode] Z Projection");
	
			// Adaptive Threshold
			run("Auto Threshold", "method=Otsu white");
			close("HOLD_STACK");
	
			if (transpMode) waitForUser("[Transparent Mode] Adaptive Threshold");
			if (!transpMode) setBatchMode(false);
	
			attemptFill = true;
			while(attemptFill)
			{
				Dialog.create("Hole Filling");
				Dialog.addChoice("Method", newArray("Basic","Shape-based", "None"));
				Dialog.show();
				holeMode = Dialog.getChoice();
				print("\n[Fill Holes]");
				print("Method: ", holeMode);
		
				if (holeMode == "Basic")
				{
					run("Fill Holes");
				}
				else if (holeMode == "Shape-based")
				{
					// Shape-Based Hole Filling
					hfminSize = 0;
					hfmaxSize = 10;
					hfminCirc = 0.5;
					hfmaxCirc = 1;
					Dialog.create("Shape-based Hole Filling");
						Dialog.addMessage("The following parameters are shape descriptors\nfor the holes you wish to detect.\n");
						Dialog.addNumber("Minimum Size (sq. " + nunit + ")", hfminSize);
						Dialog.addNumber("Maximum Size (sq. " + nunit + ")", hfmaxSize);
						Dialog.addNumber("Minimum Circularity", hfminCirc);
						Dialog.addNumber("Maximum Circularity", hfmaxCirc);
					Dialog.show();
					hfminSize = Dialog.getNumber();
					hfmaxSize = Dialog.getNumber();
					hfminCirc = Dialog.getNumber();
					hfmaxCirc = Dialog.getNumber();
					
					binary = getTitle();
					setBatchMode(false);
					run("Duplicate...", "title=Fill_Holes");
					run("Invert");
					run("Analyze Particles...", "size=0-Infinity pixel clear add");
					selectImage(binary);
					for (i = 0; i < roiManager("Count"); i++)
					{
						roiManager("Select", i);
						if ((getValue("Area") >= hfminSize) & (getValue("Area") <= hfmaxSize))
						{
							if ((getValue("Circ.") >= hfminCirc) & (getValue("Circ.") <= hfmaxCirc)) 
							{
								setColor(255, 255, 255);
								fill();
							}
						}
					}
					close("Fill_Holes");
					run("Select None");
					print("Minimum Size: ", hfminSize); 
					print("Maximum Size: ", hfmaxSize); 
					print("Minimum Circularity: ", hfminCirc); 
					print("Maximum Circularity: ", hfmaxCirc); 
				}
				attemptFill = getBoolean("Perform another iteration of Hole Filling?");
			}
			if (transpMode) waitForUser("[Transparent Mode] Shape Based Hole Exclusion");
	
			
			roiManager("Reset");
			makeRectangle(1, 1, 1, 1);
			run("Select None");
	
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
				bvSepSize = "0-15";
				Dialog.create("BioVoxxel Watershed Irregular Features");
					Dialog.addNumber("Erosion", bvErosion);
					Dialog.addNumber("Convexity Threshold", bvConvThresh);
					Dialog.addString("Separator Size", bvSepSize);
				Dialog.show();
				bvErosion = Dialog.getNumber();
				bvConvThresh = Dialog.getNumber();
				bvSepSize = Dialog.getString();
				run("Watershed Irregular Features", "erosion=" + bvErosion + " convexity_threshold=" + bvConvThresh + " separator_size=" + bvSepSize);
	
				print("\n[Watershed Irregular Features (BioVoxxel)]");
				print("Erosion: ", bvErosion); 
				print("Convexity Threshold: ", bvConvThresh); 
				print("Seperator Size: ", bvSepSize);
				
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
			run("32-bit");
			run("Reciprocal");
			run("Reciprocal"); // Double run("Reciprocal") converts 0 to NaN
			run("Maximum...", "radius=10");
			setThreshold(0, 1e99);
			run("NaN Background");
			
			bandSize = getValue("Median")/2;
			print("Band Size (pixels): ", bandSize);
			if (transpMode) waitForUser("[Transparent Mode] Band Size Measurement");
			
			// Smoothing
			selectImage(bfChannel);
			n = roiManager("Count");
			deleteList = newArray();
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
					deleteList = Array.concat(i, deleteList);
				}
			}
			if (transpMode) waitForUser("[Transparent Mode] Smoothing");
	
			// Cell Count
			ncells = roiManager("Count");
	
			// Filtering Parameters
			solidThresh = 0.9;
			roiMargin = 10;
			cleanOverlap = true;
			manualScreen = true;
			Dialog.create("ROI Filtering");
				Dialog.addNumber("Solidity Threshold: ", solidThresh);
				Dialog.addNumber("ROI Margin (pixels): ", roiMargin);
				Dialog.addCheckbox("Clean Overlapping ROIs ", cleanOverlap);
				Dialog.addCheckbox("Manual Screen ", manualScreen);
			Dialog.show();
			solidThresh = Dialog.getNumber();
			roiMargin = Dialog.getNumber();
			cleanOverlap = Dialog.getCheckbox();
			manualScreen = Dialog.getCheckbox();
	
			print("\n[ROI Filtering Parametes]");
			print("Solidity Threshold: " + solidThresh);
			print("ROI Margin (pixels): " + roiMargin);
			if(cleanOverlap) print("Cleaning Overlap...");
			else print("Not Cleaning Overlap...");
	
			// Solidity Filtering
			print("\n[Solidity Filtering]");
			nonsolidcells = 0;
			nonsolidX = newArray();
			nonsolidY = newArray();
			
			n = roiManager("Count");
			deleteList = newArray();
			for (i = 0; i < n; i++)
			{
				roiManager("Select", i);
				Roi.getContainedPoints(xp, yp);
				
				solidScore = solidity();
				if (solidScore < solidThresh)
				{
					deleteList = Array.concat(i, deleteList);
					print("Poor Solidity (" + solidScore + "): Temporary ROI " + call("ij.plugin.frame.RoiManager.getName", i)); 
					
					nonsolidcells++;
					nonsolidX = Array.concat(nonsolidX, xp);
					nonsolidY = Array.concat(nonsolidY, yp);
				}
				else print("Good Solidity (" + solidScore + "): Temporary ROI " + call("ij.plugin.frame.RoiManager.getName", i)); 
			}
			
			// Clean Up Bad ROIs
			if (deleteList.length > 0)
			{
				roiManager("Select", deleteList);
				roiManager("Delete");
			}
			roiManager("Deselect");
	
			// Edge Removal
			print("\n[Edge Cell Removal]");
			oobcells = 0;
			oobX = newArray();
			oobY = newArray();
			
			iw = getWidth();
			ih = getHeight();
			
			n = roiManager("Count");
			deleteList = newArray();
			for (i = 0; i < n; i++)
			{
				roiManager("Select", i);
				Roi.getContainedPoints(xp, yp);
				Roi.getBounds(rx, ry, rw, rh);
				
				if ((rx > roiMargin) && (ry > roiMargin) && ((rx + rw) < (iw - roiMargin)) && ((ry + rh) < (ih - roiMargin))) print(call("ij.plugin.frame.RoiManager.getName", i) + " - within bounds");
				else 
				{
					deleteList = Array.concat(i, deleteList);
					print(call("ij.plugin.frame.RoiManager.getName", i) + " - out of bounds [Deleting]");
					
					oobcells++;
					oobX = Array.concat(oobX, xp);
					oobY = Array.concat(oobY, yp);
				}
			}
	
			// Clean Up Bad ROIs
			if (deleteList.length > 0)
			{
				roiManager("Select", deleteList);
				roiManager("Delete");
			}
	
			run("Select None");
			roiManager("Deselect");
	
			// Manual Screen
			if (manualScreen)
			{
				print("Pre-Manual Screen ROI Count: ", roiManager("Count")); 
				selectWindow("ROI Manager");
				waitForUser("Manually Delete invalid ROIs from the ROI Manager.\nOnce complete, click OK to proceed.");
				print("Post-Manual Screen ROI Count: ", roiManager("Count")); 
			}
			
			// Overlapping ROI Cleanup
			if (cleanOverlap)
			{
				n = roiManager("Count");
				for (i = 0; i < n; i++)
				{
					for (j = i + 1; j < n; j++)
					{
						roiManager("Select", newArray(i,j));
						roiManager("AND");
						if (selectionType() != -1)
						{
							roiManager("Select", i);
							run("Interpolate", "interval=1 adjust");
							Roi.getCoordinates(ix, iy);
							newix = newArray();
							newiy = newArray();
				
							roiManager("Select", j);
							run("Interpolate", "interval=1 adjust");
							Roi.getCoordinates(jx, jy);
							newjx = newArray();
							newjy = newArray();
				
							makeSelection("freehand", jx, jy);
							for (k = 0; k < ix.length; k++) 
							{
								if (!Roi.contains(ix[k], iy[k]))
								{
									newix = Array.concat(newix, ix[k]);
									newiy = Array.concat(newiy, iy[k]);
								}
							}
				
							makeSelection("freehand", ix, iy);
							for (k = 0; k < jx.length; k++) 
							{
								if (!Roi.contains(jx[k], jy[k]))
								{
									newjx = Array.concat(newjx, jx[k]);
									newjy = Array.concat(newjy, jy[k]);
								}
							}
				
							roiManager("Select", i);
							makeSelection("freehand", newix, newiy);
							if (selectionType() != -1) roiManager("Update");
				
							roiManager("Deselect");
					
							roiManager("Select", j);
							makeSelection("freehand", newjx, newjy);
							if (selectionType() != -1) roiManager("Update");
						}
					}
				}
			}

			step++; // * * *

// [ 8 ] -----------------------------------------------------------------------------------------------------------------------------------------------	
		
		}
		else // 2D BInary Input
		{
			selectImage(bfChannel);
			if (nSlices > 1) run("Z Project...", "projection=[Max Intensity]");
			rename("INPUT");

			run("Duplicate...", "title=DUP duplicate");
			
			// Guarentee Binary
			run("8-bit");
			setAutoThreshold("Otsu dark");
			setThreshold(1, 10e6);
			run("Convert to Mask", "method=Otsu background=Dark black");
			
			run("Distance Map");
			efactor = nvx/nvz;
			binSlices = 2*(Math.ceil(getValue("Max")*efactor) + 2);
			inputWidth = getWidth();
			inputHeight = getHeight();

			// Ignore Measurement Channel
			if (segMode)
			{
				binSlices = getNumber("Number of Z Slices:", binSlices);
				
				// Generate New Input
				newImage("BINARY", "8-bit black", inputWidth, inputHeight, binSlices);
				selectImage("INPUT");
				run("Select All");
				run("Copy");
				selectImage("BINARY");
				
				midslice = round(nSlices/2);
				setSlice(midslice);
				run("Paste");
	
				// Guarentee Binary
				run("8-bit");
				setAutoThreshold("Otsu dark");
				setThreshold(1, 10e6);
				run("Convert to Mask", "method=Otsu background=Dark black");
				close("INPUT");
				close("DUP");
				roiManager("Deselect");
				run("Select None"); 
				rename(bfChannel);
	
				// Obtain Image Information
				getDimensions(width, height, channels, slices, frames);
				setVoxelSize(nvx, nvy, nvz, nunit);
	
				// Make ROIs
				run("Analyze Particles...", "clear add stack");	
			}
			// Not Ignoring Measurement Channel
			else
			{
				selectImage(msChannel);
				binSlices = nSlices;
				setSlice(round(binSlices/2));
				waitForUser("Suggested Midplane: " + round(binSlices/2) + "\nPlease Select a Midplane");
				midslice = getSliceNumber();				
				
				// Generate New Input
				newImage("BINARY", "8-bit black", inputWidth, inputHeight, binSlices);
				selectImage("INPUT");
				run("Select All");
				run("Copy");
				selectImage("BINARY");
				
				setSlice(midslice);
				run("Paste");
	
				// Guarentee Binary
				run("8-bit");
				setAutoThreshold("Otsu dark");
				setThreshold(1, 10e6);
				run("Convert to Mask", "method=Otsu background=Dark black");
				close("INPUT");
				close("DUP");
				roiManager("Deselect");
				run("Select None"); 
				rename(bfChannel);
	
				// Obtain Image Information
				getDimensions(width, height, channels, slices, frames);
				setVoxelSize(nvx, nvy, nvz, nunit);
	
				// Make ROIs
				run("Analyze Particles...", "clear add stack");
			}
		}
		
		// Load Nuclear Centroids		
		if (runMode != "WLCL")
		{
			roiManager("Open", midFile);
			print("\nLoading Midpoint ROIs - " + midFile);
			ncAlign = getBoolean("Align Wholecell ROIs with Nuclear Centroids?");
		}
		else ncAlign = false;

		// Make Canvas Image
		selectImage(bfChannel);
		run("Select None");
		roiManager("Deselect");
		
		run("Duplicate...", "duplicate");
		run("Multiply...", "value=0 stack");
		run("RGB Color");
		rename("Canvas");
		setVoxelSize(nvx, nvy, nvz, nunit);

		selectWindow("Log");
		print("\n[Whole Cell Z Alignment]");
		selectImage("Canvas");

		sliceDisplacement = newArray();

		// Find Nuclei in Cells with Poor Solidity or in Edge Cells
		oobNuclei = 0;
		nonsolidNuclei = 0;
		n = roiManager("Count");
		for (i = 0; i < n; i++)
		{
			if (startsWith(call("ij.plugin.frame.RoiManager.getName", i), 'Z'))
			{
				roiManager("Select", i);
				Roi.getCoordinates(rx, ry);
				rx = rx[0];
				ry = ry[0];
				
				if ((acontains(oobX, rx)) && (acontains(oobY, ry))) oobNuclei++;
				if ((acontains(nonsolidX, rx)) && (acontains(nonsolidY, ry))) nonsolidNuclei++;
			}
		}
		septatingcells = 0;
		nonucleicells = 0;
		mergedcells = 0;
		nucleimerged = 0;
		
		grabList = newArray();
		deleteList = newArray();

		// OID Banks
		oldOIDs = newArray();
		newOIDs = newArray();
		OIDnids = newArray();
		OIDcolors = newArray(); 
		
		n = roiManager("Count");
		for (i = 0; i < n; i++)
		{
			// Centroid ROIs start with Z to keep them at the end of the ROI Manager
			// Anything else is a Whole-Cell ROI
			if (!startsWith(call("ij.plugin.frame.RoiManager.getName", i), 'Z'))
			{	
				// Defaults
				cslice_a = -1;
				cslice_b = -1;
				
				nucleiContained = 0;
				roiManager("Select", i);
				Roi.getCoordinates(rx, ry);
				sliceDisplacement = Array.concat(sliceDisplacement, getSliceNumber() - midslice);
				if (runMode != "WLCL")
				{
					for (k = i; k < n; k ++)
					{
						if (startsWith(call("ij.plugin.frame.RoiManager.getName", k), 'Z'))
						{
							if (!acontains(grabList, k)) grabList = Array.concat(grabList, k);
							if (!acontains(deleteList, k)) deleteList = Array.concat(deleteList, k);
							roiManager("Select", newArray(i, k));
							roiManager("AND");
							if (selectionType() != -1) 
							{	
								roiManager("Deselect");
								run("Select None");
					
								// First Nuclei (First Come, First Served)
								if (nucleiContained == 0)
								{
									nucleiContained++;
									nid = "N_A";
									
									roiManager("Select", k);
									cslice_a = getSliceNumber();
									ID = Roi.getProperty("Object_ID");
									currentColor = Roi.getProperty("ROI_Color");

									// Update Data stored in centroid
									roiManager("Select", k);
									Roi.setProperty("Nuclear_ID", nid);
									roiManager("Update");

									// Rename
									roiManager("Select", k);
									roiManager("Rename","Z_" + ID + "_A_Centroid");

									// Store Conversion parameters as Arrays - so we don't have to reopen centroid data
									if (!acontains(oldOIDs, ID))
									{
										oldOIDs = Array.concat(oldOIDs, ID);
										newOIDs = Array.concat(newOIDs, ID);
										OIDnids = Array.concat(OIDnids, nid);
										OIDcolors = Array.concat(OIDcolors, currentColor);
									}
								}
								// Second Nuclei
								else if (nucleiContained == 1)
								{
									nucleiContained++;
									nid = "N_B";
									
									roiManager("Select", k);
									oldID = Roi.getProperty("Object_ID");
									cslice_b = getSliceNumber();

									// Update Data  stored in centroid
									roiManager("Select", k);
									Roi.setProperty("Object_ID", ID);
									Roi.setProperty("Old_Object_ID", oldID);
									Roi.setProperty("ROI_Color", currentColor);
									Roi.setProperty("Nuclear_ID", nid);
									Roi.setName("Z_" + ID + "_B_Centroid");
									roiManager("Update");

									// Rename
									roiManager("Select", k);
									roiManager("Rename","Z_" + ID + "_B_Centroid");

									// Store Conversion parameters as Arrays - so we don't have to reopen centroid data
									if (!acontains(oldOIDs, oldID))
									{
										oldOIDs = Array.concat(oldOIDs, oldID);
										newOIDs = Array.concat(newOIDs, ID);
										OIDnids = Array.concat(OIDnids, nid);
										OIDcolors = Array.concat(OIDcolors, currentColor);
									}

								}
								// Too Many
								else if (nucleiContained > 2) deleteList = Array.concat(deleteList, i);
							}
						}
					}

					roiManager("Deselect");
					run("Select None");

					// Extract Mean Midslice for cells with two nuclei
					if ((cslice_a != -1) & (cslice_b != -1)) cslice = round((cslice_a + cslice_b)/2);
					else if (cslice_a != -1) cslice = cslice_a;
					else if (!ncAlign) cslice = midslice;
					else cslice = -1;

					if (cslice != -1)
					{
						roiManager("Select", i);
						Roi.setProperty("Object_ID", ID);
						Roi.setProperty("Data_Type", "Whole_Cell");
						Roi.setProperty("ROI_Color", currentColor);
						Roi.setProperty("Nuclear_ID", "WC");
						Roi.setProperty("nucleiContained", nucleiContained);
						Roi.setStrokeColor(currentColor);
						setSlice(cslice);
						roiManager("Update");
					}
					// Zero Nuclei Case
					else deleteList = Array.concat(deleteList, i);

					print("[" + ID + "] - " + call("ij.plugin.frame.RoiManager.getName", i) + " Nuclei Contained: " + nucleiContained);

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
		
		// Grab Centroid ROIs
		if (grabList.length > 0)
		{
			// Paired Centroid ROI Export
			showStatus("Pomegranate - Exporting Paired Centroid ROIs");
			print("\n[Exporting Paired Centroid ROIs]");
			pmidFile = directoryROI + replace(File.getName(imagePath),'.','_') + "_Paired_Centroid_ROIs.zip";
			if (!File.exists(pmidFile)) 
			{
				roiManager("Select", grabList);
				roiManager("Save Selected", pmidFile);
			}
			print("File Created: " + pmidFile);
		}
		roiManager("Deselect");
		run("Select None");

		// Delete Extra ROIs
		if (deleteList.length > 0)
		{
			roiManager("Select", deleteList);
			roiManager("Delete");
		}
		roiManager("Deselect");
		run("Select None");

		if (ncAlign)
		{
			// Slice Displacement
			print("\n[Z Alignment Summary]");
			print("Mid Slice: " + midslice);
			Array.getStatistics(sliceDisplacement, sdispmin, sdispmax, sdispmean, sdispsd);
			print("Mean Slice Displacement: " + sdispmean);
			print("Min Slice Displacement: " + sdispmin);
			print("Max Slice Displacement: " + sdispmax);
			print("Standard Deviation Slice Displacement: " + sdispsd);

			// Absolute Slice Displacement
			abssliceDisplacement = newArray(sliceDisplacement.length);
			for (s = 0; s < sliceDisplacement.length; s++) abssliceDisplacement[s] = abs(sliceDisplacement[s]);
			Array.getStatistics(abssliceDisplacement, abssdispmin, abssdispmax, abssdispmean, abssdispsd);
			print("Mean Absolute Slice Displacement: " + abssdispmean);
			print("Min Absolute Slice Displacement: " + abssdispmin);
			print("Max Absolute Slice Displacement: " + abssdispmax);
			print("Standard Deviation Absolute Slice Displacement: " + abssdispsd);

			print("Data Size: " + sliceDisplacement.length + " datapoints");
		}

// [ 9 ] -----------------------------------------------------------------------------------------------------------------------------------------------

		setBatchMode("hide"); 
		
		// Reconstruction Input ROI Export
		showStatus("Pomegranate - Exporting Reconstruction Input Whole Cell ROis");
		print("\n[Exporting Reconstruction Input Whole Cell ROIs]");
		rinpFile = directoryROI + replace(File.getName(imagePath),'.','_') + "_Unfiltered_Reconstruction_Input_Whole_Cell_ROIs.zip";
		if (!File.exists(rinpFile)) roiManager("Save", rinpFile);
		print("File Created: " + rinpFile);

		roiManager("Reset");
		
		if (runMode != "WLCL")
		{
			roiManager("Open", nucFile); // Open original nuclear file
	
			deleteList = newArray();
			n = roiManager("Count");
			for (i = 0; i < oldOIDs.length; i++)
			{
				// Recall from OID arrays
				oldID = oldOIDs[i];
				ID = newOIDs[i];
				nuclearID = OIDnids[i];
				currentColor = OIDcolors[i];
	
				for (k = 0; k < n; k++)
				{
					
					// Import into Nuclei Data
					roiManager("Select", k);
					currentSlice = getSliceNumber();
					checkID = Roi.getProperty("Object_ID");
					if (checkID == oldID)
					{
						roiManager("Select", k);
						Roi.setProperty("Object_ID", ID);
						Roi.setProperty("Old_Object_ID", oldID);
						Roi.setProperty("ROI_Color", currentColor);
						Roi.setProperty("Nuclear_ID", nuclearID);
						Roi.setStrokeColor(currentColor);
						roiManager("Update");
	
						// Rename
						roiManager("Select", k);
						roiManager("Rename", nuclearID + "_" + ID + "_" + currentSlice);
	
						print ("Nuclear OID Conversion: " + oldID + " to " + ID + " at slice " + currentSlice);
					}
				}
			}
			
			roiManager("Deselect");
			run("Select None");
	
			// Paired Nuclear ROI Export
			showStatus("Pomegranate - Exporting Paired Nuclear ROis");
			print("\n[Exporting Paired Nuclear ROIs]");
			pnucFile = directoryROI + replace(File.getName(imagePath),'.','_') + "_Paired_Nuclear_ROIs.zip";
			if (!File.exists(pnucFile)) roiManager("Save", pnucFile);
			print("File Created: " + pnucFile);

			roiManager("Reset");
		}
	
		setBatchMode("show"); 
		// Reopen Reconstruction WC Input File
		roiManager("Open", rinpFile);
	}
	step++; // * * *

// [ 10 ] -----------------------------------------------------------------------------------------------------------------------------------------------

	if (runMode != "NUCL")
	{
		showStatus("Pomegranate - Constructing Whole Cell Fits");
		print("\n[Whole Cell Count]");
		n = roiManager("Count");
		finalcells = n;
		print("Cells: " + n);
	
		selectImage("Canvas");
		
		// Project into 3D
		print("\n[Whole Cell Fit Construction]");
		newImage("Binary_Filtered", "8-bit black", width, height, slices);

		n = roiManager("Count");
		for (i = 0; i < n; i++)
		{
			selectImage("Binary_Filtered");
			roiManager("Select", i);
			ID = Roi.getProperty("Object_ID");
			currentColor = Roi.getProperty("ROI_Color");
		
			if(ID == "") 
			{
				ID = "OID_" + i;
				currentColor = randomHexColor();
				Roi.setProperty("Object_ID", ID);
				Roi.setProperty("ROI_Color", currentColor);
				roiManager("Rename", "Y_" + ID);
				roiManager("Update");
			}
			
			run("Enlarge...", "enlarge=-1 pixel");
			fill();
		}

		if (transpMode) setBatchMode("exit and display");

		// Guarentee Binary
		selectImage("Binary_Filtered");
		run("8-bit");
		setAutoThreshold("Otsu dark");
		setThreshold(1, 10e6);
		run("Convert to Mask", "method=Otsu background=Dark black");
		roiManager("Deselect");
		run("Select None"); 
		
		if (isOpen("Binary_Filtered")) print("Image: Binary Filtered [OK]");
		else print("Image: Binary Filtered [Not Open]");
		
		// Distance Map
		selectImage("Binary_Filtered");
		run("Duplicate...", "duplicate title=Distance_Map");
		run("Distance Map", "stack");
		if (transpMode) 
		{
			selectImage("Distance_Map");
			waitForUser("[Transparent Mode] Distance Map");
		}

		if (isOpen("Distance_Map")) print("Image: Distance Map [OK]");
		else print("Image: Distance Map [Not Open]");
		
		// Skeleton Image
		selectImage("Binary_Filtered");
		run("Duplicate...", "duplicate title=Skeleton");
		run("Skeletonize", "stack");
		if (transpMode) 
		{
			selectImage("Skeleton");
			waitForUser("[Transparent Mode] Skeleton");
		}

		if (isOpen("Skeleton")) print("Image: Skeleton [OK]");
		else print("Image: Skeleton [Not Open]");
		
		// Skeleton Image AND Distance Map
		imageCalculator("AND create stack", "Distance_Map","Skeleton");
		rename("Medial_Axis_Transform");
		close("Skeleton");
		close("Distance_Map");
		if (transpMode) 
		{
			selectImage("Medial_Axis_Transform");
			waitForUser("[Transparent Mode] Skeleton Distance Map Union");
		}

		if (isOpen("Medial_Axis_Transform")) print("Image: Medial Axis Transform [OK]");
		else print("Image: Medial Axis Transform  [Not Open]");
		
		selectImage("Medial_Axis_Transform");

		if (transpMode) setBatchMode("hide");
		
		n = roiManager("Count");
		for (i = 0; i < n; i++)
		{
			selectImage("Medial_Axis_Transform");
			roiManager("Select", i);
			mid = getSliceNumber();

			nid = Roi.getProperty("Nuclear_ID");
			ID = Roi.getProperty("Object_ID");
			currentColor = Roi.getProperty("ROI_Color");
			setColor(currentColor);
			
			Roi.getContainedPoints(wcxPoints, wcyPoints);
			distMapValues = newArray(wcxPoints.length);
			for (j = 0; j < wcxPoints.length; j++) 
			{
				pxval = getPixel(wcxPoints[j], wcyPoints[j]);
				if (!isNaN(pxval)) distMapValues[j] = pxval;
			}

			print("\n[ " + ID + " Construction ]");
			rSlices = 0;
			selectImage("Canvas");
			getVoxelSize(vx, vy, vz, nunit);
			for (k = 1; k <= nSlices; k++)
			{
				for (j = 0; j < wcxPoints.length; j++) 
				{
					efactor = vx/vz;
					rinput = distMapValues[j];
					zinput = (mid - k) / efactor;
					segmentRadius = crossSectionRadius(rinput, zinput) + 1;
					if ((rinput != 0) & (!isNaN(segmentRadius)))
					{
						if (segmentRadius > (2 * nvx)) 
						{
							// Compound Selection
							setKeyDown("Shift");
							makeOval(wcxPoints[j] - segmentRadius, wcyPoints[j] - segmentRadius, segmentRadius * 2, segmentRadius * 2);
							print("Cell " + i + ", Slice " + k + ", Segment " + j + ") --- R0: " + rinput + ", RS: " + segmentRadius + ", Z: " + zinput + ", Elongation Factor: " + efactor );
						}
					}
					//else if (isNaN(segmentRadius)) print("Segmentation Radius is NaN!");
				}
		
				// Apply to Canvas and ROI Manager
				if (selectionType() != -1)
				{
					Roi.setProperty("Object_ID", ID);
					Roi.setProperty("Nuclear_ID", nid);
					Roi.setProperty("ROI_Color", currentColor);
					Roi.setStrokeColor(currentColor);
					
					if ((mid - k) == 0) Roi.setProperty("Mid_Slice", true);
					else Roi.setProperty("Mid_Slice", false);
					Roi.setProperty("Data_Type", "Whole_Cell");
					Roi.setName("WC_" + ID + "_" + k);
					Roi.setPosition(k);
					setSlice(k);
					roiManager("Add");
					fill();

					print("Cell " + i + ", Slice " + k + " added to ROI Manager.");
					rSlices++;
				}
				else print("Cell " + i + ", Slice " + k + " has no ROI.");
				
				run("Select None");
				run("Remove Overlay");
			}
			if (rSlices != 0) print("Cell " + ID + " was constructed completely! (RS" + rSlices + ")");
			else print("Cell " + ID + " was not constructed (RS" + rSlices + ")");
		}
		close("Medial_Axis_Transform");
		selectImage("Canvas");
		
		// ROI Name Cleanup
		n = roiManager("Count");
		deleteList = newArray();
		for (i = 0; i < n; i++) if (!startsWith(call("ij.plugin.frame.RoiManager.getName", i), "WC")) deleteList = Array.concat(deleteList, i);
		
		// Delete Original ROIs
		if (deleteList.length > 0)
		{
			roiManager("Select", deleteList);
			roiManager("Delete");
		}
		roiManager("Deselect");

		// Image Export
		selectImage("Canvas");
		run("Remove Overlay");
		run("Select None");
		wcbinary = directoryBinary+"/Whole_Cell_RGB.tif";
		if (!File.exists(wcbinary)) saveAs(".tiff", wcbinary);
		print("\n[Image Export]\nWhole Cell Binary: " + wcbinary);
	
		// Unfiltered Whole Cell ROI Export
		showStatus("Pomegranate - Exporting Unfiltered Reconstruction Output Whole Cell ROis");
		print("\n[Exporting Unfiltered Reconstruction Output Whole Cell ROIs]");
		wcFile = directoryROI + replace(File.getName(imagePath),'.','_') + "_Unfiltered_Reconstruction_Output_Whole_Cell_ROIs.zip";
		if (!File.exists(wcFile)) roiManager("Save", wcFile);
		print("File Created: " + wcFile);

		if (transpMode) waitForUser("[Transparent Mode] Reconstruction");
		if (!transpMode) setBatchMode(false);

		// Only provide Summary when using both 
		// Nuclear and Whole Cell Segmentation
		if (runMode != "WLCL")
		{
			print("\n[Prefilter Acquisition Summary]");
			print("Total Nuclei: " + nnuclei);
			print("Total Cells: " + ncells);
	
			print("\n[Filter Summary]");
			print("Removed Nuclei: " + removednuclei);
			print("Out of Bound Cells: " + oobcells);
			print("--- Nuclei in Out of Bound Cells: " + oobNuclei);
			print("Merged Cells: " + mergedcells);
			print("--- Nuclei in Merged Cells: " + mergedcells);		
			print("Septating Cells: " + septatingcells);
			print("--- Nuclei in Septating Cells: " + septatingcells * 2);
			print("No Nuclei Cells: " + nonucleicells);
			print("Poor Solidity Cells: " + nonsolidcells);
			print("--- Nuclei in Poor Solidity Cells: " + nonsolidNuclei);
	
			print("\n[Postfilter Acquisition Summary]");
			print("Final Cells: " + finalcells);
			print("Final Nuclei: " + (nnuclei - removednuclei));
			print("Unpaired Nuclei: " + (finalcells - (nnuclei - removednuclei)));
	
			print("\n[Alignment Summary]");
			print("Mean Slice Displacement: " + sdispmean);
			print("Standard Deviation Slice Displacement: " + sdispsd);
			print("Mean Absolute Slice Displacement: " + abssdispmean);
			print("Standard Deviation Absolute Slice Displacement: " + abssdispsd);
		}
	} 

	step++; // * * *

// [ 11 ] -----------------------------------------------------------------------------------------------------------------------------------------------

	// Reload and Inspect
	roiManager("Reset");
	
	if (!segMode) selectImage(msChannel);
	else 
	{
		if (runMode != "NUCL") selectImage(bfChannel);
		else if (runMode != "WLCL") selectImage(nmChannel);
	}
	
	if (runMode != "NUCL") roiManager("Open", wcFile);
	if (runMode == "NUCL") roiManager("Open", nucFile);
	else if (runMode == "BOTH") roiManager("Open", pnucFile);
	
	roiManager("Sort");

	roiManager("Show All Without Labels");

	// Hold
	waitForUser("Reconstruction complete.\nClick OK to proceed to manual ROI filtering.");

	// Manual Deletion
	setSlice(round(nSlices/2));
	manualDelete = getBoolean("Manually delete an ROI?\nClick NO to use current ROIs for quantification");
	oidRecord = newArray();
	deleteList = newArray();
	while (manualDelete)
	{
		selectWindow("ROI Manager");
		roiManager("Show All With Labels");

		setSlice(round(nSlices/2));
		waitForUser("Please select an ROI.\nClick OK to delete that ROI's object.");
		if (selectionType() != -1)
		{
			deleteList = newArray();
			deleteID = Roi.getProperty("Object_ID");
			deleteType = Roi.getProperty("Data_Type");
			oidRecord = Array.concat(oidRecord, deleteID);
			
			n = roiManager("Count");
			for (i = 0; i < n; i++)
			{
				roiManager("Select", i);
				if ((Roi.getProperty("Object_ID") == deleteID) && (Roi.getProperty("Data_Type") == deleteType)) deleteList = Array.concat(deleteList, i);
			}

			// Clear Bad ROIs
			if (deleteList.length > 0)
			{
				roiManager("Select", deleteList);
				roiManager("Delete");
			}
			roiManager("Deselect");
			run("Select None");

			setSlice(round(nSlices/2));
			manualDelete = getBoolean("Manually delete another ROI?\nClick NO to use current ROIs for quantification");
		}
		else manualDelete = getBoolean("Invalid selection. Try again?\nClick NO to use current ROIs for quantification");
	}
	if (transpMode) waitForUser("[Transparent Mode] Manual Filter");

	step++;  // * * *

// [ 12 ] -----------------------------------------------------------------------------------------------------------------------------------------------

	// Measure Intensity
	showStatus("Pomegranate - Measuring Whole Cell ROIs");
	run("Set Measurements...", "area mean standard modal min centroid center perimeter fit shape feret's median stack display redirect=None decimal=3"); // Remove Threshold Columns
	setBatchMode(true);
		
	if (!segMode) selectImage(msChannel);
	else 
	{
		if ((runMode != "NUCL") & (!binaryMode)) selectImage(bfChannel);
		else if ((runMode != "NUCL") & (binaryMode)) selectImage("Whole_Cell_RGB.tif");
		else if (runMode != "WLCL") selectImage(nmChannel);
	}
	
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
		getSelectionCoordinates(xpos, ypos);
		Roi.getContainedPoints(xpc, ypc);
		
		ID = Roi.getProperty("Object_ID");
		dType = Roi.getProperty("Data_Type");
		midType = Roi.getProperty("Mid_Slice");
		crad = Roi.getProperty("Cell_Radius");
		nid = Roi.getProperty("Nuclear_ID");
		pixelArea = xpc.length;
				
		setResult("Object_ID", i, ID);
		if (midType) setResult("ROI_Type", i, "MID");
		else setResult("ROI_Type", i, "NONMID");

		setResult("Nuclear_ID", i, nid);
		setResult("Data_Type", i, dType);
		setResult("Image", i, imageName);
		setResult("Experiment", i, expName);
		setResult("xpos", i, replace(String.join(xpos)," ",""));
		setResult("ypos", i, replace(String.join(ypos)," ",""));
		
		setResult("voxelSize_X", i, nvx);
		setResult("voxelSize_Y", i, nvy);
		setResult("voxelSize_Z", i, nvz);
		setResult("voxelSize_unit", i, nunit);

		setResult("Area_px", i, pixelArea);
	}
		
	// Results Export
	showStatus("Pomegranate - Exporting Whole Cell Measurements");
	print("\n[Exporting Results]");
	ResultFile = directoryResults + replace(File.getName(imagePath),'.','_') + "_Results_Full.csv";
	if (!File.exists(ResultFile)) saveAs("Results", ResultFile);
	print("File Created: " + ResultFile);
	
	step++; // * * *

// [ 13 ] -----------------------------------------------------------------------------------------------------------------------------------------------

	if (runMode != "NUCL")
	{
		// Revise Reconstruction Input based on manual selection
		roiManager("Reset");
		roiManager("Open", rinpFile);
		deleteList = newArray();
		for (i = 0; i < roiManager("Count"); i++)
		{
			roiManager("Select", i);
			currentID = Roi.getProperty("Object_ID");
			for (j = 0; j < oidRecord.length; j++)
			{
				if ((currentID == oidRecord[j])) deleteList = Array.concat(deleteList, i);
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

		// Filtered Reconstruction Input ROI Export
		showStatus("Pomegranate - Exporting Filtered Reconstruction Output Whole Cell ROIs");
		print("\n[Exporting Filtered Reconstruction Output Whole Cell ROIs]");
		frinpFile = directoryROI + replace(File.getName(imagePath),'.','_') + "_Filtered_Reconstruction_Input_Whole_Cell_ROIs.zip";
		if (!File.exists(frinpFile)) roiManager("Save", frinpFile);
		print("File Created: " + frinpFile);

		if (runMode == "BOTH")
		{
			// Revise Nuclear ROIs based on manual selection
			roiManager("Reset");
			roiManager("Open", pnucFile);
			deleteList = newArray();
			for (i = 0; i < roiManager("Count"); i++)
			{
				roiManager("Select", i);
				currentID = Roi.getProperty("Object_ID");
				for (j = 0; j < oidRecord.length; j++)
				{
					if ((currentID == oidRecord[j])) deleteList = Array.concat(deleteList, i);
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
	
			// Filtered Nuclear ROI Export
			print("\n[Exporting Nuclear ROI Files]");
			fnucFile = directoryROI + replace(File.getName(imagePath),'.','_') + "_Filtered_Nuclear_ROIs.zip";
			if (!File.exists(fnucFile)) roiManager("Save", fnucFile);
			print("File Created: " + fnucFile);
		}
	
		// Revise Reconstruction Output ROIs based on manual selection
		roiManager("Reset");
		roiManager("Open", wcFile);
		deleteList = newArray();
		for (i = 0; i < roiManager("Count"); i++)
		{
			roiManager("Select", i);
			currentID = Roi.getProperty("Object_ID");
			for (j = 0; j < oidRecord.length; j++)
			{
				if ((currentID == oidRecord[j])) deleteList = Array.concat(deleteList, i);
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
	
		// Filtered Whole Cell ROI Export
		showStatus("Pomegranate - Filtered iltered Reconstruction Output Exporting Whole Cell ROIs");
		print("\n[Exporting Filtered Reconstruction Output Whole Cell ROIs]");
		fwcFile = directoryROI + replace(File.getName(imagePath),'.','_') + "_Filtered_Reconstruction_Output_Whole_Cell_ROIs.zip";
		if (!File.exists(fwcFile)) roiManager("Save", fwcFile);
		print("File Created: " + fwcFile);
	}

// [ 14 ] -----------------------------------------------------------------------------------------------------------------------------------------------

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

// Radius of Spherical Cross Sections in Z
function crossSectionRadius(r,z) 
{
	return(sqrt(pow(r,2) - pow(z,2)));
}

// Return a Random Color in Hex Function
function randomHexColor()
{
	hex = newArray();
	char = newArray('1','2','3','4','5','6','7','8','9','0','a','b','c','d','e','f');
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
		
		makeSelection("polygon",rx,ry); // Restore
		return(AR1/AR2);
	}
	else return(NaN);
}

// Return true if Array contains Val
function acontains(arr, val)
{
	L1 = arr.length;
	arr2 = Array.deleteValue(arr, val);
	L2 = arr2.length;
	if (L1 != L2) return true;
	else return false;
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

// Auto Focus based on Standard Deviation
function autoFocus()
{
	run("Select None");
	arr = newArray();
	for (i = 1; i <= nSlices; i++)
	{
		setSlice(i);
		sd = getValue("StdDev");
		if (sd != 0) arr = Array.concat(arr, sd);
		else arr = Array.concat(arr, 1E99);
	}
	g = Array.findMinima(arr, 0);
	run("Select None");
	return(g[0]);
}

