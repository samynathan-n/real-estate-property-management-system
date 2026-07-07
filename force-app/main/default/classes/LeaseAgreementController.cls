public with sharing class LeaseAgreementController {
    @AuraEnabled(cacheable=true)
    public static List<Lease_Agreement__c> getLeaseAgreements() {
        return [SELECT Id, Name, Property__r.Name, Tenant__r.Name, Agreed_Monthly_Rent__c, Start_Date__c, End_Date__c 
                FROM Lease_Agreement__c ORDER BY CreatedDate DESC];
    }

    @AuraEnabled
    public static List<Map<String, String>> getLookupOptions(String objectName) {
        List<Map<String, String>> options = new List<Map<String, String>>();
        String query = 'SELECT Id, Name FROM ' + objectName + ' ORDER BY Name ASC';
        for(SObject s : Database.query(query)) {
            options.add(new Map<String, String>{'label' => (String)s.get('Name'), 'value' => (String)s.get('Id')});
        }
        return options;
    }
}