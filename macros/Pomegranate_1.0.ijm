/*  Pomegranate
 *  
 *  Virginia Polytechnic Institute and State University
 *  Blacksburg, Virginia - Biocomplexity Institute
 *  Hauf Lab
 *  
 *  Erod Keaton D. Baybay (2019) - erodb@vt.edu
 */

macro "Pomegranate"
{
	versionFIJI = "1.52n";
	versionPIPELINE = "1.0";

	// Runtime
	sTime = getTime(); 
	
	cleanAll();
	run("Collect Garbage");
	run("Monitor Memory...");
	
	step = 0; // Progress Ticker
	requires(versionFIJI);
	print("[Pomegranate " + versionPIPELINE + "]");
	print("Required FIJI Version: " + versionFIJI);
	print("Currently Running FIJI Version: " + getVersion);
	run("Set Measurements...", "area mean standard modal min centroid center perimeter median stack display redirect=None decimal=3");

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
	
	// Radius used as tolerence for XY shifts of the centroid
	// Higher Tolerence = Releaxed - More leniant on oddly-shaped / near-telophase nuclei
	// Lower Toleence = Strict - Less likely to group two nuclei as one nuclei if cells are 'stacked'
	 
	while (step == 3)
	{
		r = 15 * vx;
		en = 0.2;
		Dialog.create("Nuclei Building Parameters");
			Dialog.addNumber("Tolerance Radius (microns)", r);
			Dialog.addNumber("Enlarge Parameter (microns)", en);
		Dialog.show();
		r = Dialog.getNumber / vx;
		en = Dialog.getNumber;

		print("Tolerance Radius (microns): " + r);
		print("Enlarge Parameter (microns): " + en);

		if ((!isNaN(r)) && (r > 0)) step++; // * * *
		else showMessageWithCancel("Pomegranate Error", "Error: Invalid Radius");
	}
	
// [ 4 ] -----------------------------------------------------------------------------------------------------------------------------------------------
	
	// Sluggish algorithm to group ROIs that make up one nuclei - using ROI names with predictable delimiters
	
	roiManager("Deselect");
	roiManager("Set Color", "Black");

	nuclearIndex = 0;
	midList = newArray();
	n = roiManager("Count");
	
	print("\n[Nuclei Building]");
	for (i = 0; i < n; i++)
	{
		showStatus("Pomegranate - Building Nuclei #" + nuclearIndex);
		if (!startsWith(call("ij.plugin.frame.RoiManager.getName", i), 'N'))
		{
			nuclearIndex++;
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

			// Area Screening Defaults
			getStatistics(area);
			Av = area;
			Ai = i;

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
					if (sqrt(pow((ix - jx),2) + pow((iy - jy),2)) <= r)
					{
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
			print("Nuclear Index: " + Roi.getProperty("Nucleus_ID") + "   | Mid-Slice Index: " + Ai + "   | Mid-Slice Area (sq. micron): " + area);
			midList = Array.concat(midList, Ai);
		}
	} 
	
	print("\n[Detection Summary]");
	print("Total Detected ROIs: " + roiManager("Count"));
	print("Total Generated Nuclei: " + nuclearIndex);

	//ROI Export
	roiFile = directoryMain + replace(File.getName(imagePath),'.','_') + "_Nuclear_ROIs.zip";
	if (!File.exists(roiFile)) roiManager("Save", roiFile);
	print("File Created: " + roiFile);

	step++; // * * *
	
// [ 5 ] -----------------------------------------------------------------------------------------------------------------------------------------------

	// Measure Intensity
	showStatus("Pomegranate - Measuring");

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

	showStatus("Pomegranate - Exporting Results");

	print("\n[Exporting Results]");
			
	// Results Export
	resultFile = directoryMain + replace(File.getName(imagePath),'.','_') + "_Results.csv";
	if (!File.exists(resultFile)) saveAs("Results", resultFile);
	print("File Created: " + resultFile);

	//cleanAll();

	print("\n[Run Performance]");
	print("Total Runtime: " + ((getTime() - sTime)/1000) + " seconds");   
	print("Processing Time: " + ((getTime() - sTime)/1000)/nuclearIndex + " seconds per nuclei");  
	 
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
