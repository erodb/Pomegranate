# Pomegranate 
A segmentation and reconstruction pipeline that uses a combination of bright-field images, fluorescent markers, and the known morphological characteristics of fission yeast to produce a volumetric fit of a cell’s whole cell and nuclear geometry.

### Table of Contents
* [Publication Links](#publication-links)
* [Documentation](#documentation)
* [Contact Information](#contact-information)
* [Version History](#version-history)

## Publication Links
The associated publication for this software can be found on [PLOS One](#publication-links) and [bioRxiv](#publication-links).

## Documentation
See XXX for all user guides, tutorials and documentation. Included here will be a quick start guide with sample images.

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
