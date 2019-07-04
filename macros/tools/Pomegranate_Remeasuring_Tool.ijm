macro "Pomegranate Remeasure"
{
	close('*');
	roiManager("Reset");
	run("Clear Results");
	run("Set Measurements...", "area mean standard modal min centroid center perimeter median stack display redirect=None decimal=3");
	
	
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
}
