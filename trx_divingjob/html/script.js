const { createApp } = Vue;

createApp({
    data() {
        return {
            showOxygen: false,
            oxygenPercentage: 100,
            timeUnderwater: 0,
            maxTime: 120,
            timeRemaining: 120,
            depth: 0,
            hasDivingGear: false
        }
    },
    
    methods: {
        formatTime(seconds) {
            if (seconds < 0) return '∞';
            
            const minutes = Math.floor(seconds / 60);
            const remainingSeconds = seconds % 60;
            return `${minutes}:${remainingSeconds.toString().padStart(2, '0')}`;
        },
        
        formatDepth(meters) {
            if (meters == null) return '0 m';
            const rounded = Math.max(0, Math.round(meters));
            return `${rounded} m`;
        },
        
        updateOxygen(data) {
            const clamped = Math.max(0, Math.min(100, Math.round(data.oxygen)));
            this.oxygenPercentage = clamped;
            this.timeUnderwater = data.time;
            this.maxTime = data.maxTime;
            this.timeRemaining = data.time;
            this.hasDivingGear = !!data.hasDivingGear;
            this.depth = typeof data.depth === 'number' ? data.depth : 0;
        },
        
        showOxygenUI(show) {
            this.showOxygen = show;
        }
    },
    
    mounted() {
        window.addEventListener('message', (event) => {
            const data = event.data;
            
            switch (data.type) {
                case 'showOxygen':
                    this.showOxygenUI(data.show);
                    break;
                    
                case 'updateOxygen':
                    this.updateOxygen(data);
                    break;
            }
        });
    }
}).mount('#app'); 