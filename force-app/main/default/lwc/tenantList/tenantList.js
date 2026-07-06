import { LightningElement, wire, track } from 'lwc';
import getTenants from '@salesforce/apex/TenantController.getTenants';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const COLUMNS = [
    { label: 'Tenant Name', fieldName: 'Name', type: 'text' },
    { label: 'Email', fieldName: 'Email__c', type: 'email' },
    { label: 'Phone', fieldName: 'Phone__c', type: 'phone' }
];

export default class TenantList extends LightningElement {
    @track isModalOpen = false;
    columns = COLUMNS;
    tenants;
    wiredTenantsResult; // Store for refresh

    @wire(getTenants)
    wiredTenants(result) {
        this.wiredTenantsResult = result;
        if (result.data) {
            this.tenants = result.data;
        } else if (result.error) {
            console.error(result.error);
        }
    }

    openModal() {
        this.isModalOpen = true;
    }

    closeModal() {
        this.isModalOpen = false;
    }

    handleSuccess(event) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Success',
                message: 'Tenant created successfully!',
                variant: 'success'
            })
        );
        this.isModalOpen = false;
        // Refresh the table data
        return refreshApex(this.wiredTenantsResult);
    }

    handleError(event) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error',
                message: event.detail.detail,
                variant: 'error'
            })
        );
    }
}