FROM node:14-alpine

# Create a working directory and copy the package.json and package-lock.json files
WORKDIR /app
COPY frontend/package*.json ./

# show files
RUN ls -al

# Install dependencies
RUN npm install

# Copy the rest of the application code
COPY frontend/ .

# show files
RUN ls -al

# Build the Vue.js application
RUN npm run build

# Set the default command to run when the container starts
CMD ["npm", "run", "dev"]
