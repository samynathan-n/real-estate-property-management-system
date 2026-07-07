import { LightningElement, wire, track } from 'lwc';
import getLeaseAgreements from '@salesforce/apex/LeaseAgreementController.getLeaseAgreements';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const COLUMNS = [
    {
        label: 'Lease ID',
        fieldName: 'recordUrl',
        type: 'url',
        typeAttributes: { 
            label: { fieldName: 'Name' }, 
            target: '_blank' 
        }
    },
    { 
        label: 'Property', 
        fieldName: 'PropertyName', 
        type: 'text' 
    },
    { 
        label: 'Tenant', 
        fieldName: 'TenantName', 
        type: 'text' 
    },
    { 
        label: 'Monthly Rent', 
        fieldName: 'Agreed_Monthly_Rent__c', 
        type: 'currency',
        typeAttributes: { currencyCode: 'INR', step: '0.01' } 
    },
    { 
        label: 'Start Date', 
        fieldName: 'Start_Date__c', 
        type: 'date-local' 
    },
    { 
        label: 'End Date', 
        fieldName: 'End_Date__c', 
        type: 'date-local' 
    }
];

export default class LeaseAgreementList extends LightningElement {
    @track isModalOpen = false;
    @track leases = [];
    columns = COLUMNS;
    wiredLeasesResult; // Tracked for refreshApex

    // Wire to the Apex controller
    @wire(getLeaseAgreements)
    wiredLeases(result) {
        this.wiredLeasesResult = result;
        if (result.data) {
            // Flatten the data: DataTables cannot read nested fields like Property__r.Name
            this.leases = result.data.map(row => {
                return {
                    ...row,
                    PropertyName: row.Property__r ? row.Property__r.Name : '',
                    TenantName: row.Tenant__r ? row.Tenant__r.Name : '',
                    recordUrl: `/lightning/r/Lease_Agreement__c/${row.Id}/view`
                };
            });
        } else if (result.error) {
            this.showToast('Error', 'Failed to load leases', 'error');
            console.error(result.error);
        }
    }

    // Modal Handlers
    openModal() {
        this.isModalOpen = true;
    }

    closeModal() {
        this.isModalOpen = false;
    }

    // Form Success Handler
    handleSuccess(event) {
        this.showToast('Success', 'Lease Agreement created successfully', 'success');
        this.isModalOpen = false;
        
        // Refresh the list immediately without reloading the page
        return refreshApex(this.wiredLeasesResult);
    }

    // Helper for Toast Notifications
    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant
            })
        );
    }
}