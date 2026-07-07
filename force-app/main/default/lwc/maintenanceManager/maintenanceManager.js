import { LightningElement, wire, track } from 'lwc';
import getMaintenanceRequests from '@salesforce/apex/MaintenanceController.getMaintenanceRequests';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const COLUMNS = [
    { label: 'Property', fieldName: 'propertyName', type: 'text' },
    { label: 'Assigned Vendor', fieldName: 'vendorName', type: 'text', cellAttributes: { class: 'slds-text-title_bold' } },
    { label: 'Status', fieldName: 'Status__c', type: 'text' },
    { label: 'Description', fieldName: 'Description__c', type: 'text' },
    { label: 'Date Raised', fieldName: 'CreatedDate', type: 'date' }
];

export default class MaintenanceManager extends LightningElement {
    @track isModalOpen = false;
    @track requests = [];
    columns = COLUMNS;
    wiredResult;

    @wire(getMaintenanceRequests)
    wiredRequests(result) {
        this.wiredResult = result;
        if (result.data) {
            // Flatten for the datatable
            this.requests = result.data.map(item => ({
                ...item,
                propertyName: item.Property__r ? item.Property__r.Name : 'N/A',
                vendorName: item.Vendor__r ? item.Vendor__r.Name : 'Assigning...'
            }));
        }
    }

    handleOpenModal() {
        this.isModalOpen = true;
    }

    handleCloseModal() {
        this.isModalOpen = false;
    }

    handleSuccess() {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Success',
            message: 'Maintenance request raised and vendor assigned!',
            variant: 'success'
        }));
        this.isModalOpen = false;
        return refreshApex(this.wiredResult);
    }

    handleError(error) {
        console.error(error);
    }
}