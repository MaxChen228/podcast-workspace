/** @type {import('tailwindcss').Config} */
export default {
    content: [
        "./index.html",
        "./src/**/*.{js,ts,jsx,tsx}",
    ],
    theme: {
        extend: {
            fontFamily: {
                sans: ['Inter', 'system-ui', 'sans-serif'],
            },
            colors: {
                background: "var(--background)",
                surface: "var(--surface)",
                "surface-hover": "var(--surface-hover)",
                "surface-active": "var(--surface-active)",
                primary: "var(--primary)",
                "primary-foreground": "var(--primary-foreground)",
                border: "var(--border)",
                muted: "var(--muted)",
                "muted-foreground": "var(--muted-foreground)",
            },
            animation: {
                "slide-up": "slideUp 0.3s ease-out",
                "fade-in": "fadeIn 0.2s ease-out",
            },
            keyframes: {
                slideUp: {
                    "0%": { transform: "translateY(10px)", opacity: 0 },
                    "100%": { transform: "translateY(0)", opacity: 1 },
                },
                fadeIn: {
                    "0%": { opacity: 0 },
                    "100%": { opacity: 1 },
                },
            },
        },
    },
    plugins: [],
}
