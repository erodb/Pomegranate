macro "Pomegranate 1.0"
{
	cleanAll();
	versionFIJI = "1.52n";
	versionPIPELINE = "1.0";
	
	step = 0; // Progress Ticker
	requires(versionFIJI);
	print("Required FIJI Version: " + versionFIJI);
	print("Currently Running FIJI Version: " + getVersion);
	run("Set Measurements...", "area mean standard modal min centroid center perimeter median stack display redirect=None decimal=3");
	
// [ 0 ] -----------------------------------------------------------------------------------------------------------------------------------------------
	showStatus("Pomegranate - Opening Images");

	// Designate Input Image
	while (step == 0)
	{
		Dialog.create("Input Image");
			Dialog.addChoice("Input Method", newArray("Select Image from Directory","Manually Enter Path"));
		Dialog.show();
		
		if (Dialog.getChoice() == "Select Image from Directory") imagePath = File.openDialog("Choose an Input  File"); 
		else imagePath = getString("Image Path", "/Users/hauflab/Documents");
		
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
			Dialog.addChoice("Measurement Channel", channelList);
			Dialog.addChoice("Nuclear Marker Channel", channelList);
			Dialog.addChoice("Bright-Field Channel", channelList);
		Dialog.show();	
		msChannel = parseInt(Dialog.getChoice()); // Measurement Channel
		nmChannel = parseInt(Dialog.getChoice()); // Nuclear Marker Channel
		bfChannel = parseInt(Dialog.getChoice()); // Bright-Field Channel
		
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
	run("Analyze Particles...", "clear add stack");
	selectImage(nmChannel);
	close("DUP");
	roiManager("Show All Without Labels");
	setBatchMode(false);

	step++; // * * *

// [ 3 ] -----------------------------------------------------------------------------------------------------------------------------------------------
	while (step == 3)
	{
		r = 15 * vx;
		Dialog.create("Nuclei Building Parameters");
			Dialog.addNumber("Tolerance Radius", r);
		Dialog.show();
		r = Dialog.getNumber / vx;

		if ((!isNaN(r)) && (r > 0)) step++; // * * *
		else showMessageWithCancel("Pomegranate Error", "Error: Invalid Radius");
	}
	
// [ 4 ] -----------------------------------------------------------------------------------------------------------------------------------------------
	roiManager("Deselect");
	roiManager("Set Color", "Black");
	
	nuclearIndex = 1;
	n = roiManager("Count");
	for (i = 0; i < n; i++)
	{
		showStatus("Pomegranate - Building Nuclei #" + nuclearIndex);
		if (!startsWith(call("ij.plugin.frame.RoiManager.getName", i), 'N'))
		{
			currentColor = randomHexColor();
			
			roiManager("Select",i);
			nuclearName = "N" + nuclearIndex + "-" + i  + "-" + getSliceNumber();
			roiManager("Rename", nuclearName);
			roiManager("Set Color", currentColor);

			// Establish First Reference Point
			getSelectionBounds(px, py, pw, ph);
			ix = px + round(pw/2);
			iy = py + round(ph/2);
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

					if (sqrt(pow((ix - jx),2) + pow((iy - jy),2)) <= r)
					{
						nuclearName = "N" + nuclearIndex + "-" + j  + "-" + getSliceNumber();
						roiManager("Rename", nuclearName);
						roiManager("Set Color", currentColor);

						// Update Reference Point
						ix = jx;
						iy = jy;
					}
				}
			}
			nuclearIndex++;
		}
	} 

	roiManager("Sort");
	step++; // * * *
// [ 5 ] -----------------------------------------------------------------------------------------------------------------------------------------------
	 
	showStatus("Pomegranate - Measuring");

	selectImage(msChannel);
	roiManager("Deselect");
	roiManager("Show All Without Labels");
	roiManager("Measure");

	waitForUser("Done", "Macro is complete.");
}
// -----------------------------------------------------------------------------------------------------------------------------------------------

// Clean Up Function
function cleanAll()
{
	close('*')
	run("Clear Results");
	roiManager("Reset");
	print("\\Clear");
}

// Array Contains Function
function acontains(arr,val) 
{ 
	ping = false;
	for (i = 0; i < arr.length; i++)
	{
		if (val == arr[i]) ping = true;
	}
	return ping;
} 

// Return a Random Color in Hex
function randomHexColor()
{
	hex = newArray();
	char = newArray('1','2','3','4','5','6','7','8','9','0','A','B','C','D','E','F');
	output = '#' + char[round((char.length - 1) * random)] + char[round((char.length - 1) * random)] + char[round((char.length - 1) * random)] + char[round((char.length - 1) * random)] + char[round((char.length - 1) * random)] + char[round((char.length - 1) * random)];
	return output;
}
