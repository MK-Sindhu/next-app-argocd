FROM node:20-alpine

WORKDIR /app

COPY todo-app/package*.json ./
RUN npm install

COPY todo-app/ .
RUN npm run build

CMD ["npm", "start"]
