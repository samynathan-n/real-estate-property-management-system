import { LightningElement, api, wire } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import JSPDF from '@salesforce/resourceUrl/jspdf';
import sendLeasePdfEmail from '@salesforce/apex/LeaseDocumentService.sendLeasePdfEmail';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const FIELDS = ['Lease_Agreement__c.Name', 'Lease_Agreement__c.Property__r.Name', 'Lease_Agreement__c.Tenant__r.Name', 'Lease_Agreement__c.Agreed_Monthly_Rent__c', 'Lease_Agreement__c.Terms__c'];

export default class LeasePdfActions extends LightningElement {
    @api recordId;
    @wire(getRecord, { recordId: '$recordId', fields: FIELDS }) lease;
    isLoading = false;

    renderedCallback() {
        loadScript(this, JSPDF);
    }

    async generatePdf(isDownload) {
        const { jsPDF } = window.jspdf;
        const doc = new jsPDF();
        doc.setFontSize(22); doc.text("LEASE AGREEMENT", 20, 20);
        doc.setFontSize(12);
        doc.text(`Reference: ${getFieldValue(this.lease.data, 'Lease_Agreement__c.Name')}`, 20, 40);
        doc.text(`Property: ${getFieldValue(this.lease.data, 'Lease_Agreement__c.Property__r.Name')}`, 20, 50);
        doc.text(`Tenant: ${getFieldValue(this.lease.data, 'Lease_Agreement__c.Tenant__r.Name')}`, 20, 60);
        doc.text(`Rent: INR ${getFieldValue(this.lease.data, 'Lease_Agreement__c.Agreed_Monthly_Rent__c')}`, 20, 70);
        doc.text("Terms:", 20, 85);
        doc.text(getFieldValue(this.lease.data, 'Lease_Agreement__c.Terms__c') || 'N/A', 20, 95);

        if (isDownload) {
            doc.save('Lease.pdf');
        } else {
            return doc.output('datauristring').split(',')[1];
        }
    }

    async handleDownload() { this.generatePdf(true); }

    async handleSend() {
        this.isLoading = true;
        try {
            const base64 = await this.generatePdf(false);
            await sendLeasePdfEmail({ leaseId: this.recordId, base64Pdf: base64 });
            this.dispatchEvent(new ShowToastEvent({title: 'Success', message: 'Sent!', variant: 'success'}));
        } catch (e) { console.error(e); }
        this.isLoading = false;
    }
}