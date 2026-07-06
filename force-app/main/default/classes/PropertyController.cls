public with sharing class PropertyController {

    private static final Integer PAGE_SIZE = 25;

    // --- WRAPPERS ---
    public class PropertyListResult {
        @AuraEnabled public List<Property__c> records;
        @AuraEnabled public Integer totalRecords;
        @AuraEnabled public Integer pageNumber;
        @AuraEnabled public Integer totalPages;
    }

    public class PicklistOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
    }

    // --- PHASE 2: SEARCH LOGIC ---
    @AuraEnabled(cacheable=false) // Set to false because filters change
    public static PropertyListResult getProperties(
        Integer pageNumber,
        Decimal minPrice,
        Decimal maxPrice,
        String status,
        String furnishingStatus,
        Decimal distanceKm,
        Decimal userLatitude,
        Decimal userLongitude
    ) {
        if (pageNumber == null || pageNumber < 1) pageNumber = 1;
        
        List<String> whereClauses = new List<String>();
        Map<String, Object> binds = new Map<String, Object>();

        if (minPrice != null) {
            whereClauses.add('Rent__c >= :minPrice');
            binds.put('minPrice', minPrice);
        }
        if (maxPrice != null) {
            whereClauses.add('Rent__c <= :maxPrice');
            binds.put('maxPrice', maxPrice);
        }
        if (String.isNotBlank(status)) {
            whereClauses.add('Status__c = :status');
            binds.put('status', status);
        }
        if (String.isNotBlank(furnishingStatus)) {
            whereClauses.add('Furnishing_Status__c = :furnishing');
            binds.put('furnishing', furnishingStatus);
        }
        if (distanceKm != null && userLatitude != null && userLongitude != null) {
            whereClauses.add('DISTANCE(Geolocation__c, GEOLOCATION(:lat, :lon), \'km\') < :dist');
            binds.put('lat', (Double)userLatitude);
            binds.put('lon', (Double)userLongitude);
            binds.put('dist', (Double)distanceKm);
        }

        String whereStr = whereClauses.isEmpty() ? '' : ' WHERE ' + String.join(whereClauses, ' AND ');
        Integer offsetVal = (pageNumber - 1) * PAGE_SIZE;

        String recordQuery = 'SELECT Id, Name, Rent__c, Status__c, Type__c, Furnishing_Status__c, Description__c, ' +
                             'Geolocation__Latitude__s, Geolocation__Longitude__s ' +
                             'FROM Property__c' + whereStr + ' ORDER BY CreatedDate DESC LIMIT :pageSize OFFSET :offset';
        
        binds.put('pageSize', PAGE_SIZE);
        binds.put('offset', offsetVal);

        List<Property__c> records = (List<Property__c>) Database.queryWithBinds(recordQuery, binds, AccessLevel.USER_MODE);
        Integer totalRecords = Database.countQueryWithBinds('SELECT COUNT() FROM Property__c' + whereStr, binds, AccessLevel.USER_MODE);

        PropertyListResult res = new PropertyListResult();
        res.records = records;
        res.totalRecords = totalRecords;
        res.pageNumber = pageNumber;
        res.totalPages = (Integer)Math.ceil((Decimal)totalRecords / PAGE_SIZE);
        return res;
    }

    // --- PHASE 2: CREATION & IMAGE VALIDATION (Task 13) ---

    @AuraEnabled
    public static Id createProperty(Property__c property) {
        try {
            insert property;
            return property.Id;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /** 
     * THIS IS THE MISSING ACTION 
     * This method MUST be @AuraEnabled and the parameter name MUST be propertyId
     */
    @AuraEnabled
    public static void finalizeProperty(Id propertyId) {
        Integer fileCount = [SELECT COUNT() FROM ContentDocumentLink WHERE LinkedEntityId = :propertyId];
        if (fileCount == 0) {
            throw new AuraHandledException('At least one image is required before the property is finalized.');
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<String> getPropertyImages(Id propertyId) {
        List<String> imageIds = new List<String>();
        // Querying ContentDocumentLink to find files attached to the property
        for (ContentDocumentLink cdl : [SELECT ContentDocument.LatestPublishedVersionId 
                                        FROM ContentDocumentLink 
                                        WHERE LinkedEntityId = :propertyId 
                                        AND ContentDocument.FileType IN ('PNG', 'JPG', 'JPEG', 'GIF')]) {
            // Constructing the URL for the image
            imageIds.add('/sfc/servlet.shepherd/version/download/' + cdl.ContentDocument.LatestPublishedVersionId);
        }
        return imageIds;
    }

    @AuraEnabled
    public static void deleteProperty(Id propertyId) {
        try {
            delete [SELECT Id FROM Property__c WHERE Id = :propertyId];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // --- PICKLIST HELPERS ---

    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getCountryOptions() {
        return getPicklistValues('Property_Address__CountryCode__s');
    }

    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getStateOptions() {
        return getPicklistValues('Property_Address__StateCode__s');
    }

    private static List<PicklistOption> getPicklistValues(String fieldApiName) {
        List<PicklistOption> options = new List<PicklistOption>();
        Schema.DescribeFieldResult fieldResult = Property__c.sObjectType.getDescribe().fields.getMap().get(fieldApiName).getDescribe();
        for (Schema.PicklistEntry entry : fieldResult.getPicklistValues()) {
            if (entry.isActive()) {
                PicklistOption opt = new PicklistOption();
                opt.label = entry.getLabel();
                opt.value = entry.getValue();
                options.add(opt);
            }
        }
        return options;
    }
}