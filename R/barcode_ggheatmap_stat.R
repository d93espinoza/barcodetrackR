#' Barcode Top Clone Heatmap
#'
#' Creates a heatmap from the columns of data in the Summarized Experiment object, with the option to label based on statistical analysis. Uses ggplot2.
#'
#'@param your_SE A Summarized Experiment object.
#'@param sample_size A numeric vector providing the sample size of each column of the SummarizedExperiment passed to the function. This sample size describes the samples that the barcoding data is meant to approximate.
#'@param stat_test The statistical test to use on the constructed contingency table for each barcoe. Options are "chi-squared" and "fisher."
#'@param stat_option For "subsequent" statistical testing is performed on each column of data compared to the column before it. For "reference," all other columns of data are compared to a reference column.
#'@param stat_ref Provide the column name of the reference column if stat_option is set to "reference." Defaults to the first column in the SummarizedExperiment.
#'@param stat_display Choose which clones to display on the heatmap. IF set to "top," the top n_clones ranked by abduncance for each sample will be displayed. If set to "change," the top n_clones with the lowest p-value from statistical testing will be shown for each sample. If set to "increase," the top n_clones (ranked by p-value) which increase in abundance for each sample will be shown. And if set to "decrease," the top n_clones (ranked by lowest p-value) which decrease in abdundance will be shown.
#'@param top_n_significant The top 'n' clones with statistically significant change in proportion, to show for each sample. This argument must be specified when stat_display is set to "change," "increase," or "decrease."
#'@param show_all_signficant Logical. If set to TRUE when stat_display = "change," "increase," or "decrease" then the top_n_significant argument will be overriden and all clones with a statistically singificant change, increase, or decrease in proportion will be shown.
#'@param p_threshold The p_value threshold to use for statistical testing
#'@param plot_labels Vector of x axis labels. Defaults to colnames(your_SE).
#'@param n_clones The top 'n' clones to plot.
#'@param cellnote_assay Character. One of "stars", "reads", or "percentages" or "p_val"
#'@param your_title The title for the plot.
#'@param grid Logical. Include a grid or not in the heatmap.
#'@param label_size The size of the column labels.
#'@param dendro Logical. Whether or not to show row dendrogram when hierarchical clustering.
#'@param cellnote_size The numerical size of the cell note labels.
#'@param distance_method Character. Use summary(proxy::pr_DB) to see all possible options for distance metrics in clustering.
#'@param minkowski_power The power of the Minkowski distance (if minkowski is the distance method used).
#'@param hclust_linkage Character. One of "ward.D", "ward.D2", "single", "complete", "average" (= UPGMA), "mcquitty" (= WPGMA), "median" (= WPGMC) or "centroid" (= UPGMC).
#'@param row_order Character; "hierarchical" to perform hierarchical clustering on the output and order in that manner, "emergence" to organize rows  by order of presence in data (from left to right), or a character vector of rows within the summarized experiment to plot.
#'@param clusters How many clusters to cut hierarchical tree into for display when row_order is "hierarchical".
#'@param percent_scale A numeric vector through which to spread the color scale (values inclusive from 0 to 1). Must be same length as color_scale.
#'@param color_scale A character vector which indicates the colors of the color scale. Must be same length as percent_scale.
#'
#'@return Displays a heatmap in the current plot window.
#'
#'@import tidyverse
#'@importFrom rlang %||%
#'@importFrom dplyr mutate_all
#'
#'@export
#'
#'@examples
#'barcode_ggheatmap(your_SE = ZH33_SE,  n_clones = 100,  grid = TRUE, label_size = 3)
#'
barcode_ggheatmap_stat <- function(your_SE,
                                   sample_size,
                                   stat_test = "chi-squared",
                                   stat_option = "subsequent",
                                   stat_ref = NULL,
                                   stat_display = "top",
                                   top_n_significant = 10,
                                   show_all_significant = FALSE,
                                   p_threshold = 0.05,
                                   plot_labels = NULL,
                                   n_clones = 10,
                                   cellnote_assay = "stars",
                                   your_title = NULL,
                                   grid = TRUE,
                                   label_size = 12,
                                   dendro = FALSE,
                                   cellnote_size = 4,
                                   distance_method = "Euclidean",
                                   minkowski_power = 2,
                                   hclust_linkage = "complete",
                                   row_order = "hierarchical",
                                   clusters = 0,
                                   percent_scale = c(0, 0.000025, 0.001, 0.01, 0.1, 1),
                                   color_scale = c("#4575B4", "#4575B4", "lightblue", "#fefeb9", "#D73027", "red4")) {
  
  # Remove elements of SE where all counts are 0
  your_SE <- your_SE[rowSums(your_SE@assays@data$counts) > 0, ]
  
  #get labels for heatmap
  plot_labels <- plot_labels %||% colnames(your_SE)
  if(length(plot_labels) != ncol(your_SE)){
    stop("plot_labels must be same length as number of columns being plotted")
  }
  
  #error checking
  if (stat_test != "chi-squared" & stat_test != "fisher"){
    stop("stat_test must be either 'chi-squared' or 'fisher'.")
  }
  
  if(length(percent_scale) != length(color_scale)){
    stop("percent_scale and color_scale must be vectors of the same length.")
  }


  # If stat_display is set to "top", we only have to perform statistical testing on the top_n barcodes for each sample.
  if (stat_display == "top"){
    top_clones_choices <- apply(SummarizedExperiment::assays(your_SE)$ranks, 1, function(x){any(x<=n_clones, na.rm = TRUE)})
    your_SE <- your_SE[top_clones_choices,]
    
    # Initialize p value matrix
    p_mat <- SummarizedExperiment::assays(your_SE)$percentages 
    
    if (stat_option == "subsequent"){
      stat_ref_index <- 1 # for book-keeping
      stat_test_index <- 2:length(colnames(your_SE))
      p_mat[,1] <- rep(1, times = nrow(your_SE)) # Fill first row with p value of 1
      for (i in stat_test_index){
        # Perform statistical test
        if (stat_test == "chi-squared"){
          p_mat[,i] <- sapply(1:nrow(your_SE), function(z) chisq.test(x = rbind(c(SummarizedExperiment::assays(your_SE)$percentages[z,i]*sample_size[i],
                                                                                  SummarizedExperiment::assays(your_SE)$percentages[z,i-1]*sample_size[i-1]),
                                                                                c(sample_size[i] - SummarizedExperiment::assays(your_SE)$percentages[z,i]*sample_size[i],
                                                                                  sample_size[i-1] - SummarizedExperiment::assays(your_SE)$percentages[z,i-1]*sample_size[i-1])))$p.val)
          p_mat[,i] <- sapply(1:nrow(your_SE), function(z) fisher.test(x = rbind(c(SummarizedExperiment::assays(your_SE)$percentages[z,i]*sample_size[i],
                                                                                  SummarizedExperiment::assays(your_SE)$percentages[z,i-1]*sample_size[i-1]),
                                                                                c(sample_size[i] - SummarizedExperiment::assays(your_SE)$percentages[z,i]*sample_size[i],
                                                                                  sample_size[i-1] - SummarizedExperiment::assays(your_SE)$percentages[z,i-1]*sample_size[i-1])))$p.val)
        }
        
      } 
    } else if (stat_option == "reference"){
      stat_ref_choice <- stat_ref %||% colnames(your_SE)[1]
      # Error checking
      if (stat_ref_choice %in% colnames(your_SE) == FALSE){
        stop("stat_ref must be a column name in your_SE")
      }
      stat_test_index <- 1:length(colnames(your_SE))
      stat_ref_index <- which(colnames(your_SE) %in% stat_ref_choice)
      stat_test_index <- stat_test_index[!stat_test_index %in% stat_ref_index] # Remove reference column
      p_mat[,stat_ref_index] <- rep(1, times = nrow(your_SE)) # Fill reference column with p value of 1
      
      for (i in stat_test_index){
        # Perform statistical test compared to reference
        if (stat_test == "chi-squared"){
          p_mat[,i] <- sapply(1:nrow(your_SE), function(z) chisq.test(x = rbind(c(SummarizedExperiment::assays(your_SE)$percentages[z,i]*sample_size[i],
                                                                                  SummarizedExperiment::assays(your_SE)$percentages[z,stat_ref_index]*sample_size[stat_ref_index]),
                                                                                c(sample_size[i] - SummarizedExperiment::assays(your_SE)$percentages[z,i]*sample_size[i],
                                                                                  sample_size[stat_ref_index] - SummarizedExperiment::assays(your_SE)$percentages[z,stat_ref_index]*sample_size[stat_ref_index])))$p.val)
        } else if (stat_test == "fisher") {
          p_mat[,i] <- sapply(1:nrow(your_SE), function(z) fisher.test(x = rbind(c(SummarizedExperiment::assays(your_SE)$percentages[z,i]*sample_size[i],
                                                                                   SummarizedExperiment::assays(your_SE)$percentages[z,stat_ref_index]*sample_size[stat_ref_index]),
                                                                                 c(sample_size[i] - SummarizedExperiment::assays(your_SE)$percentages[z,i]*sample_size[i],
                                                                                   sample_size[stat_ref_index] - SummarizedExperiment::assays(your_SE)$percentages[z,stat_ref_index]*sample_size[stat_ref_index])))$p.val)
        }
      }
      
    }
    
    # Add results of statistical testing into SE
    SummarizedExperiment::assays(your_SE)$p_val <- p_mat
    
  } else if (stat_display == "change" | stat_display == "increase" | stat_display == "decrease"){
    # Must perform statistical testing on all rows in order to rank most significant
    p_mat <- SummarizedExperiment::assays(your_SE)$percentages # Initialize matrix to store p values
    if (stat_option == "subsequent"){
      stat_ref_index <- 1 # for book-keeping
      stat_test_index <- 2:length(colnames(your_SE))
      p_mat[,1] <- rep(1, times = nrow(your_SE)) # Fill first row with p value of 1
      for (i in stat_test_index){
        # Perform statistical test
        if (stat_test == "chi-squared"){
          p_mat[,i] <- sapply(1:nrow(your_SE), function(z) chisq.test(x = rbind(c(SummarizedExperiment::assays(your_SE)$percentages[z,i]*sample_size[i],
                                                                                  SummarizedExperiment::assays(your_SE)$percentages[z,i-1]*sample_size[i-1]),
                                                                                c(sample_size[i] - SummarizedExperiment::assays(your_SE)$percentages[z,i]*sample_size[i],
                                                                                  sample_size[i-1] - SummarizedExperiment::assays(your_SE)$percentages[z,i-1]*sample_size[i-1])))$p.val)
        } else if (stat_test == "fisher") {
          p_mat[,i] <- sapply(1:nrow(your_SE), function(z) fisher.test(x = rbind(c(SummarizedExperiment::assays(your_SE)$percentages[z,i]*sample_size[i],
                                                                                   SummarizedExperiment::assays(your_SE)$percentages[z,i-1]*sample_size[i-1]),
                                                                                 c(sample_size[i] - SummarizedExperiment::assays(your_SE)$percentages[z,i]*sample_size[i],
                                                                                   sample_size[i-1] - SummarizedExperiment::assays(your_SE)$percentages[z,i-1]*sample_size[i-1])))$p.val)
        }
      } 
    } else if (stat_option == "reference"){
      stat_ref_choice <- stat_ref %||% colnames(your_SE)[1]
      # Error checking
      if (stat_ref_choice %in% colnames(your_SE) == FALSE){
        stop("stat_ref must be a column name in your_SE")
      }
      stat_test_index <- 1:length(colnames(your_SE))
      stat_ref_index <- which(colnames(your_SE) %in% stat_ref_choice)
      stat_test_index <- stat_test_index[!stat_test_index %in% stat_ref_index] # Remove reference column
      p_mat[,stat_ref_index] <- rep(1, times = nrow(your_SE)) # Fill reference column with p value of 1
      # Perform statistical test
      for (i in stat_test_index){
        # Perform statistical test compared to reference
        if (stat_test == "chi-squared"){
          p_mat[,i] <- sapply(1:nrow(your_SE), function(z) chisq.test(x = rbind(c(SummarizedExperiment::assays(your_SE)$percentages[z,i]*sample_size[i],
                                                                                  SummarizedExperiment::assays(your_SE)$percentages[z,stat_ref_index]*sample_size[stat_ref_index]),
                                                                                c(sample_size[i] - SummarizedExperiment::assays(your_SE)$percentages[z,i]*sample_size[i],
                                                                                  sample_size[stat_ref_index] - SummarizedExperiment::assays(your_SE)$percentages[z,stat_ref_index]*sample_size[stat_ref_index])))$p.val)
        } else if (stat_test == "fisher") {
          p_mat[,i] <- sapply(1:nrow(your_SE), function(z) fisher.test(x = rbind(c(SummarizedExperiment::assays(your_SE)$percentages[z,i]*sample_size[i],
                                                                                   SummarizedExperiment::assays(your_SE)$percentages[z,stat_ref_index]*sample_size[stat_ref_index]),
                                                                                 c(sample_size[i] - SummarizedExperiment::assays(your_SE)$percentages[z,i]*sample_size[i],
                                                                                   sample_size[stat_ref_index] - SummarizedExperiment::assays(your_SE)$percentages[z,stat_ref_index]*sample_size[stat_ref_index])))$p.val)
      }
      }
    }
    
    # Add results of statistical testing into SE
    SummarizedExperiment::assays(your_SE)$p_val <- p_mat
    
    # Create reference table for increasing or decreasing clones
    if (stat_display == "increase" | stat_display == "decrease"){
      increase_matrix = SummarizedExperiment::assays(your_SE)$percentages # Initialize
      increase_matrix[,stat_ref_index] <- rep("filler", times = nrow(your_SE))
      for (i in stat_test_index){
        increase_matrix[,i] <- SummarizedExperiment::assays(your_SE)$percentages[,i] > SummarizedExperiment::assays(your_SE)$percentages[,stat_ref_index]
      }
      SummarizedExperiment::assays(your_SE)$increasing <- increase_matrix
    }
    
    # Artificially set p-values to one for decreasing fold changes when the stat_display is set to increasing
    p_mat_fake <- p_mat
    if (stat_display == "increase"){
      for (i in stat_test_index){
        p_mat_fake[,i][increase_matrix[,i] == FALSE] <- rep(1,length(p_mat_fake[,i][increase_matrix[,i] == FALSE]))
      }
    } else if (stat_display == "decrease"){
      for (i in stat_test_index){ 
      p_mat_fake[,i][increase_matrix[,i] == TRUE] <- rep(1,length(p_mat_fake[,i][increase_matrix[,i] == TRUE]))
      }
    }
    SummarizedExperiment::assays(your_SE)$p_val_fake <- p_mat_fake
    
    stat_significant_clones <- apply(SummarizedExperiment::assays(your_SE)$p_val_fake, 1, function(x){any(x<=p_threshold, na.rm = TRUE)})
    your_SE <- your_SE[stat_significant_clones,]
    
    p_val_ranks <-  as.data.frame(apply(SummarizedExperiment::assays(your_SE)$p_val, 2, rank, ties.method = "min", na.last = "keep"))
    p_val_ranks[,stat_ref_index] <- rep(top_n_significant + 1, nrow(your_SE))
    SummarizedExperiment::assays(your_SE)$p_val_ranks <- p_val_ranks
    
    if (show_all_significant == FALSE){
      top_significant_clone_choices <- apply(SummarizedExperiment::assays(your_SE)$p_val_ranks, 1, function(x){any(x<=top_n_significant, na.rm = TRUE)})
      your_SE <- your_SE[top_significant_clone_choices,]
    }
  }

  
# Below here is normal barcode_ggheatmap
    
    #creates data frame with '*' for those cells w/ top clones, "NA" for those who are not. Then adds this back to the SE.
    cellnote_matrix = SummarizedExperiment::assays(your_SE)$p_val
    cellnote_matrix[cellnote_matrix > p_threshold] <- NA
    cellnote_matrix[cellnote_matrix <= p_threshold] <- "*"
    SummarizedExperiment::assays(your_SE)$stars <- as.data.frame(cellnote_matrix)

    #subset the rows of the summarized experiment and get the ordering of barcodes within the heatmap for plotting
    if(row_order == "hierarchical" | row_order == "emergence") {
    
    #this does the heavy duty plotting set-up. It sets the order of the data on the heatmap and the dendrogram/cluster cuts
    if(row_order == "hierarchical"){
      clustering_data <- SummarizedExperiment::assays(your_SE)[["logs"]]
      clustering_data.dist <- proxy::dist(clustering_data, method = distance_method, p = minkowski_power)
      hclustering <- hclust(clustering_data.dist, method = hclust_linkage)
      barcode_order <- rownames(your_SE)[hclustering$order]

      if(dendro){
        dendro_data <- ggdendro::dendro_data(hclustering, type = 'rectangle')
      }

      if(clusters>0){
        clustercuts_data <-data.frame(clusters = cutree(hclustering, clusters),
                                      assignment = factor(hclustering$labels, levels = hclustering$labels[(hclustering$order)]))
      }


    } else if(row_order == "emergence"){
      barcode_order <- rownames(your_SE)[do.call(order, SummarizedExperiment::assays(your_SE)$percentages)]
    }

  } else {
    message("using supplied row_order")
    your_SE <- your_SE[row_order,]
    barcode_order <- row_order
  }
    
  # set column names as plot_labels
  colnames(your_SE) <- plot_labels
    
  #create scale for plotting
  log_used <- S4Vectors::metadata(your_SE)$log_base
  scale_factor_used <- S4Vectors::metadata(your_SE)$scale_factor
  log_scale <- log(percent_scale*scale_factor_used + 1, base = log_used)

  #organizing data for plotting
  plotting_data <- tibble::rownames_to_column(SummarizedExperiment::assays(your_SE)[["logs"]], var = "sequence")
  plotting_data <- tidyr::pivot_longer(plotting_data, cols = -sequence, names_to = "sample_name", values_to = "value")
  plotting_data$sample_name <- factor(plotting_data$sample_name, levels = plot_labels)
  plotting_data$sequence <- factor(plotting_data$sequence, levels = barcode_order)

  #organizing labels for plotting overlay
  plotting_cellnote <- tibble::rownames_to_column(SummarizedExperiment::assays(your_SE)[[cellnote_assay]], var = "sequence")
  if(cellnote_assay == "stars"){
    plotting_cellnote <- plotting_cellnote %>% dplyr::mutate_all(as.character)
  }
  plotting_cellnote <- tidyr::pivot_longer(plotting_cellnote, cols = -sequence, names_to = "sample_name", values_to = "label")
  plotting_data$cellnote <- plotting_cellnote$label
  if(is.numeric(plotting_data$cellnote)){
    if(cellnote_assay == "percentages"){
      plotting_data$cellnote <- paste0(round(plotting_data$cellnote*100, digits = 2), "%")
    } else if (cellnote_assay == "p_val"){
      plotting_data$cellnote <- signif(plotting_data$cellnote, digits = 2)
    } else {
      plotting_data$cellnote <- round(plotting_data$cellnote, digits = 2)
    }
  }



  if(grid) grid_color = "black" else grid_color = NA

  #make a plot_label that is invisible -> use it in the dendrogram and cluster bars to make sure they are the same height as the heatmap
  invisible_label <- plot_labels[which(max(nchar(as.character(plot_labels))) == nchar(as.character(plot_labels)))[1]]


  g1_heatmap <- ggplot2::ggplot(plotting_data, ggplot2::aes(x = sample_name, y = sequence))+
    ggplot2::geom_tile(ggplot2::aes(fill = value), color = grid_color)+
    ggplot2::geom_text(ggplot2::aes(label = cellnote), vjust = 0.75, size = cellnote_size, color = "black")+
    ggplot2::scale_fill_gradientn(
      paste0("Percentage\nContribution"),
      colors = color_scale,
      values = scales::rescale(log_scale, to = c(0,1)),
      breaks = log_scale,
      limits = c(min(log_scale), max(log_scale)),
      labels = paste0(percent_scale*100, "%"),
      expand = c(0,0))+
    ggplot2::scale_y_discrete(labels = NULL, breaks = NULL, expand = c(0,0))+
    ggplot2::scale_x_discrete(expand = c(0,0))+
    ggplot2::ylab(NULL)+
    ggplot2::xlab(NULL)+
    ggplot2::ggtitle(your_title)+
    ggplot2::theme(
      plot.margin = ggplot2::unit(c(0,0,0,0), "cm"),
      plot.title = ggplot2::element_text(size = 20),
      axis.text.x = ggplot2::element_text(angle=90, hjust = 1, vjust = 0.5, size = label_size),
      #legend.text = ggplot2::element_text(size =  15, face = 'bold'),
      legend.title = ggplot2::element_text(size =  15),
      axis.ticks = ggplot2::element_blank())

  if(row_order != 'emergence'){

    if(dendro){
      g2_dendrogram <- ggplot2::ggplot(ggdendro::segment(dendro_data))+
        ggplot2::geom_segment(ggplot2::aes(x = x, y = y, xend = xend, yend = yend))+
        ggplot2::scale_x_discrete(expand = c(.5/nrow(your_SE),0.01))+
        ggplot2::scale_y_reverse(expand = c(0.01,0), labels =invisible_label, breaks = 1)+
        ggplot2::coord_flip()+
        ggplot2::ylab(NULL)+
        ggplot2::xlab(NULL)+
        ggplot2::theme(
          plot.margin = ggplot2::unit(c(0,0,0,0), "cm"),
          plot.title = ggplot2::element_text(size = 20),
          axis.text.x = ggplot2::element_text(colour = 'white', angle=90, hjust = 1, vjust = 0.5, size = label_size),
          panel.background = ggplot2::element_rect(fill = "white",colour = "white"),
          axis.ticks = ggplot2::element_blank()
        )
      if(!is.null(your_title )){
        g2_dendrogram <- g2_dendrogram + ggplot2::ggtitle("\n")
      }
    }
    if(clusters > 0){
      g3_clusters <-ggplot2::ggplot(clustercuts_data, ggplot2::aes(x = 1, y = assignment, fill = factor(clusters)))+
        ggplot2::geom_tile()+
        ggplot2::scale_x_continuous(expand=c(0,0), labels = invisible_label, breaks = 1)+
        ggplot2::theme(
          plot.margin = ggplot2::unit(c(0,0.1,0,0), "cm"),
          plot.title = ggplot2::element_text(size = 20),
          axis.title=ggplot2::element_blank(),
          axis.ticks=ggplot2::element_blank(),
          axis.text.y=ggplot2::element_blank(),
          axis.text.x = ggplot2::element_text(colour = 'white', angle=90, hjust = 1, vjust = 0.5, size = label_size),
          legend.position="none")
      if(!is.null(your_title )){
        g3_clusters <- g3_clusters + ggplot2::ggtitle("\n")
      }

    }

  }

  #now finally plot using cowplot
  if(row_order == "emergence"){
    g1_heatmap
  } else if(clusters > 0 & dendro){
    cowplot::plot_grid(g2_dendrogram, g3_clusters, g1_heatmap, rel_widths = c(1, .2, 4), ncol = 3)
  } else if (clusters == 0 & dendro){
    cowplot::plot_grid(g2_dendrogram, g1_heatmap, rel_widths = c(1, 4), ncol = 2)
  } else if (clusters > 0 & !dendro){
    cowplot::plot_grid(g3_clusters, g1_heatmap, rel_widths = c(1, .2), ncol = 2)
  } else if (clusters == 0 & !dendro){
    g1_heatmap
  }

}
