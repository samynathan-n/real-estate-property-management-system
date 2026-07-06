public with sharing class TenantController {
    @AuraEnabled(cacheable=true)
    public static List<Tenant__c> getTenants() {
        // Simple query for Phase 3 list view
        return [SELECT Id, Name, Email__c, Phone__c FROM Tenant__c ORDER BY CreatedDate DESC];
    }
}