macro "Pomegranate Analysis Revision Tool"
{
	versionFIJI = "1.53b";
	requires(versionFIJI);

	// Title Pop Up
	showMessage("Pomegranate Analysis Revision Tool", "<html>"
			+"<font size=+3><center><b>Pomegranate</b><br></center>"
			+"<font size=+1><center><b>Analysis Revision Tool</b><br></center>"
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
	
	roiManager("Associate", "true");
	roiManager("UseNames", "true");
	run("Options...", "iterations=1 count=1 black do=Nothing");
	
	run("Set Measurements...", "area mean standard modal min centroid center perimeter fit shape feret's median stack limit display redirect=None decimal=3");


// -----------------------------------------------------------------------------------------------------------------------------------------------

	// Designate Existing Output File
	Dialog.create("Existing Results File");
		Dialog.addChoice("Input Method", newArray("Select Existing Output File from Directory","Manually Enter Path"));
	Dialog.show();
	if (Dialog.getChoice() == "Select Existing Output File from Directory") oldPath = getDirectory("Choose Existing Output File"); 
	else oldPath = getString("File Path", "/Users/hauflab/Documents");

	// Output Directory
	oldDirectoryMain = oldPath +"/";
		
		// Old ROI Directory
		oldDirectoryROI = oldDirectoryMain + "ROIs/";
		if (!File.exists(oldDirectoryROI)) exit("Error: Missing ROI Directory\nResponse: Ending Analysis");

		// Old Binary Directory
		oldDirectoryBinary = oldDirectoryMain + "Binaries/";
		if (!File.exists(oldDirectoryROI)) exit("Error: Missing Binaries Directory\nResponse: Ending Analysis");

		// Identify ROI Files
		unuclei = -1;
		fnuclei = -1;
		uinput = -1;
		finput = -1;
		uoutput = -1;
		foutput = -1;
		
		roiList = getFileList(oldDirectoryROI);
		for (i = 0; i < roiList.length; i++) 
		{
			if (endsWith(roiList[i], "_Unfiltered_Nuclear_ROIs.zip")) unuclei = roiList[i];
			if (endsWith(roiList[i], "_Filtered_Nuclear_ROIs.zip")) fnuclei = roiList[i];
			if (endsWith(roiList[i], "_Unfiltered_Reconstruction_Input_Whole_Cell_ROIs.zip")) uinput = roiList[i];
			if (endsWith(roiList[i], "_Filtered_Reconstruction_Input_Whole_Cell_ROIs.zip")) finput = roiList[i];
			if (endsWith(roiList[i], "_Unfiltered_Reconstruction_Output_Whole_Cell_ROIs.zip")) uoutput = roiList[i];
			if (endsWith(roiList[i], "_Filtered_Reconstruction_Output_Whole_Cell_ROIs.zip")) foutput = roiList[i];
		}


	// Run Mode Detection	
	if ((unuclei != -1) & (fnuclei != -1) & (uinput != -1) & (finput != -1) & (uoutput != -1) & (foutput != -1)) 
	{
		runMode = "BOTH";
		runModeText = "Detected Analysis Type: Nuclear and Wholecell";
	}
	else if ((unuclei != -1) & (fnuclei != -1) & (uinput == -1) & (finput == -1) & (uoutput == -1) & (foutput == -1)) 
	{
		runMode = "NUCL";
		runModeText = "Detected Analysis Type: Nuclear Only";
	}
	else if ((unuclei == -1) & (fnuclei == -1) & (uinput != -1) & (finput != -1) & (uoutput != -1) & (foutput != -1)) 
	{
		runMode = "WLCL";
		runModeText = "Detected Analysis Type: Whole Cell Only";
	}
	else
	{
		showMessageWithCancel("Pomegranate Error", "Error: Invalid ROI file configuration. Check files in ROI directory.\nResponse: Ending Analysis");
		cleanAll();
		exit();
	}

	transpMode = false;
	segMode = false;
	importModeList = newArray("Single Multi-Channel Image", "Multiple Single-Channel Images");
	Dialog.create("Pomegranate Run Parameters");
		Dialog.addMessage(runModeText);
		Dialog.addChoice("Import Type", importModeList);
		Dialog.addCheckbox("Ignore Measurement Channel", segMode);
		Dialog.addCheckbox("Transparent Mode", transpMode);
	Dialog.show();
	importMode = Dialog.getChoice();
	segMode = Dialog.getCheckbox();
	transpMode = Dialog.getCheckbox();

	if (importMode == importModeList[0]) importMode = "MERGED";
	else if (importMode == importModeList[1]) importMode = "UNMERGED";

// -----------------------------------------------------------------------------------------------------------------------------------------------

	// Designate Input Image
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

		if (!isOpen(imageName)) 
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
		print("Voxel Size: " + vx + " " + unit + ", " + vy + " " + unit + ", " + vz + " " + unit);
		if (channels > 1)
		{
			channelList = newArray(channels);
			for (i = 1; i <= channels; i++) channelList[i-1] = "" + i;
			
			// Assign Channels
			channelHold = true;
			while (channelHold)
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
				if ((nmChannel != bfChannel) && (msChannel != bfChannel) && (nmChannel != msChannel)) channelHold = false; // * * *
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

		if (!segMode) selectImage(msChannel);
		else if (runMode == "NUCL") selectImage(nmChannel);
		else if (runMode == "WLCL") selectImage(bfChannel);
		else if (runMode == "BOTH") selectImage(bfChannel);
			
		// Get Image Dimensions
		getDimensions(width, height, channels, slices, frames);
		getVoxelSize(vx, vy, vz, unit);

		// Quick Check
		getVoxelSize(vx, vy, vz, unit);
		print("Voxel Size: " + vx + " " + unit + ", " + vy + " " + unit + ", " + vz + " " + unit);

	}

	// Save IDs
	getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
	saveID = "" + year + "" + month + "" + dayOfMonth + "_" + hour + "" + minute + "_" + replace(imageName,".","_");
	runID = "OID" + (year - 2000) + "" + month + "" + dayOfMonth + "" + hour + "" + minute;

	// Voxel Size Management
	Dialog.create("Voxel Size Management");
		Dialog.addNumber("Voxel Width (" + unit + ")", 0.1071);
		Dialog.addNumber("Voxel Height (" + unit + ")", 0.1071);
		Dialog.addNumber("Voxel Depth (" + unit + ")", 0.0659);
	Dialog.show();
	nvx = Dialog.getNumber();
	nvy = Dialog.getNumber();
	nvz = Dialog.getNumber();

	if (!segMode) 
	{
		selectImage(msChannel);
		setVoxelSize(nvx, nvy, nvz, unit);
	}
	if (runMode != "WLCL")
	{
		selectImage(nmChannel);
		setVoxelSize(nvx, nvy, nvz, unit);
	}
	if (runMode != "NUCL")
	{
		selectImage(bfChannel);
		setVoxelSize(nvx, nvy, nvz, unit);
	}

	// Set Experiment Name
	expName = getString("Experiment Name", imageName);

	// Designate Output Directory
	Dialog.create("Output Directory");
		Dialog.addChoice("Output Method", newArray("Select Output Directory","Manually Enter Path"));
	Dialog.show();
	if (Dialog.getChoice() == "Select Output Directory") outputPath = getDirectory("Select Output Directory"); 
	else outputPath = getString("Output Path", "/Users/hauflab/Documents");	

// -----------------------------------------------------------------------------------------------------------------------------------------------

	// Output Directory
	directoryMain = outputPath + saveID+"/";
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

// -----------------------------------------------------------------------------------------------------------------------------------------------

	// Choose ROI Type and get ROI File Paths
	if(getBoolean("Use filtered ROIs or unfiltered ROIs?", "Filtered ROIs", "Unfiltered ROIs"))
	{
		if (runMode != "WLCL") npath = oldDirectoryROI + fnuclei;
		if (runMode != "NUCL") wcINpath = oldDirectoryROI + finput;
		if (runMode != "NUCL") wcOUTpath = oldDirectoryROI + foutput;
	}
	else
	{
		if (runMode != "WLCL") npath = oldDirectoryROI + unuclei;
		if (runMode != "NUCL") wcINpath = oldDirectoryROI + uinput;
		if (runMode != "NUCL") wcOUTpath = oldDirectoryROI + uoutput;
	}

	print("\n[ROI File Paths]");
	if (runMode != "WLCL") print("Nuclear ROI File Path: " + npath);
	if (runMode != "NUCL") print("Whole Cell Reconstruction Input ROI File Path: " + wcINpath);
	if (runMode != "NUCL") print("Whole Cell Reconstruction Output ROI File Path: " + wcOUTpath);

// -----------------------------------------------------------------------------------------------------------------------------------------------

	// Reload Nuclei and Save Copy
	if (runMode != "WLCL")
	{
		roiManager("Open", npath);

		// Nuclear ROI Export
		print("\n[Exporting Nuclear ROI Files]");
		nucFile = directoryROI + replace(File.getName(imagePath),'.','_') + "_Unfiltered_Nuclear_ROIs.zip";
		if (!File.exists(nucFile)) roiManager("Save", nucFile);
		print("File Created: " + nucFile);

		roiManager("Reset");
	}

// -----------------------------------------------------------------------------------------------------------------------------------------------

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
		
		redoR = getBoolean("Rerun Whole Cell Reconstruction?");
		if (redoR)
		{

			// Make Canvas Image
			selectImage(bfChannel);
			run("Select None");
			roiManager("Deselect");
			
			run("Duplicate...", "duplicate");
			run("Multiply...", "value=0 stack");
			run("RGB Color");
			rename("Canvas");
		
			// Load Input ROIs
			roiManager("Open", wcINpath);
			
			showStatus("Pomegranate - Constructing Whole Cell Fits");
			print("\n[Whole Cell Count]");
			n = roiManager("Count");
			finalcells = n;
			print("Cells: " + n);
	
			// Reconstruction Input ROI Export
			showStatus("Pomegranate - Exporting Whole Cell ROis");
			print("\n[Exporting Whole Cell ROIs]");
			rinpFile = directoryROI + replace(File.getName(imagePath),'.','_') + "_Unfiltered_Reconstruction_Input_Whole_Cell_ROIs.zip";
			if (!File.exists(rinpFile)) roiManager("Save", rinpFile);
			print("File Created: " + rinpFile);
		
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
	
			// Guarentee Binary
			selectImage("Binary_Filtered");
			run("8-bit");
			setAutoThreshold("Otsu dark");
			setThreshold(1, 10e6);
			run("Convert to Mask", "method=Otsu background=Dark black");
			roiManager("Deselect");
			run("Select None"); 
			
			// Distance Map
			selectImage("Binary_Filtered");
			run("Duplicate...", "duplicate title=Distance_Map");
			run("Distance Map", "stack");
			if (transpMode) waitForUser("[Transparent Mode] Distance Map");
			
			// Skeleton Image
			selectImage("Binary_Filtered");
			run("Duplicate...", "duplicate title=Skeleton");
			run("Skeletonize", "stack");
			if (transpMode) waitForUser("[Transparent Mode] Skeleton");
			
			// Skeleton Image AND Distance Map
			imageCalculator("AND create stack", "Distance_Map","Skeleton");
			rename("Medial_Axis_Transform");
			close("Skeleton");
			close("Distance_Map");
			if (transpMode) waitForUser("[Transparent Mode] Skeleton Distance Map Union");
			
			selectImage("Medial_Axis_Transform");
			
			n = roiManager("Count");
			for (i = 0; i < n; i++)
			{
				selectImage("Medial_Axis_Transform");
				roiManager("Select", i);
				
				ID = Roi.getProperty("Object_ID");
				currentColor = Roi.getProperty("ROI_Color");
				setColor(currentColor);
				
				mid = getSliceNumber();
				Roi.getContainedPoints(wcxPoints, wcyPoints);
				distMapValues = newArray(wcxPoints.length);
				for (j = 0; j < wcxPoints.length; j++) distMapValues[j] = getPixel(wcxPoints[j], wcyPoints[j]);
			
				selectImage("Canvas");
				getVoxelSize(vx, vy, vz, unit);
				for (k = 1; k <= nSlices; k++)
				{
					for (j = 0; j < wcxPoints.length; j++) 
					{
						efactor = vx/vz;
						rinput = distMapValues[j];
						zinput = (mid - k) / efactor;
						segmentRadius = crossSectionRadius(rinput, zinput) + 1;
						if ((rinput != 0) & (!isNaN(segmentRadius))) print("Cell " + i + ", Slice " + k + ", Segment " + j + ") --- R0: " + rinput + ", RS: " + segmentRadius + ", Z: " + zinput );
						if (segmentRadius > 2) 
						{
							// Compound Selection
							setKeyDown("Shift");
							makeOval(wcxPoints[j] - segmentRadius, wcyPoints[j] - segmentRadius, segmentRadius * 2, segmentRadius * 2);
						}
					}
			
					// Apply to Canvas and ROI Manager
					if (selectionType() != -1)
					{
						Roi.setProperty("Object_ID", ID);
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
					}
					run("Select None");
					run("Remove Overlay");
				}
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
		
			// Whole Cell ROI Export
			showStatus("Pomegranate - Exporting Whole Cell ROis");
			print("\n[Exporting Whole Cell ROIs]");
			wcFile = directoryROI + replace(File.getName(imagePath),'.','_') + "_Unfiltered_Reconstruction_Output_Whole_Cell_ROIs.zip";
			if (!File.exists(wcFile)) roiManager("Save", wcFile);
			print("File Created: " + wcFile);
	
			if (transpMode) waitForUser("[Transparent Mode] Reconstruction");
			if (!transpMode) setBatchMode(false);

			roiManager("Reset");
		}
		else
		{
			roiManager("Open", wcOUTpath);

			// Open Old Whole-Cell RGB
			open(oldDirectoryBinary + "Whole_Cell_RGB.tif");

			// Image Export (Copy)
			wcbinary = directoryBinary+"/Whole_Cell_RGB.tif";
			if (!File.exists(wcbinary)) saveAs(".tiff", wcbinary);
			print("\n[Image Export]\nWhole Cell Binary: " + wcbinary);
			
			// Whole Cell ROI Export
			showStatus("Pomegranate - Exporting Whole Cell ROis");
			print("\n[Exporting Whole Cell ROIs]");
			wcFile = directoryROI + replace(File.getName(imagePath),'.','_') + "_Unfiltered_Reconstruction_Output_Whole_Cell_ROIs.zip";
			if (!File.exists(wcFile)) roiManager("Save", wcFile);
			print("File Created: " + wcFile);

			roiManager("Reset");
		}
	} 

// -----------------------------------------------------------------------------------------------------------------------------------------------

	// Reload and Inspect
	roiManager("Reset");
	
	if (!segMode) selectImage(msChannel);
	else 
	{
		if ((runMode != "NUCL") & (!binaryMode)) selectImage(bfChannel);
		else if ((runMode != "NUCL") & (binaryMode)) selectImage("Whole_Cell_RGB.tif");
		else if (runMode != "WLCL") selectImage(nmChannel);
	}
	
	if (runMode != "NUCL") roiManager("Open", wcFile);
	if (runMode != "WLCL") roiManager("Open", nucFile);
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

// -----------------------------------------------------------------------------------------------------------------------------------------------

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
		setResult("voxelSize_unit", i, unit);

		setResult("Area_px", i, pixelArea);
	}
		
	// Results Export
	showStatus("Pomegranate - Exporting Whole Cell Measurements");
	ResultFile = directoryResults + replace(File.getName(imagePath),'.','_') + "_Results_Full.csv";
	if (!File.exists(ResultFile)) saveAs("Results", ResultFile);

// [ 12 ] -----------------------------------------------------------------------------------------------------------------------------------------------

	if (runMode != "NUCL")
	{	
		if (redoR)
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
	}

// -----------------------------------------------------------------------------------------------------------------------------------------------

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
	waitForUser("Done", "Analysis revision is complete\nPlease review files in your output directory");
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

// Radius of Spherical Cross Sections in Z
function crossSectionRadius(r,z) 
{
	return(sqrt(pow(r,2) - pow(z,2)));
}