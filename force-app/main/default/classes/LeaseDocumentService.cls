public with sharing class LeaseDocumentService {
    @AuraEnabled
    public static void sendLeasePdfEmail(Id leaseId, String base64Pdf) {
        Lease_Agreement__c lease = [SELECT Name, Tenant__r.Email__c, Property__r.Name 
                                    FROM Lease_Agreement__c WHERE Id = :leaseId LIMIT 1];
        
        if (lease.Tenant__r.Email__c == null) throw new AuraHandledException('Tenant email is missing.');

        Messaging.EmailFileAttachment efa = new Messaging.EmailFileAttachment();
        efa.setFileName('Lease_' + lease.Name + '.pdf');
        efa.setBody(EncodingUtil.base64Decode(base64Pdf));
        efa.setContentType('application/pdf');

        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(new String[] { lease.Tenant__r.Email__c });
        email.setSubject('Your Lease Agreement - ' + lease.Property__r.Name);
        email.setPlainTextBody('Please find your signed lease agreement attached.');
        email.setFileAttachments(new Messaging.EmailFileAttachment[] { efa });

        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
    }
}