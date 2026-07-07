public with sharing class MaintenanceController {
    @AuraEnabled(cacheable=true)
    public static List<Maintenance_Request__c> getMaintenanceRequests() {
        return [SELECT Id, Name, 
                       Property__r.Name, 
                       Vendor__r.Name, 
                       Status__c, 
                       Description__c, 
                       CreatedDate 
                FROM Maintenance_Request__c 
                ORDER BY CreatedDate DESC];
    }
}