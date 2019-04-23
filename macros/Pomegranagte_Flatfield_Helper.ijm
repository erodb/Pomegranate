macro "Pomegranate Flatfielding Tool"
{
	close('*');
	run("Collect Garbage");
	run("Monitor Memory...");

	// Save IDs
	getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
	saveID = "" + year + "" + month + "" + dayOfMonth + "_" + hour + "" + minute;
	
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
	
	run("Z Project...", "projection=[Average Intensity]");
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
	
	run("Z Project...", "projection=[Average Intensity]");
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
	run("Z Project...", "projection=[Average Intensity]");
	close(image);
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
	

// ---------------------------------------------------------------------------------------------------------------------------------------------------------

	// Designate Output Directory
	Dialog.create("Output Directory");
		Dialog.addChoice("Output Method", newArray("Select Output Directory","Manually Enter Path"));
	Dialog.show();
	if (Dialog.getChoice() == "Select Output Directory") outputPath = getDirectory("Select Output Directory"); 
	else outputPath = getString("Output Path", "/Users/hauflab/Documents");	
	msN = bfN = nmN = 2;
	setBatchMode(true);
		
	cont = true;
	while (cont) 
	{
		run("Collect Garbage");
		
		// Designate Input Image
		hold = true;
		Dialog.create("Input Image");
			Dialog.addChoice("Input Method", newArray("Select Image from Directory","Manually Enter Path"));
		Dialog.show();
		if (Dialog.getChoice() == "Select Image from Directory") imagePath = File.openDialog("Choose an Input  File"); 
		else imagePath = getString("Image Path", "/Users/hauflab/Documents");
	
		run("Bio-Formats Importer", "open=" + imagePath + " autoscale color_mode=Composite view=Hyperstack stack_order=XYCZT");
		imageName = File.getName(imagePath);
		
		// Get Image Dimensions
		getDimensions(width, height, channels, slices, frames);
		getVoxelSize(vx, vy, vz, unit);
		channelList = newArray(channels);
		for (i = 1; i <= channels; i++) channelList[i-1] = "" + i;
	
		// Assign Channels
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
	
			/*
			print("\n[Run Parameters]");
			print("Measurement Channel: " + msChannel);
			print("Nuclear Marker Channel: " + nmChannel);
			print("Bright-Field Channel: " + bfChannel);
			*/
			
			if ((nmN != bfN) && (msN != bfN) && (nmN != msN)) hold = false; // * * *
			else showMessageWithCancel("Pomegranate Error", "Error: Invalid Channels");
		}
	
		run("Split Channels");	
		msChannel = "C"+msN+"-"+imageName;
		nmChannel = "C"+nmN+"-"+imageName;
		bfChannel = "C"+bfN+"-"+imageName;
	
		// Apply Nuclear Marker Channel Correction
		imageCalculator("Subtract 32-bit stack", nmChannel, "dnFlatfield");
		imageCalculator("Divide 32-bit stack", "Result of " + nmChannel, "nmFlatfield");
		rename("Processed_"+nmChannel);
		resetMinAndMax;
		close(nmChannel);
	
		// Apply Measurement Channel Correction
		imageCalculator("Subtract 32-bit stack", msChannel, "dnFlatfield");
		imageCalculator("Divide 32-bit stack", "Result of " + msChannel, "msFlatfield");
		rename("Processed_"+msChannel);
		resetMinAndMax;
		close(msChannel);
	
		selectWindow(bfChannel);
		run("32-bit");
	
		run("Merge Channels...", "c1=Processed_" + msChannel + " c2=Processed_" + nmChannel + " c3=" + bfChannel + " create");
		
		saveAs("Tiff", outputPath + "/" + saveID + "_" + imageName);
		close('*' + imageName);

		waitForUser("Correction complete: " + getTitle());
		close(getTitle());
		cont = getBoolean("Process Another Image?");
	}

	setBatchMode(false);
}