macro "Pomegranate Batch Re-Measure"
{
	close('*');
	roiManager("Reset");
	run("Clear Results");
	run("Set Measurements...", "area mean standard modal min centroid center perimeter median stack display redirect=None decimal=3");
	
	waitForUser("Please Select an output Directory");
	output = getDirectory("Choose Output Directory");

	loop = true;
	while(loop)
	{
		close('*');
		roiManager("Reset");
		run("Clear Results");
		
		// Open Image
		waitForUser("Please Select an Input Image");
		imagePath = File.openDialog("Choose an Input File"); 
	
		setBatchMode(true);
		run("Bio-Formats Importer", "open=" + imagePath + " autoscale color_mode=Composite view=Hyperstack stack_order=XYCZT");
		getDimensions(width, height, channels, slices, frames);
		getVoxelSize(vx, vy, vz, unit);
		channelList = newArray(channels);
		for (i = 1; i <= channels; i++) channelList[i-1] = "" + i;
	
		// Designate Channel
		Dialog.create("Channel Selection");
			Dialog.addChoice("Measurement Channel", channelList);
		Dialog.show();	
		msN = parseInt(Dialog.getChoice());

		// Deconvolution Crop
		Dialog.create("Deconvolution Crop");
			Dialog.addNumber("Width", 960);
			Dialog.addNumber("Height", 960);
		Dialog.show();	

		trimx = width - Dialog.getNumber();
		trimy = height - Dialog.getNumber();

		makeRectangle(trimx/2, trimy/2, width - trimx, height - trimy);
		run("Crop");
	
		// Isolate Channel
		imageName = getTitle();
		run("Split Channels");	
		msChannel = "C"+msN+"-"+imageName;
		selectImage(msChannel);
		close("\\Others");
		setBatchMode(false);

		setSlice(round(nSlices/2));

		// ROI Loading
		waitForUser("Please Select ROI File");
		roi = File.openDialog("Choose an Input File"); 
		roiManager("Open", roi);
		roiManager("Measure");
		roiManager("Show All Without Labels");
		
		// Results Export
		resultFile = output + replace(File.getName(imagePath),'.','_') + "_Results.csv";
		if (!File.exists(resultFile)) saveAs("Results", resultFile);

		loop = getBoolean("Process Another Image?");
	}
}
