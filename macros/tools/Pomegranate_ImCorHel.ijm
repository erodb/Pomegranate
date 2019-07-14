macro "Pomegranate ImCorHel"
{
	/* Pomegranate 2019
	 * Image Correction Helper (ImCorHel) 
	 * 
	 * Erod Keaton Baybay (erodb@vt.edu)
	 */
	
	close('*');
	run("Collect Garbage");

	// Save IDs
	getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
	saveID = "" + year + "" + month + "" + dayOfMonth + "_" + hour + "" + minute;
	
	// Corrections Menu
	Dialog.create("Corrections Menu");
		Dialog.addCheckbox("Flatfielding", true);
		Dialog.addCheckbox("Axial Chromatic Aberration", true);
		Dialog.addCheckbox("Axial Distance Calibration", true);
	Dialog.show();
	ffCorrection = Dialog.getCheckbox();
	acCorrection = Dialog.getCheckbox();
	adCorrection = Dialog.getCheckbox();

	if (ffCorrection)
	{
		// Nuclear Marker Channel Input (Directory)
		Dialog.create("Nuclear Marker Channel Flatfielding ");
			Dialog.addCheckbox("Import as Stack", false);
			Dialog.addChoice("Input Method", newArray("Select Input from Finder","Manually Enter Path"));
		Dialog.show();
		nmMODE = Dialog.getCheckbox();
		method = Dialog.getChoice();
		
		if (!nmMODE)
		{
			if (method == "Select Input from Finder") nmFLAT = getDirectory("Choose an Input  File"); 
			else nmFLAT = getString("Image Path", "/Users/hauflab/Documents");
			nmLIST = getFileList(nmFLAT);
		}
		else
		{
			if (method == "Select Input from Finder") nmFLAT = File.openDialog("Choose an Input  File"); 
			else nmFLAT = getString("Image Path", "/Users/hauflab/Documents");
		}
	
		// ---------------------------------------------------------------------------------------------------------------------------------------------------------
	
		// Measurement Channel Input (Directory)
		Dialog.create("Measurement Channel Flatfielding");
			Dialog.addCheckbox("Import as Stack", false);
			Dialog.addChoice("Input Method", newArray("Select Input from Finder","Manually Enter Path"));
		Dialog.show();
		msMODE = Dialog.getCheckbox();
		method = Dialog.getChoice();
		
		if (!msMODE)
		{
			if (method == "Select Input from Finder") msFLAT = getDirectory("Choose an Input  File"); 
			else msFLAT = getString("Image Path", "/Users/hauflab/Documents");
			msLIST = getFileList(msFLAT);
		}
		else
		{
			if (method == "Select Input from Finder") msFLAT = File.openDialog("Choose an Input  File"); 
			else msFLAT = getString("Image Path", "/Users/hauflab/Documents");
		}
	
		// ---------------------------------------------------------------------------------------------------------------------------------------------------------
	
		// Dark Noise Input (Directory)
		Dialog.create("Dark Noise Correction");
			Dialog.addCheckbox("Import as Stack", false);
			Dialog.addChoice("Input Method", newArray("Select Input from Finder","Manually Enter Path"));
		Dialog.show();
		dnMODE = Dialog.getCheckbox();
		method = Dialog.getChoice();
		
		if (!dnMODE)
		{
			if (method == "Select Input from Finder") dnFLAT = getDirectory("Choose an Input  File"); 
			else dnFLAT = getString("Image Path", "/Users/hauflab/Documents");
			dnLIST = getFileList(dnFLAT);
		}
		else
		{
			if (method == "Select Input from Finder") dnFLAT = File.openDialog("Choose an Input  File"); 
			else dnFLAT = getString("Image Path", "/Users/hauflab/Documents");
		}
	
		// ---------------------------------------------------------------------------------------------------------------------------------------------------------
	
		// Measurement Channel Flatfield
		if(!msMODE)
		{
			setBatchMode(true);
			for (i = 0; i < msLIST.length; i++)
			{
				run("Bio-Formats Importer", "open=" + msFLAT + "/" + msLIST[i] + " autoscale color_mode=Composite view=Hyperstack stack_order=XYCZT");
				rename("component_" + msLIST[i]);
			}
			run("Images to Stack", "name=Stack title=component use");
			setBatchMode(false);
		}
		else run("Bio-Formats Importer", "open=" + msFLAT + " autoscale color_mode=Composite view=Hyperstack stack_order=XYCZT");
	
		image = getTitle();
		if (nSlices > 1) 
		{
			run("Z Project...", "projection=[Average Intensity]");
			close(image);
		}
		run("32-bit");
		rename("msFlatfield");
		
	
		// ---------------------------------------------------------------------------------------------------------------------------------------------------------
	
		// Nuclear Marker Flatfield
		if(!nmMODE)
		{
			setBatchMode(true);
			for (i = 0; i < nmLIST.length; i++)
			{
				run("Bio-Formats Importer", "open=" + nmFLAT + "/" + nmLIST[i] + " autoscale color_mode=Composite view=Hyperstack stack_order=XYCZT");
				rename("component_" + nmLIST[i]);
			}
			run("Images to Stack", "name=Stack title=component use");
			setBatchMode(false);
		}
		else run("Bio-Formats Importer", "open=" + nmFLAT + " autoscale color_mode=Composite view=Hyperstack stack_order=XYCZT");
		
		image = getTitle();
		if (nSlices > 1) 
		{
			run("Z Project...", "projection=[Average Intensity]");
			close(image);
		}
		run("32-bit");
		rename("nmFlatfield");
		
		// ---------------------------------------------------------------------------------------------------------------------------------------------------------
	
		// Dark Noise Flatfield
		if(!dnMODE)
		{
			setBatchMode(true);
			for (i = 0; i < dnLIST.length; i++)
			{
				run("Bio-Formats Importer", "open=" + dnFLAT + "/" + dnLIST[i] + " autoscale color_mode=Composite view=Hyperstack stack_order=XYCZT");
				rename("component_" + dnLIST[i]);
			}
			run("Images to Stack", "name=Stack title=component use");
			setBatchMode(false);
		}
		else run("Bio-Formats Importer", "open=" + dnFLAT + " autoscale color_mode=Composite view=Hyperstack stack_order=XYCZT");
	
		image = getTitle();
		if (nSlices > 1) 
		{
			run("Z Project...", "projection=[Average Intensity]");
			close(image);
		}
		run("32-bit");
		resetMinAndMax;
		rename("dnFlatfield");
		run("Fire");
	
		// ---------------------------------------------------------------------------------------------------------------------------------------------------------
	
		// Subtract Dark Noise (msFlatfield)
		selectImage("msFlatfield");
		imageCalculator("Subtract 32-bit", "msFlatfield", "dnFlatfield");
		run("Select All");
		getStatistics(area, mean, min, max, std, histogram);
		run("Divide...", "value=" + mean);
		close("Stack");
		resetMinAndMax;
		rename("msFlatfield");
		run("Fire");
	
		// Subtract Dark Noise (nmFlatfield)
		selectImage("nmFlatfield");
		imageCalculator("Subtract 32-bit", "nmFlatfield", "dnFlatfield");
		run("Select All");
		getStatistics(area, mean, min, max, std, histogram);
		run("Divide...", "value=" + mean);
		close("Stack");
		resetMinAndMax;
		rename("nmFlatfield");
		run("Fire");
	}
// ---------------------------------------------------------------------------------------------------------------------------------------------------------

	// Axial Chromatic Abberation
	nmShift = 9; // TRITC
	msShift = 6; // FITC
	bfShift = 7; // POL
	if (acCorrection)
	{
		Dialog.create("Axial Chromatic Abberation");
			Dialog.addNumber("Nuclear Marker Channel Shift (slices)", nmShift);
			Dialog.addNumber("Measurement Channel Shift (slices)", msShift);
			Dialog.addNumber("Bright Field Channel Shift (slices)", bfShift);
		Dialog.show();
		nmShift = Dialog.getNumber();
		msShift = Dialog.getNumber();	
		bfShift = Dialog.getNumber();		

		shiftArray = newArray(nmShift,msShift,bfShift);
		Array.getStatistics(shiftArray, shiftMin, shiftMax);

		// Stack Size Balance
		nmBalance = shiftMax - nmShift;
		msBalance = shiftMax - msShift;
		bfBalance = shiftMax - bfShift; 
	}

// ---------------------------------------------------------------------------------------------------------------------------------------------------------

	// Axial Distance Calibration
	zscale = 0;
	if (adCorrection) 
	{
		while (zscale == 0) zscale = getNumber("Axial Distance Scaling Factor", 0.659);
	}
	

// ---------------------------------------------------------------------------------------------------------------------------------------------------------

	// Designate Output Directory
	Dialog.create("Output Directory");
		Dialog.addChoice("Output Method", newArray("Select Output Directory","Manually Enter Path"));
	Dialog.show();
	if (Dialog.getChoice() == "Select Output Directory") outputPath = getDirectory("Select Output Directory"); 
	else outputPath = getString("Output Path", "/Users/hauflab/Documents");	
	msN = bfN = nmN = 2;
	setBatchMode(true);

	auto = getBoolean("Run in Auto Batch Mode?");
		
	cont = true;
	while (cont) 
	{	
		// Designate Input Image
		if (!auto)
		{
			Dialog.create("Input Image");
				Dialog.addChoice("Input Method", newArray("Select Image from Directory","Manually Enter Path"));
			Dialog.show();
			if (Dialog.getChoice() == "Select Image from Directory") imagePath = File.openDialog("Choose an Input  File"); 
			else imagePath = getString("Image Path", "/Users/hauflab/Documents");
			
			inputDirectory = File.getParent(imagePath);
			inputList = Array.concat(newArray(), File.getName(imagePath));
		}
		else 
		{
			Dialog.create("Input Directory");
				Dialog.addChoice("Input Method", newArray("Select Input Directory","Manually Enter Path"));
			Dialog.show();
			if (Dialog.getChoice() == "Select Input Directory") inputDirectory = getDirectory("Choose an Input  Directory"); 
			else inputDirectory = getString("Image Path", "/Users/hauflab/Documents");

			inputList = getFileList(inputDirectory);
		}
		
		for (m = 0; m < inputList.length; m++)
		{
			run("Collect Garbage");
			
			run("Bio-Formats Importer", "open=" + inputDirectory + "/" + inputList[m] + " autoscale color_mode=Composite view=Hyperstack stack_order=XYCZT");
			imageName = inputList[m];
			
			// Get Image Dimensions
			getDimensions(width, height, channels, slices, frames);
			getVoxelSize(vx, vy, vz, unit);
			channelList = newArray(channels);
			for (i = 1; i <= channels; i++) channelList[i-1] = "" + i;
		
			// Assign Channels
			hold = true;

			if ((auto) && (m > 0)) hold = false; // * * * (Auto Batch Mode Override)
			while (hold)
			{
				Dialog.create("Channel Selection");
					Dialog.addChoice("Measurement Channel", channelList, msN);
					Dialog.addChoice("Nuclear Marker Channel", channelList, nmN);
					Dialog.addChoice("Bright-Field Channel", channelList, bfN);
				Dialog.show();	
				msN = parseInt(Dialog.getChoice()); // Measurement Channel
				nmN = parseInt(Dialog.getChoice()); // Nuclear Marker Channel
				bfN = parseInt(Dialog.getChoice()); // Bright-Field Channel
				
				if ((nmN != bfN) && (msN != bfN) && (nmN != msN)) hold = false; // * * *
				else showMessageWithCancel("Pomegranate Error", "Error: Invalid Channels");
			}

			
			getDimensions(width, height, channels, slices, frames);
			getVoxelSize(vx, vy, vz, unit);
			if (adCorrection) run("Properties...", "channels=" + channels +" slices=" + slices +" frames=" + frames + " unit=" + unit + " pixel_width=" + vx + " pixel_height=" + vy + " voxel_depth=" + vz * zscale);

			if (channels > 1)
			{
				run("Split Channels");	
				msChannel = "C"+msN+"-"+imageName;
				nmChannel = "C"+nmN+"-"+imageName;
				bfChannel = "C"+bfN+"-"+imageName;
	
				// ---------------------------------------------------------------------------------------------------------------------------------------------------------
			
				// Apply Nuclear Marker Channel Correction
				selectImage(nmChannel);
				if (ffCorrection) 
				{
					imageCalculator("Subtract 32-bit stack", nmChannel, "dnFlatfield");
					imageCalculator("Divide 32-bit stack", "Result of " + nmChannel, "nmFlatfield");
				}
				
				if (acCorrection)
				{
					run("Reverse");
					setSlice(nSlices);
					for (i = 0; i < nmBalance; i++) run("Add Slice");
					
					run("Reverse");
					setSlice(nSlices);
					for (i = 0; i < nmShift; i++) run("Add Slice");
				}
	
				rename("Processed_"+nmChannel);
				run("Grays");
				run("32-bit");
	
				setSlice(nSlices/2);
				resetMinAndMax;
				close(nmChannel);
				run("Collect Garbage");
	
				// ---------------------------------------------------------------------------------------------------------------------------------------------------------
	
				// Apply Measurement Channel Correction
				selectImage(msChannel);
				if (ffCorrection) 
				{
					imageCalculator("Subtract 32-bit stack", msChannel, "dnFlatfield");
					imageCalculator("Divide 32-bit stack", "Result of " + msChannel, "msFlatfield");
				}
	
				if (acCorrection)
				{
					run("Reverse");
					setSlice(nSlices);
					for (i = 0; i < msBalance; i++) run("Add Slice");
	
					run("Reverse");
					setSlice(nSlices);
					for (i = 0; i < msShift; i++) run("Add Slice");
				}
				
				rename("Processed_"+msChannel);
				run("Grays");
				run("32-bit");
				
				setSlice(nSlices/2);
				resetMinAndMax;
				close(msChannel);
				run("Collect Garbage");
	
				// ---------------------------------------------------------------------------------------------------------------------------------------------------------
	
				// Apply Bright Field Channel Correction
				selectImage(bfChannel);
				if (acCorrection)
				{
					run("Reverse");
					setSlice(nSlices);
					for (i = 0; i < bfBalance; i++) run("Add Slice");
	
					run("Reverse");
					setSlice(nSlices);
					for (i = 0; i < bfShift; i++) run("Add Slice");
				}
				
				rename("Processed_"+bfChannel);
				run("Grays");
				run("32-bit");
	
				setSlice(nSlices/2);
				resetMinAndMax;
				close(bfChannel);
				run("Collect Garbage");
			
				// ---------------------------------------------------------------------------------------------------------------------------------------------------------
	
				run("Merge Channels...", "c1=Processed_" + msChannel + " c2=Processed_" + nmChannel + " c3=Processed_" + bfChannel + " create");
				
				saveAs("Tiff", outputPath + "/" + saveID + "_" + imageName);
				close(saveID + "_*");
				
				if (!auto) cont = getBoolean("Corrections Complete! Process Another Image?");
				else cont = false;
			}
			run("Collect Garbage");
		}
	}

	setBatchMode(false);
}