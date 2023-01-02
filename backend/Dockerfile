FROM node:14-alpine

# Create a working directory and copy the package.json and package-lock.json files
WORKDIR /app
COPY backend/package*.json ./

# Install dependencies
RUN npm install

# Copy the rest of the application code
COPY backend/ .

# Set the default command to run when the container starts
CMD ["node", "index.js"]
