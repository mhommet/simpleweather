# --- ETAPE 1 : BUILD ---
FROM node:20-alpine as build-stage
WORKDIR /app

# On copie les fichiers de dépendances
COPY package*.json ./

# On installe TOUT (ce qui est dans package.json)
RUN npm install

# On copie tout le code source
COPY . .

# On construit l'application (génère le dossier /dist)
# La variable d'env est passée au build si besoin (mais pour Vite c'est mieux dans .env)
RUN npm run build

# --- ETAPE 2 : PRODUCTION (NGINX) ---
FROM nginx:alpine as production-stage
WORKDIR /usr/share/nginx/html

# On nettoie le dossier par défaut de Nginx
RUN rm -rf ./*

# On copie le dossier dist généré à l'étape 1
COPY --from=build-stage /app/dist .

# On copie une config Nginx personnalisée pour la PWA (SPA routing)
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
