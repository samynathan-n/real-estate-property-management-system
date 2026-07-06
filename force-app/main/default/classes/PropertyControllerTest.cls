@isTest
private class PropertyControllerTest {

    private static Property__c buildProperty(String suffix, Decimal rent, String status, String furnishing) {
        Property__c p = new Property__c();
        p.Name = 'Test Property ' + suffix;
        p.Property_Address__Street__s = '1 MG Road';
        p.Property_Address__City__s = 'Bengaluru';
        p.Property_Address__StateCode__s = 'KA';
        p.Property_Address__PostalCode__s = '560001';
        p.Property_Address__CountryCode__s = 'IN';
        p.Type__c = 'Residential';
        p.Furnishing_Status__c = furnishing;
        p.Status__c = status;
        p.Rent__c = rent;
        p.Description__c = 'Test description';
        p.Geolocation__Latitude__s = 12.9715987;
        p.Geolocation__Longitude__s = 77.5945627;
        return p;
    }

    @TestSetup
    static void setup() {
        // Disable the geocoding callout side-effect for these tests by
        // inserting outside Test.startTest with no mock -- callout failures
        // inside the trigger's batch are caught internally and won't fail insert.
        List<Property__c> props = new List<Property__c>();
        for (Integer i = 0; i < 30; i++) {
            Decimal rent = 10000 + (i * 1000);
            String status = Math.mod(i, 2) == 0 ? 'Available' : 'Occupied';
            String furnishing = Math.mod(i, 3) == 0 ? 'Furnished' : 'Unfurnished';
            props.add(buildProperty(String.valueOf(i), rent, status, furnishing));
        }
        insert props;
    }

    @isTest
    static void testPaginationFirstPage() {
        Test.startTest();
        PropertyController.PropertyListResult result = PropertyController.getProperties(1, null);
        Test.stopTest();

        System.assertEquals(25, result.records.size(), 'First page should return 25 records');
        System.assertEquals(30, result.totalRecords, 'Total records should reflect all inserted properties');
        System.assertEquals(2, result.totalPages, 'Total pages should be ceil(30/25) = 2');
    }

    @isTest
    static void testPaginationSecondPage() {
        Test.startTest();
        PropertyController.PropertyListResult result = PropertyController.getProperties(2, null);
        Test.stopTest();

        System.assertEquals(5, result.records.size(), 'Second page should return remaining 5 records');
    }

    @isTest
    static void testFilterByStatus() {
        PropertyController.PropertyFilter filter = new PropertyController.PropertyFilter();
        filter.status = 'Available';

        Test.startTest();
        PropertyController.PropertyListResult result = PropertyController.getProperties(1, filter);
        Test.stopTest();

        for (Property__c p : result.records) {
            System.assertEquals('Available', p.Status__c, 'All returned records should match the status filter');
        }
    }

    @isTest
    static void testFilterByFurnishingAndPriceRange() {
        PropertyController.PropertyFilter filter = new PropertyController.PropertyFilter();
        filter.furnishingStatus = 'Furnished';
        filter.minPrice = 10000;
        filter.maxPrice = 20000;

        Test.startTest();
        PropertyController.PropertyListResult result = PropertyController.getProperties(1, filter);
        Test.stopTest();

        for (Property__c p : result.records) {
            System.assertEquals('Furnished', p.Furnishing_Status__c, 'Furnishing filter should be applied');
            System.assert(p.Rent__c >= 10000 && p.Rent__c <= 20000, 'Rent should be within filtered range');
        }
    }

    @isTest
    static void testDistanceFilter() {
        PropertyController.PropertyFilter filter = new PropertyController.PropertyFilter();
        filter.distanceKm = 50;
        filter.userLatitude = 12.9716;
        filter.userLongitude = 77.5946;

        Test.startTest();
        PropertyController.PropertyListResult result = PropertyController.getProperties(1, filter);
        Test.stopTest();

        System.assert(result.records.size() > 0, 'Properties within 50km of the given point should be returned');
    }

    @isTest
    static void testHasAttachedImageFalseWhenNoFiles() {
        Property__c prop = [SELECT Id FROM Property__c LIMIT 1];

        Test.startTest();
        Boolean hasImage = PropertyController.hasAttachedImage(prop.Id);
        Test.stopTest();

        System.assertEquals(false, hasImage, 'No ContentDocumentLink exists yet, should return false');
    }

    @isTest
    static void testGetCountryOptionsReturnsPicklistValues() {
        Test.startTest();
        List<PropertyController.PicklistOption> options = PropertyController.getCountryOptions();
        Test.stopTest();

        System.assert(options != null, 'Country options should not be null');
        // Depending on org configuration this may be empty if no countries are
        // activated, but the call itself must not throw.
    }

    @isTest
    static void testGetStateOptionsReturnsPicklistValues() {
        Test.startTest();
        List<PropertyController.PicklistOption> options = PropertyController.getStateOptions();
        Test.stopTest();

        System.assert(options != null, 'State options should not be null');
    }

    @isTest
    static void testCreatePropertyReturnsId() {
        Property__c newProp = buildProperty('new', 15000, 'Available', 'Furnished');

        Test.startTest();
        Id newId = PropertyController.createProperty(newProp);
        Test.stopTest();

        System.assertNotEquals(null, newId, 'createProperty should return the new record Id');
    }

    @isTest
    static void testFinalizePropertyThrowsWhenNoImage() {
        Property__c prop = [SELECT Id FROM Property__c LIMIT 1];

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            PropertyController.finalizeProperty(prop.Id);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, exceptionThrown, 'finalizeProperty should throw when no image is attached');
    }

    @isTest
    static void testFinalizePropertySucceedsWithImage() {
        Property__c prop = [SELECT Id FROM Property__c LIMIT 1];

        ContentVersion cv = new ContentVersion();
        cv.Title = 'Test Image';
        cv.PathOnClient = 'test.jpg';
        cv.VersionData = Blob.valueOf('Test Content');
        insert cv;

        ContentVersion insertedCv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
        ContentDocumentLink link = new ContentDocumentLink();
        link.ContentDocumentId = insertedCv.ContentDocumentId;
        link.LinkedEntityId = prop.Id;
        link.ShareType = 'V';
        insert link;

        Test.startTest();
        PropertyController.finalizeProperty(prop.Id); // should not throw
        Test.stopTest();

        System.assert(true, 'finalizeProperty completed without exception');
    }

    @isTest
    static void testDeletePropertyRemovesDraft() {
        Property__c draft = buildProperty('draft', 12000, 'Available', 'Unfurnished');
        insert draft;

        Test.startTest();
        PropertyController.deleteProperty(draft.Id);
        Test.stopTest();

        List<Property__c> remaining = [SELECT Id FROM Property__c WHERE Id = :draft.Id];
        System.assertEquals(0, remaining.size(), 'Draft property should be deleted');
    }

    @isTest
    static void testGetCountryOptionsReturnsActiveValues() {
        Test.startTest();
        List<PropertyController.PicklistOption> options = PropertyController.getCountryOptions();
        Test.stopTest();

        System.assert(options.size() > 0, 'Country picklist should have at least one active value');
    }

    @isTest
    static void testGetStateOptionsReturnsActiveValues() {
        Test.startTest();
        List<PropertyController.PicklistOption> options = PropertyController.getStateOptions();
        Test.stopTest();

        System.assert(options.size() > 0, 'State picklist should have at least one active value');
    }

    @isTest
    static void testHasAttachedImageTrueAfterFileLink() {
        Property__c prop = [SELECT Id FROM Property__c LIMIT 1];

        ContentVersion cv = new ContentVersion();
        cv.Title = 'Test Image';
        cv.PathOnClient = 'test.jpg';
        cv.VersionData = Blob.valueOf('Test Content');
        insert cv;

        ContentVersion insertedCv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];

        ContentDocumentLink link = new ContentDocumentLink();
        link.ContentDocumentId = insertedCv.ContentDocumentId;
        link.LinkedEntityId = prop.Id;
        link.ShareType = 'V';
        insert link;

        Test.startTest();
        Boolean hasImage = PropertyController.hasAttachedImage(prop.Id);
        Test.stopTest();

        System.assertEquals(true, hasImage, 'ContentDocumentLink exists, should return true');
    }
}
