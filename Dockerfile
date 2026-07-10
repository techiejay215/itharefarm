# Use the official Flutter image with proper setup
FROM cirrusci/flutter:stable

# Set working directory
WORKDIR /app

# Enable web support
RUN flutter config --enable-web

# Copy pubspec files first (better caching)
COPY pubspec.yaml pubspec.lock* ./

# Get dependencies with verbose output
RUN flutter pub get --verbose

# Copy the rest of the code
COPY . .

# Build the web app with release mode
RUN flutter build web --release

# Use nginx to serve the files
FROM nginx:alpine

# Copy built files to nginx
COPY --from=0 /app/build/web /usr/share/nginx/html

# Expose port 80
EXPOSE 80

# Start nginx
CMD ["nginx", "-g", "daemon off;"]