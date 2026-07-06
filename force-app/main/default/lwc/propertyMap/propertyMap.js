import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import getPropertyImages from '@salesforce/apex/PropertyController.getPropertyImages';

export default class PropertyDetailView extends LightningElement {
    @api recordId;
    @track imageUrls;

    // Fields using strings for safety
    fields = [
        'Property__c.Name',
        'Property__c.Rent__c',
        'Property__c.Status__c',
        'Property__c.Type__c',
        'Property__c.Furnishing_Status__c',
        'Property__c.Description__c',
        'Property__c.Geolocation__Latitude__s',
        'Property__c.Geolocation__Longitude__s'
    ];

    // Wire to a PROPERTY (not a function) so 'wiredRecord.data' works
    @wire(getRecord, { recordId: '$recordId', fields: '$fields' })
    wiredRecord;

    @wire(getPropertyImages, { propertyId: '$recordId' })
    wiredImages({ error, data }) {
        if (data) {
            this.imageUrls = data;
        } else if (error) {
            console.error('Images Error:', error);
        }
    }

    // GETTERS
    get isLoaded() {
        return this.wiredRecord && (this.wiredRecord.data || this.wiredRecord.error);
    }

    get propertyName() {
        return getFieldValue(this.wiredRecord.data, 'Property__c.Name');
    }

    get formattedRent() {
        const rent = getFieldValue(this.wiredRecord.data, 'Property__c.Rent__c');
        return rent ? '₹' + rent.toLocaleString('en-IN') : 'N/A';
    }

    get mapMarkers() {
        const lat = getFieldValue(this.wiredRecord.data, 'Property__c.Geolocation__Latitude__s');
        const lon = getFieldValue(this.wiredRecord.data, 'Property__c.Geolocation__Longitude__s');
        if (lat && lon) {
            return [{
                location: { Latitude: lat, Longitude: lon },
                title: this.propertyName
            }];
        }
        return [];
    }
}