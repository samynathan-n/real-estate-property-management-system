import { LightningElement, wire, track } from 'lwc';
import getVendors from '@salesforce/apex/VendorController.getVendors';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const COLUMNS = [
    { label: 'Vendor Name', fieldName: 'Name', type: 'text' },
    { label: 'Phone', fieldName: 'Phone__c', type: 'phone' },
    { label: 'Email', fieldName: 'Email__c', type: 'email' }
];

export default class VendorList extends LightningElement {
    @track isModalOpen = false;
    @track vendors = [];
    columns = COLUMNS;
    wiredVendorsResult;

    @wire(getVendors)
    wiredVendors(result) {
        this.wiredVendorsResult = result;
        if (result.data) {
            this.vendors = result.data;
        } else if (result.error) {
            console.error('Error fetching vendors:', result.error);
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
            message: 'Vendor added to the system!',
            variant: 'success'
        }));
        this.isModalOpen = false;
        // Immediate UI update
        return refreshApex(this.wiredVendorsResult);
    }

    handleError(error) {
        console.error('Vendor Save Error:', error);
    }
}