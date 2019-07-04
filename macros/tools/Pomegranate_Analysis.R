library(tidyverse) # install.packages("tidyverse")
library(ggpubr) # install.packages("ggpubr")

voxelSizeZ <- 0.05633 # microns/voxel
dZ_Tolerance <- 10 # Number of slices away from midplane to use for analysis

# Filtering Unpaired Data
data.Combined <- read.csv(file.choose(), header = TRUE) %>%
  mutate(Integrated_Density = Mean * Area,
         Object_ID = as.character(Object_ID)) %>%
  group_by(Object_ID) %>%
  filter(length(unique(Data_Type)) == 2)

# Calculate Distance from MidSlice
data.Mid <- filter(data.Combined[,c("Object_ID","Data_Type","ROI_Type","Slice")], 
                   ROI_Type == "MID")[,c("Object_ID","Data_Type","Slice")] %>% 
  rename(Mid_Slice = Slice)
data.Combined <- merge(data.Combined, data.Mid) %>% 
  mutate(dZ_Slice = Mid_Slice - Slice)

# Restrict to Measurement Window
data.Combined <- filter(data.Combined, abs(dZ_Slice) <= dZ_Tolerance)

data.Summary <- data.Combined %>%
  group_by(Object_ID, Data_Type) %>%
  summarise(Volume_microns3 = sum(Area * voxelSizeZ),
            Vol_Integrated_Density = sum(Integrated_Density),
            Intensity_per_Vol = sum(Integrated_Density)/Volume_microns3)

plot.A <- ggplot(data = data.Summary) +
        geom_point(aes(x = Vol_Integrated_Density, 
                       y = Volume_microns3, 
                       color = Data_Type)) +
        labs(x = "Integrated Density (a.u.)", 
             y = "Volume (cubic microns)",
             color = "Class") +
        scale_color_manual(values = c("red", "black")) +
        theme_bw()

plot.B <- ggplot(data = data.Summary) +
        geom_point(aes(x = Data_Type, y = Intensity_per_Vol),
                   size = 2) +
        geom_line(aes(x = Data_Type, y = Intensity_per_Vol, group = Object_ID),
                  alpha = 0.2) +
        labs(x = "Region", 
             y = "Mean Intensity per Voxel (a.u.)") +
        theme_bw()

# Volume Histogram
plot.C <- ggplot() +
        geom_histogram(data = filter(data.Summary, Data_Type == "Whole_Cell"),
                       aes(x = Volume_microns3, y = ..count.., fill = "Whole Cell"),
                       alpha = 0.5,
                       color = "black",
                       bins = 50) +
        geom_histogram(data = filter(data.Summary, Data_Type == "Nucleus"),
                       aes(x = Volume_microns3, y = ..count.., fill = "Nucleus"),
                       alpha = 0.5,
                       color = "black",
                       bins = 50) +
        labs(x = "Volume (cubic microns)", 
             y = "Count",
             fill = "Class") +
        scale_fill_manual(values = c("red", "black")) +
        theme_bw()

# Intensity Histogram
plot.D <- ggplot() +
        geom_histogram(data = filter(data.Summary, Data_Type == "Whole_Cell"),
                       aes(x = Intensity_per_Vol, y = ..count.., fill = "Whole Cell"),
                       alpha = 0.5,
                       color = "black",
                       bins = 50) +
        geom_histogram(data = filter(data.Summary, Data_Type == "Nucleus"),
                       aes(x = Intensity_per_Vol, y = ..count.., fill = "Nucleus"),
                       alpha = 0.5,
                       color = "black",
                       bins = 50) +
        labs(x = "Mean Intensity per Voxel (a.u.)", 
             y = "Count",
             fill = "Class") +
        scale_fill_manual(values = c("red", "black")) +
        theme_bw()

ggarrange(plot.A, plot.B, ncol = 2)
ggarrange(plot.C, plot.D, ncol = 2)
