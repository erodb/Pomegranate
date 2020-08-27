library(tidyverse) # install.packages("tidyverse")
library(ggpubr) # install.packages("ggpubr")
library(MASS) # install.packages("MASS")
library(gridExtra) # install.packages("gridExtra")
library(ggcorrplot) # install.packages("ggcorrplot")

`%notin%` <- Negate(`%in%`)

# Set this working directory as the directory that is holding multiple Pomegranate outputs
# or as the directory of a single Pomegranate Output
setwd("C:/Users/Erod/Desktop/Pomegranate/Septating_Nuclei_Repair") 
exclusionList <- c("") # Put Object_IDs of cells you wish to exclude here

# [0] Functions ------------------------------------------------------------------------------------------------------------

rodVolume <- function(r,l){((l - (2*r))*pi*(r^2)) + ((4/3)*pi*(r^3))}
ellipsoidVolume <- function(minor, major){(4/3)*pi*(minor^2)*major}
rodSurfaceArea <- function(r,l){(4*pi*(r^2)) + ((2*pi*r) * l)}
ellipsoidSurfaceArea <- function(minor, major){4*pi*(((((minor*minor)^1.6075)+((major*minor)^1.6075)+((major*minor)^1.6075))/3)^(1/1.6075))} # Knud Thomsen's formula

# [1] Import Data ------------------------------------------------------------------------------------------------------------
# This requires an output from Core Pomegranate
# Importing CSVs (May take some time, depending on the size of the dataset)
data.Full.Original <- list.files(pattern = "\\_Full.csv", recursive = TRUE) %>% # --- From base POMEGRANATE analysis
  lapply(read.csv, header = TRUE) %>%
  do.call(rbind, .)

# This requires an output from the Analysis Extension Tool
# Importing CSVs (May take some time, depending on the size of the dataset)
data.Widths.Original<- list.files(pattern = "\\_Width_Profile.csv", recursive = TRUE) %>% # --- From POMEGRANATE analysis extension
  lapply(read.csv, header = TRUE) %>%
  do.call(rbind, .)

# GET EQUATION AND R-SQUARED AS STRING
# SOURCE: https://groups.google.com/forum/#!topic/ggplot2/1TgH-kG5XMA
ggRegPlot <- function(data, xparam, yparam){
  model <- lm(yparam ~ xparam, data)
  annotations.lm <- as.character(c("Intercept: ",
                                   format(unname(coef(model)[1]), digits = 2),
                                   " - Slope: ", 
                                   format(unname(coef(model)[2]), digits = 2),
                                   " - R2: ",
                                   format(summary(model)$r.squared, digits = 3)))
  ggplot(data) +
    geom_point(aes(x = xparam, y = yparam), size = 0.5) +
    ggtitle(paste0(annotations.lm, collapse = "")) +
    geom_abline(intercept = as.numeric(annotations.lm[2]),
                slope = as.numeric(annotations.lm[4]),
                color = "red") +
    scale_x_continuous(expand = c(0,0)) +
    scale_y_continuous(expand = c(0,0)) +
    theme_classic()
}

# [2] Process and Summarise Full Data ------------------------------------------------------------------------------------------------------------
data.Full.Combined <- data.Full.Original %>%
  mutate(Integrated_Density = Mean * Area,
         Image = as.character(Image),
         Experiment = as.character(Experiment),
         Data_Type = as.character(Data_Type),
         Object_ID = as.character(Object_ID)) %>%
  group_by(Object_ID)

# Calculate distance from midSlice
data.Full.Mid <- data.Full.Combined %>% 
  group_by(Object_ID, Data_Type, Image, Nuclear_ID) %>%
  mutate(Width_Z = n() * voxelSize_Z) %>%
  filter(ROI_Type == "MID") %>% 
  transmute(Slice,Area,Feret,MinFeret,Minor,Major,Width_Z) %>%
  rename(Mid_Slice = Slice,
         Mid_Area = Area,
         Length_Feret = Feret,
         Width_Feret = MinFeret,
         Major_Ellipsoid = Major,
         Minor_Ellipsoid = Minor) %>%
  mutate(Width_XY = Width_Feret,
         Width_Z = Width_Z,
         Aspect_Ratio = Width_Z/Width_XY)

data.Full.Combined <- merge(data.Full.Combined, data.Full.Mid) %>% 
  mutate(dZSlice = Mid_Slice - Slice)

# Summarise Full Data
data.Full.Summary <- data.Full.Combined %>%
  group_by(Object_ID, Data_Type, Image, Experiment, Nuclear_ID) %>%
  summarise(Volume_microns3 = sum(Area * voxelSize_Z),
            Mid_Cross_Area = mean(Mid_Area),
            SurfaceArea_microns2 = 2*Mid_Cross_Area + sum(Perim. * voxelSize_Z),
            Vol_Integrated_Density = sum(na.omit(Integrated_Density)),
            Intensity_per_Vol = Vol_Integrated_Density/Volume_microns3,
            Aspect_Ratio = unique(Aspect_Ratio))

# Paired Nuclei
data.Full.Summary.Paired <- data.Full.Summary %>%
  group_by(Object_ID, Image) %>% mutate(N = n()) %>%
  filter(N != 1,
         Object_ID %notin% exclusionList,
         Aspect_Ratio < 1.2,
         Aspect_Ratio > 0.8) %>%
  arrange(Data_Type) %>%
  mutate(Volume_Ratio = lag(Volume_microns3)/Volume_microns3)

data.Full.Approximation <- data.Full.Mid %>%
  mutate(Volume_Feret = ifelse(Data_Type == "Whole_Cell",
                               rodVolume(Width_Feret/2, Length_Feret),
                               ellipsoidVolume(Width_Feret/2, Length_Feret/2)),
         Volume_Ellipsoid = ifelse(Data_Type == "Whole_Cell",
                                   rodVolume(Minor_Ellipsoid/2, Major_Ellipsoid),
                                   ellipsoidVolume(Minor_Ellipsoid/2, Major_Ellipsoid/2)),
         SurfaceArea_Feret = ifelse(Data_Type == "Whole_Cell",
                                    rodSurfaceArea(Width_Feret/2, Length_Feret),
                                    ellipsoidSurfaceArea(Width_Feret/2, Length_Feret/2)),
         SurfaceArea_Ellipsoid = ifelse(Data_Type == "Whole_Cell",
                                        rodSurfaceArea(Minor_Ellipsoid/2, Major_Ellipsoid),
                                        ellipsoidSurfaceArea(Minor_Ellipsoid/2, Major_Ellipsoid/2)))

data.Full.Approximation.Paired <- data.Full.Approximation %>%
  group_by(Image, Object_ID) %>%
  filter(length(unique(Data_Type)) != 1,
         Object_ID %notin% exclusionList) %>%
  mutate(refSlope = ifelse(Data_Type == "Nucleus",1, NA),
         refIntercept = ifelse(Data_Type == "Nucleus",0, NA))

# [3] Process and Summarise Width Data ------------------------------------------------------------------------------------------------------------
data.Widths.Filtered <- data.Widths.Original %>%
  mutate(Radius = Radius * voxelSize_X, 
         Diameter = 2 * Radius) 

data.Widths.Summary <- data.Widths.Filtered %>%
  group_by(Image, Object_ID) %>% 
  summarise(SD_Width = sd(Diameter),
            Mean_Width = mean(Diameter),
            CV_Width = SD_Width/Mean_Width) %>%
  group_by(Image) %>%
  mutate(Image_Density = n(),
         Image_Mean_Width = mean(Mean_Width))

data.Widths.Tips <- data.Widths.Filtered %>%
  filter(Type == "Tip") %>%
  group_by(Image, Object_ID) %>% 
  filter(n() == 2) %>%
  summarise(Smaller_Tip_Radius = min(Radius),
            Larger_Tip_Radius = max(Radius),
            Tip_Delta = max(Radius) - min(Radius),
            Tip_Ratio = min(Radius)/max(Radius))

# [4] Merge Key Datasets ------------------------------------------------------------------------------------------------------------------
data.Merged <- merge(data.Full.Summary.Paired, data.Full.Approximation.Paired, by = c("Image","Object_ID","Data_Type")) %>%
  merge(data.Widths.Summary, by = c("Image","Object_ID")) %>%
  merge(data.Widths.Tips, by = c("Image","Object_ID"))

data.Merged <- data.Merged %>%
  filter(Object_ID %notin% exclusionList)

data.Merged.Prep <- data.Merged %>%
  filter(Data_Type == "Whole_Cell") %>%
  dplyr::select(Volume_microns3, SurfaceArea_microns2, Length_Feret, Major_Ellipsoid, Width_Feret, Minor_Ellipsoid, Mean_Width, Image_Density)

data.Merged.Corr <- data.Merged.Prep %>%
  cor() %>%
  round(2)

data.Merged.Corr.Pmat <- data.Merged.Prep %>% 
  cor_pmat()

# [5] Correlation Plots ------------------------------------------------------------------------------------------------------------------
ggcorrplot(data.Merged.Corr,
           outline.col = "white",
           ggtheme = ggplot2::theme_classic,
           lab = TRUE,
           colors = c("#440154FF", "white", "#FFCC00"),
           p.mat = data.Merged.Corr.Pmat)
# [6] Volume and Surface Area Plots ------------------------------------------------------------------------------------------------------------------

# Freedman-Diaconis Binwidth Calculation
fdbw.v.wc <- 2 * IQR(filter(data.Full.Summary.Paired, Data_Type == "Whole_Cell")$Volume_microns3) / length(filter(data.Full.Summary.Paired, Data_Type == "Whole_Cell")$Volume_microns3)^(1/3)
fdbw.v.n <- 2 * IQR(filter(data.Full.Summary.Paired, Data_Type == "Nucleus")$Volume_microns3) / length(filter(data.Full.Summary.Paired, Data_Type == "Nucleus")$Volume_microns3)^(1/3)
fdbw.sa.wc <- 2 * IQR(filter(data.Full.Summary.Paired, Data_Type == "Whole_Cell")$SurfaceArea_microns2) / length(filter(data.Full.Summary.Paired, Data_Type == "Whole_Cell")$SurfaceArea_microns2)^(1/3)
fdbw.sa.n <- 2 * IQR(filter(data.Full.Summary.Paired, Data_Type == "Nucleus")$SurfaceArea_microns2) / length(filter(data.Full.Summary.Paired, Data_Type == "Nucleus")$SurfaceArea_microns2)^(1/3)

data.Full.Approximation.Stats <- data.Full.Approximation.Paired %>%
  group_by(Data_Type) %>%
  summarise(mean_Volume_Ellipsoid = mean(Volume_Ellipsoid), 
            median_Volume_Ellipsoid = median(Volume_Ellipsoid), 
            sd_Volume_Ellipsoid = sd(Volume_Ellipsoid), 
            mean_Volume_Feret = mean(Volume_Feret), 
            median_Volume_Feret = median(Volume_Feret), 
            sd_Volume_Feret = sd(Volume_Feret), 
            mean_SurfaceArea_Ellipsoid = mean(SurfaceArea_Ellipsoid), 
            median_SurfaceArea_Ellipsoid = median(SurfaceArea_Ellipsoid),
            sd_SurfaceArea_Ellipsoid = sd(SurfaceArea_Ellipsoid),
            mean_SurfaceArea_Feret = mean(SurfaceArea_Feret), 
            median_SurfaceArea_Feret = median(SurfaceArea_Feret),
            sd_SurfaceArea_Feret = sd(SurfaceArea_Feret),
            Count = n())

data.Full.Summary.Stats <- data.Full.Summary.Paired %>%
  group_by(Data_Type) %>%
  summarise(mean_Volume_Reconstruction = mean(Volume_microns3), 
            median_Volume_Reconstruction = median(Volume_microns3), 
            sd_Volume_Reconstruction = sd(Volume_microns3),
            mean_SurfaceArea_Reconstruction = mean(SurfaceArea_microns2), 
            median_SurfaceArea_Reconstruction = median(SurfaceArea_microns2),
            sd_SurfaceArea_Reconstruction = sd(SurfaceArea_microns2))

data.Full.Stats <- merge(data.Full.Approximation.Stats, data.Full.Summary.Stats)

# WHOLECELL Volume
plot.Volume.Feret.WC <- ggplot(filter(data.Full.Approximation.Paired,
                                      Data_Type == "Whole_Cell"))  +
  geom_histogram(aes(x = Volume_Feret, y = stat(count)), 
                 fill = "blue", 
                 color = "black",
                 alpha = 0.3, 
                 binwidth = fdbw.v.wc) +
  labs(x = "Feret Min-Max Approximate Whole-Cell Volume", y = "Count") +
  scale_x_continuous(limits = c(10,250)) +
  theme_classic() +
  theme(strip.background = element_blank())

# WHOLECELL Volume
plot.Volume.Ellipsoid.WC <- ggplot(filter(data.Full.Approximation.Paired,
                                          Data_Type == "Whole_Cell"))  +
  geom_histogram(aes(x = Volume_Ellipsoid, y = stat(count)), 
                 fill = "red", 
                 color = "black",
                 alpha = 0.3, 
                 binwidth = fdbw.v.wc) +
  labs(x = "Ellipsoid Minor-Major Approximate Whole-Cell Volume", y = "Count") +
  scale_x_continuous(limits = c(10,250)) +
  theme_classic() +
  theme(strip.background = element_blank())

# WHOLECELL Volume
plot.Volume.Reconstruction.WC <- ggplot(filter(data.Full.Summary.Paired,
                                               Data_Type == "Whole_Cell"))  +
  geom_histogram(aes(x = Volume_microns3, y = stat(count)), 
                 fill = "green", 
                 color = "black",
                 alpha = 0.3, 
                 binwidth = fdbw.v.wc) +
  labs(x = "Reconstruction Whole-Cell Volume", y = "Count") +
  scale_x_continuous(limits = c(10,250)) +
  theme_classic() +
  theme(strip.background = element_blank())

# WHOLECELL Volume Combined
ggarrange(plot.Volume.Feret.WC, plot.Volume.Ellipsoid.WC, plot.Volume.Reconstruction.WC,
          nrow = 3, ncol= 1)


# ---

# NUCLEAR Volume
plot.Volume.Feret.N <- ggplot(filter(data.Full.Approximation.Paired,
                                     Data_Type == "Nucleus"))  +
  geom_histogram(aes(x = Volume_Feret, y = stat(count)), 
                 fill = "blue", 
                 color = "black",
                 alpha = 0.3, 
                 binwidth = fdbw.v.n) +
  labs(x = "Feret Min-Max Approximate Nuclear Volume", y = "Count") +
  scale_x_continuous(limits = c(0,20)) +
  theme_classic() +
  theme(strip.background = element_blank())

# NUCLEAR Volume
plot.Volume.Ellipsoid.N <- ggplot(filter(data.Full.Approximation.Paired,
                                         Data_Type == "Nucleus"))  +
  geom_histogram(aes(x = Volume_Ellipsoid, y = stat(count)), 
                 fill = "red", 
                 color = "black",
                 alpha = 0.3, 
                 binwidth = fdbw.v.n) +
  labs(x = "Ellipsoid Minor-Major Approximate Nuclear Volume", y = "Count") +
  scale_x_continuous(limits = c(0,20)) +
  theme_classic() +
  theme(strip.background = element_blank())

# NUCLEAR Volume
plot.Volume.Reconstruction.N <- ggplot(filter(data.Full.Summary.Paired,
                                              Data_Type == "Nucleus"))  +
  geom_histogram(aes(x = Volume_microns3, y = stat(count)), 
                 fill = "green", 
                 color = "black",
                 alpha = 0.3, 
                 binwidth = fdbw.v.n) +
  labs(x = "Reconstruction Nuclear Volume", y = "Count") +
  scale_x_continuous(limits = c(0,20)) +
  theme_classic() +
  theme(strip.background = element_blank())

# NUCLEAR Volume Combined
ggarrange(plot.Volume.Feret.N, plot.Volume.Ellipsoid.N, plot.Volume.Reconstruction.N,
          nrow = 3, ncol= 1)

# ---

# WHOLECELL Surface Area
plot.SurfaceArea.Feret.WC <- ggplot(filter(data.Full.Approximation.Paired,
                                           Data_Type == "Whole_Cell"))  +
  geom_histogram(aes(x = SurfaceArea_Feret, y = stat(count)), 
                 fill = "blue", 
                 color = "black",
                 alpha = 0.3, 
                 binwidth = fdbw.sa.wc) +
  labs(x = "Feret Min-Max Approximate Whole-Cell Surface Area", y = "Count") +
  scale_x_continuous(limits = c(50,250)) +
  theme_classic() +
  theme(strip.background = element_blank())

# WHOLECELL Surface Area
plot.SurfaceArea.Ellipsoid.WC <- ggplot(filter(data.Full.Approximation.Paired,
                                               Data_Type == "Whole_Cell"))  +
  geom_histogram(aes(x = SurfaceArea_Ellipsoid, y = stat(count)), 
                 fill = "red", 
                 color = "black",
                 alpha = 0.3, 
                 binwidth = fdbw.sa.wc) +
  labs(x = "Ellipsoid Minor-Major Approximate Whole-Cell Surface Area", y = "Count") +
  scale_x_continuous(limits = c(50,250)) +
  theme_classic() +
  theme(strip.background = element_blank())

# WHOLECELL Surface Area
plot.SurfaceArea.Reconstruction.WC <- ggplot(filter(data.Full.Summary.Paired,
                                                    Data_Type == "Whole_Cell"))  +
  geom_histogram(aes(x = SurfaceArea_microns2, y = stat(count)), 
                 fill = "green", 
                 color = "black",
                 alpha = 0.3, 
                 binwidth = fdbw.sa.wc) +
  labs(x = "Reconstruction Whole-Cell Surface Area", y = "Count") +
  scale_x_continuous(limits = c(50,250)) +
  theme_classic() +
  theme(strip.background = element_blank())

# WHOLECELL Surface Area Combined
ggarrange(plot.SurfaceArea.Feret.WC, plot.SurfaceArea.Ellipsoid.WC, plot.SurfaceArea.Reconstruction.WC,
          nrow = 3, ncol= 1)

# ---

# NUCLEAR Surface Area 
plot.SurfaceArea.Feret.N <- ggplot(filter(data.Full.Approximation.Paired,
                                          Data_Type == "Nucleus"))  +
  geom_histogram(aes(x = SurfaceArea_Feret, y = stat(count)), 
                 fill = "blue", 
                 color = "black",
                 alpha = 0.3, 
                 binwidth = fdbw.sa.n) +
  labs(x = "Feret Min-Max Approximate Nuclear Surface Area", y = "Count") +
  scale_x_continuous(limits = c(0,50)) +
  theme_classic() +
  theme(strip.background = element_blank())

# NUCLEAR Surface Area
plot.SurfaceArea.Ellipsoid.N <- ggplot(filter(data.Full.Approximation.Paired,
                                              Data_Type == "Nucleus"))  +
  geom_histogram(aes(x = SurfaceArea_Ellipsoid, y = stat(count)), 
                 fill = "red", 
                 color = "black",
                 alpha = 0.3, 
                 binwidth = fdbw.sa.n) +
  labs(x = "Ellipsoid Minor-Major Approximate Nuclear Surface Area", y = "Count") +
  scale_x_continuous(limits = c(0,50)) +
  theme_classic() +
  theme(strip.background = element_blank())

# NUCLEAR Surface Area
plot.SurfaceArea.Reconstruction.N <- ggplot(filter(data.Full.Summary.Paired,
                                                   Data_Type == "Nucleus"))  +
  geom_histogram(aes(x = SurfaceArea_microns2, y = stat(count)), 
                 fill = "green", 
                 color = "black",
                 alpha = 0.3, 
                 binwidth = fdbw.sa.n) +
  labs(x = "Reconstruction Nuclear Surface Area", y = "Count") +
  scale_x_continuous(limits = c(0,50)) +
  theme_classic() +
  theme(strip.background = element_blank())

# NUCLEAR Surface Area Combined
ggarrange(plot.SurfaceArea.Feret.N, plot.SurfaceArea.Ellipsoid.N, plot.SurfaceArea.Reconstruction.N,
          nrow = 3, ncol= 1)


# [6] Intensity of Target Signal Plots ------------------------------------------------------------------------------------------------------------------
plot.Signal.WC <- ggRegPlot(filter(data.Full.Summary.Paired, Data_Type == "Whole_Cell"), 
                            xparam = filter(data.Full.Summary.Paired, Data_Type == "Whole_Cell")$Volume_microns3, 
                            yparam = filter(data.Full.Summary.Paired, Data_Type == "Whole_Cell")$Intensity_per_Vol) + 
  labs(x = bquote("Cell Volume"~("µm"^3)), y = "Signal Concentration (a.u.)")

plot.Signal.N <- ggRegPlot(filter(data.Full.Summary.Paired, Data_Type == "Nucleus"), 
                           xparam = filter(data.Full.Summary.Paired, Data_Type == "Nucleus")$Volume_microns3, 
                           yparam = filter(data.Full.Summary.Paired, Data_Type == "Nucleus")$Intensity_per_Vol) + 
  labs(x = bquote("Nuclear Volume"~("µm"^3)), y = "Signal Concentration (a.u.)")

ggarrange(plot.Signal.N, plot.Signal.WC,
          ncol = 2, nrow = 1)