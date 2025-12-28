/** @type {import('tailwindcss').Config} */
export default {
    content: [
        "./index.html",
        "./src/**/*.{vue,js,ts,jsx,tsx}",
    ],
    theme: {
        extend: {
            colors: {
                'widget-bg': 'rgba(255, 255, 255, 0.1)',
                'deep-blue': '#0f172a',
            }
        },
    },
    plugins: [],
}
