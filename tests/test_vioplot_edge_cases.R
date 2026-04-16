library(testthat)
library(sm)

context("BoxPlotR Plotting Edge Cases")

# Source the custom plot functions
source("../MyVioplot.R")

test_that("MyVioplot handles all-NA data gracefully", {
  # Create a dataset where one sample is completely NA
  plot_data <- list(
    Sample1 = c(1, 2, 3, 4, 5),
    Sample2 = c(NA_real_, NA_real_, NA_real_),
    Sample3 = c(5, 6, 7, 8, 9)
  )
  
  # vioplot should execute without crash / 'missing value where TRUE/FALSE needed'
  test_result <- tryCatch({
    pdf(file = NULL) # sink output to avoid creating Rplots.pdf
    vioplot(plot_data, at = 1:3, col = "blue")
    dev.off()
    TRUE
  }, error = function(e) {
    message("Failed with error: ", e$message)
    FALSE
  })
  
  expect_true(test_result)
})

test_that("MyVioplot handles data below minimum threshold (length < 2)", {
  # Create a dataset where one sample has only 1 valid value
  plot_data <- list(
    Sample1 = c(1, 2, 3, 4, 5),
    Sample2 = c(10, NA, NA),
    Sample3 = c(5, 6, 7, 8, 9)
  )
  
  test_result <- tryCatch({
    pdf(file = NULL) 
    vioplot(plot_data, at = 1:3, col = "blue")
    dev.off()
    TRUE
  }, error = function(e) {
    FALSE
  })
  
  expect_true(test_result)
})

test_that("MyVioplot limits logic works in horizontal mode", {
  plot_data <- list(
    Sample1 = c(1, 2, 3, 4, 5),
    Sample2 = c(2, 3, 4, 5, 6)
  )
  
  test_result <- tryCatch({
    pdf(file = NULL) 
    # Horizontal means ylim is the values scale
    vioplot(plot_data, at = 1:2, col = "blue", horizontal = TRUE, ylim = c(0, 10))
    dev.off()
    TRUE
  }, error = function(e) {
    FALSE
  })
  
  expect_true(test_result)
})
