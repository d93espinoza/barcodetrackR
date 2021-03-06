% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/barcode_binary_heatmap.R
\name{barcode_binary_heatmap}
\alias{barcode_binary_heatmap}
\title{Barcode Binary Heatmap}
\usage{
barcode_binary_heatmap(
  your_SE,
  plot_labels = NULL,
  threshold = 0,
  your_title = NULL,
  label_size = 12,
  return_table = FALSE
)
}
\arguments{
\item{your_SE}{A Summarized Experiment object.}

\item{plot_labels}{Vector of x axis labels. Defaults to colnames(your_SE).}

\item{threshold}{Clones with a proportion below this threshold will be set to 0.}

\item{your_title}{The title for the plot.}

\item{label_size}{The size of the column labels.}

\item{return_table}{Logical. Whether or not to return table of barcode sequences with their presence or absence in each sample indicated as a 1 or 0 resepctively in the value column column.}
}
\value{
Displays a binary heat map in the current plot window. Or if return_table is set to TRUE, returns a dataframe indicating the presence or absence of each barcode in each sample.
}
\description{
Creates a binary heatmap showing the absence or presence of new clones in samples ordered from L to R in the SummarizedExperiment.
}
\examples{
data(wu_subset)
barcode_binary_heatmap(your_SE = wu_subset[, 1:4])
}
