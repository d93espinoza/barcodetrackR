#' Clonal diversity plot
#'
#' A line plot that tracks a diversity measure from selected samples of the SummarizedExperiment object plotted over a specified variable.
#'
#' @param your_SE Summarized Experiment object containing clonal tracking data as created by the barcodetrackR `create_SE` function.
#' @param group_by The column of metadata you want to group by e.g. cell_type
#' @param group_by_choices Choice(s) from the column designated in group_by that will be used for plotting. Defaults to all if left as NULL.
#' @param plot_over The column of metadata that you want to be the x-axis of the plot. e.g. timepoint
#' @param plot_over_display_choices Choice(s) from the column designated in plot_over that will be used for plotting. Defaults to all if left as NULL.
#' @param keep_numeric If plot_over is numeric, whether to space the x-axis appropriately according to the numerical values.
#' @param index_type Character. One of "shannon", "shannon_count", "simpson", or "invsimpson".
#' @param point_size Numeric. Size of points.
#' @param line_size Numeric. Size of lines.
#' @param text_size Numeric. Size of text in plot.
#' @param your_title Character. The title for the plot.
#' @param return_table Logical. IF set to TRUE, rather than returning the plot of clonal diversity, the function will return a dataframe containing the diversity index values for each specified sample.
#'
#' @return Outputs plot of a diversity measure tracked for groups over a factor. Or if return_table is set to true, a dataframe will be returned instead.
#'
# #'@importFrom diverse diversity
#' @importFrom vegan diversity
#' @importFrom rlang %||%
#' @importFrom magrittr %>%
#' @import tibble
#'
#' @examples
#' data(wu_subset)
#' clonal_diversity(
#'     your_SE = wu_subset, index_type = "shannon",
#'     plot_over = "months", group_by = "celltype"
#' )
#' @export
clonal_diversity <- function(your_SE,
    plot_over,
    plot_over_display_choices = NULL,
    keep_numeric = TRUE,
    group_by,
    group_by_choices = NULL,
    index_type = "shannon",
    point_size = 3,
    line_size = 2,
    text_size = 12,
    your_title = NULL,
    return_table = FALSE) {

    # Some basic error checking before running the function
    coldata_names <- colnames(SummarizedExperiment::colData(your_SE))
    if (!(plot_over %in% coldata_names)) {
        stop("plot_over must match a column name in colData(your_SE)")
    }
    if (!(group_by %in% coldata_names)) {
        stop("group_by must match a column name in colData(your_SE)")
    }
    if (is.numeric(SummarizedExperiment::colData(your_SE)[[plot_over]])) {
        plot_over_display_choices <- plot_over_display_choices %||% sort(unique(SummarizedExperiment::colData(your_SE)[[plot_over]]))
        plot_over_display_choices <- as.numeric(as.character(plot_over_display_choices))
    } else if (is.factor(SummarizedExperiment::colData(your_SE)[[plot_over]])) {
        plot_over_display_choices <- plot_over_display_choices %||% factor(SummarizedExperiment::colData(your_SE)[[plot_over]], levels = levels(SummarizedExperiment::colData(your_SE)[[plot_over]]))
    } else {
        plot_over_display_choices <- plot_over_display_choices %||% factor(SummarizedExperiment::colData(your_SE)[[plot_over]], levels = unique(SummarizedExperiment::colData(your_SE)[[plot_over]]))
    }

    group_by_choices <- group_by_choices %||% levels(as.factor(SummarizedExperiment::colData(your_SE)[[group_by]]))

    # More error handling
    if (!all(plot_over_display_choices %in% levels(as.factor(SummarizedExperiment::colData(your_SE)[[plot_over]])))) {
        stop("All elements of plot_over_display_choices must match values in plot_over column")
    }
    if (!all(group_by_choices %in% levels(as.factor(SummarizedExperiment::colData(your_SE)[[group_by]])))) {
        stop("All elements of group_by_choices must match values in group_by column")
    }

    # extract bc data and metadata
    temp_subset <- your_SE[, (your_SE[[plot_over]] %in% plot_over_display_choices)]
    # Keep only the data included in group_by_choices
    temp_subset <- temp_subset[, (temp_subset[[group_by]] %in% group_by_choices)]
    temp_subset_coldata <- SummarizedExperiment::colData(temp_subset) %>% tibble::as_tibble()
    your_data <- SummarizedExperiment::assays(temp_subset)[["proportions"]]
    your_data <- your_data[rowSums(your_data) > 0, , drop = FALSE]

    # calculate measure for each sample
    if (index_type %in% c("shannon", "simpson", "invsimpson")) {
        calculated_index <- vegan::diversity(your_data, MARGIN = 2, index = index_type) %>%
            tibble::enframe(name = "SAMPLENAME", value = "index") %>%
            dplyr::mutate(index_type = index_type)
    } else if (index_type == "shannon_count") {
        calculated_index <- vegan::diversity(your_data, MARGIN = 2, index = "shannon") %>%
            tibble::enframe(name = "SAMPLENAME", value = "index") %>%
            dplyr::mutate(index_type = index_type)
        calculated_index$index <- exp(calculated_index$index)
    } else {
        stop("index_type must be one of \"shannon\", \"shannon_count\", \"simpson\", or \"invsimpson\"")
    }


    # merge measures with colData
    plotting_data <- temp_subset_coldata %>%
        dplyr::mutate(SAMPLENAME = as.character(.data$SAMPLENAME)) %>%
        dplyr::left_join(calculated_index, by = "SAMPLENAME")


    # Make sure plot over is a factor if not numeric or specified to not keep numeric.
    if (is.numeric(temp_subset_coldata[[plot_over]]) & keep_numeric) {
    } else if (is.numeric(temp_subset_coldata[[plot_over]]) & keep_numeric == FALSE) {
        plotting_data[[plot_over]] <- factor(plotting_data[[plot_over]], levels = unique(plot_over_display_choices))
    } else {
        plotting_data[[plot_over]] <- factor(plotting_data[[plot_over]], levels = levels(plot_over_display_choices))
    }

    if (return_table) {
        return(plotting_data)
    }

    plotting_data$x_value <- plotting_data[[plot_over]]
    plotting_data$group_by <- plotting_data[[group_by]]

    # Create ggplot
    g <- ggplot2::ggplot(plotting_data, ggplot2::aes(x = .data$x_value, y = .data$index, group = .data$group_by, colour = .data$group_by)) +
        ggplot2::geom_line(size = line_size) +
        ggplot2::geom_point(size = point_size) +
        ggplot2::labs(x = plot_over, col = group_by, y = paste0(index_type, ifelse(index_type == "shannon_count", "", " index"))) +
        ggplot2::theme_classic() +
        ggplot2::theme(text = ggplot2::element_text(size = text_size)) +
        ggplot2::ggtitle(your_title)

    if (is.numeric(temp_subset_coldata[[plot_over]]) & keep_numeric) {
        g + ggplot2::scale_x_continuous(paste0(plot_over), breaks = plot_over_display_choices, labels = plot_over_display_choices)
    } else {
        g + ggplot2::scale_x_discrete(paste0(plot_over), breaks = plot_over_display_choices, labels = plot_over_display_choices)
    }
}
