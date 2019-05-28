macro "Pomegranate View 3D" 
{
	if (selectionType() != -1)
	{
		setBatchMode(true);
		
		imageName = getTitle();
		getSelectionCoordinates(x, y);
		run("Remove Overlay");
		run("From ROI Manager");
		makeSelection("polygon", x, y);

		run("Duplicate...", "title=DUP_" + imageName + " duplicate");
		selectImage("DUP_" + imageName);
		run("Flatten", "stack");
		run("Select None");
		
		run("3D Viewer");
		call("ij3d.ImageJ3DViewer.setCoordinateSystem", "false");
		call("ij3d.ImageJ3DViewer.add", "DUP_" + imageName, "None", "VOL_" + imageName, "1", "true", "true", "true", "1", "0");
		call("ij3d.ImageJ3DViewer.select", "VOL_" + imageName);
		call("ij3d.ImageJ3DViewer.setColor", "235", "220", "160");
		call("ij3d.ImageJ3DViewer.setTransparency", "0.60");

		close("DUP_" + imageName);

		setBatchMode(false);
	}
	else 
	{
		waitForUser("This macro requires a selection");
	}
}