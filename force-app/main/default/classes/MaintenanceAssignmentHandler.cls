public with sharing class MaintenanceAssignmentHandler {
    
    public static void assignVendors(List<Maintenance_Request__c> newList) {
        // 1. Fetch all Vendors
        List<Vendor__c> vendors = [SELECT Id FROM Vendor__c];
        
        // Task 34: Handle zero-vendor edge case
        if (vendors.isEmpty()) {
            for (Maintenance_Request__c mr : newList) {
                mr.addError('No Vendors registered in the system. Please create a Vendor before raising requests.');
            }
            return;
        }

        // 2. Initialize Workload Map (VendorId -> Count)
        Map<Id, Integer> workloadMap = new Map<Id, Integer>();
        for (Vendor__c v : vendors) {
            workloadMap.put(v.Id, 0);
        }

        // 3. Task 32: Aggregate query counting "Open" or "In Progress" requests per vendor
        AggregateResult[] currentWorkloads = [
            SELECT Vendor__c, COUNT(Id) cnt 
            FROM Maintenance_Request__c 
            WHERE Status__c IN ('Open', 'In Progress') 
            AND Vendor__c IN :workloadMap.keySet()
            GROUP BY Vendor__c
        ];

        for (AggregateResult ar : currentWorkloads) {
            workloadMap.put((Id)ar.get('Vendor__c'), (Integer)ar.get('cnt'));
        }

        // 4. Task 33: Assign each new request to the vendor with the lowest count
        for (Maintenance_Request__c mr : newList) {
            Id selectedVendorId = null;
            Integer minVal = 2147483647; // Start with max integer

            // Find vendor with least workload
            for (Id vId : workloadMap.keySet()) {
                Integer currentVal = workloadMap.get(vId);
                if (currentVal < minVal) {
                    minVal = currentVal;
                    selectedVendorId = vId;
                }
            }

            // Assign the vendor
            mr.Vendor__c = selectedVendorId;

            // Increment in-memory counter so the next record in the SAME bulk insert 
            // sees that this vendor just got a new job.
            workloadMap.put(selectedVendorId, minVal + 1);
        }
    }
}