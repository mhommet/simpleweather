<script setup>
import { ref, onMounted, computed } from 'vue'
import axios from 'axios'
import { format, addDays } from 'date-fns'
import { fr } from 'date-fns/locale'

// Configuration API depuis les variables d'environnement
const WORLDTIDES_API_KEY = import.meta.env.VITE_WORLDTIDES_API_KEY

// --- ETATS ---
const searchQuery = ref('')
const weather = ref(null)
const marine = ref(null)
const tides = ref([])
const loading = ref(false)
const error = ref(null)
const locationName = ref('')

const getWeatherIcon = (code) => {
  if (code === 0) return '☀️'; 
  if (code >= 1 && code <= 3) return '⛅'; 
  if (code >= 45 && code <= 48) return '🌫️'; 
  if (code >= 51 && code <= 67) return '🌧️'; 
  if (code >= 71) return '❄️'; 
  if (code >= 95) return '⚡'; 
  return '❓';
}

const getDayName = (dateStr) => {
  return format(new Date(dateStr), 'EEEE', { locale: fr });
}

// --- RÉCUPÉRATION DES MARÉES VIA WORLDTIDES API ---
const fetchTides = async (lat, lon) => {
  if (!WORLDTIDES_API_KEY) {
    console.warn('⚠️ Clé API WorldTides manquante - Configurez VITE_WORLDTIDES_API_KEY dans .env')
    return []
  }

  try {
    const now = Math.floor(Date.now() / 1000) // Timestamp Unix
    const response = await axios.get(
      `https://www.worldtides.info/api/v3?extremes&lat=${lat}&lon=${lon}&key=${WORLDTIDES_API_KEY}&start=${now}&length=86400`
    )
    
    if (response.data.extremes) {
      return response.data.extremes.map(e => ({
        type: e.type === 'High' ? 'HAUTE' : 'BASSE',
        time: new Date(e.dt * 1000).toISOString(),
        height: e.height
      }))
    }
    return []
  } catch (err) {
    console.error('Erreur WorldTides:', err)
    return []
  }
}

// --- API ---
const searchCity = async () => {
  const q = (searchQuery.value ?? '').trim() // retire espaces début/fin
  if (!q) return

  loading.value = true
  try {
    const geoRes = await axios.get(
      `https://geocoding-api.open-meteo.com/v1/search?name=${encodeURIComponent(q)}&count=1&language=fr&format=json`
    )

    if (geoRes.data.results && geoRes.data.results.length > 0) {
      const p = geoRes.data.results[0]
      searchQuery.value = q // optionnel: remet la valeur propre dans l'input
      await fetchData(p.latitude, p.longitude, (p.name ?? q).trim())
    } else {
      error.value = "Ville introuvable"
      loading.value = false
    }
  } catch (e) {
    error.value = "Erreur recherche"
    loading.value = false
  }
}


const useMyLocation = () => {
  if (!navigator.geolocation) {
    error.value = "GPS non disponible sur cet appareil";
    return;
  }

  loading.value = true;
  navigator.geolocation.getCurrentPosition(
    (pos) => fetchData(pos.coords.latitude, pos.coords.longitude, "Ma Position"),
    (err) => { 
      console.error('Erreur géolocalisation:', err);
      if (err.code === 1) {
        error.value = "Autorisez la géolocalisation dans les réglages du navigateur";
      } else if (err.code === 2) {
        error.value = "Position indisponible";
      } else if (err.code === 3) {
        error.value = "Délai de géolocalisation dépassé";
      } else {
        error.value = "Erreur GPS";
      }
      loading.value = false;
    },
    {
      enableHighAccuracy: true,
      timeout: 10000,
      maximumAge: 0
    }
  )
}

const fetchData = async (lat, lon, name) => {
  try {
    loading.value = true;
    error.value = null;
    locationName.value = (name || `${lat.toFixed(2)}, ${lon.toFixed(2)}`).trim()

    // 1. Météo
    const weatherRes = await axios.get(`https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&current=temperature_2m,weather_code,wind_speed_10m,relative_humidity_2m&daily=weather_code,temperature_2m_max,temperature_2m_min&timezone=auto`)
    weather.value = weatherRes.data

    // 2. Marine (Données de houle)
    try {
      const marineRes = await axios.get(`https://marine-api.open-meteo.com/v1/marine?latitude=${lat}&longitude=${lon}&current=wave_height&hourly=wave_height&daily=wave_height_max&timezone=auto`)
      
      if (marineRes.data.daily.wave_height_max[0] === null) {
        marine.value = null; // Terre
      } else {
        marine.value = marineRes.data;
      }
    } catch { 
      marine.value = null; 
    }

    // 3. Marées via WorldTides
    tides.value = await fetchTides(lat, lon)

  } catch (e) { 
    error.value = "Erreur réseau"; 
  } 
  finally { 
    loading.value = false; 
  }
}

// Démarrage sur Caen par défaut
onMounted(() => { 
  fetchData(49.18, -0.37, "Caen"); 
})

const todayDate = computed(() => format(new Date(), 'EEEE d MMMM', { locale: fr }))
</script>

<template>
  <div class="min-h-screen bg-slate-900 text-white p-4 font-sans flex flex-col items-center pb-32 safe-area-padding">
    
    <!-- Recherche -->
    <div class="w-full max-w-md mb-6 flex gap-2 z-50">
      <div class="relative flex-1">
        <input 
          v-model.trim="searchQuery" 
          @keyup.enter="searchCity" 
          type="text" 
          placeholder="Ville..." 
          class="w-full bg-slate-800/80 border border-slate-600 rounded-2xl py-3 px-4 pl-10 focus:border-blue-400 outline-none shadow-lg text-white placeholder-slate-400"
        >
        <span class="absolute left-3 top-3.5 text-slate-400">🔍</span>
      </div>
      <button 
        @click="useMyLocation" 
        class="bg-blue-600 rounded-2xl p-3 shadow-lg active:scale-95 transition-transform"
      >
        📍
      </button>
    </div>

    <!-- Loading / Erreur -->
    <div v-if="loading" class="mt-20 animate-pulse text-blue-300">
      Chargement...
    </div>
    <div v-else-if="error" class="mt-10 text-red-300 bg-red-900/20 p-4 rounded-2xl">
      {{ error }}
    </div>

    <!-- MAIN -->
    <div v-else-if="weather" class="w-full max-w-md space-y-5 animate-fade-in mb-20">
      
      <div class="px-2">
        <h1 class="text-3xl font-bold capitalize">{{ todayDate }}</h1>
        <h2 class="text-lg text-blue-300 flex items-center gap-1">{{ locationName }}</h2>
      </div>

      <!-- Météo Bento -->
      <div class="grid grid-cols-2 gap-4">
        <div class="col-span-2 bg-gradient-to-br from-blue-600 to-indigo-700 rounded-[2rem] p-6 shadow-xl relative overflow-hidden border border-white/10">
          <div class="relative z-10">
            <div class="text-7xl font-bold">{{ Math.round(weather.current.temperature_2m) }}°</div>
            <div class="text-blue-100 text-lg font-medium mt-1">
              {{ getWeatherIcon(weather.current.weather_code) }} Actuellement
            </div>
          </div>
        </div>
        <div class="bg-slate-800/50 backdrop-blur rounded-[1.5rem] p-4 flex flex-col justify-between aspect-square border border-white/5">
          <span class="text-xs font-bold text-slate-400 uppercase">Vent</span>
          <span class="text-2xl font-bold">
            {{ weather.current.wind_speed_10m }} 
            <small class="text-sm font-normal">km/h</small>
          </span>
          <span class="text-2xl">💨</span>
        </div>
        <div class="bg-slate-800/50 backdrop-blur rounded-[1.5rem] p-4 flex flex-col justify-between aspect-square border border-white/5">
          <span class="text-xs font-bold text-slate-400 uppercase">Humidité</span>
          <span class="text-2xl font-bold">
            {{ weather.current.relative_humidity_2m }} 
            <small class="text-sm font-normal">%</small>
          </span>
          <span class="text-2xl">💧</span>
        </div>
      </div>

      <!-- SECTION MARINE (Seulement si données) -->
      <div v-if="marine && marine.current" class="bg-blue-900/30 backdrop-blur rounded-[2rem] p-6 border border-blue-500/20">
        <div class="flex items-center gap-2 mb-4">
          <span class="text-2xl">🌊</span>
          <h3 class="font-bold text-blue-100">Océan & Marées</h3>
        </div>

        <div class="flex justify-between items-end mb-6 border-b border-white/5 pb-4">
          <div>
            <div class="text-4xl font-bold">{{ marine.current.wave_height }}m</div>
            <div class="text-xs text-blue-300">Houle</div>
          </div>
        </div>

        <!-- Marées (WorldTides API) -->
        <div v-if="tides.length > 0" class="space-y-3">
          <p class="text-[10px] text-blue-300/50 uppercase tracking-widest mb-2">
            Horaires de marée
          </p>
          <div 
            v-for="(tide, idx) in tides" 
            :key="idx" 
            class="flex justify-between items-center bg-blue-950/40 p-3 rounded-xl border border-blue-500/10"
          >
            <div class="flex items-center gap-3">
              <span class="text-xl">{{ tide.type === 'HAUTE' ? '🌊' : '⬇️' }}</span>
              <div>
                <div class="font-bold text-sm text-blue-100">
                  Marée {{ tide.type === 'HAUTE' ? 'Haute' : 'Basse' }}
                </div>
                <div class="text-xs text-blue-300">
                  {{ format(new Date(tide.time), 'HH:mm') }}
                </div>
              </div>
            </div>
            <div class="font-mono text-lg font-medium text-white">
              {{ tide.height.toFixed(2) }}m
            </div>
          </div>
        </div>
        <div v-else class="text-center text-xs text-blue-300/60 py-2">
          {{ !WORLDTIDES_API_KEY ? '⚠️ Configurez votre clé API WorldTides dans le fichier .env' : 'Pas de données de marée disponibles pour cette zone' }}
        </div>
      </div>

      <!-- Prévisions 7j -->
      <div>
        <h3 class="text-slate-400 text-xs font-bold uppercase tracking-widest mb-3 ml-2">
          7 prochains jours
        </h3>
        <div class="bg-slate-800/40 backdrop-blur rounded-[2rem] p-4 border border-white/5 space-y-1">
          <div 
            v-for="(temp, index) in weather.daily.temperature_2m_max" 
            :key="index" 
            class="flex items-center justify-between p-3 hover:bg-white/5 rounded-xl transition-colors"
          >
            <span class="w-24 font-medium capitalize text-sm">
              {{ index === 0 ? 'Auj.' : getDayName(weather.daily.time[index]) }}
            </span>
            <span class="text-xl">
              {{ getWeatherIcon(weather.daily.weather_code[index]) }}
            </span>
            <div class="flex gap-3 w-24 justify-end text-sm">
              <span class="font-bold">{{ Math.round(temp) }}°</span>
              <span class="text-slate-500">{{ Math.round(weather.daily.temperature_2m_min[index]) }}°</span>
            </div>
          </div>
        </div>
      </div>
      
    </div>
  </div>
</template>

<style>
.safe-area-padding { 
  padding-bottom: env(safe-area-inset-bottom); 
}

.animate-fade-in { 
  animation: fadeIn 0.6s ease-out; 
}

@keyframes fadeIn { 
  from { 
    opacity: 0; 
    transform: translateY(10px); 
  } 
  to { 
    opacity: 1; 
    transform: translateY(0); 
  } 
}
</style>