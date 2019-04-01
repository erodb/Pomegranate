macro "Pomegranate 1.0"
{
	base = getTitle();
	showStatus("");
	setBatchMode(true); 
	run("Duplicate...", "title=DUP duplicate");
	setSlice(round(nSlices/2));

	// Otsu Thresholding
	setAutoThreshold("Otsu dark stack");
	run("Convert to Mask", "method=Otsu background=Dark black");

	// Smoothing
	run("Gaussian Blur...", "sigma=0.3 scaled stack");
	run("Make Binary", "method=Otsu background=Dark black");

	run("Analyze Particles...", "clear add stack");
	selectImage(base);
	close("DUP");
	setBatchMode(false); 
	roiManager("Show All Without Labels");
}
