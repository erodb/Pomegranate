# Pomegranate 
Pomegranate is a nuclear and whole-cell detection, reconstruction, and 3D segmentation tool for static images of fission yeast.

### Table of Contents
* [Publication Links](#publication-links)
* [Documentation](#documentation)
* [Contact Information](#contact-information)
* [Version History](#version-history)

## Publication Links
The associated publication for this software can be found on [bioRxiv](#publication-links).

## Documentation
See the [Documentation](https://github.com/erodb/Pomegranate/tree/master/documentation) folder for all user guides, tutorials and documentation. Included here are a quick start guide to get Pomegranate installed via the Hauf Lab update site. In addition, the Pomegranate User Guide will contain a link to a repository containing samples images. 

## Contact Information
**Development and Maintenance** 
* Erod Keaton Baybay (erodb@vt.edu)

**Co-Authors** 
* Eric Esposito (eeric@vt.edu)
* Silke Hauf (silke@vt.edu)

## Version History
**Version 1.0** 
* Original internal release of Pomegranate

**Version 1.0b** 
* Added drop down menu for various hole filling algorithms (Shape-based, Regular, or None)
* Added an optional manual exclusion phase during whole-cell segmentation's filtering and smoothing

**Version 1.0c** 
* Replaced the equation for nuclear stability score to a simpler algorithm (cohesion radius).
  * The cohesion radius describes the smallest circle that can contain all centroids - centered at the mean position of the centroids. It can also be represented as the largest distance between the mean centroid and any single centroid.

**Version 1.0d** 
* Added 'segmentation only' option - removing the requirement for a channel with intensity images.

**Version 1.1** 
* Complete overhaul of reconstruction method. Reconstruction now compensates for nonuniform radii in cells.

**Version 1.2** 
* Revision to reanalysis pipeline, ROIs are now saved in such a way that manual exclusions can be optionally undone during reanalysis.
* First public release of Pomegranate.
