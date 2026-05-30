library(testthat)
library(ggplot2)

context("BoxPlotR ggplot2 Boxplot Tests")

test_that("ggplot2 boxplot rendering works with notches and overlays", {
  # Mock dataset
  plot_data <- list(
    Sample1 = c(1, 2, 3, 4, 5, 6, 7, 8, 9, 10),
    Sample2 = c(5, 5, 6, 7, 8, 8, 9, 10, 11, 12)
  )
  
  # Calculate boxplot stats using our custom myboxplot.stats
  source("../boxplot_stats_Function.R")
  
  bp_stats <- boxplot(plot_data, na.rm = TRUE, range = 1.5, plot = FALSE)
  
  df_stats <- data.frame(
    Group = factor(bp_stats$names, levels = names(plot_data)),
    ymin = bp_stats$stats[1, ],
    lower = bp_stats$stats[2, ],
    middle = bp_stats$stats[3, ],
    upper = bp_stats$stats[4, ],
    ymax = bp_stats$stats[5, ],
    notchlower = bp_stats$conf[1, ],
    notchupper = bp_stats$conf[2, ],
    fill = bp_stats$names
  )
  
  df_long <- data.frame(
    Value = unlist(plot_data, use.names = FALSE),
    Group = rep(names(plot_data), each = 10)
  )
  
  # Verify that building the ggplot with notches works
  test_notches <- tryCatch({
    p <- ggplot(df_stats, aes(x = Group, fill = Group)) +
      suppressWarnings(geom_boxplot(
        aes(ymin = ymin, lower = lower, middle = middle, upper = upper, ymax = ymax,
            notchlower = notchlower, notchupper = notchupper),
        stat = "identity",
        varwidth = FALSE,
        notch = TRUE,
        width = 0.6
      ))
    ggplot_build(p)
    TRUE
  }, error = function(e) {
    FALSE
  })
  expect_true(test_notches)

  # Verify that building with data points overlay works
  test_data_points <- tryCatch({
    p <- ggplot(df_stats, aes(x = Group, fill = Group)) +
      suppressWarnings(geom_boxplot(
        aes(ymin = ymin, lower = lower, middle = middle, upper = upper, ymax = ymax,
            notchlower = notchlower, notchupper = notchupper),
        stat = "identity",
        varwidth = FALSE,
        notch = TRUE,
        width = 0.6
      )) +
      geom_jitter(
        data = df_long,
        mapping = aes(y = Value),
        width = 0.05, height = 0,
        color = "black", size = 1, alpha = 0.5
      )
    ggplot_build(p)
    TRUE
  }, error = function(e) {
    FALSE
  })
  expect_true(test_data_points)

  # Verify that building with means and CI overlays works
  test_means_ci <- tryCatch({
    ci_fun <- function(x) {
      n <- sum(!is.na(x))
      if (n <= 1) return(c(ymin = NA, ymax = NA))
      se <- sd(x, na.rm = TRUE) / sqrt(n)
      t_val <- qt(0.975, df = n - 1)
      me <- t_val * se
      m <- mean(x, na.rm = TRUE)
      c(ymin = m - me, ymax = m + me)
    }
    p <- ggplot(df_stats, aes(x = Group, fill = Group)) +
      suppressWarnings(geom_boxplot(
        aes(ymin = ymin, lower = lower, middle = middle, upper = upper, ymax = ymax,
            notchlower = notchlower, notchupper = notchupper),
        stat = "identity",
        varwidth = FALSE,
        notch = TRUE,
        width = 0.6
      )) +
      stat_summary(
        data = df_long,
        aes(x = Group, y = Value),
        fun = mean,
        geom = "point",
        shape = 18,
        size = 4,
        color = "red",
        inherit.aes = FALSE
      ) +
      stat_summary(
        data = df_long,
        aes(x = Group, y = Value),
        fun.data = ci_fun,
        geom = "errorbar",
        width = 0.2,
        color = "red",
        linewidth = 0.8,
        inherit.aes = FALSE
      )
    ggplot_build(p)
    TRUE
  }, error = function(e) {
    FALSE
  })
  expect_true(test_means_ci)
})
