public with sharing class VendorController {
    @AuraEnabled(cacheable=true)
    public static List<Vendor__c> getVendors() {
        // Fetching vendors to display in the management list
        return [SELECT Id, Name, Phone__c, Email__c FROM Vendor__c ORDER BY CreatedDate DESC];
    }
}