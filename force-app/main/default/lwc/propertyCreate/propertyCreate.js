import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import createProperty from '@salesforce/apex/PropertyController.createProperty';
import finalizeProperty from '@salesforce/apex/PropertyController.finalizeProperty';
import deleteProperty from '@salesforce/apex/PropertyController.deleteProperty';
import getCountryOptions from '@salesforce/apex/PropertyController.getCountryOptions';
import getStateOptions from '@salesforce/apex/PropertyController.getStateOptions';

const TYPE_OPTIONS = [
    { label: 'Residential', value: 'Residential' },
    { label: 'Commercial', value: 'Commercial' }
];

const FURNISHING_OPTIONS = [
    { label: 'Furnished', value: 'Furnished' },
    { label: 'Semi-Furnished', value: 'Semi-Furnished' },
    { label: 'Unfurnished', value: 'Unfurnished' }
];

const STATUS_OPTIONS = [
    { label: 'Available', value: 'Available' },
    { label: 'Occupied', value: 'Occupied' }
];

export default class PropertyCreate extends NavigationMixin(LightningElement) {
    @track step = 'form'; // 'form' -> 'upload' -> 'done'
    @track isSaving = false;
    @track draftPropertyId;
    @track uploadedFileCount = 0;

    @track countryOptions = [];
    @track stateOptions = [];

    typeOptions = TYPE_OPTIONS;
    furnishingOptions = FURNISHING_OPTIONS;
    statusOptions = STATUS_OPTIONS;

    // form fields
    fields = {
        name: '',
        street: '',
        city: '',
        state: '',      // stores the CODE (e.g. 'KA'); label shown in the dropdown
        postalCode: '',
        country: '',    // stores the CODE (e.g. 'IN'); label shown in the dropdown
        type: 'Residential',
        furnishingStatus: 'Furnished',
        status: 'Available',
        rent: null,
        description: ''
    };

    @wire(getCountryOptions)
    wiredCountries({ data, error }) {
        if (data) {
            this.countryOptions = data.map((opt) => ({ label: opt.label, value: opt.value }));
        } else if (error) {
            this.countryOptions = [];
        }
    }

    @wire(getStateOptions)
    wiredStates({ data, error }) {
        if (data) {
            this.stateOptions = data.map((opt) => ({ label: opt.label, value: opt.value }));
        } else if (error) {
            this.stateOptions = [];
        }
    }

    get isFormStep() {
        return this.step === 'form';
    }

    get isUploadStep() {
        return this.step === 'upload';
    }

    get isDoneStep() {
        return this.step === 'done';
    }

    get finishDisabled() {
        return this.uploadedFileCount === 0;
    }

    get acceptedFormats() {
        return ['.png', '.jpg', '.jpeg', '.gif'];
    }

    handleFieldChange(event) {
        const field = event.target.dataset.field;
        this.fields = { ...this.fields, [field]: event.target.value };
    }

    handleComboChange(event) {
        const field = event.target.dataset.field;
        this.fields = { ...this.fields, [field]: event.detail.value };
    }

    validateForm() {
        const inputs = this.template.querySelectorAll('lightning-input, lightning-combobox, lightning-textarea');
        let allValid = true;
        inputs.forEach((input) => {
            if (!input.reportValidity()) {
                allValid = false;
            }
        });
        return allValid;
    }

    handleCreateDraft() {
        if (!this.validateForm()) {
            return;
        }

        this.isSaving = true;

        const property = {
            Name: this.fields.name,
            Property_Address__Street__s: this.fields.street,
            Property_Address__City__s: this.fields.city,
            Property_Address__StateCode__s: this.fields.state,
            Property_Address__PostalCode__s: this.fields.postalCode,
            Property_Address__CountryCode__s: this.fields.country,
            Type__c: this.fields.type,
            Furnishing_Status__c: this.fields.furnishingStatus,
            Status__c: this.fields.status,
            Rent__c: this.fields.rent,
            Description__c: this.fields.description
        };

        createProperty({ property })
            .then((newId) => {
                this.draftPropertyId = newId;
                this.step = 'upload';
            })
            .catch((error) => {
                this.showToast('Error', this.extractErrorMessage(error), 'error');
            })
            .finally(() => {
                this.isSaving = false;
            });
    }

    handleUploadFinished(event) {
        const uploadedFiles = event.detail.files;
        this.uploadedFileCount += uploadedFiles.length;
    }

    handleFinish() {
        this.isSaving = true;

        finalizeProperty({ propertyId: this.draftPropertyId })
            .then(() => {
                this.step = 'done';
                this.showToast('Success', 'Property created successfully.', 'success');
            })
            .catch((error) => {
                this.showToast('Error', this.extractErrorMessage(error), 'error');
            })
            .finally(() => {
                this.isSaving = false;
            });
    }

    handleCancelUpload() {
        // No image was attached and the user is backing out -- clean up the draft record.
        deleteProperty({ propertyId: this.draftPropertyId })
            .then(() => {
                this.resetForm();
                this.showToast('Cancelled', 'Property creation was cancelled.', 'warning');
            })
            .catch((error) => {
                this.showToast('Error', this.extractErrorMessage(error), 'error');
            });
    }

    handleViewRecord() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.draftPropertyId,
                objectApiName: 'Property__c',
                actionName: 'view'
            }
        });
    }

    handleCreateAnother() {
        this.resetForm();
    }

    resetForm() {
        this.step = 'form';
        this.draftPropertyId = undefined;
        this.uploadedFileCount = 0;
        this.fields = {
            name: '',
            street: '',
            city: '',
            state: '',
            postalCode: '',
            country: '',
            type: 'Residential',
            furnishingStatus: 'Furnished',
            status: 'Available',
            rent: null,
            description: ''
        };
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    extractErrorMessage(error) {
        return error?.body?.message || error?.message || 'An unexpected error occurred.';
    }
}
