FROM node:14-alpine

# Create a working directory and copy the package.json and package-lock.json files
WORKDIR /app
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy the rest of the application code
COPY . .

# Build the Vue.js application
RUN npm run build

# Expose the default port for the Vue.js development server
EXPOSE 8080

# Set the default command to run when the container starts
CMD ["npm", "run", "serve"]
