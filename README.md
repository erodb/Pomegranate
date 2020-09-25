# Pomegranate 
Pomegranate is a nuclear and whole-cell detection, reconstruction, and 3D segmentation tool for static images of fission yeast.

### Table of Contents
* [Publication Links](#publication-links)
* [Documentation](#documentation)
* [Contact Information](#contact-information)
* [Version History](#version-history)

## Publication Links
The associated publication for this software can be found on [bioRxiv](https://www.biorxiv.org/content/10.1101/2020.07.07.191932v1).

## Documentation
See the [Documentation](https://github.com/erodb/Pomegranate/tree/master/documentation) folder for all user guides, tutorials and documentation. Included here are a quick start guide to get Pomegranate installed via the Hauf Lab update site, as well as the accompanying Pomegranate User Guide. The Pomegranate User Guide will contain a link to a repository containing samples images and outputs. 

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
* Added 'Segmentation Only' option - removing the requirement for a channel with flourescent microscopy images.

**Version 1.1** 
* Complete overhaul of reconstruction method. Reconstruction now compensates for nonuniform radii in cells.

**Version 1.2** 
* Revision to reanalysis pipeline, ROIs are now saved in such a way that manual exclusions can be optionally undone during reanalysis.
* First public release of Pomegranate.

**Version 1.2a** 
* Minor bug fixes.
* Ability to abort analysis before prerun cleanup.

**Version 1.2b** 
* Minor bug fixes.
* Reformated image input methods, added new image input method: Multiple Single-Channel images for core Pomegranate.
* Renamed the 'Segmentation Only' Run parameter to 'Ignore Measurement Channel' in core Pomegranate.
* Repaired issues with binary image input.

**Version 1.2c** 
* Minor bug fixes.
* Repaired Pomegranate Analysis Extention Tool.

**Version 1.2d** 
* Reformated image input methods, added new image input method: Multiple Single-Channel images for Analysis Revision Tool.
* Renamed the 'Segmentation Only' Run parameter to 'Ignore Measurement Channel' in the Analysis Revision Tool.

**Version 1.2e** 
* Added position and voxel size columns to Pomegranate Analysis Extension Tool.

**Version 1.2f** 
* Made image name format consistent betwen Pomegranate core output, and Pomegranate analysis extension output.
* Sample R code added to R folder.

**Version 1.2g** 
* Fixed a bug that led to erroneous result file outputs for 2D binary whole cell inputs.
* Repaired Pomegranate Analysis Revision Tool to be compatible with these changes.

**Version 1.2h** 
* Pomegranate now allows for binucleated cells in nuclear analyses. These were previously excluded from the analysis.
* A new Nuclear ID column has been added to annotate seperate nucleis in the same cell.
* Fixed a bug where the ROI Manager would be cleared prior to reconstruction.
* Repaired Sample R Code to reflect these changes.
