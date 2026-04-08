# Use the official lightweight rocker shiny image
FROM rocker/shiny:latest

# Install system dependencies required for basic R packages
RUN apt-get update && apt-get install -y \
    libcurl4-gnutls-dev \
    libcairo2-dev \
    libxt-dev \
    libssl-dev \
    libssh2-1-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install required R packages
RUN R -e "install.packages(c('beeswarm', 'vioplot', 'beanplot', 'RColorBrewer'), repos='https://cloud.r-project.org/')"

# Remove default Shiny apps
RUN rm -rf /srv/shiny-server/*

# Copy the application files to the container
COPY . /srv/shiny-server/

# Ensure proper ownership
RUN chown -R shiny:shiny /srv/shiny-server/

# Expose the shiny server port
EXPOSE 3838

# Run the Shiny server
CMD ["/usr/bin/shiny-server"]
