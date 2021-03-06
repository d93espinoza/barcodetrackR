#' Rank Abundance Statistical Test
#'
#' Carries out a specific instance of statistical testing relevant to clonal tracking experiments. For the provided SummarizedExperiment,
#' compare the rank-abundance distribution which is described by the increase in cumulative abundance within that sample as barcode abundances are added, starting with the most abundant barcode.
#' The two-sided Kolmogorov-Smirnov statistical test is carried out comparing each pair of samples using the R function ks.test:https://www.rdocumentation.org/packages/dgof/versions/1.2/topics/ks.test
#' Note that this test compares rank-abundance distribution regardless of whether the samples share the same barcodes or lineage tracing elements. The test could be employed on two samples with no barcode sequence overlap, simply to compare whether the rank abundance distribution of barcodes is drawn from the same distribution.
#'
#'
#' @param your_SE  Summarized Experiment object containing clonal tracking data as created by the barcodetrackR `create_SE` function.
#' @param statistical_test The statistical test used to compare distributions. For now, the only implemented test is the Kolmogorov-Smirnov test.
#' @return Returns a list containing two dataframes \cr [["D_statistic"]] is a dataframe containing pairwise D-statistics between each pair of samples in your_SE. The D statistic represents the maximal difference between the two rank abundance distributions. \cr [["p_value]] A dataframe containing the p-value computed by the KS test for each pair of samples. The null hypothesis is that the two rank-abundance profiles come from the same distribution.
#'
#'
#' @importFrom magrittr %>%
#'
#' @export
#'
#' @examples
#' data(wu_subset)
#' rank_abundance_stat_test(your_SE = wu_subset, statistical_test = "ks")
rank_abundance_stat_test <- function(your_SE,
    statistical_test = "ks") {


    # error checking
    if (statistical_test != "ks") {
        stop("statistical_test must be set to 'ks' since that is the only option for now.")
    }

    your_data <- SummarizedExperiment::assays(your_SE)[["proportions"]]

    # Initialize data frames
    D_stat_DF <- data.frame(matrix(
        ncol = ncol(your_data), nrow = ncol(your_data),
        dimnames = list(colnames(your_data), colnames(your_data))
    ))

    p_val_DF <- data.frame(matrix(
        ncol = ncol(your_data), nrow = ncol(your_data),
        dimnames = list(colnames(your_data), colnames(your_data))
    ))

    # Get rank_abundance_data
    lapply(seq_len(ncol(your_data)), function(i) {
        tibble::tibble(sample_name = colnames(your_data)[i], percentage = your_data[, i]) %>%
            dplyr::filter(.data$percentage > 0) %>%
            dplyr::arrange(desc(.data$percentage)) %>%
            dplyr::mutate(cumulative_sum = cumsum(.data$percentage), rank = dplyr::row_number()) %>%
            dplyr::mutate(scaled_rank = dplyr::percent_rank(-.data$percentage))
    }) -> my_data_list

    # Compare each pairwise rank abundance profile
    for (i in seq_along(my_data_list)) { # column index

        for (j in i:(length(my_data_list))) { # row index

            D_stat_DF[j, i] <- stats::ks.test(my_data_list[[j]]$cumulative_sum, my_data_list[[i]]$cumulative_sum)$statistic
            p_val_DF[j, i] <- stats::ks.test(my_data_list[[j]]$cumulative_sum, my_data_list[[i]]$cumulative_sum)$p.value
        }
    }

    # Compile results into list
    output_list <- list(
        D_statistic = D_stat_DF,
        p_value = p_val_DF
    )

    return(output_list)
}
