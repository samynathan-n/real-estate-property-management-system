import { LightningElement, track } from 'lwc';
import getProperties from '@salesforce/apex/PropertyController.getProperties';

const STATUS_OPTIONS = [
    { label: 'All', value: '' },
    { label: 'Available', value: 'Available' },
    { label: 'Occupied', value: 'Occupied' }
];

export default class PropertyList extends LightningElement {
    @track properties = [];
    @track isLoading = false;
    @track errorMessage;

    // Filter & Location State
    zipCode;
    distanceKm = 10; // DEFAULT RANGE 10 KM
    countryCode = ''; // Will be detected (e.g., 'in', 'us')
    
    userLatitude;
    userLongitude;

    // Pagination
    @track pageNumber = 1;
    @track totalPages = 1;
    @track totalRecords = 0;

    statusOptions = STATUS_OPTIONS;

    connectedCallback() {
        this.detectCountry(); // Get country code on load
        this.loadProperties();
    }

    /**
     * Use browser location ONLY to identify the country code (ISO 3166-1 alpha-2)
     * This prevents the Zip search from returning results in China/Global.
     */
    async detectCountry() {
        if (navigator.geolocation) {
            navigator.geolocation.getCurrentPosition(async (position) => {
                try {
                    const lat = position.coords.latitude;
                    const lon = position.coords.longitude;
                    // Reverse Geocode to get the country code
                    const response = await fetch(
                        `https://nominatim.openstreetmap.org/reverse?format=json&lat=${lat}&lon=${lon}`
                    );
                    const data = await response.json();
                    if (data.address && data.address.country_code) {
                        this.countryCode = data.address.country_code;
                        console.log('Detected Country:', this.countryCode);
                    }
                } catch (err) {
                    console.error('Country detection failed', err);
                    this.countryCode = 'in'; // Fallback to India if it fails
                }
            });
        }
    }

    // Input Handlers
    handleZipChange(e) { this.zipCode = e.target.value; }
    handleDistanceChange(e) { this.distanceKm = e.target.value; }
    
    async handleApplyFilters() {
        this.isLoading = true;
        this.errorMessage = undefined;

        try {
            if (this.zipCode) {
                // Search Zip ONLY within the detected country
                // We use &countrycodes= to restrict the search
                const url = `https://nominatim.openstreetmap.org/search?format=json&postalcode=${this.zipCode}&countrycodes=${this.countryCode}&limit=1`;
                
                const response = await fetch(url);
                const data = await response.json();

                if (data && data.length > 0) {
                    this.userLatitude = parseFloat(data[0].lat);
                    this.userLongitude = parseFloat(data[0].lon);
                } else {
                    throw new Error(`Zip ${this.zipCode} not found in country: ${this.countryCode.toUpperCase()}`);
                }
            }
            this.pageNumber = 1;
            this.loadProperties();
        } catch (error) {
            this.errorMessage = error.message;
            this.isLoading = false;
        }
    }

    loadProperties() {
        this.isLoading = true;
        getProperties({
            pageNumber: this.pageNumber,
            // (add price and status params here if you have them)
            distanceKm: this.zipCode ? this.distanceKm : null,
            userLatitude: this.userLatitude,
            userLongitude: this.userLongitude
        })
        .then(result => {
            this.totalRecords = result.totalRecords;
            this.totalPages = result.totalPages;
            this.properties = result.records.map(prop => ({
                ...prop,
                recordUrl: `/lightning/r/Property__c/${prop.Id}/view`
            }));
        })
        .catch(error => {
            this.errorMessage = error.body ? error.body.message : error.message;
        })
        .finally(() => {
            this.isLoading = false;
        });
    }

    // Standard pagination handlers
    handleNext() { if (this.pageNumber < this.totalPages) { this.pageNumber++; this.loadProperties(); } }
    handlePrevious() { if (this.pageNumber > 1) { this.pageNumber--; this.loadProperties(); } }
    get pageInfoLabel() { return `Page ${this.pageNumber} of ${this.totalPages}`; }
    get hasProperties() { return this.properties.length > 0; }
}